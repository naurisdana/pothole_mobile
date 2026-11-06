import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/pothole_report.dart';
import 'report_payload.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.body});

  final int statusCode;
  final String message;
  final String? body;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class RateLimitException extends ApiException {
  const RateLimitException(super.statusCode, super.message, {super.body, this.retryAfter});

  final Duration? retryAfter;
}

class ReportUploadResult {
  const ReportUploadResult({
    required this.id,
    required this.code,
    required this.score,
    required this.category,
    required this.status,
    required this.reporterCount,
    required this.isDuplicate,
    required this.imagePath,
  });

  final String id;
  final String code;
  final double score;
  final String category;
  final String status;
  final int reporterCount;
  final bool isDuplicate;
  final String imagePath;

  factory ReportUploadResult.fromJson(Map<String, dynamic> json) {
    return ReportUploadResult(
      id: '${json['id'] ?? ''}',
      code: '${json['kode_laporan'] ?? ''}',
      score: _double(json['skor']),
      category: '${json['kategori'] ?? ''}',
      status: '${json['status'] ?? ''}',
      reporterCount: json['jumlah_terlapor'] is num
          ? (json['jumlah_terlapor'] as num).toInt()
          : int.tryParse('${json['jumlah_terlapor']}') ?? 0,
      isDuplicate: json['is_duplicate'] == true,
      imagePath: '${json['gambar_path'] ?? ''}',
    );
  }

  static double _double(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }
}

class RoadSafeApiClient {
  RoadSafeApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String baseUrl;

  static String get _defaultBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return kIsWeb ? 'http://localhost:8000/api/v1' : 'http://10.0.2.2:8000/api/v1';
  }

  Future<void> registerDevice({
    required String id,
    String? model,
    String? appVersion,
  }) async {
    final response = await _client.post(
      _uri('/devices/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': id,
        if (model != null) 'model_perangkat': model,
        if (appVersion != null) 'versi_app': appVersion,
      }),
    );
    _checkSuccess(response, expected: const {200, 201});
  }

  Future<ReportUploadResult> uploadReport(ReportPayload payload) async {
    if (payload.gpsAccuracy > 20) {
      throw ArgumentError('Laporan ditahan: akurasi GPS harus <= 20 meter.');
    }
    if (!await payload.imageFile.exists()) {
      throw ArgumentError('File gambar tidak ditemukan: ${payload.imagePath}');
    }

    final request = http.MultipartRequest('POST', _uri('/reports/'))
      ..fields.addAll(payload.toFormFields())
      ..files.add(await http.MultipartFile.fromPath('gambar', payload.imagePath));
    final response = await _client.send(request).timeout(const Duration(seconds: 30));
    final body = await response.stream.bytesToString();
    if (response.statusCode == 429) {
      throw RateLimitException(
        response.statusCode,
        'Batas request tercapai.',
        body: body,
        retryAfter: _retryAfter(response.headers['retry-after']),
      );
    }
    if (response.statusCode != 201) {
      throw ApiException(response.statusCode, 'Upload laporan gagal.', body: body);
    }
    final decoded = jsonDecode(body);
    return ReportUploadResult.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  Future<List<PotholeReport>> getReports({
    required String deviceId,
    int limit = 50,
  }) async {
    final response = await _client.get(_uri('/reports/', {
      'device_id': deviceId,
      'limit': '$limit',
    }));
    _checkSuccess(response);
    final decoded = jsonDecode(response.body);
    final list = decoded is List ? decoded : (decoded['items'] as List? ?? const []);
    return list
        .map((item) => PotholeReport.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMapReports() async {
    final response = await _client.get(_uri('/reports/map'));
    _checkSuccess(response);
    final decoded = jsonDecode(response.body);
    final list = decoded is List ? decoded : (decoded['items'] as List? ?? const []);
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  void _checkSuccess(http.Response response, {Set<int> expected = const {200}}) {
    if (response.statusCode == 429) {
      throw RateLimitException(
        response.statusCode,
        'Batas request tercapai.',
        body: response.body,
        retryAfter: _retryAfter(response.headers['retry-after']),
      );
    }
    if (!expected.contains(response.statusCode)) {
      throw ApiException(response.statusCode, 'Request API gagal.', body: response.body);
    }
  }

  Duration? _retryAfter(String? value) {
    final seconds = int.tryParse(value ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
