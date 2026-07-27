import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'backend_config.dart';
import 'auth_token_storage.dart';

class AuthService {
  AuthService._();
  int _failedLoginAttempts = 0;
  static const _requestTimeout = Duration(seconds: 30);
  static const _offlineMessage =
      "You're offline. Please go online and try again.";

  void _logEvent(String action, String status) {
    debugPrint("ACTION: $action | STATUS: $status | TIME: ${DateTime.now()}");
  }

  static final AuthService instance = AuthService._();
  static const _storage = AuthTokenStorage();
  static const _tokenKey = 'secure_move_token';
  static const _emailKey = 'secure_move_email';

  String get _baseUrl => BackendConfig.authBaseUrl;

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name.trim(),
              'email': _normalizeEmail(email),
              'password': password,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AuthException(_offlineMessage);
    } on http.ClientException {
      throw const AuthException(_offlineMessage);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final message = _extractErrorMessage(response);
    if (message.toLowerCase().contains('duplicate') ||
        message.toLowerCase().contains('already exists')) {
      throw const AuthException('An account with this email already exists.');
    }

    throw AuthException(message);
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _postPublic(
      '/auth/verify-email',
      body: {
        'email': _normalizeEmail(email),
        'code': code.trim(),
      },
      featureName: 'Email verification',
    );
  }

  Future<void> resendEmailVerification({
    required String email,
  }) async {
    await _postPublic(
      '/auth/verification/resend',
      body: {'email': _normalizeEmail(email)},
      featureName: 'Email verification',
    );
  }

  Future<void> requestPasswordReset({
    required String email,
  }) async {
    await _postPublic(
      '/auth/password/forgot',
      body: {'email': _normalizeEmail(email)},
      featureName: 'Password reset',
    );
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    await _postPublic(
      '/auth/password/reset',
      body: {
        'email': _normalizeEmail(email),
        'code': code.trim(),
        'password': password,
      },
      featureName: 'Password reset',
    );
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': normalizedEmail,
              'password': password,
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AuthException(_offlineMessage);
    } on http.ClientException {
      throw const AuthException(_offlineMessage);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _failedLoginAttempts = 0;
      _logEvent("Login", "Success");
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final token = body['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const AuthException('Login failed. No token returned.');
      }

      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _emailKey, value: normalizedEmail);
      return;
    }

    final message = _extractErrorMessage(response);
    _failedLoginAttempts++;

    _logEvent("Login", "Failed");

    if (_failedLoginAttempts >= 3) {
      _logEvent("Fraud Alert", "Multiple failed logins");
    }
    if (message.toLowerCase().contains('invalid credentials')) {
      throw const AuthException('Wrong email or password.');
    }

    throw AuthException(
      message,
      code: _extractErrorCode(response),
    );
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
  }

  Future<void> expireSession() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<String?> getSavedEmail() => _storage.read(key: _emailKey);

  Future<List<SecurityAuditEvent>> getSecurityAuditEvents({
    int limit = 25,
    bool includeAllAvailable = false,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Please log in again to view security activity.');
    }

    final profile = await getCurrentUserProfile();
    final queryParameters = <String, String>{
      'limit': '$limit',
      if (includeAllAvailable && profile?.roleId == 3) 'scope': 'all',
    };

    http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$_baseUrl/security/audit-logs').replace(
              queryParameters: queryParameters,
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException catch (error) {
      throw AuthException(
        'Security activity timed out while contacting $_baseUrl. If this is Render, the service may still be waking up. Please wait a moment and try again.\nDetails: $error',
      );
    } on http.ClientException catch (error) {
      throw AuthException(
        '${BackendConfig.buildConnectionHelp(
          featureName: 'Security activity',
          baseUrl: _baseUrl,
        )}\nDetails: ${error.message}',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AuthException(
        'Your session expired. Please log in again to view security activity.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractErrorMessage(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final logs = body['logs'];
    if (logs is! List) {
      return const [];
    }

    return logs
        .whereType<Map<String, dynamic>>()
        .map(SecurityAuditEvent.fromJson)
        .toList();
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final token = await getToken();
    final email = await getSavedEmail();

    if (token == null || token.isEmpty) {
      if (email == null || email.isEmpty) {
        return null;
      }
      return UserProfile(email: email);
    }

    try {
      final liveProfile = await _fetchCurrentUserProfile(token);
      if (liveProfile != null) {
        return liveProfile;
      }
    } catch (_) {
      // Fall back to JWT decoding when the /auth/me endpoint is unavailable.
    }

    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return UserProfile(email: email ?? '');
      }

      final normalizedPayload = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalizedPayload));
      final data = jsonDecode(payload) as Map<String, dynamic>;

      return UserProfile(
        userId: data['user_id'] is int ? data['user_id'] as int : null,
        name: data['name'] as String?,
        email: (data['email'] as String?) ?? (email ?? ''),
        roleId: data['role_id'] is int ? data['role_id'] as int : null,
        role: data['role'] as String?,
        companyId: data['company_id'] is int ? data['company_id'] as int : null,
      );
    } catch (_) {
      if (email == null || email.isEmpty) {
        return null;
      }

      return UserProfile(email: email);
    }
  }

  Future<UserProfile?> _fetchCurrentUserProfile(String token) async {
    http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$_baseUrl/auth/me'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      return null;
    } on http.ClientException {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final user = body['user'];
    if (user is! Map<String, dynamic>) {
      return null;
    }

    return UserProfile(
      userId: user['user_id'] is int ? user['user_id'] as int : null,
      name: user['name'] as String?,
      email: (user['email'] as String?) ?? '',
      roleId: user['role_id'] is int ? user['role_id'] as int : null,
      role: user['role'] as String?,
      companyId: user['company_id'] is int ? user['company_id'] as int : null,
    );
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        final message = body['message'];
        if (error is String && error.isNotEmpty) {
          return error;
        }
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      return 'The server returned an invalid error response.';
    }

    return 'Request failed with status ${response.statusCode}.';
  }

  String? _extractErrorCode(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final code = body['code'];
        if (code is String && code.isNotEmpty) {
          return code;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> _postPublic(
    String path, {
    required Map<String, dynamic> body,
    required String featureName,
  }) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw AuthException('$_offlineMessage $featureName timed out.');
    } on http.ClientException {
      throw const AuthException(_offlineMessage);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw AuthException(
      _extractErrorMessage(response),
      code: _extractErrorCode(response),
    );
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();
}

class AuthException implements Exception {
  const AuthException(this.message, {this.code});

  final String message;
  final String? code;
}

class UserProfile {
  const UserProfile({
    required this.email,
    this.userId,
    this.name,
    this.roleId,
    this.role,
    this.companyId,
  });

  final int? userId;
  final String email;
  final String? name;
  final int? roleId;
  final String? role;
  final int? companyId;

  String get displayName {
    final explicitName = name?.trim() ?? '';
    if (explicitName.isNotEmpty) {
      return explicitName;
    }

    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) {
      return 'SecureMove User';
    }

    return localPart
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String get initials {
    final chunks = displayName.split(' ').where((part) => part.isNotEmpty);
    final letters = chunks.take(2).map((part) => part[0].toUpperCase()).join();
    return letters.isEmpty ? 'SM' : letters;
  }

  String get roleLabel {
    switch (roleValue) {
      case 'company_admin':
        return 'Company Admin';
      case 'super_admin':
        return 'System Admin';
      case 'conductor':
        return 'Conductor';
      case 'driver':
        return 'Driver';
      default:
        return 'Traveler';
    }
  }

  String get roleValue {
    final explicitRole = role?.trim();
    if (explicitRole != null && explicitRole.isNotEmpty) {
      return explicitRole;
    }

    switch (roleId) {
      case 2:
        return 'company_admin';
      case 3:
        return 'super_admin';
      case 4:
        return 'driver';
      case 5:
        return 'conductor';
      default:
        return 'passenger';
    }
  }
}

class SecurityAuditEvent {
  const SecurityAuditEvent({
    required this.id,
    required this.eventType,
    required this.status,
    required this.severity,
    required this.createdAt,
    this.email,
    this.userId,
    this.ipAddress,
    this.userAgent,
    this.details,
  });

  factory SecurityAuditEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    final createdAtRaw = json['created_at'];
    if (createdAtRaw is String && createdAtRaw.isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(createdAtRaw)?.toLocal();
    }

    return SecurityAuditEvent(
      id: json['audit_log_id'] is int ? json['audit_log_id'] as int : 0,
      eventType: (json['event_type'] as String?) ?? 'unknown_event',
      status: (json['status'] as String?) ?? 'unknown',
      severity: (json['severity'] as String?) ?? 'info',
      createdAt: parsedCreatedAt ?? DateTime.now(),
      email: json['email'] as String?,
      userId: json['user_id'] is int ? json['user_id'] as int : null,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      details: json['details'] is Map<String, dynamic>
          ? json['details'] as Map<String, dynamic>
          : null,
    );
  }

  final int id;
  final String eventType;
  final String status;
  final String severity;
  final DateTime createdAt;
  final String? email;
  final int? userId;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic>? details;

  String get title {
    switch (eventType) {
      case 'login_success':
        return 'Successful login';
      case 'login_failed':
        return 'Failed login attempt';
      case 'fraud_alert':
        return 'Fraud alert triggered';
      case 'register_success':
        return 'Account created';
      case 'register_failed':
        return 'Account creation failed';
      default:
        return eventType.replaceAll('_', ' ');
    }
  }

  String get severityLabel => severity.toUpperCase();

  String get summary {
    final reason = details?['reason'];
    if (reason is String && reason.isNotEmpty) {
      return reason;
    }

    if (status == 'success') {
      return 'Completed successfully';
    }

    return status.replaceAll('_', ' ');
  }
}
