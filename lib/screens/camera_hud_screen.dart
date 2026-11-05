import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// HUD kamera UI-M01. Pratinjau langsung, status sensor, dan tombol jeda.
class CameraHudScreen extends StatefulWidget {
  const CameraHudScreen({super.key, this.active = true});

  final bool active;

  @override
  State<CameraHudScreen> createState() => _CameraHudScreenState();
}

class _CameraHudScreenState extends State<CameraHudScreen> {
  CameraController? _controller;
  Timer? _fpsTimer;
  var _starting = false;
  var _paused = false;
  var _frames = 0;
  int? _fps;
  String? _error;
  String _gpsLabel = 'GPS: mencari';

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      unawaited(_start());
    }
  }

  @override
  void didUpdateWidget(covariant CameraHudScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      if (_controller == null) {
        unawaited(_start());
      } else if (!_paused) {
        unawaited(_controller!.resumePreview());
      }
    } else {
      unawaited(_controller?.pausePreview());
    }
  }

  @override
  void dispose() {
    _fpsTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
      _fps = null;
    });

    final previous = _controller;
    _controller = null;
    _fpsTimer?.cancel();
    await previous?.dispose();

    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        _fail('Perangkat ini tidak punya kamera yang bisa dipakai.');
        return;
      }
      final rear = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        rear,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      if (!widget.active || _paused) {
        await controller.pausePreview();
      }
      await _watchFrames(controller);
      setState(() {
        _controller = controller;
        _starting = false;
      });
      unawaited(_readGps());
    } on CameraException catch (error) {
      _fail(_cameraMessage(error));
    } catch (error) {
      _fail('Kamera tidak bisa dinyalakan. $error');
    }
  }

  Future<void> _watchFrames(CameraController controller) async {
    try {
      await controller.startImageStream((_) => _frames++);
      _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _fps = _frames);
        _frames = 0;
      });
    } catch (_) {
      _fps = null;
    }
  }

  Future<void> _readGps() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _setGps('GPS: nonaktif');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setGps('GPS: ditolak');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final accuracy = position.accuracy.isFinite ? position.accuracy.round() : 0;
      _setGps('GPS: OK (±${accuracy}m)');
    } catch (_) {
      _setGps('GPS: tidak tersedia');
    }
  }

  void _setGps(String label) {
    if (!mounted) return;
    setState(() => _gpsLabel = label);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _starting = false;
      _error = message;
      _controller = null;
    });
  }

  String _cameraMessage(CameraException error) {
    final code = error.code.toLowerCase();
    if (code.contains('denied') || code.contains('permission') || code.contains('access')) {
      return 'Izin kamera ditolak. Izinkan Kamera untuk RoadSafe di pengaturan ponsel, lalu tekan Coba lagi.';
    }
    final detail = error.description ?? '';
    if (detail.isEmpty) return 'Kamera tidak bisa dinyalakan.';
    return 'Kamera tidak bisa dinyalakan. $detail';
  }

  Future<void> _togglePause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final nextPaused = !_paused;
    try {
      if (nextPaused) {
        await controller.pausePreview();
      } else {
        await controller.resumePreview();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _paused = nextPaused);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final showDetection = ready && !_paused && _error == null;

    return ColoredBox(
      color: const Color(0xFF07101C),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            _LivePreview(controller: controller)
          else
            const CustomPaint(painter: _RoadScenePainter()),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x00000000), Color(0x99000000)],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [
                  _StatusPill(
                    fps: _paused ? 0 : _fps,
                    live: ready && !_paused && _fps == null,
                    gpsLabel: _gpsLabel,
                  ),
                  const Spacer(),
                  if (_starting)
                    const Column(
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 12),
                        Text(
                          'Menyalakan kamera...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  else if (_error != null)
                    _CameraNotice(message: _error!, onRetry: _start)
                  else if (showDetection)
                    const _DetectionBox(),
                  const Spacer(),
                  if (ready)
                    FilledButton.icon(
                      onPressed: _togglePause,
                      style: FilledButton.styleFrom(
                        backgroundColor: _paused ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(168, 48),
                        shape: const StadiumBorder(),
                      ),
                      icon: Icon(_paused ? LucideIcons.play : LucideIcons.pause, size: 16),
                      label: Text(
                        _paused ? 'Lanjut' : 'Jeda',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  const SizedBox(height: 14),
                  const _HudCaption(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final preview = controller.value.previewSize;
    if (preview == null) return CameraPreview(controller);
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: portrait ? preview.height : preview.width,
          height: portrait ? preview.width : preview.height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.fps, required this.live, required this.gpsLabel});

  final int? fps;
  final bool live;
  final String gpsLabel;

  @override
  Widget build(BuildContext context) {
    final fpsLabel = fps == null ? (live ? 'LIVE' : '— FPS') : '$fps FPS';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Dot(color: Color(0xFF22C55E)),
          const SizedBox(width: 6),
          Text(fpsLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          const Icon(LucideIcons.mapPin, size: 13, color: Color(0xFF16A34A)),
          const SizedBox(width: 4),
          Text(gpsLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          const Icon(LucideIcons.cloud, size: 13, color: Color(0xFF64748B)),
          const SizedBox(width: 4),
          const Text('Online', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DetectionBox extends StatelessWidget {
  const _DetectionBox();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const CustomPaint(painter: _CornerPainter(), size: Size(230, 96)),
          Positioned(
            top: -14,
            left: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.alertTriangle, size: 14, color: Color(0xFFDC2626)),
                  SizedBox(width: 4),
                  Text(
                    'H • TINGGI',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            right: 0,
            bottom: -16,
            child: Text(
              'CONF 84%',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    const length = 18.0;
    final path = Path()
      ..moveTo(0, length)
      ..lineTo(0, 0)
      ..lineTo(length, 0)
      ..moveTo(size.width - length, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, length)
      ..moveTo(0, size.height - length)
      ..lineTo(0, size.height)
      ..lineTo(length, size.height)
      ..moveTo(size.width - length, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CameraNotice extends StatelessWidget {
  const _CameraNotice({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE6101724),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.cameraOff, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _HudCaption extends StatelessWidget {
  const _HudCaption();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xD9101724),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          _Dot(color: Color(0xFF60A5FA)),
          SizedBox(width: 8),
          Text(
            'HUD CAM-01',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          Expanded(
            child: Text(
              'ROAD DEFECT SCANNER',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Icon(LucideIcons.locateFixed, color: Color(0xFFCBD5E1), size: 13),
          SizedBox(width: 4),
          Text(
            'AUTO',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RoadScenePainter extends CustomPainter {
  const _RoadScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1B2636));
    final road = Path()
      ..moveTo(size.width * 0.18, size.height)
      ..lineTo(size.width * 0.42, size.height * 0.28)
      ..lineTo(size.width * 0.58, size.height * 0.28)
      ..lineTo(size.width * 0.86, size.height)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF4B5563));
    final lane = Paint()
      ..color = const Color(0xFFF5C542)
      ..strokeWidth = 4;
    for (var i = 0; i < 7; i++) {
      final t = i / 7;
      final y = size.height * (0.36 + t * 0.6);
      canvas.drawLine(Offset(size.width * 0.5, y), Offset(size.width * 0.5, y + 18 + t * 16), lane);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.62),
        width: size.width * 0.28,
        height: 36,
      ),
      Paint()..color = const Color(0xFF111827),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
