import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Application configuration constants.
class AppConfig {
  AppConfig._();

  // Backend mode keys
  static const String _backendModeKey = 'backend_mode';
  static const String localMode = 'local';
  static const String cloudMode = 'cloud';

  // Cached values
  static String? _cachedBackendMode;
  static SharedPreferences? _prefs;

  /// Initialize the config (call this at app startup)
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _cachedBackendMode = _prefs?.getString(_backendModeKey);
  }

  /// Get current backend mode
  static String get backendMode =>
      _cachedBackendMode ?? cloudMode; // Default to cloud, even in debug

  /// Check if using local backend
  static bool get isLocalBackend => backendMode == localMode;

  /// Check if using cloud backend
  static bool get isCloudBackend => backendMode == cloudMode;

  /// Switch backend mode
  static Future<void> setBackendMode(String mode) async {
    _cachedBackendMode = mode;
    await _prefs?.setString(_backendModeKey, mode);
  }

  /// Environment detection
  static bool get isProduction => !kDebugMode;

  /// Local backend URL
  static String get localBackendUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Cloud backend URL
  static const String cloudBackendUrl = 'http://157.173.111.215:8000';

  /// Base URL for the Speda API (dynamic based on mode)
  static String get apiBaseUrl {
    if (isLocalBackend) {
      return localBackendUrl;
    }
    return cloudBackendUrl;
  }

  /// API key for authentication
  static String get apiKey {
    if (isLocalBackend) {
      return 'speda-dev-token'; // Local dev token
    }
    // Production API key
    return const String.fromEnvironment('SPEDA_API_KEY',
        defaultValue: 'sk-speda-prod-api-2025');
  }

  /// Default timezone
  static const String defaultTimezone = 'Europe/Istanbul';

  /// App name
  static const String appName = 'Speda';

  /// App version
  static const String appVersion = '1.0.0';

  /// Mobile OAuth redirect scheme
  static const String mobileRedirectUri = 'speda://auth/callback';
}
