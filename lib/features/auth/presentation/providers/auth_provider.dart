import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../data/auth_repository.dart';
import '../../data/models/user_model.dart';

/// State Management Autentikasi aplikasi RoadSafe menggunakan ChangeNotifier.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  UserModel? _user;
  String? _token;

  // --- Getters ---
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  UserModel? get user => _user;
  String? get token => _token;

  /// True jika pengguna telah login dan memiliki token valid
  bool get isAuthenticated =>
      _token != null && _token!.isNotEmpty && _user != null;

  /// Membersihkan pesan error
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Pengecekan Sesi (Auto-Login saat App Start).
  /// Membaca token dari Secure Storage dan memverifikasi validitas via `GET /auth/me`.
  Future<bool> checkAuthSession() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final savedToken = await _repository.getSavedToken();
      if (savedToken == null || savedToken.isEmpty) {
        _token = null;
        _user = null;
        _isInitialized = true;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _token = savedToken;
      // Ambil cache user terlebih dahulu agar instan
      _user = await _repository.getSavedUser();
      notifyListeners();

      // Validasi token ke server (GET /auth/me)
      final refreshedUser = await _repository.getCurrentUser();
      _user = refreshedUser;
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      // Jika token tidak valid / kedaluwarsa (401), bersihkan sesi
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _repository.logout();
        _token = null;
        _user = null;
      }
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      // Jika gagal koneksi (offline), tetap gunakan cache jika ada token
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
      return _token != null && _user != null;
    }
  }

  /// Proses Login (`POST /auth/login`)
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.login(
        email: email,
        password: password,
      );

      _token = result.accessToken;
      _user = result.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gagal melakukan login: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Proses Registrasi Pengguna Baru (`POST /auth/register`)
  Future<UserModel?> register({
    required String nama,
    required String email,
    required String password,
    String peran = 'pelapor',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final createdUser = await _repository.register(
        nama: nama,
        email: email,
        password: password,
        peran: peran,
      );

      _isLoading = false;
      notifyListeners();
      return createdUser;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Gagal mendaftar: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Logout: Bersihkan session token dan reset state
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.logout();
    } finally {
      _token = null;
      _user = null;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Static Accessor Helper ---
  static AuthProvider of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<AuthProviderScope>();
      assert(scope != null, 'AuthProviderScope tidak ditemukan dalam widget tree.');
      return scope!.notifier!;
    } else {
      final element = context.getElementForInheritedWidgetOfExactType<AuthProviderScope>();
      final scope = element?.widget as AuthProviderScope?;
      assert(scope != null, 'AuthProviderScope tidak ditemukan dalam widget tree.');
      return scope!.notifier!;
    }
  }
}

/// InheritedNotifier untuk mendistribusikan AuthProvider ke seluruh Widget Tree
class AuthProviderScope extends InheritedNotifier<AuthProvider> {
  const AuthProviderScope({
    super.key,
    required AuthProvider notifier,
    required super.child,
  }) : super(notifier: notifier);
}

