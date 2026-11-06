import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../screens/main_navigation_screen.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';

/// Gerbang inisialisasi sesi & Auto-Login saat aplikasi dibuka.
class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  @override
  void initState() {
    super.initState();
    // Jalankan pengecekan sesi setelah frame pertama dirender
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = AuthProvider.of(context, listen: false);
      auth.checkAuthSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthProvider.of(context);

    // Jika proses validasi sesi selesai
    if (auth.isInitialized) {
      if (auth.isAuthenticated) {
        return const MainNavigationScreen();
      } else {
        return const LoginPage();
      }
    }

    // Tampilan Splash / Loading saat memeriksa sesi tersimpan
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF3B6CFF),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x663B6CFF),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.shieldAlert,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'RoadSafe',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Memeriksa status sesi...',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF3B6CFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

