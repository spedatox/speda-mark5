import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io' show Platform;

/// Google Sign-In service for native mobile authentication
class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  // Web client ID for backend token verification
  // This is used to request an ID token that the backend can verify
  static const String _serverClientId =
      '295111632948-uk6k0hr7ukomdcchbqk6e0o2bkmqlq7d.apps.googleusercontent.com';

  // Scopes needed for Calendar and Tasks
  static const List<String> _scopes = [
    'email',
    'profile',
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/tasks',
    'https://www.googleapis.com/auth/tasks.readonly',
  ];

  GoogleSignIn? _googleSignIn;

  /// Initialize Google Sign-In
  void _ensureInitialized() {
    _googleSignIn ??= GoogleSignIn(
      scopes: _scopes,
      serverClientId: _serverClientId,
    );
  }

  /// Check if we should use native sign-in (mobile platforms)
  static bool get shouldUseNativeSignIn {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Sign in with Google natively
  Future<GoogleSignInAuthentication?> signIn() async {
    _ensureInitialized();

    try {
      final account = await _googleSignIn!.signIn();
      if (account == null) {
        return null; // User cancelled
      }

      final auth = await account.authentication;
      return auth;
    } catch (e) {
      print('Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _ensureInitialized();
    await _googleSignIn?.signOut();
  }

  /// Check if already signed in
  Future<bool> isSignedIn() async {
    _ensureInitialized();
    return await _googleSignIn?.isSignedIn() ?? false;
  }

  /// Get current user info
  GoogleSignInAccount? get currentUser => _googleSignIn?.currentUser;

  /// Get access token for API calls
  Future<String?> getAccessToken() async {
    _ensureInitialized();

    try {
      // Try silent sign-in first
      var account = await _googleSignIn!.signInSilently();
      account ??= _googleSignIn!.currentUser;

      if (account != null) {
        final auth = await account.authentication;
        return auth.accessToken;
      }
    } catch (e) {
      print('Error getting access token: $e');
    }
    return null;
  }
}
