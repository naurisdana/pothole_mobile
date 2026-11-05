import 'package:flutter/material.dart';

import 'screens/main_navigation_screen.dart';

void main() {
  runApp(const RoadSafeApp());
}

class RoadSafeApp extends StatelessWidget {
  const RoadSafeApp({super.key});

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
      home: const MainNavigationScreen(),
    );
  }
}
