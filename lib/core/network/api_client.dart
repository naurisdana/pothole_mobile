import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

/// Representasi Exception untuk seluruh kegagalan panggilan API.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.data,
  });

  @override
  String toString() => message;
}

/// HTTP Client terpadu dengan Token Interceptor & Error Parsing terpusat.
class ApiClient {
  ApiClient({
    http.Client? client,
    SecureStorage? storage,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? SecureStorage.instance,
        _baseUrl = baseUrl ?? ApiConstants.baseUrl;

  final http.Client _client;
  final SecureStorage _storage;
  final String _baseUrl;

  /// Helper untuk menyusun URL lengkap
  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanBase = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase$cleanPath';

    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams = queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      return Uri.parse(fullUrl).replace(queryParameters: stringParams);
    }
    return Uri.parse(fullUrl);
  }

  /// Interceptor: Menyematkan header default dan Bearer Token jika tersedia.
  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool requiresAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// Request HTTP GET
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    return _sendRequest(() async {
      final uri = _buildUri(path, queryParameters);
      final requestHeaders = await _buildHeaders(
        extraHeaders: headers,
        requiresAuth: requiresAuth,
      );
      return _client.get(uri, headers: requestHeaders).timeout(ApiConstants.timeoutDuration);
    });
  }

  /// Request HTTP POST
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    return _sendRequest(() async {
      final uri = _buildUri(path, queryParameters);
      final requestHeaders = await _buildHeaders(
        extraHeaders: headers,
        requiresAuth: requiresAuth,
      );
      final encodedBody = body != null ? jsonEncode(body) : null;

      return _client
          .post(uri, headers: requestHeaders, body: encodedBody)
          .timeout(ApiConstants.timeoutDuration);
    });
  }

  /// Eksekusi request dengan penanganan error terpusat
  Future<dynamic> _sendRequest(Future<http.Response> Function() requestFn) async {
    try {
      final response = await requestFn();
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException(
        statusCode: 0,
        message: 'Tidak dapat terhubung ke server RoadSafe. Periksa koneksi internet Anda.',
      );
    } on TimeoutException {
      throw const ApiException(
        statusCode: 408,
        message: 'Koneksi ke server waktu habis (timeout). Silakan coba beberapa saat lagi.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 500,
        message: 'Terjadi kesalahan tidak terduga: ${e.toString()}',
      );
    }
  }

  /// Mengurai respons dan melempar ApiException jika status >= 400
  dynamic _handleResponse(http.Response response) {
    dynamic decodedBody;
    if (response.body.isNotEmpty) {
      try {
        decodedBody = jsonDecode(response.body);
      } catch (_) {
        decodedBody = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    final errorMessage = _extractErrorMessage(response.statusCode, decodedBody);
    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      data: decodedBody,
    );
  }

  /// Mengekstrak pesan error spesifik dari response FastAPI (misal: "detail")
  String _extractErrorMessage(int statusCode, dynamic body) {
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      if (detail is String) {
        return detail;
      } else if (detail is List && detail.isNotEmpty) {
        // FastAPI Pydantic validation error format
        final first = detail.first;
        if (first is Map && first.containsKey('msg')) {
          final loc = (first['loc'] as List?)?.last ?? 'field';
          return '$loc: ${first['msg']}';
        }
      }
      if (body.containsKey('message')) {
        return body['message'].toString();
      }
    }

    switch (statusCode) {
      case 400:
        return 'Permintaan tidak valid (Bad Request).';
      case 401:
        return 'Email atau kata sandi salah.';
      case 403:
        return 'Akses ditolak (Forbidden).';
      case 404:
        return 'Endpoint atau data tidak ditemukan.';
      case 422:
        return 'Data input tidak memenuhi validasi server.';
      case 429:
        return 'Terlalu banyak permintaan. Silakan tunggu beberapa saat.';
      case 500:
      case 502:
      case 503:
        return 'Server RoadSafe sedang mengalami kendala. Silakan coba lagi nanti.';
      default:
        return 'Terjadi kesalahan (Kode: $statusCode).';
    }
  }
}

