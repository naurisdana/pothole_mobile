import 'package:flutter/material.dart';
import 'features/auth/presentation/pages/auth_gate_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RoadSafeApp());
}

class RoadSafeApp extends StatefulWidget {
  const RoadSafeApp({super.key});

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
        home: const AuthGatePage(),
      ),
    );
  }
}
