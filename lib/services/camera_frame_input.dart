import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Frame kamera yang sudah disalin, aman dikirim ke isolate inference.
class CameraTensorRequest {
  const CameraTensorRequest({
    required this.width,
    required this.height,
    required this.planes,
    required this.rowStrides,
    required this.pixelStrides,
    required this.rotationDegrees,
  });

  final int width;
  final int height;
  final List<Uint8List> planes;
  final List<int> rowStrides;
  final List<int> pixelStrides;
  final int rotationDegrees;
}

const visionInputSize = 640;

/// Area gambar di dalam kanvas 640x640. Sisa sisinya diisi abu-abu, sama seperti latihan YOLO.
class VisionLetterbox {
  const VisionLetterbox({
    required this.padX,
    required this.padY,
    required this.contentWidth,
    required this.contentHeight,
  });

  final double padX;
  final double padY;
  final double contentWidth;
  final double contentHeight;

  factory VisionLetterbox.forFrame(int srcW, int srcH, int rotationDegrees) {
    final rotation = rotationDegrees % 360;
    final swap = rotation == 90 || rotation == 270;
    final orientedW = (swap ? srcH : srcW).toDouble();
    final orientedH = (swap ? srcW : srcH).toDouble();
    final scale = math.min(visionInputSize / orientedW, visionInputSize / orientedH);
    final contentW = orientedW * scale;
    final contentH = orientedH * scale;
    return VisionLetterbox(
      padX: (visionInputSize - contentW) / 2,
      padY: (visionInputSize - contentH) / 2,
      contentWidth: contentW,
      contentHeight: contentH,
    );
  }

  double mapX(double normalizedOnCanvas) {
    return ((normalizedOnCanvas * visionInputSize - padX) / contentWidth).clamp(0.0, 1.0);
  }

  double mapY(double normalizedOnCanvas) {
    return ((normalizedOnCanvas * visionInputSize - padY) / contentHeight).clamp(0.0, 1.0);
  }
}

/// Mengubah frame YUV/BGRA menjadi tensor NCHW 640x640 dalam orientasi layar.
Float32List buildVisionInput(CameraTensorRequest request) {
  final srcW = request.width;
  final srcH = request.height;
  final rotation = request.rotationDegrees % 360;
  final swap = rotation == 90 || rotation == 270;
  final orientedW = swap ? srcH : srcW;
  final orientedH = swap ? srcW : srcH;
  final input = Float32List(3 * visionInputSize * visionInputSize);
  const padValue = 114 / 255.0;
  for (var index = 0; index < input.length; index++) {
    input[index] = padValue;
  }
  if (srcW <= 0 || srcH <= 0 || request.planes.isEmpty) return input;

  final box = VisionLetterbox.forFrame(srcW, srcH, rotation);
  final scaleX = orientedW / box.contentWidth;
  final scaleY = orientedH / box.contentHeight;

  for (var oy = 0; oy < visionInputSize; oy++) {
    final fy = oy - box.padY;
    if (fy < 0 || fy >= box.contentHeight) continue;
    final dy = (fy * scaleY).round().clamp(0, orientedH - 1);
    for (var ox = 0; ox < visionInputSize; ox++) {
      final fx = ox - box.padX;
      if (fx < 0 || fx >= box.contentWidth) continue;
      final dx = (fx * scaleX).round().clamp(0, orientedW - 1);
      final source = _sourcePoint(dx, dy, rotation, srcW, srcH);
      final rgb = _rgbAt(request, source.$1, source.$2);
      final offset = oy * visionInputSize + ox;
      input[offset] = rgb.$1 / 255.0;
      input[visionInputSize * visionInputSize + offset] = rgb.$2 / 255.0;
      input[2 * visionInputSize * visionInputSize + offset] = rgb.$3 / 255.0;
    }
  }
  return input;
}

