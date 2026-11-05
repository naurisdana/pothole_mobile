import 'package:flutter/material.dart';

/// Tempat pratinjau kamera HUD. Isi deteksi menyusul di layar UI-M01.
class CameraHudScreen extends StatelessWidget {
  const CameraHudScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0B1220),
      child: SafeArea(
        child: Center(
          child: Text(
            'Kamera HUD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
