import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_screens.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) {
    return _FallbackErrorView(details: details);
  };

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

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
    return ColoredBox(
      color: const Color(0xFFF4F7FB),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DefaultTextStyle(
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFF2A54C6),
                        size: 32,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'This section had a problem',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Go back or retry the action.',
                        style: TextStyle(
                          color: Color(0xFF5E6C87),
                          height: 1.35,
                        ),
                      ),
                      if (Navigator.canPop(context)) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Go back'),
                        ),
                      ],
                      if (kDebugMode) ...[
                        const SizedBox(height: 10),
                        Text(
                          details.exceptionAsString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFEF4444),
                            fontFamily: 'monospace',
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
