import 'package:flutter/foundation.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/api_response.dart';

/// Briefing provider for managing daily briefing state.
class BriefingProvider extends ChangeNotifier {
  final ApiService _apiService;
  final LocationService _locationService = LocationService();

  BriefingModel? _briefing;
  bool _isLoading = false;
  String? _error;

  BriefingProvider(this._apiService);

  // Getters
  BriefingModel? get briefing => _briefing;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasBriefing => _briefing != null;

  /// Load today's briefing with location-based weather
  Future<void> loadBriefing() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get user's location for weather
      double? latitude;
      double? longitude;

      try {
        final position = await _locationService.getCurrentLocation();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
          debugPrint('[BRIEFING] Got location: $latitude, $longitude');
        }
      } catch (e) {
        debugPrint('[BRIEFING] Could not get location: $e');
      }

      _briefing = await _apiService.getTodayBriefing(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh briefing
  Future<void> refresh() async {
    await loadBriefing();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
