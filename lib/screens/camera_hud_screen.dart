import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../services/camera_frame_input.dart';
import '../services/detection_assessment.dart';
import '../services/device_identity.dart';
import '../services/reporting_controller.dart';
import '../services/road_safe_api_client.dart';
import '../services/vision_inference_service.dart';

/// HUD kamera UI-M01. Pratinjau langsung, status sensor, dan tombol jeda.
class CameraHudScreen extends StatefulWidget {
  const CameraHudScreen({super.key, this.active = true});

  final bool active;

  @override
  State<CameraHudScreen> createState() => _CameraHudScreenState();
}

class _CameraHudScreenState extends State<CameraHudScreen> {
  CameraController? _controller;
  final _vision = VisionInferenceService();
  Timer? _fpsTimer;
  var _starting = false;
  var _paused = false;
  var _busy = false;
  var _frames = 0;
  int? _fps;
  String? _error;
  String? _modelNote;
  String _gpsLabel = 'GPS: mencari';
  Position? _position;
  StreamSubscription<Position>? _gpsSub;
  DateTime? _reportCooldownUntil;
  var _stableCount = 0;
  VisionDetection? _tracked;
  List<VisionDetection> _detections = const [];
  DetectionAssessment? _assessment;
  String? _captureNote;
  ReportingController? _reports;
  var _sending = false;

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

  Future<void> _prepareModel() async {
    try {
      await _vision.initialize();
      if (!mounted) return;
      setState(() => _modelNote = null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _modelNote = 'Model ONNX belum siap');
    }
  }

  void _maybeInfer(CameraController controller, CameraImage image) {
    if (_busy || _paused || !widget.active || image.planes.isEmpty) return;
    _busy = true;
    final request = CameraTensorRequest(
      width: image.width,
      height: image.height,
      planes: [for (final plane in image.planes) Uint8List.fromList(plane.bytes)],
      rowStrides: [for (final plane in image.planes) plane.bytesPerRow],
      pixelStrides: [for (final plane in image.planes) plane.bytesPerPixel ?? 1],
      rotationDegrees: _displayRotation(controller),
    );
    unawaited(_infer(request));
  }

