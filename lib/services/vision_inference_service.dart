import 'dart:typed_data';
import 'vision_runtime_native.dart'
    if (dart.library.html) 'vision_runtime_web.dart';

class VisionDetection {
  const VisionDetection({
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double confidence;
  final double left;
  final double top;
  final double right;
  final double bottom;
}

class VisionInferenceService {
  final VisionRuntime _runtime = createVisionRuntime();
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> initialize() async {
    if (_ready) return;
    await _runtime.initialize();
    _ready = true;
  }

  Future<List<VisionDetection>> detect(Uint8List imageBytes) async {
    await initialize();
    return _map(await _runtime.detect(imageBytes));
  }

  Future<List<VisionDetection>> detectTensor(Float32List input) async {
    await initialize();
    return _map(await _runtime.detectTensor(input));
  }

  List<VisionDetection> _map(List<dynamic> detections) {
    return [
      for (final item in detections)
        VisionDetection(
          confidence: item.confidence as double,
          left: item.left as double,
          top: item.top as double,
          right: item.right as double,
          bottom: item.bottom as double,
        ),
    ];
  }

  void dispose() {
    _runtime.dispose();
    _ready = false;
  }
}
