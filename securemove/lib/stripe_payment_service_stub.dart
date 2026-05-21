import 'bus.dart';

class StripePaymentService {
  StripePaymentService._();

  static final StripePaymentService instance = StripePaymentService._();

  bool get isSupportedPlatform => false;
  bool get hasPublishableKey => false;
  bool get isReady => false;
  String get currency => 'zmw';

  String get missingConfigurationMessage {
    return 'Stripe test checkout is currently enabled for Android and iPhone builds only.';
  }

  Future<void> initialize() async {}

  Future<void> payForBus(
    Bus bus, {
    double? amount,
    int ticketCount = 1,
    DateTime? travelDate,
  }) async {
    throw const PaymentException(
      'Stripe test checkout is currently enabled for Android and iPhone builds only.',
    );
  }
}

class PaymentException implements Exception {
  const PaymentException(this.message);

  final String message;
}
