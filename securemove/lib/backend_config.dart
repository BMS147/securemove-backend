class BackendConfig {
  BackendConfig._();

  static const _defaultRenderAuthBaseUrl =
      'http://localhost:3000';
  static const _defaultRenderPaymentBaseUrl =
      'http://localhost:3000';

  static const _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const _configuredPaymentApiBaseUrl = String.fromEnvironment(
    'PAYMENT_API_BASE_URL',
    defaultValue: '',
  );

  static String get authBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) {
      return _configuredApiBaseUrl;
    }

    return _defaultBaseUrl;
  }

  static String get paymentBaseUrl {
    if (_configuredPaymentApiBaseUrl.isNotEmpty) {
      return _configuredPaymentApiBaseUrl;
    }

    return _defaultPaymentBaseUrl;
  }

  static String get _defaultBaseUrl {
    return _defaultRenderAuthBaseUrl;
  }

  static String get _defaultPaymentBaseUrl {
    return _defaultRenderPaymentBaseUrl;
  }

  static String buildConnectionHelp({
    required String featureName,
    required String baseUrl,
  }) {
    return '$featureName could not reach $baseUrl. The app now defaults to your Render auth backend. If you are testing a different server, override it with --dart-define=API_BASE_URL=https://your-service.onrender.com.';
  }
}