  Future<void> _infer(CameraTensorRequest request) async {
    try {
      if (!_vision.isReady) await _vision.initialize();
      final input = await VisionInputWorker.instance.prepare(request);
      final detections = await _vision.detectTensor(input);
      if (!mounted || _paused || !widget.active) return;
      final frame = VisionLetterbox.forFrame(request.width, request.height, request.rotationDegrees);
      final mapped = [
        for (final detection in detections)
          VisionDetection(
            confidence: detection.confidence,
            left: frame.mapX(detection.left),
            top: frame.mapY(detection.top),
            right: frame.mapX(detection.right),
            bottom: frame.mapY(detection.bottom),
          ),
      ]..sort((a, b) => b.confidence.compareTo(a.confidence));
      final smoothed = _stabilize(mapped);
      final primary = smoothed.isEmpty ? null : DetectionAssessment.fromDetection(smoothed.first);
      setState(() {
        _detections = smoothed;
        _assessment = primary;
        _modelNote = null;
      });
      final cooledDown = _reportCooldownUntil != null && DateTime.now().isBefore(_reportCooldownUntil!);
      if (primary != null && primary.detection.confidence >= 0.5 && _stableCount >= 3 && !cooledDown) {
        _stableCount = 0;
        unawaited(_offerReport(request, primary));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detections = const [];
        _assessment = null;
        _tracked = null;
        _stableCount = 0;
        _modelNote = _vision.isReady ? 'Deteksi gagal' : 'Model ONNX belum siap';
      });
    } finally {
      _busy = false;
    }
  }

  List<VisionDetection> _stabilize(List<VisionDetection> incoming) {
    if (incoming.isEmpty) {
      _stableCount = 0;
      _tracked = null;
      return const [];
    }
    final current = incoming.first;
    final previous = _tracked;
    if (previous != null && _boxIou(previous, current) >= 0.35) {
      final chosen = VisionDetection(
        confidence: current.confidence,
        left: previous.left * 0.25 + current.left * 0.75,
        top: previous.top * 0.25 + current.top * 0.75,
        right: previous.right * 0.25 + current.right * 0.75,
        bottom: previous.bottom * 0.25 + current.bottom * 0.75,
      );
      _tracked = chosen;
      _stableCount++;
      if (incoming.length == 1) return [chosen];
      return [chosen, ...incoming.skip(1)];
    }
    _tracked = current;
    _stableCount = 1;
    return incoming;
  }

  double _boxIou(VisionDetection a, VisionDetection b) {
    final left = math.max(a.left, b.left);
    final top = math.max(a.top, b.top);
    final right = math.min(a.right, b.right);
    final bottom = math.min(a.bottom, b.bottom);
    final width = right - left;
    final height = bottom - top;
    if (width <= 0 || height <= 0) return 0;
    final intersection = width * height;
    final union = (a.right - a.left) * (a.bottom - a.top) +
        (b.right - b.left) * (b.bottom - b.top) -
        intersection;
    if (union <= 0) return 0;
    return intersection / union;
  }

  int _displayRotation(CameraController controller) {
    final sensor = controller.description.sensorOrientation;
    final device = switch (controller.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final front = controller.description.lensDirection == CameraLensDirection.front;
    if (front) return (sensor + device) % 360;
    return (sensor - device + 360) % 360;
  }

  Size _orientedPreviewSize(CameraController controller) {
    final preview = controller.value.previewSize ?? Size.zero;
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    if (portrait) return Size(preview.height, preview.width);
    return Size(preview.width, preview.height);
  }

  @override
  void dispose() {
    _fpsTimer?.cancel();
    _gpsSub?.cancel();
    _controller?.dispose();
    _vision.dispose();
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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
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
      unawaited(_prepareModel());
    } on CameraException catch (error) {
      _fail(_cameraMessage(error));
    } catch (error) {
      _fail('Kamera tidak bisa dinyalakan. $error');
    }
  }

  Future<void> _watchFrames(CameraController controller) async {
    try {
      await controller.startImageStream((image) {
        _frames++;
        _maybeInfer(controller, image);
      });
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
      _rememberPosition(position);
      await _gpsSub?.cancel();
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 8,
        ),
      ).listen(_rememberPosition, onError: (_) {});
    } catch (_) {
      _setGps('GPS: tidak tersedia');
    }
  }

  void _rememberPosition(Position position) {
    _position = position;
    final accuracy = position.accuracy.isFinite ? position.accuracy.round() : 0;
    _setGps('GPS: OK (±${accuracy}m)');
  }

  Future<void> _ensureReporter() async {
    if (_reports != null) return;
    final id = await DeviceIdentity().getOrCreate();
    final api = RoadSafeApiClient();
    try {
      await api.registerDevice(id: id, model: 'Flutter Mobile', appVersion: '1.0.0');
    } catch (_) {}
    _reports = ReportingController(
      api: api,
      deviceId: id,
      requiredConsecutiveFrames: 1,
    );
  }

  Future<void> _offerReport(CameraTensorRequest request, DetectionAssessment assessment) async {
    if (_sending || _paused || !widget.active) return;
    final position = _position;
    if (position == null) {
      _setCapture('Menunggu GPS untuk mengirim laporan');
      return;
    }
    if (!position.accuracy.isFinite || position.accuracy > 20) {
      _setCapture('GPS ±${position.accuracy.round()} m. Laporan baru dikirim saat akurasi ≤ 20 m');
      return;
    }
    _sending = true;
    try {
      await _ensureReporter();
      final jpeg = await compute(encodeFrameJpeg, request);
      if (jpeg.isEmpty || !mounted) return;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}${Platform.pathSeparator}pothole-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(jpeg, flush: true);
      final speed = position.speed.isFinite && position.speed >= 0 ? position.speed * 3.6 : null;
      final heading = position.heading.isFinite && position.heading >= 0 ? position.heading : null;
      final progress = await _reports!.addFrame(
        DetectionFrame(
          imagePath: path,
          confidence: assessment.detection.confidence,
          l: assessment.parameters.l,
          k: assessment.parameters.k,
          p: assessment.parameters.p,
          t: assessment.parameters.t,
          telemetry: TelemetrySnapshot(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            speed: speed,
            heading: heading,
          ),
        ),
      );
      if (!mounted) return;
      final delivery = progress.delivery;
      if (delivery == null) {
        try {
          await File(path).delete();
        } catch (_) {}
        _setCapture('Mengunci lubang ${progress.frames}/${progress.requiredFrames}');
        return;
      }
      final code = (progress.code == null || progress.code!.isEmpty) ? 'laporan' : progress.code!;
      if (delivery == ReportDelivery.sent || delivery == ReportDelivery.duplicate) {
        _reportCooldownUntil = DateTime.now().add(const Duration(seconds: 8));
      }
      _setCapture(switch (delivery) {
        ReportDelivery.sent => 'SMART AUTO-CAPTURE: $code (NEW_REPORT_CREATED)',
        ReportDelivery.duplicate => 'Lubang ini sudah tercatat ($code)',
        ReportDelivery.queued => 'Sinyal putus. Laporan disimpan dan dikirim saat online',
        ReportDelivery.heldForGps => 'Akurasi GPS belum cukup untuk mengirim laporan',
      });
    } catch (_) {
      _setCapture('Laporan belum terkirim. Coba lagi saat sinyal stabil');
    } finally {
      _sending = false;
    }
  }

  void _setCapture(String note) {
    if (!mounted) return;
    setState(() => _captureNote = note);
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
    setState(() {
      _paused = nextPaused;
      if (nextPaused) {
        _detections = const [];
        _assessment = null;
        _tracked = null;
        _stableCount = 0;
      }
    });
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
          if (showDetection && _detections.isNotEmpty && controller.value.previewSize != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DetectionPainter(
                    detections: _detections,
                    imageSize: _orientedPreviewSize(controller),
                  ),
                ),
              ),
            ),
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
                  if (_captureNote != null) ...[
                    const SizedBox(height: 8),
                    _CaptureBanner(text: _captureNote!),
                  ],
                  if (_assessment != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _UrgencyCard(assessment: _assessment!),
                    ),
                  ],
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
                  else if (showDetection && _detections.isEmpty)
                    Text(
                      _modelNote ?? 'Memindai jalan...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  const Spacer(),
                  if (ready)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _togglePause,
                          style: FilledButton.styleFrom(
                            backgroundColor: _paused ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(148, 48),
                            shape: const StadiumBorder(),
                          ),
                          icon: Icon(_paused ? LucideIcons.play : LucideIcons.pause, size: 16),
                          label: Text(
                            _paused ? 'Lanjut' : 'Jeda',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
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
      ),
    );
  }
}

