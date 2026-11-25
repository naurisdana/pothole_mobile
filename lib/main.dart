import 'package:flutter/material.dart';

import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'screens/app_entry.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/onboarding_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RoadSafeApp());
}

class RoadSafeApp extends StatefulWidget {
  const RoadSafeApp({
    super.key,
    this.store = const OnboardingStore(),
    this.requestAccess,
    this.splashHold = const Duration(milliseconds: 1600),
  });

  final OnboardingStore store;
  final Future<void> Function()? requestAccess;
  final Duration splashHold;

  @override
  State<RoadSafeApp> createState() => _RoadSafeAppState();
}

class _RoadSafeAppState extends State<RoadSafeApp> {
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
  }

  @override
  void dispose() {
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthProviderScope(
      notifier: _authProvider,
      child: MaterialApp(
        title: 'RoadSafe',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B6CFF)),
          scaffoldBackgroundColor: const Color(0xFFF7F8FB),
          fontFamily: 'Roboto',
        ),
        home: widget.requestAccess != null
            ? AppEntry(
                store: widget.store,
                requestAccess: widget.requestAccess,
                splashHold: widget.splashHold,
              )
            : _SessionStart(
                store: widget.store,
                splashHold: widget.splashHold,
              ),
      ),
    );
  }
}

/// Logo pembuka, lalu sesi backend, izin pertama, dan portal utama.
class _SessionStart extends StatefulWidget {
  const _SessionStart({required this.store, required this.splashHold});

  final OnboardingStore store;
  final Duration splashHold;

  @override
  State<_SessionStart> createState() => _SessionStartState();
}

class _SessionStartState extends State<_SessionStart> {
  var _ready = false;
  var _onboarded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final auth = AuthProvider.of(context, listen: false);
    await auth.checkAuthSession();
    final onboarded = await widget.store.isCompleted();
    await Future<void>.delayed(widget.splashHold);
    if (!mounted) return;
    setState(() {
      _onboarded = onboarded;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SplashScreen();
    final auth = AuthProvider.of(context);
    if (!auth.isAuthenticated) return const LoginPage();
    if (!_onboarded) return OnboardingScreen(store: widget.store);
    return const MainNavigationScreen();
  }
}
