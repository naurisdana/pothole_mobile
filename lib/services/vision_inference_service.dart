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

  String get urgencyLabel {
    final area = (right - left) * (bottom - top);
    if (area >= 0.18) return 'H - TINGGI';
    if (area >= 0.07) return 'M - SEDANG';
    return 'L - RENDAH';
  }
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
    final detections = await _runtime.detect(imageBytes);
    return detections
        .map(
          (item) => VisionDetection(
            confidence: item.confidence,
            left: item.left,
            top: item.top,
            right: item.right,
            bottom: item.bottom,
          ),
        )
        .toList();
  }

  void dispose() {
    _runtime.dispose();
    _ready = false;
  }
}
