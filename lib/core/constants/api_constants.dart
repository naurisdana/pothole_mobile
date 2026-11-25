/// Konstanta endpoint API dan konfigurasi server RoadSafe Backend.
class ApiConstants {
  ApiConstants._();

  /// Base URL backend FastAPI.
  /// Override: --dart-define=API_BASE_URL=https://host/api/v1
  static const String serverBaseUrl = 'https://api-roadasafe.houselab.my.id/api/v1';

  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return serverBaseUrl;
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
