import 'dart:math' as math;

import '../models/pothole_report.dart';
import 'vision_inference_service.dart';

/// Skor L/K/P/T untuk satu kotak deteksi.
/// Model ONNX hanya mengenal kelas lubang. K adalah perkiraan dari bentuk kotak,
/// bukan pengukuran kedalaman dari sensor.
class DetectionAssessment {
  const DetectionAssessment({
    required this.detection,
    required this.parameters,
    required this.areaCm2,
  });

  final VisionDetection detection;
  final ReportParameters parameters;
  final double areaCm2;

  double get score => parameters.urgencyScore;
  ReportCategory get category => ReportCategory.fromScore(score);

  String get mark => 'P-001';

  factory DetectionAssessment.fromDetection(VisionDetection detection) {
    final width = (detection.right - detection.left).clamp(0.0, 1.0);
    final height = (detection.bottom - detection.top).clamp(0.0, 1.0);
    final area = width * height;
    final centerX = (detection.left + detection.right) / 2;
    final l = (area / 0.02 * 40).clamp(0.0, 100.0);
    final k = (height / math.max(width, 0.02) * 32).clamp(0.0, 100.0);
    final p = (100 - (centerX - 0.5).abs() * 200).clamp(0.0, 100.0);
    const t = 55.0;
    final widthCm = width * 350;
    final heightCm = height * 250;
    return DetectionAssessment(
      detection: detection,
      parameters: ReportParameters(l: l, k: k, p: p, t: t),
      areaCm2: widthCm * heightCm,
    );
  }
}
