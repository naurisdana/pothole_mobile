import 'dart:typed_data';

class RuntimeDetection {
  const RuntimeDetection({
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

class VisionRuntime {
  Future<void> initialize() async {
    throw UnsupportedError(
      'ONNX Runtime hanya tersedia di Android/iOS. Jalankan aplikasi di device mobile.',
    );
  }

  Future<List<RuntimeDetection>> detect(Uint8List imageBytes) async {
    throw UnsupportedError(
      'Inference ONNX tidak tersedia pada Web.',
    );
  }

  void dispose() {}
}

VisionRuntime createVisionRuntime() => VisionRuntime();
