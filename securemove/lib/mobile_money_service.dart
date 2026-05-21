import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'backend_config.dart';

class MobileMoneyPayment {
  const MobileMoneyPayment({
    required this.paymentId,
    required this.bookingId,
    required this.amount,
    required this.provider,
    required this.transactionReference,
    required this.status,
  });

  factory MobileMoneyPayment.fromJson(Map<String, dynamic> json) {
    return MobileMoneyPayment(
      paymentId: json['payment_id'] as int? ?? 0,
      bookingId: json['booking_id'] as int? ?? 0,
      amount: _readAmount(json['amount']),
      provider: (json['provider'] as String?) ?? 'unknown',
      transactionReference:
          (json['transaction_reference'] as String?) ?? 'unknown',
      status: (json['status'] as String?) ?? 'pending',
    );
  }

  final int paymentId;
  final int bookingId;
  final double amount;
  final String provider;
  final String transactionReference;
  final String status;

  bool get isSuccessful => status == 'successful';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending';

  static double _readAmount(dynamic rawValue) {
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    if (rawValue is String) {
      return double.tryParse(rawValue) ?? 0;
    }
    return 0;
  }
}

class MobileMoneyResult {
  const MobileMoneyResult({
    required this.payment,
    this.providerStatus,
    this.message,
  });

  factory MobileMoneyResult.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'] as Map<String, dynamic>?;
    if (payment == null) {
      throw const AuthException(
        'The backend did not return a mobile money payment record.',
      );
    }

    return MobileMoneyResult(
      payment: MobileMoneyPayment.fromJson(payment),
      providerStatus: json['providerStatus'],
      message: json['message'] as String?,
    );
  }

  final MobileMoneyPayment payment;
  final dynamic providerStatus;
  final String? message;
}

class MobileMoneyProviderStatus {
  const MobileMoneyProviderStatus({
    required this.enabled,
    required this.simulated,
  });

  factory MobileMoneyProviderStatus.fromJson(Map<String, dynamic> json) {
    return MobileMoneyProviderStatus(
      enabled: json['enabled'] as bool? ?? false,
      simulated: json['simulated'] as bool? ?? false,
    );
  }

  final bool enabled;
  final bool simulated;
}

class MobileMoneyConfig {
  const MobileMoneyConfig({
    required this.mode,
    required this.mtn,
    required this.airtel,
    required this.enabled,
    this.message,
    this.provider,
    this.currency = 'ZMW',
  });

  factory MobileMoneyConfig.fromJson(Map<String, dynamic> json) {
    final providers = json['providers'] as Map<String, dynamic>? ?? const {};
    return MobileMoneyConfig(
      mode: (json['mode'] as String?) ?? 'mock',
      enabled: json['enabled'] as bool? ?? true,
      message: json['message'] as String?,
      provider: json['provider'] as String?,
      currency: (json['currency'] as String?) ?? 'ZMW',
      mtn: MobileMoneyProviderStatus.fromJson(
        providers['mtn'] as Map<String, dynamic>? ?? const {},
      ),
      airtel: MobileMoneyProviderStatus.fromJson(
        providers['airtel'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final String mode;
  final MobileMoneyProviderStatus mtn;
  final MobileMoneyProviderStatus airtel;
  final bool enabled;
  final String? message;
  final String? provider;
  final String currency;

  bool get isMockMode => mode == 'mock';
  bool get hasAnyProvider => enabled && (isMockMode || mtn.enabled || airtel.enabled);
}

class MobileMoneyService {
  MobileMoneyService._();

  static final MobileMoneyService instance = MobileMoneyService._();

  String get _baseUrl => BackendConfig.paymentBaseUrl;

  Future<MobileMoneyResult> initiatePayment({
    required int bookingId,
    required String provider,
    required String phoneNumber,
    required double amount,
  }) async {
    final token = await _requireToken();

    final response = await _post(
      '/payments/mobile-money/initiate',
      token: token,
      body: {
        'bookingId': bookingId,
        'provider': provider,
        'phoneNumber': phoneNumber,
        'amount': amount,
      },
      featureName: 'Mobile money payment',
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return MobileMoneyResult.fromJson(body);
  }

  Future<MobileMoneyResult> getPaymentStatus(int paymentId) async {
    final token = await _requireToken();

    http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$_baseUrl/payments/$paymentId/status'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException catch (error) {
      throw AuthException(
        'Payment status timed out while contacting $_baseUrl.\nDetails: $error',
      );
    } on http.ClientException catch (error) {
      throw AuthException(
        '${BackendConfig.buildConnectionHelp(featureName: 'Payment status', baseUrl: _baseUrl)}\nDetails: ${error.message}',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractErrorMessage(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return MobileMoneyResult.fromJson(body);
  }

  Future<MobileMoneyConfig> getConfig() async {
    final token = await _requireToken();

    http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$_baseUrl/payments/mobile-money/config'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (error) {
      throw AuthException(
        'Mobile money config timed out while contacting $_baseUrl.\nDetails: $error',
      );
    } on http.ClientException catch (error) {
      throw AuthException(
        '${BackendConfig.buildConnectionHelp(featureName: 'Mobile money config', baseUrl: _baseUrl)}\nDetails: ${error.message}',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractErrorMessage(response));
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return MobileMoneyConfig.fromJson(body);
    } catch (_) {
      throw const AuthException('Mobile money temporarily unavailable, try again later.');
    }
  }

  Future<String> _requireToken() async {
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Please log in again to continue.');
    }
    return token;
  }

  Future<http.Response> _post(
    String path, {
    required String token,
    required Map<String, dynamic> body,
    required String featureName,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(_extractErrorMessage(response));
      }

      return response;
    } on TimeoutException catch (error) {
      throw AuthException(
        '$featureName timed out while contacting $_baseUrl.\nDetails: $error',
      );
    } on http.ClientException catch (error) {
      throw AuthException(
        '${BackendConfig.buildConnectionHelp(featureName: featureName, baseUrl: _baseUrl)}\nDetails: ${error.message}',
      );
    }
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

    return 'Payment request failed with status ${response.statusCode}.';
  }
}
