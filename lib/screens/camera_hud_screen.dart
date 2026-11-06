import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/vision_inference_service.dart';

class CameraHudScreen extends StatefulWidget {
  const CameraHudScreen({super.key});

  @override
  State<CameraHudScreen> createState() => _CameraHudScreenState();
}

class _CameraHudScreenState extends State<CameraHudScreen> {
  CameraController? _controller;
  final _vision = VisionInferenceService();
  List<VisionDetection> _detections = const [];
  String? _error;
  bool _paused = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('Kamera tidak ditemukan.');
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      try {
        await _vision.initialize();
        if (mounted) setState(() {});
      } catch (error) {
        if (mounted) setState(() => _error = 'Runtime ONNX tidak tersedia: $error');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _captureAndDetect() async {
    final controller = _controller;
    if (controller == null || _busy || _paused) return;
    setState(() => _busy = true);
    try {
      final file = await controller.takePicture();
      final detections = await _vision.detect(await file.readAsBytes());
      if (mounted) setState(() => _detections = detections);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _vision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ColoredBox(
      color: const Color(0xFF0B1220),
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller?.value.isInitialized == true)
              CameraPreview(controller!)
            else
              Center(
                child: Text(
                  _error ?? 'Menyiapkan kamera dan model ONNX...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _status('MODEL: ${_vision.isReady ? "READY" : "LOADING"}'),
                  const SizedBox(width: 8),
                  _status('GPS: MENUNGGU'),
                  const SizedBox(width: 8),
                  _status(_paused ? 'PAUSED' : 'ONLINE'),
                ],
              ),
            ),
            for (final detection in _detections)
              Positioned(
                left: detection.left * MediaQuery.sizeOf(context).width,
                top: detection.top * MediaQuery.sizeOf(context).height,
                width: (detection.right - detection.left) * MediaQuery.sizeOf(context).width,
                height: (detection.bottom - detection.top) * MediaQuery.sizeOf(context).height,
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 3)),
                  alignment: Alignment.topLeft,
                  child: ColoredBox(
                    color: Colors.red,
                    child: Text(
                      '${detection.urgencyLabel}  ${(detection.confidence * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => setState(() => _paused = !_paused),
                      child: Text(_paused ? 'Lanjutkan Deteksi' : 'Jeda Deteksi'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _busy ? null : _captureAndDetect,
                    child: Text(_busy ? '...' : 'Deteksi'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _status(String text) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
      );
}
