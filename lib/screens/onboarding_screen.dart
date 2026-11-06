import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/onboarding_store.dart';
import 'main_navigation_screen.dart';

/// Layar izin pertama, mengikuti UI-M00 dan warna portal RoadSafe.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.store = const OnboardingStore(), this.requestAccess});

  final OnboardingStore store;
  final Future<void> Function()? requestAccess;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  var _busy = false;

  Future<void> _requestDeviceAccess() async {
    try {
      await availableCameras();
    } catch (_) {}
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    final requestAccess = widget.requestAccess;
    if (requestAccess != null) {
      await requestAccess();
    } else {
      await _requestDeviceAccess();
    }
    await widget.store.markCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => const MainNavigationScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                children: const [
                  _BrandPill(),
                  SizedBox(height: 18),
                  Text(
                    'Mulai Pantau Jalan Bersama',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 28,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Ubah ponsel Anda menjadi sensor jalan pintar yang otonom dan hands-free demi infrastruktur yang lebih aman dan mulus.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.45),
                  ),
                  SizedBox(height: 18),
                  _PermissionCard(
                    icon: LucideIcons.camera,
                    eyebrow: 'IZIN KAMERA',
                    badge: '100% On-Device AI',
                    title: 'Deteksi Real-Time di Perangkat',
                    body:
                        'Kamera belakang ponsel memindai lubang jalan dengan AI YOLOv8 lokal tanpa mengirim streaming video ke server.',
                  ),
                  SizedBox(height: 12),
                  _PermissionCard(
                    icon: LucideIcons.mapPin,
                    eyebrow: 'IZIN LOKASI PRESISI',
                    badge: 'Akurasi Sub-Meter',
                    title: 'Penandaan Spasial Akurat',
                    body:
                        'Mencatat koordinat GPS presisi dan kecepatan kendaraan untuk verifikasi perbaikan jalan dinas terkait.',
                  ),
                  SizedBox(height: 12),
                  _PermissionCard(
                    icon: LucideIcons.shield,
                    eyebrow: 'JAMINAN PRIVASI UU PDP',
                    badge: 'UU PDP No. 27/2022',
                    title: 'Penyamaran Wajah & Plat Nomor Otomatis',
                    body:
                        'Setiap foto bukti otomatis diburamkan (blur) langsung di perangkat sebelum laporan dikirim.',
                  ),
                  SizedBox(height: 12),
                  _OfflineNote(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _busy ? null : _continue,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3B6CFF),
                        disabledBackgroundColor: const Color(0xFF93AAFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                          : const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Izinkan Akses & Lanjutkan',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(LucideIcons.arrowRight, size: 18),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.shieldCheck, size: 14, color: Color(0xFF94A3B8)),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Operasional 100% hands-free demi keselamatan berkendara',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F0FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.signal, size: 14, color: Color(0xFF3B6CFF)),
            SizedBox(width: 6),
            Text(
              'ROADSAFE EDGE-SENSING',
              style: TextStyle(
                color: Color(0xFF3B6CFF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.eyebrow,
    required this.badge,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String eyebrow;
  final String badge;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F0FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF3B6CFF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      eyebrow,
                      style: const TextStyle(
                        color: Color(0xFF3B6CFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.zap, size: 16, color: Color(0xFF3B6CFF)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tidak menguras kuota data. Model sensorik berjalan sepenuhnya secara luring di perangkat ponsel Anda.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
