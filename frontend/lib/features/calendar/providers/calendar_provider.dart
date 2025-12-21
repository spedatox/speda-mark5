import 'package:flutter/foundation.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/models/api_response.dart';

/// Calendar provider for managing events state.
/// Supports both local events and Google Calendar events.
class CalendarProvider extends ChangeNotifier {
  final ApiService _apiService;
  final NotificationService _notificationService = NotificationService();

  List<EventModel> _localEvents = [];
  List<GoogleCalendarEvent> _googleEvents = [];
  bool _isLoading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  bool _googleConnected = false;

  CalendarProvider(this._apiService);

  // Getters
  List<EventModel> get localEvents => List.unmodifiable(_localEvents);
  List<GoogleCalendarEvent> get googleEvents =>
      List.unmodifiable(_googleEvents);
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;
  bool get googleConnected => _googleConnected;

  /// Get all events for today (combined)
  List<dynamic> get todayEvents {
    final now = DateTime.now();
    final List<dynamic> combined = [];

    // Add Google events for today
    combined.addAll(_googleEvents.where((e) {
      if (e.start == null) return false;
      return e.start!.year == now.year &&
          e.start!.month == now.month &&
          e.start!.day == now.day;
    }));

    // Add local events for today
    combined.addAll(_localEvents.where((e) =>
        e.startTime.year == now.year &&
        e.startTime.month == now.month &&
        e.startTime.day == now.day));

    return combined;
  }

  /// Get events for a specific date (combined)
  List<dynamic> getEventsForDate(DateTime date) {
    final List<dynamic> combined = [];

    // Add Google events
    combined.addAll(_googleEvents.where((e) {
      if (e.start == null) return false;
      return e.start!.year == date.year &&
          e.start!.month == date.month &&
          e.start!.day == date.day;
    }));

    // Add local events
    combined.addAll(_localEvents.where((e) =>
        e.startTime.year == date.year &&
        e.startTime.month == date.month &&
        e.startTime.day == date.day));

    return combined;
  }

  /// Load all events (tries Google first, falls back to local)
  Future<void> loadEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to load from Google Calendar
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now().add(const Duration(days: 60));

      _googleEvents = await _apiService.getGoogleCalendarEvents(
        startDate: start.toIso8601String(),
        endDate: end.toIso8601String(),
      );
      _googleConnected = true;
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        _googleConnected = false;
        // Fall back to local events
        try {
          _localEvents = await _apiService.getEvents(
            startDate:
                startDate ?? DateTime.now().subtract(const Duration(days: 30)),
            endDate: endDate ?? DateTime.now().add(const Duration(days: 60)),
          );
        } catch (_) {
          // Ignore local errors
        }
      } else {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load today's events
  Future<void> loadTodayEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to load from Google Calendar
      _googleEvents = await _apiService.getGoogleTodayEvents();
      _googleConnected = true;
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        _googleConnected = false;
        // Fall back to local events
        try {
          _localEvents = await _apiService.getTodayEvents();
        } catch (_) {
          // Ignore local errors
        }
      } else {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new event - uses Google Calendar if connected
  Future<dynamic> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    String? location,
    bool allDay = false,
  }) async {
    try {
      // Check Google auth status if not already connected
      if (!_googleConnected) {
        try {
          final authStatus = await _apiService.getAuthStatus();
          _googleConnected = authStatus['google'] ?? false;
        } catch (_) {
          // Ignore auth check errors
        }
      }

      if (_googleConnected) {
        // Create in Google Calendar
        final event = await _apiService.createGoogleCalendarEvent(
          title: title,
          startTime: startTime,
          endTime: endTime,
          description: description,
          location: location,
        );
        _googleEvents.add(event);
        _googleEvents.sort((a, b) {
          final aStart = a.start ?? DateTime.now();
          final bStart = b.start ?? DateTime.now();
          return aStart.compareTo(bStart);
        });

        // Schedule notification reminder
        if (event.start != null) {
          await _notificationService.scheduleEventReminder(
            eventId: event.id,
            eventTitle: event.summary,
            eventTime: event.start!,
            minutesBefore: 15,
            location: event.location,
          );
        }

        notifyListeners();
        return event;
      } else {
        // Create locally
        final event = await _apiService.createEvent(
          title: title,
          startTime: startTime,
          endTime: endTime,
          description: description,
          location: location,
          allDay: allDay,
        );
        _localEvents.add(event);
        _localEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

        // Schedule notification reminder for local event
        await _notificationService.scheduleEventReminder(
          eventId: event.id.toString(),
          eventTitle: event.title,
          eventTime: event.startTime,
          minutesBefore: 15,
          location: event.location,
        );

        notifyListeners();
        return event;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Set selected date
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh events
  Future<void> refresh() async {
    await loadEvents();
  }
}
