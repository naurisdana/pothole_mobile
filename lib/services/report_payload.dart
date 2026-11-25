import 'dart:io';

class ReportPayload {
  const ReportPayload({
    required this.imagePath,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.confidence,
    required this.l,
    required this.k,
    required this.p,
    required this.t,
    this.street,
    this.speed,
    this.heading,
    this.damageType = 'Lubang (Pothole)',
    this.modelVersion = 'yolov8n-pothole-v1.0',
    this.timestamp,
  });

  final String imagePath;
  final String deviceId;
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final double confidence;
  final double l;
  final double k;
  final double p;
  final double t;
  final String? street;
  final double? speed;
  final double? heading;
  final String damageType;
  final String modelVersion;
  final DateTime? timestamp;

  File get imageFile => File(imagePath);

  Map<String, String> toFormFields() => {
        'device_id': deviceId,
        'latitude': '$latitude',
        'longitude': '$longitude',
        'akurasi_gps': '$gpsAccuracy',
        'confidence': '$confidence',
        'nilai_L': '$l',
        'nilai_K': '$k',
        'nilai_P': '$p',
        'nilai_T': '$t',
        if (street != null) 'lokasi_jalan': street!,
        if (speed != null) 'kecepatan': '$speed',
        if (heading != null) 'arah': '$heading',
        'tipe_kerusakan': damageType,
        'versi_model': modelVersion,
        if (timestamp != null) 'waktu': timestamp!.toIso8601String(),
      };
}
