import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

/// Application configuration constants.
class AppConfig {
  AppConfig._();

  /// Environment detection
  static bool get isProduction => !kDebugMode;
  
  /// Base URL for the Speda API
  /// In debug mode: localhost
  /// In release mode: production server
  static String get apiBaseUrl {
    if (kDebugMode) {
      // Development - use localhost
      // For Android emulator use 10.0.2.2 instead of localhost
      if (!kIsWeb && Platform.isAndroid) {
        return 'http://10.0.2.2:8000';
      }
      return 'http://localhost:8000';
    }
    // Production - Oracle Cloud Server
    // TODO: Replace with your actual server URL
    return 'https://speda-api.your-domain.com';
  }

  /// API key for authentication
  /// TODO: In production, this should be securely stored
  static String get apiKey {
    if (kDebugMode) {
      return 'sk-test-dev-key-1234567890';
    }
    // Production API key - store securely!
    return const String.fromEnvironment('SPEDA_API_KEY', defaultValue: 'your-production-api-key');
  }

  /// Default timezone
  static const String defaultTimezone = 'Europe/Istanbul';

  /// App name
  static const String appName = 'Speda';

  /// App version
  static const String appVersion = '1.0.0';
}
