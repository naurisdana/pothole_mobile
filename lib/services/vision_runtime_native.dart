import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

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
  static const _assetPath = 'lib/model_vision/best.onnx';
  static const _inputSize = 640;
  OrtSession? _session;

  Future<void> initialize() async {
    OrtEnv.instance.init();
    final raw = await rootBundle.load(_assetPath);
    final options = OrtSessionOptions();
    _session = OrtSession.fromBuffer(raw.buffer.asUint8List(), options);
    options.release();
  }

  Future<List<RuntimeDetection>> detect(Uint8List jpegBytes) async {
    final decoded = img.decodeImage(jpegBytes);
    if (decoded == null) {
      throw StateError('Frame kamera tidak dapat dibaca.');
    }
    final resized = img.copyResize(
      decoded,
      width: _inputSize,
      height: _inputSize,
    );
    final input = Float32List(1 * 3 * _inputSize * _inputSize);
    var offset = 0;
    for (var channel = 0; channel < 3; channel++) {
      for (var y = 0; y < _inputSize; y++) {
        for (var x = 0; x < _inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          input[offset++] =
              (channel == 0 ? pixel.r : channel == 1 ? pixel.g : pixel.b) /
                  255.0;
        }
      }
    }

    final inputValue = OrtValueTensor.createTensorWithDataList(
      input,
      [1, 3, 640, 640],
    );
    final runOptions = OrtRunOptions();
    final outputs = await _session!.runAsync(
      runOptions,
      {'images': inputValue},
    );
    inputValue.release();
    runOptions.release();

    final output =
        outputs == null || outputs.isEmpty ? null : outputs.first?.value;
    outputs?.forEach((value) => value?.release());
    if (output is! List<num>) return const [];
    return _decodeCandidates(output);
  }

  List<RuntimeDetection> _decodeCandidates(List<num> output) {
    final candidates = <RuntimeDetection>[];
    for (var index = 0; index < 8400; index++) {
      final confidence = output[4 * 8400 + index].toDouble();
      if (confidence < 0.35) continue;
      final centerX = output[index].toDouble() / _inputSize;
      final centerY = output[8400 + index].toDouble() / _inputSize;
      final width = output[2 * 8400 + index].toDouble() / _inputSize;
      final height = output[3 * 8400 + index].toDouble() / _inputSize;
      candidates.add(
        RuntimeDetection(
          confidence: confidence,
          left: (centerX - width / 2).clamp(0, 1),
          top: (centerY - height / 2).clamp(0, 1),
          right: (centerX + width / 2).clamp(0, 1),
          bottom: (centerY + height / 2).clamp(0, 1),
        ),
      );
    }
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates.take(10).toList();
  }

  void dispose() {
    _session?.release();
    _session = null;
    OrtEnv.instance.release();
  }
}

VisionRuntime createVisionRuntime() => VisionRuntime();
