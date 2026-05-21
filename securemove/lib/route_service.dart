import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'backend_config.dart';
import 'bus.dart';

class RouteService {
  RouteService._();

  static final RouteService instance = RouteService._();

  String get _baseUrl => BackendConfig.authBaseUrl;

  Future<List<Bus>> searchRoutes({
    required String from,
    required String to,
  }) async {
    http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$_baseUrl/routes/search').replace(
              queryParameters: {
                'from': from.trim(),
                'to': to.trim(),
              },
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException catch (error) {
      throw AuthException(
        'Route search timed out while contacting $_baseUrl. If this is Render, the service may still be waking up. Please wait a moment and try again.\nDetails: $error',
      );
    } on http.ClientException catch (error) {
      throw AuthException(
        '${BackendConfig.buildConnectionHelp(
          featureName: 'Route search',
          baseUrl: _baseUrl,
        )}\nDetails: ${error.message}',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractErrorMessage(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = body['routes'];
    if (routes is! List) {
      return const [];
    }

    return routes
        .whereType<Map<String, dynamic>>()
        .map(Bus.fromJson)
        .toList();
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

    return 'Route request failed with status ${response.statusCode}.';
  }
}
