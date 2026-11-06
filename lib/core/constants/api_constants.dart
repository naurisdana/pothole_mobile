import 'package:flutter/foundation.dart';

/// Konstanta endpoint API dan konfigurasi server RoadSafe Backend.
class ApiConstants {
  ApiConstants._();

  /// Base URL backend FastAPI.
  /// - Emulator Android: http://10.0.2.2:8000/api/v1
  /// - Web / Desktop: http://localhost:8000/api/v1
  /// - Override via environment: --dart-define=API_BASE_URL=http://`IP`:8000/api/v1
  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return 'http://localhost:8000/api/v1';
    return 'http://10.0.2.2:8000/api/v1';
  }

  // --- Auth Endpoints ---
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String me = '/auth/me';

  // --- Storage Keys ---
  static const String keyAccessToken = 'roadasafe_access_token';
  static const String keyTokenType = 'roadasafe_token_type';
  static const String keyUserData = 'roadasafe_user_profile';

  // --- Request Timeout ---
  static const Duration timeoutDuration = Duration(seconds: 20);
}
