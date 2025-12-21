import 'package:flutter/foundation.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/models/api_response.dart';

/// Task provider for managing tasks state.
/// Supports both local tasks and Google Tasks.
class TaskProvider extends ChangeNotifier {
  final ApiService _apiService;
  final NotificationService _notificationService = NotificationService();

  List<TaskModel> _localTasks = [];
  List<GoogleTask> _googleTasks = [];
  bool _isLoading = false;
  String? _error;
  bool _showCompleted = false;
  bool _googleConnected = false;

  TaskProvider(this._apiService);

  // Getters
  List<TaskModel> get localTasks => List.unmodifiable(_localTasks);
  List<GoogleTask> get googleTasks => List.unmodifiable(_googleTasks);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get showCompleted => _showCompleted;
  bool get googleConnected => _googleConnected;

  /// Combined tasks getter - returns local if Google not connected
  List<dynamic> get tasks {
    if (_googleConnected) {
      return _googleTasks;
    }
    return _localTasks;
  }

  /// Pending tasks count
  int get pendingCount {
    if (_googleConnected) {
      return _googleTasks.where((t) => !t.isCompleted).length;
    }
    return _localTasks.where((t) => t.isPending).length;
  }

  /// Overdue tasks
  List<dynamic> get overdueTasks {
    if (_googleConnected) {
      return _googleTasks.where((t) => t.isOverdue).toList();
    }
    return _localTasks.where((t) => t.isOverdue).toList();
  }

  /// Load all tasks (tries Google first, falls back to local)
  Future<void> loadTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to load from Google Tasks
      _googleTasks = await _apiService.getGoogleTasks(
        showCompleted: _showCompleted,
      );
      _googleConnected = true;
      // Clear local tasks when Google is connected to avoid confusion
      _localTasks = [];
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        _googleConnected = false;
        // Fall back to local tasks
        try {
          _localTasks = await _apiService.getTasks(includeDone: _showCompleted);
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

  /// Create a new task - always creates in Google if connected
  Future<bool> createTask({
    required String title,
    String? notes,
    DateTime? dueDate,
  }) async {
    try {
      // First ensure we know if Google is connected by checking auth status
      if (!_googleConnected) {
        // Double-check Google auth status
        try {
          final authStatus = await _apiService.getAuthStatus();
          _googleConnected = authStatus['google'] ?? false;
        } catch (_) {
          // Ignore auth check errors
        }
      }

      if (_googleConnected) {
        final task = await _apiService.createGoogleTask(
          title: title,
          notes: notes,
          dueDate: dueDate,
        );
        _googleTasks.insert(0, task);

        // Schedule notification if due date is set
        if (dueDate != null) {
          await _notificationService.scheduleTaskReminder(
            taskId: task.id,
            taskTitle: task.title,
            dueTime: dueDate,
            minutesBefore: 60, // 1 hour before
          );
        }
      } else {
        final task = await _apiService.createTask(
          title: title,
          notes: notes,
          dueDate: dueDate,
        );
        _localTasks.insert(0, task);

        // Schedule notification if due date is set
        if (dueDate != null) {
          await _notificationService.scheduleTaskReminder(
            taskId: task.id.toString(),
            taskTitle: task.title,
            dueTime: dueDate,
            minutesBefore: 60, // 1 hour before
          );
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Complete a task
  Future<bool> completeTask(dynamic taskId) async {
    try {
      if (_googleConnected && taskId is String) {
        await _apiService.completeGoogleTask(taskId);
        final index = _googleTasks.indexWhere((t) => t.id == taskId);
        if (index != -1) {
          _googleTasks.removeAt(index);
        }
      } else if (taskId is int) {
        final updatedTask = await _apiService.completeTask(taskId);
        final index = _localTasks.indexWhere((t) => t.id == taskId);
        if (index != -1) {
          _localTasks[index] = updatedTask;
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a local task
  Future<bool> deleteTask(int taskId) async {
    try {
      await _apiService.deleteTask(taskId, confirmed: true);
      _localTasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggle showing completed tasks
  void toggleShowCompleted() {
    _showCompleted = !_showCompleted;
    loadTasks();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh tasks
  Future<void> refresh() async {
    await loadTasks();
  }
}
