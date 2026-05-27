import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_screens.dart';
import 'stripe_payment_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) {
    return _FallbackErrorView(details: details);
  };

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  try {
    await StripePaymentService.instance.initialize();
  } catch (_) {
    // The app can still boot and show a helpful message in the payment UI.
  }

  runApp(const SecureMoveApp());
}

class SecureMoveApp extends StatefulWidget {
  const SecureMoveApp({super.key});

  @override
  State<SecureMoveApp> createState() => _SecureMoveAppState();
}

class _SecureMoveAppState extends State<SecureMoveApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _sessionExpiredInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _expireSessionInBackground();
      case AppLifecycleState.resumed:
        _returnToLoginIfExpired();
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _expireSessionInBackground() async {
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    _sessionExpiredInBackground = true;
    await AuthService.instance.expireSession();
  }

  void _returnToLoginIfExpired() {
    if (!_sessionExpiredInBackground) {
      return;
    }

    _sessionExpiredInBackground = false;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    navigator.pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'SecureMove',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routes: {
        '/': (_) => const LoginScreen(),
      },
      initialRoute: '/',
    );
  }
}

class _FallbackErrorView extends StatelessWidget {
  const _FallbackErrorView({
    required this.details,
  });

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F7FB),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x100F2554),
                    blurRadius: 28,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFF2A54C6),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Something went wrong',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'The app hit an unexpected problem. Please go back and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF5E6C87),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
