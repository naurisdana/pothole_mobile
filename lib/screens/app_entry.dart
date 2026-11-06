import 'package:flutter/material.dart';

import '../services/onboarding_store.dart';
import 'main_navigation_screen.dart';
import 'onboarding_screen.dart';
import 'splash_screen.dart';

/// Logo pembuka, lalu onboarding pada peluncuran pertama, lalu portal tiga tab.
class AppEntry extends StatefulWidget {
  const AppEntry({
    super.key,
    this.store = const OnboardingStore(),
    this.requestAccess,
    this.splashHold = const Duration(milliseconds: 1600),
  });

  final OnboardingStore store;
  final Future<void> Function()? requestAccess;
  final Duration splashHold;

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool? _completed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final completed = await widget.store.isCompleted();
    await Future<void>.delayed(widget.splashHold);
    if (!mounted) return;
    setState(() => _completed = completed);
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completed;
    if (completed == null) return const SplashScreen();
    if (completed) return const MainNavigationScreen();
    return OnboardingScreen(store: widget.store, requestAccess: widget.requestAccess);
  }
}
