import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Service for managing local notifications (reminders, task alerts, etc.)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> init() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    // Android settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    debugPrint('[NotificationService] Initialized');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
        '[NotificationService] Notification tapped: ${response.payload}');
    // TODO: Navigate to relevant screen based on payload
  }

  /// Request notification permissions (call on first launch or settings)
  Future<bool> requestPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final iOS = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iOS != null) {
      final granted = await iOS.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true; // Desktop platforms don't need permission
  }

  /// Schedule a notification for a specific time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    // Don't schedule notifications in the past
    if (scheduledTime.isBefore(DateTime.now())) {
      debugPrint('[NotificationService] Skipping past notification: $title');
      return;
    }

    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'speda_reminders',
      'Hatırlatıcılar',
      channelDescription: 'Speda hatırlatıcı bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    debugPrint(
        '[NotificationService] Scheduled: "$title" at ${scheduledTime.toString()}');
  }

  /// Schedule a reminder X minutes before an event
  Future<void> scheduleEventReminder({
    required String eventId,
    required String eventTitle,
    required DateTime eventTime,
    int minutesBefore = 15,
    String? location,
  }) async {
    final reminderTime = eventTime.subtract(Duration(minutes: minutesBefore));

    final body = location != null
        ? '$minutesBefore dakika sonra: $eventTitle\n📍 $location'
        : '$minutesBefore dakika sonra: $eventTitle';

    await scheduleNotification(
      id: eventId.hashCode,
      title: '⏰ Yaklaşan Etkinlik',
      body: body,
      scheduledTime: reminderTime,
      payload: 'event:$eventId',
    );
  }

  /// Schedule a task due reminder
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    required DateTime dueTime,
    int minutesBefore = 30,
  }) async {
    final reminderTime = dueTime.subtract(Duration(minutes: minutesBefore));

    await scheduleNotification(
      id: taskId.hashCode,
      title: '📋 Görev Hatırlatması',
      body: '$taskTitle - $minutesBefore dakika kaldı!',
      scheduledTime: reminderTime,
      payload: 'task:$taskId',
    );
  }

  /// Schedule a custom reminder (from chat "hatırlat" command)
  Future<void> scheduleCustomReminder({
    required String message,
    required DateTime reminderTime,
  }) async {
    await scheduleNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🔔 Speda Hatırlatması',
      body: message,
      scheduledTime: reminderTime,
      payload: 'reminder:$message',
    );
  }

  /// Show an immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'speda_general',
      'Genel Bildirimler',
      channelDescription: 'Speda genel bildirimleri',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint('[NotificationService] Cancelled notification: $id');
  }

  /// Cancel a notification by event/task ID
  Future<void> cancelByEntityId(String entityId) async {
    await cancelNotification(entityId.hashCode);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    debugPrint('[NotificationService] Cancelled all notifications');
  }

  /// Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}
