import 'package:flutter/foundation.dart';

import '../../../core/services/api_service.dart';
import '../../../core/models/api_response.dart';

/// Briefing provider for managing daily briefing state.
class BriefingProvider extends ChangeNotifier {
  final ApiService _apiService;

  BriefingModel? _briefing;
  bool _isLoading = false;
  String? _error;

  BriefingProvider(this._apiService);

  // Getters
  BriefingModel? get briefing => _briefing;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasBriefing => _briefing != null;

  /// Load today's briefing
  Future<void> loadBriefing() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _briefing = await _apiService.getTodayBriefing();
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
