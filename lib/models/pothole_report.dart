/// Laporan kerusakan jalan yang ditangkap sensor ponsel RoadSafe.
/// Skor urgensi = (0.35 * L) + (0.25 * K) + (0.20 * P) + (0.20 * T).
/// Rendah 0–33, Sedang 34–66, Tinggi 67–100.
class PotholeReport {
  const PotholeReport({
    required this.id,
    required this.imagePath,
    required this.lat,
    required this.lng,
    required this.gpsAccuracy,
    required this.speed,
    required this.score,
    required this.category,
    required this.status,
    required this.parameters,
    required this.timestamp,
    required this.street,
  });

  /// Menyusun laporan dan menghitung skor serta kategori dari parameter.
  factory PotholeReport.detected({
    required String id,
    required String imagePath,
    required double lat,
    required double lng,
    required double gpsAccuracy,
    required double speed,
    required ReportStatus status,
    required ReportParameters parameters,
    required DateTime timestamp,
    required String street,
  }) {
    final score = parameters.urgencyScore;
    return PotholeReport(
      id: id,
      imagePath: imagePath,
      lat: lat,
      lng: lng,
      gpsAccuracy: gpsAccuracy,
      speed: speed,
      score: score,
      category: ReportCategory.fromScore(score),
      status: status,
      parameters: parameters,
      timestamp: timestamp,
      street: street,
    );
  }

  final String id;
  final String imagePath;
  final double lat;
  final double lng;

  /// Akurasi GPS dalam meter.
  final double gpsAccuracy;

  /// Kecepatan kendaraan dalam km/jam.
  final double speed;

  final double score;
  final ReportCategory category;
  final ReportStatus status;
  final ReportParameters parameters;
  final DateTime timestamp;
  final String street;

  PotholeReport copyWith({ReportStatus? status}) {
    return PotholeReport(
      id: id,
      imagePath: imagePath,
      lat: lat,
      lng: lng,
      gpsAccuracy: gpsAccuracy,
      speed: speed,
      score: score,
      category: category,
      status: status ?? this.status,
      parameters: parameters,
      timestamp: timestamp,
      street: street,
    );
  }
}

/// Parameter penilaian: L luas, K kedalaman, P posisi lajur, T kepadatan.
class ReportParameters {
  const ReportParameters({
    required this.l,
    required this.k,
    required this.p,
    required this.t,
  });

  final double l;
  final double k;
  final double p;
  final double t;

  static const double weightL = 0.35;
  static const double weightK = 0.25;
  static const double weightP = 0.20;
  static const double weightT = 0.20;

  double get urgencyScore {
    final raw = (weightL * l) + (weightK * k) + (weightP * p) + (weightT * t);
    return (raw * 10).round() / 10;
  }
}

enum ReportCategory {
  high,
  medium,
  low;

  static ReportCategory fromScore(double score) {
    if (score <= 33) return ReportCategory.low;
    if (score <= 66) return ReportCategory.medium;
    return ReportCategory.high;
  }

  String get label {
    switch (this) {
      case ReportCategory.high:
        return 'TINGGI';
      case ReportCategory.medium:
        return 'SEDANG';
      case ReportCategory.low:
        return 'RENDAH';
    }
  }
}

enum ReportStatus {
  menungguSinyal,
  terkirim,
  dalamPenanganan,
  terverifikasi,
  selesai,
  ditolak;

  String get label {
    switch (this) {
      case ReportStatus.menungguSinyal:
        return 'Menunggu Sinyal';
      case ReportStatus.terkirim:
        return 'Terkirim ke Server';
      case ReportStatus.dalamPenanganan:
        return 'Dalam Penanganan';
      case ReportStatus.terverifikasi:
        return 'Terverifikasi';
      case ReportStatus.selesai:
        return 'Selesai';
      case ReportStatus.ditolak:
        return 'Ditolak';
    }
  }
}
