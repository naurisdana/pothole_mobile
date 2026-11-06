import 'package:flutter/material.dart';

import 'screens/app_entry.dart';
import 'services/onboarding_store.dart';

void main() {
  runApp(const RoadSafeApp());
}

class RoadSafeApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoadSafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B6CFF)),
        scaffoldBackgroundColor: const Color(0xFFF7F8FB),
        fontFamily: 'Roboto',
      ),
      home: AppEntry(store: store, requestAccess: requestAccess, splashHold: splashHold),
    );
  }
}
