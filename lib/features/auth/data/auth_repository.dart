import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import 'models/user_model.dart';

/// Repository untuk menangani seluruh komunikasi data autentikasi.
class AuthRepository {
  AuthRepository({
    ApiClient? apiClient,
    SecureStorage? storage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? SecureStorage.instance;

  final ApiClient _apiClient;
  final SecureStorage _storage;

  /// Memanggil API Login (`POST /auth/login`)
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.login,
      body: {
        'email': email.trim(),
        'password': password,
      },
      requiresAuth: false,
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        statusCode: 500,
        message: 'Format respons login tidak valid dari server.',
      );
    }

    final authResponse = AuthResponse.fromJson(response);

    // Simpan token & user secara lokal ke Secure Storage
    await _storage.saveAccessToken(authResponse.accessToken);
    await _storage.saveUserJson(jsonEncode(authResponse.user.toJson()));

    return authResponse;
  }

  /// Memanggil API Registrasi (`POST /auth/register`)
  Future<UserModel> register({
    required String nama,
    required String email,
    required String password,
    String peran = 'pelapor',
  }) async {
    final response = await _apiClient.post(
      ApiConstants.register,
      body: {
        'nama': nama.trim(),
        'email': email.trim(),
        'password': password,
        'peran': peran,
      },
      requiresAuth: false,
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        statusCode: 500,
        message: 'Format respons registrasi tidak valid dari server.',
      );
    }

    return UserModel.fromJson(response);
  }

  /// Memanggil API Profil Pengguna (`GET /auth/me`) untuk memverifikasi validitas sesi/token
  Future<UserModel> getCurrentUser() async {
    final response = await _apiClient.get(
      ApiConstants.me,
      requiresAuth: true,
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        statusCode: 500,
        message: 'Format respons profil pengguna tidak valid.',
      );
    }

    final user = UserModel.fromJson(response);
    // Perbarui data cache lokal terbaru
    await _storage.saveUserJson(jsonEncode(user.toJson()));
    return user;
  }

  /// Mengambil access token yang tersimpan di secure storage
  Future<String?> getSavedToken() async {
    return _storage.getAccessToken();
  }

  /// Mengambil profil user yang tersimpan di secure storage
  Future<UserModel?> getSavedUser() async {
    final rawJson = await _storage.getUserJson();
    if (rawJson == null || rawJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      return UserModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Menghapus seluruh sesi pengguna (Logout)
  Future<void> logout() async {
    await _storage.clearAuthSession();
  }
}

