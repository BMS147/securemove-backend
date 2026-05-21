import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';

import 'backend_config.dart';
import 'bus.dart';

class StripePaymentService {
  StripePaymentService._();

  static final StripePaymentService instance = StripePaymentService._();
  static const _configuredPublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );
  static const _configuredCurrency = String.fromEnvironment(
    'STRIPE_CURRENCY',
    defaultValue: 'zmw',
  );

  bool get isSupportedPlatform => Platform.isAndroid || Platform.isIOS;
  bool get hasPublishableKey => _configuredPublishableKey.isNotEmpty;
  bool get isReady => isSupportedPlatform && hasPublishableKey;

  String get currency => _configuredCurrency.toLowerCase();

  String get missingConfigurationMessage {
    if (!isSupportedPlatform) {
      return 'Stripe test checkout is currently enabled for Android and iPhone builds only.';
    }

    return 'Add your test publishable key with --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_... before using Stripe checkout.';
  }

  Future<void> initialize() async {
    if (!isReady) {
      return;
    }

    Stripe.publishableKey = _configuredPublishableKey;
    await Stripe.instance.applySettings();
  }

  Future<void> payForBus(
    Bus bus, {
    double? amount,
    int ticketCount = 1,
    DateTime? travelDate,
  }) async {
    if (!isReady) {
      throw PaymentException(missingConfigurationMessage);
    }

    final clientSecret = await _createPaymentIntent(
      amount: amount == null
          ? _priceToSmallestUnit(bus.price)
          : (amount * 100).round(),
      description: _buildDescription(
        bus,
        ticketCount: ticketCount,
        travelDate: travelDate,
      ),
    );

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'SecureMove',
        paymentIntentClientSecret: clientSecret,
      ),
    );

    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (error) {
      final localizedMessage = error.error.localizedMessage;
      throw PaymentException(
        localizedMessage == null || localizedMessage.isEmpty
            ? 'Stripe checkout was canceled.'
            : localizedMessage,
      );
    }
  }

  Future<String> _createPaymentIntent({
    required int amount,
    required String description,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/payments/create-intent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount,
        'currency': currency,
        'description': description,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentException(_extractErrorMessage(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final clientSecret =
        body['clientSecret'] as String? ?? body['client_secret'] as String?;

    if (clientSecret == null || clientSecret.isEmpty) {
      throw const PaymentException(
        'Your payments endpoint did not return a Stripe client secret.',
      );
    }

    return clientSecret;
  }

  String get _baseUrl => BackendConfig.paymentBaseUrl;

  String _buildDescription(
    Bus bus, {
    required int ticketCount,
    required DateTime? travelDate,
  }) {
    final dateLabel = travelDate == null
        ? null
        : '${travelDate.day}/${travelDate.month}/${travelDate.year}';
    final ticketLabel = ticketCount == 1 ? '1 ticket' : '$ticketCount tickets';
    final dateSuffix = dateLabel == null ? '' : ' on $dateLabel';
    return 'SecureMove $ticketLabel for ${bus.company} at ${bus.time}$dateSuffix';
  }

  int _priceToSmallestUnit(String rawPrice) {
    final cleaned = rawPrice.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (cleaned.isEmpty) {
      throw PaymentException(
        'Could not read the ticket price "$rawPrice" for Stripe checkout.',
      );
    }

    final normalized = cleaned.contains(',') && !cleaned.contains('.')
        ? cleaned.replaceAll(',', '.')
        : cleaned.replaceAll(',', '');

    final parsed = double.tryParse(normalized);
    if (parsed == null) {
      throw PaymentException(
        'Could not convert the ticket price "$rawPrice" into a Stripe amount.',
      );
    }

    return (parsed * 100).round();
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

class PaymentException implements Exception {
  const PaymentException(this.message);

  final String message;
}
