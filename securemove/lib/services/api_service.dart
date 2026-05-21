import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth_service.dart';
import '../backend_config.dart';

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  String get baseUrl => BackendConfig.authBaseUrl;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body: body);
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _send('PUT', path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('Please log in again to continue.');
    }

    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final response = await _sendWithRetry(
      method,
      uri,
      headers,
      body: body,
      retries: 3,
    );

    final decoded = _decodeJson(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['error'] ?? decoded['message'];
      throw ApiException(
        message is String && message.isNotEmpty
            ? message
            : 'Request failed with status ${response.statusCode}.',
      );
    }

    return decoded;
  }

  Future<http.Response> getWithRetry(String endpoint, {int retries = 3}) async {
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('Please log in again to continue.');
    }
    return _sendWithRetry(
      'GET',
      Uri.parse('$baseUrl$endpoint'),
      {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      retries: retries,
    );
  }

  Future<http.Response> _sendWithRetry(
    String method,
    Uri uri,
    Map<String, String> headers, {
    Map<String, dynamic>? body,
    int retries = 3,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < retries; attempt++) {
      try {
        switch (method) {
          case 'POST':
            return await http
                .post(uri, headers: headers, body: jsonEncode(body ?? {}))
                .timeout(const Duration(seconds: 30));
          case 'PUT':
            return await http
                .put(uri, headers: headers, body: jsonEncode(body ?? {}))
                .timeout(const Duration(seconds: 30));
          case 'DELETE':
            return await http
                .delete(uri, headers: headers)
                .timeout(const Duration(seconds: 30));
          default:
            return await http
                .get(uri, headers: headers)
                .timeout(const Duration(seconds: 30));
        }
      } on TimeoutException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }

      if (attempt < retries - 1) {
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    }

    throw ApiException(
      'SecureMove API is waking up or temporarily unavailable. Please retry in a moment.',
      cause: lastError,
    );
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'items': decoded};
    } catch (_) {
      if (response.statusCode >= 400) {
        return {
          'error':
              'SecureMove API route is unavailable. Restart or redeploy the backend and try again.',
        };
      }
      throw const ApiException('The server returned an invalid JSON response.');
    }

    return const {};
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.cause});
  final String message;
  final Object? cause;
}