class _CaptureBanner extends StatelessWidget {
  const _CaptureBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final sent = text.contains('NEW_REPORT_CREATED');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: sent ? const Color(0xF0145C32) : const Color(0xE6101724),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sent ? const Color(0xFF4ADE80) : const Color(0xFFFACC15)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _UrgencyCard extends StatelessWidget {
  const _UrgencyCard({required this.assessment});

  final DetectionAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final detection = assessment.detection;
    final parameters = assessment.parameters;
    final percent = (detection.confidence * 100).toStringAsFixed(0);
    final area = assessment.areaCm2.round();
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE6101724),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFACC15)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, height: 1.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${assessment.mark}  |  Lubang  |  $percent%  |  Area ±$area cm²'),
            Text(
              'Urgensi: ${assessment.category.label} (${assessment.score.toStringAsFixed(1)})  |  L:${parameters.l.round()} K:${parameters.k.round()} P:${parameters.p.round()} T:${parameters.t.round()}',
            ),
            const Text(
              'K diperkirakan dari bentuk kotak',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
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

class _DetectionPainter extends CustomPainter {
  const _DetectionPainter({required this.detections, required this.imageSize});

  final List<VisionDetection> detections;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return;
    final scale = math.max(size.width / imageSize.width, size.height / imageSize.height);
    final displayedW = imageSize.width * scale;
    final displayedH = imageSize.height * scale;
    final dx = (size.width - displayedW) / 2;
    final dy = (size.height - displayedH) / 2;
    final border = Paint()
      ..color = const Color(0xFFFACC15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final labelBorder = Paint()
      ..color = const Color(0xFFFACC15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint()..color = const Color(0xF0111827);
    for (var index = 0; index < detections.length; index++) {
      final detection = detections[index];
      final rect = Rect.fromLTRB(
        dx + detection.left * displayedW,
        dy + detection.top * displayedH,
        dx + detection.right * displayedW,
        dy + detection.bottom * displayedH,
      );
      if (rect.width < 8 || rect.height < 8) continue;
      canvas.drawRect(rect, border);
      final label = 'P-${(index + 1).toString().padLeft(3, '0')}';
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Color(0xFFFACC15), fontSize: 12, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelRect = Rect.fromLTWH(rect.left, math.max(0, rect.top - 20), text.width + 10, 20);
      canvas.drawRect(labelRect, fill);
      canvas.drawRect(labelRect, labelBorder);
      text.paint(canvas, Offset(labelRect.left + 5, labelRect.top + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections || oldDelegate.imageSize != imageSize;
  }
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
