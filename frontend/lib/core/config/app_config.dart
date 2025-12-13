import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

/// Application configuration constants.
class AppConfig {
  AppConfig._();

  /// Environment detection
  static bool get isProduction => !kDebugMode;
  
  /// Base URL for the Speda API
  /// Always use production server (Oracle Cloud)
  static String get apiBaseUrl {
    // Always use production server
    return 'http://92.5.112.78:8000';
    
    // Uncomment below for local development:
    // if (kDebugMode) {
    //   if (!kIsWeb && Platform.isAndroid) {
    //     return 'http://10.0.2.2:8000';
    //   }
    //   return 'http://localhost:8000';
    // }
    // return 'http://92.5.112.78:8000';
  }

  /// API key for authentication
  /// In production, this should match the server's API_TOKEN
  static String get apiKey {
    if (kDebugMode) {
      return 'sk-speda-prod-api-2025';
    }
    // Production API key
    return const String.fromEnvironment('SPEDA_API_KEY', defaultValue: 'sk-speda-prod-api-2025');
  }

  /// Default timezone
  static const String defaultTimezone = 'Europe/Istanbul';

  /// App name
  static const String appName = 'Speda';

  /// App version
  static const String appVersion = '1.0.0';
}
