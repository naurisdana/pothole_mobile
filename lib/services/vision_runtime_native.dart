import 'dart:math' as math;
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
    final bytes = raw.buffer.asUint8List();
    try {
      _session = _open(bytes, useXnnpack: true);
    } catch (_) {
      _session = _open(bytes, useXnnpack: false);
    }
  }

  OrtSession _open(Uint8List bytes, {required bool useXnnpack}) {
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(4)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    if (useXnnpack) options.appendXnnpackProvider();
    final session = OrtSession.fromBuffer(bytes, options);
    options.release();
    return session;
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

    return _run(input);
  }

  Future<List<RuntimeDetection>> detectTensor(Float32List input) {
    return _run(input);
  }

  Future<List<RuntimeDetection>> _run(Float32List input) async {
    final session = _session;
    if (session == null) {
      throw StateError('Model belum siap.');
    }
    final inputValue = OrtValueTensor.createTensorWithDataList(
      input,
      [1, 3, _inputSize, _inputSize],
    );
    final runOptions = OrtRunOptions();
    try {
      final inputName = session.inputNames.isEmpty ? 'images' : session.inputNames.first;
      final outputName = session.outputNames.contains('output0')
          ? 'output0'
          : session.outputNames.first;
      final outputs = await session.runAsync(
        runOptions,
        {inputName: inputValue},
        [outputName],
      );
      final output = outputs == null || outputs.isEmpty ? null : outputs.first?.value;
      outputs?.forEach((value) => value?.release());
      return _decodeCandidates(output);
    } finally {
      inputValue.release();
      runOptions.release();
    }
  }

  List<RuntimeDetection> _decodeCandidates(dynamic output) {
    final shape = _shapeOf(output);
    final flat = _flatten(output);
    if (flat.isEmpty || shape.length < 2) return const [];
    final dims = shape.length >= 3 && shape.first == 1 ? shape.sublist(1) : shape;
    if (dims.length < 2) return const [];
    final channelMajor = dims[0] <= dims[1];
    final channels = channelMajor ? dims[0] : dims[1];
    final anchors = channelMajor ? dims[1] : dims[0];
    if (channels < 5 || anchors <= 0 || flat.length < channels * anchors) {
      return const [];
    }

    double at(int channel, int anchor) {
      return channelMajor ? flat[channel * anchors + anchor] : flat[anchor * channels + channel];
    }

    final maskChannels = channels > 36 ? 32 : 0;
    final classChannels = channels - 4 - maskChannels;
    if (classChannels < 1) return const [];

    var peak = 0.0;
    final step = math.max(1, anchors ~/ 48);
    for (var index = 0; index < anchors; index += step) {
      peak = math.max(peak, at(2, index).abs());
    }
    final scale = peak > 2 ? _inputSize.toDouble() : 1.0;
    final candidates = <RuntimeDetection>[];
    for (var index = 0; index < anchors; index++) {
      var confidence = 0.0;
      for (var channel = 4; channel < 4 + classChannels; channel++) {
        confidence = math.max(confidence, _score(at(channel, index)));
      }
      if (confidence < 0.4) continue;
      final centerX = at(0, index) / scale;
      final centerY = at(1, index) / scale;
      final width = at(2, index) / scale;
      final height = at(3, index) / scale;
      if (width <= 0.01 || height <= 0.01) continue;
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
    return _suppress(candidates);
  }

  double _score(double raw) {
    if (raw >= 0 && raw <= 1) return raw;
    final exp = math.exp(-raw);
    return 1 / (1 + exp);
  }

  List<int> _shapeOf(dynamic value) {
    if (value is! List || value.isEmpty) return const [];
    if (value.first is num) return [value.length];
    return [value.length, ..._shapeOf(value.first)];
  }

  List<double> _flatten(dynamic value) {
    if (value is num) return [value.toDouble()];
    if (value is List<double>) return value;
    if (value is List) {
      final flat = <double>[];
      for (final item in value) {
        flat.addAll(_flatten(item));
      }
      return flat;
    }
    return const [];
  }

  List<RuntimeDetection> _suppress(List<RuntimeDetection> boxes) {
    final kept = <RuntimeDetection>[];
    for (final box in boxes) {
      final overlaps = kept.any((other) => _iou(box, other) > 0.45);
      if (!overlaps) kept.add(box);
      if (kept.length == 4) break;
    }
    return kept;
  }

  double _iou(RuntimeDetection a, RuntimeDetection b) {
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

  void dispose() {
    _session?.release();
    _session = null;
    OrtEnv.instance.release();
  }
}

VisionRuntime createVisionRuntime() => VisionRuntime();
