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

  factory PotholeReport.fromJson(Map<String, dynamic> json) {
    final parameters = ReportParameters(
      l: _number(json['nilai_L'] ?? json['l']),
      k: _number(json['nilai_K'] ?? json['k']),
      p: _number(json['nilai_P'] ?? json['p']),
      t: _number(json['nilai_T'] ?? json['t']),
    );
    final score = _number(json['skor'] ?? json['score'], fallback: parameters.urgencyScore);
    return PotholeReport(
      id: '${json['id'] ?? json['kode_laporan'] ?? ''}',
      imagePath: '${json['gambar_path'] ?? json['gambar_url'] ?? ''}',
      lat: _number(json['latitude'] ?? json['lat']),
      lng: _number(json['longitude'] ?? json['lng']),
      gpsAccuracy: _number(json['akurasi_gps'] ?? json['gps_accuracy']),
      speed: _number(json['kecepatan'] ?? json['speed']),
      score: score,
      category: _category(json['kategori'] ?? json['category'], score),
      status: _status(json['status']),
      parameters: parameters,
      timestamp: DateTime.tryParse(
            '${json['waktu'] ?? json['timestamp'] ?? ''}',
          ) ??
          DateTime.now(),
      street: '${json['lokasi_jalan'] ?? json['street'] ?? 'Lokasi tidak diketahui'}',
    );
  }

  static double _number(dynamic value, {double fallback = 0}) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
  }

  static ReportCategory _category(dynamic value, double score) {
    final normalized = '$value'.toLowerCase();
    if (normalized == 'high' || normalized.contains('tinggi')) {
      return ReportCategory.high;
    }
    if (normalized == 'medium' || normalized.contains('sedang')) {
      return ReportCategory.medium;
    }
    if (normalized == 'low' || normalized.contains('rendah')) {
      return ReportCategory.low;
    }
    return ReportCategory.fromScore(score);
  }

  static ReportStatus _status(dynamic value) {
    final normalized = '$value'.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (normalized == 'pending' || normalized == 'terkirim') {
      return ReportStatus.terkirim;
    }
    if (normalized.contains('penanganan')) return ReportStatus.dalamPenanganan;
    if (normalized.contains('verifikasi')) return ReportStatus.terverifikasi;
    if (normalized == 'selesai' || normalized == 'completed') {
      return ReportStatus.selesai;
    }
    if (normalized == 'ditolak' || normalized == 'rejected') {
      return ReportStatus.ditolak;
    }
    return ReportStatus.terkirim;
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
