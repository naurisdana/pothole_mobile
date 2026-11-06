import 'package:flutter/material.dart';

/// Layar putih pertama: ikon perisai dan tulisan ROADASAFE di tengah.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const iconAsset = 'assets/images/roadasafe.png';
  static const logoAsset = 'assets/images/logo_roadasafe.png';

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          key: Key('splash-logo'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage(iconAsset),
              width: 96,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 18),
            Image(
              image: AssetImage(logoAsset),
              width: 210,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}