/// Foto bukti berorientasi layar, cukup untuk dikirim ke laporan.
Uint8List encodeFrameJpeg(CameraTensorRequest request) {
  final srcW = request.width;
  final srcH = request.height;
  final rotation = request.rotationDegrees % 360;
  final swap = rotation == 90 || rotation == 270;
  final orientedW = swap ? srcH : srcW;
  final orientedH = swap ? srcW : srcH;
  if (srcW <= 0 || srcH <= 0 || orientedW <= 0 || orientedH <= 0 || request.planes.isEmpty) {
    return Uint8List(0);
  }
  final shrink = math.max(1.0, math.max(orientedW, orientedH) / 640);
  final outW = math.max(1, (orientedW / shrink).round());
  final outH = math.max(1, (orientedH / shrink).round());
  final photo = img.Image(width: outW, height: outH);
  for (var oy = 0; oy < outH; oy++) {
    final dy = (oy * shrink).round().clamp(0, orientedH - 1);
    for (var ox = 0; ox < outW; ox++) {
      final dx = (ox * shrink).round().clamp(0, orientedW - 1);
      final source = _sourcePoint(dx, dy, rotation, srcW, srcH);
      final rgb = _rgbAt(request, source.$1, source.$2);
      photo.setPixelRgb(ox, oy, rgb.$1, rgb.$2, rgb.$3);
    }
  }
  return Uint8List.fromList(img.encodeJpg(photo, quality: 72));
}

(int, int) _sourcePoint(int dx, int dy, int rotation, int srcW, int srcH) {
  switch (rotation) {
    case 90:
      return (srcW - 1 - dy, dx);
    case 180:
      return (srcW - 1 - dx, srcH - 1 - dy);
    case 270:
      return (dy, srcH - 1 - dx);
    default:
      return (dx.clamp(0, srcW - 1), dy.clamp(0, srcH - 1));
  }
}

(int, int, int) _rgbAt(CameraTensorRequest request, int x, int y) {
  final sx = x.clamp(0, request.width - 1);
  final sy = y.clamp(0, request.height - 1);
  final planes = request.planes;
  if (planes.length >= 3) {
    final yValue = _sample(planes[0], request.rowStrides[0], request.pixelStrides[0], sx, sy);
    final uValue = _sample(planes[1], request.rowStrides[1], request.pixelStrides[1], sx >> 1, sy >> 1);
    final vValue = _sample(planes[2], request.rowStrides[2], request.pixelStrides[2], sx >> 1, sy >> 1);
    return _yuvToRgb(yValue, uValue, vValue);
  }
  if (planes.length == 2) {
    final yValue = _sample(planes[0], request.rowStrides[0], request.pixelStrides[0], sx, sy);
    final uv = _samplePair(planes[1], request.rowStrides[1], request.pixelStrides[1], sx >> 1, sy >> 1);
    return _yuvToRgb(yValue, uv.$2, uv.$1);
  }
  final pixelStride = request.pixelStrides.isEmpty ? 1 : request.pixelStrides[0];
  if (pixelStride >= 4) {
    final index = sy * request.rowStrides[0] + sx * pixelStride;
    final b = _at(planes[0], index);
    final g = _at(planes[0], index + 1);
    final r = _at(planes[0], index + 2);
    return (r, g, b);
  }
  final gray = _sample(planes[0], request.rowStrides[0], pixelStride, sx, sy);
  return (gray, gray, gray);
}

int _sample(Uint8List bytes, int rowStride, int pixelStride, int x, int y) {
  final stride = pixelStride <= 0 ? 1 : pixelStride;
  return _at(bytes, y * rowStride + x * stride);
}

(int, int) _samplePair(Uint8List bytes, int rowStride, int pixelStride, int x, int y) {
  final stride = pixelStride <= 0 ? 2 : pixelStride;
  final index = y * rowStride + x * stride;
  return (_at(bytes, index), _at(bytes, index + 1));
}

int _at(Uint8List bytes, int index) {
  if (index < 0 || index >= bytes.length) return 0;
  return bytes[index];
}

(int, int, int) _yuvToRgb(int y, int u, int v) {
  final c = y - 16;
  final d = u - 128;
  final e = v - 128;
  final r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
  final g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
  final b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);
  return (r, g, b);
}
