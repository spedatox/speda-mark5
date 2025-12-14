import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/services/api_service.dart';
import '../../../core/models/api_response.dart';

/// Message model for the chat UI
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<ChatAction>? actions;
  final bool isStreaming;
  final bool isFunctionCall;
  final String? functionName;
  final Map<String, dynamic>? functionResult;
  final String? processingStatus; // For inline processing indicator

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.actions,
    this.isStreaming = false,
    this.isFunctionCall = false,
    this.functionName,
    this.functionResult,
    this.processingStatus,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    bool? isUser,
    DateTime? timestamp,
    List<ChatAction>? actions,
    bool? isStreaming,
    bool? isFunctionCall,
    String? functionName,
    Map<String, dynamic>? functionResult,
    String? processingStatus,
  }) {
    return ChatMessage(
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      actions: actions ?? this.actions,
      isStreaming: isStreaming ?? this.isStreaming,
      isFunctionCall: isFunctionCall ?? this.isFunctionCall,
      functionName: functionName ?? this.functionName,
      functionResult: functionResult ?? this.functionResult,
      processingStatus: processingStatus ?? this.processingStatus,
    );
  }
}

/// Chat provider for managing conversation state.
class ChatProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<ChatMessage> _messages = [];
  int? _conversationId;
  String? _conversationTitle;
  bool _isLoading = false;
  String? _error;
  bool _isStreaming = false;
  bool _isBackendConnected = false;
  StreamSubscription<NotificationEvent>? _notificationSub;

  ChatProvider(this._apiService) {
    _checkBackendConnection();
    _startNotificationStream();
  }

  Future<void> _checkBackendConnection() async {
    try {
      await _apiService.checkHealth();
      _isBackendConnected = true;
    } catch (e) {
      _isBackendConnected = false;
    }
    notifyListeners();
  }

  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;
  String? get error => _error;
  int? get conversationId => _conversationId;
  String? get conversationTitle => _conversationTitle;
  bool get isBackendConnected => _isBackendConnected;

  /// Refresh backend connection status
  Future<void> refreshConnectionStatus() => _checkBackendConnection();

  /// Safe notify that schedules after frame if needed
  void _safeNotifyListeners() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _startNotificationStream() {
    _notificationSub ??= _apiService.streamNotifications().listen((event) {
      if (event.type == 'reminder' && event.items != null) {
        for (final item in event.items!) {
          final title = item['title']?.toString() ?? 'Reminder';
          final status = item['status']?.toString() ?? '';
          final due = item['due_date']?.toString();
          final statusLabel = status == 'overdue' ? 'Overdue' : 'Due soon';
          final text = due != null
              ? '$statusLabel: $title (due $due)'
              : '$statusLabel: $title';
          _messages = [
            ..._messages,
            ChatMessage(
              content: text,
              isUser: false,
            ),
          ];
        }
        _safeNotifyListeners();
      }
    }, onError: (_) {});
  }

  /// Send a message with streaming response
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Add user message
    _messages = [
      ..._messages,
      ChatMessage(
        content: message,
        isUser: true,
      )
    ];
    _isLoading = true;
    _isStreaming = true;
    _error = null;
    _safeNotifyListeners();

    // Add placeholder for assistant response with processing status
    _messages = [
      ..._messages,
      ChatMessage(
        content: '',
        isUser: false,
        isStreaming: true,
        processingStatus: 'Processing...',
      )
    ];
    _safeNotifyListeners();

    try {
      String fullResponse = '';
      String? currentFunctionName;

      await for (final event in _apiService.streamMessage(
        message: message,
        conversationId: _conversationId,
      )) {
        switch (event.type) {
          case 'start':
            _conversationId = event.conversationId;
            _isBackendConnected = true; // Connected successfully
            break;
          case 'function_start':
            // Show that a function is being executed - inline with processingStatus
            currentFunctionName = event.functionName;
            final statusMessage =
                _getFunctionStatusMessage(event.functionName ?? 'unknown');
            _messages = [
              ..._messages.sublist(0, _messages.length - 1),
              ChatMessage(
                content: '',
                isUser: false,
                isStreaming: true,
                isFunctionCall: true,
                functionName: event.functionName,
                processingStatus: statusMessage,
              ),
            ];
            _safeNotifyListeners();
            break;
          case 'function_result':
            // Function completed - keep showing function name while processing
            final completedStatusMessage = _getCompletedFunctionStatusMessage(
                event.functionName ?? currentFunctionName ?? 'unknown');
            _messages = [
              ..._messages.sublist(0, _messages.length - 1),
              ChatMessage(
                content: '',
                isUser: false,
                isStreaming: true,
                isFunctionCall: true,
                functionName: event.functionName ?? currentFunctionName,
                functionResult: event.functionResult,
                processingStatus: completedStatusMessage,
              ),
            ];
            _safeNotifyListeners();
            break;
          case 'chunk':
            if (event.content != null) {
              fullResponse += event.content!;
              // Keep showing function context while synthesizing
              final processingStatus = currentFunctionName != null
                  ? _getSynthesizingStatusMessage(currentFunctionName)
                  : null;
              // Update the last message with accumulated content
              _messages = [
                ..._messages.sublist(0, _messages.length - 1),
                ChatMessage(
                  content: fullResponse,
                  isUser: false,
                  isStreaming: true,
                  processingStatus: processingStatus,
                ),
              ];
              _safeNotifyListeners();
            }
            break;
          case 'done':
            // Finalize the message
            _messages = [
              ..._messages.sublist(0, _messages.length - 1),
              ChatMessage(
                content: event.content ?? fullResponse,
                isUser: false,
                isStreaming: false,
              ),
            ];
            break;
          case 'title_generated':
            // Store the AI-generated conversation title
            _conversationTitle = event.title;
            _safeNotifyListeners();
            break;
          case 'error':
            _error = event.message;
            _messages = [
              ..._messages.sublist(0, _messages.length - 1),
              ChatMessage(
                content: 'Sorry, something went wrong. Please try again.',
                isUser: false,
                isStreaming: false,
              ),
            ];
            break;
        }
      }
    } catch (e) {
      _error = e.toString();
      _isBackendConnected = false; // Mark as disconnected on error
      // Replace the streaming placeholder with error message
      if (_messages.isNotEmpty && _messages.last.isStreaming) {
        _messages = [
          ..._messages.sublist(0, _messages.length - 1),
          ChatMessage(
            content: 'Connection error. Backend may be offline.',
            isUser: false,
            isStreaming: false,
          ),
        ];
      }
    } finally {
      _isLoading = false;
      _isStreaming = false;
      _safeNotifyListeners();
    }
  }

  /// Upload a file/image to knowledge base and surface confirmation
  Future<void> uploadFile(String filePath) async {
    _isLoading = true;
    _safeNotifyListeners();
    try {
      final result = await _apiService.uploadDocument(filePath: filePath);
      final msg = result['message']?.toString() ?? 'File uploaded';
      addSystemMessage(msg);
    } catch (e) {
      addSystemMessage('Upload failed: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Get a user-friendly status message for function execution
  String _getFunctionStatusMessage(String functionName) {
    switch (functionName) {
      case 'get_calendar_events':
        return '📅 Checking your calendar...';
      case 'create_calendar_event':
        return '📅 Creating calendar event...';
      case 'get_tasks':
        return '✅ Fetching your tasks...';
      case 'create_task':
        return '✅ Creating new task...';
      case 'complete_task':
        return '✅ Completing task...';
      case 'delete_task':
        return '🗑️ Deleting task...';
      case 'get_current_weather':
        return '🌤️ Checking weather...';
      case 'get_weather_forecast':
        return '🌤️ Getting weather forecast...';
      case 'get_news_headlines':
        return '📰 Fetching news...';
      case 'search_news':
        return '📰 Searching news...';
      case 'web_search':
        return '🔍 Searching the web...';
      case 'get_daily_briefing':
        return '📋 Preparing your briefing...';
      default:
        return '⚙️ Processing...';
    }
  }

  /// Get status message after function completed
  String _getCompletedFunctionStatusMessage(String functionName) {
    switch (functionName) {
      case 'get_calendar_events':
        return '📅 Calendar data received, analyzing...';
      case 'create_calendar_event':
        return '📅 Event created, preparing confirmation...';
      case 'get_tasks':
        return '✅ Tasks retrieved, analyzing...';
      case 'create_task':
        return '✅ Task created, preparing confirmation...';
      case 'complete_task':
        return '✅ Task completed, preparing confirmation...';
      case 'delete_task':
        return '🗑️ Task deleted, preparing confirmation...';
      case 'get_current_weather':
        return '🌤️ Weather data received, preparing summary...';
      case 'get_weather_forecast':
        return '🌤️ Forecast received, preparing summary...';
      case 'get_news_headlines':
        return '📰 Headlines received, preparing summary...';
      case 'search_news':
        return '📰 Articles found, preparing summary...';
      case 'web_search':
        return '🔍 Search results received, analyzing...';
      case 'get_daily_briefing':
        return '📋 Briefing data compiled, formatting...';
      default:
        return '⚙️ Data received, preparing response...';
    }
  }

  /// Get status message while synthesizing response after function call
  String _getSynthesizingStatusMessage(String functionName) {
    switch (functionName) {
      case 'get_calendar_events':
        return '📅 Formatting calendar response...';
      case 'get_tasks':
        return '✅ Formatting task list...';
      case 'get_current_weather':
      case 'get_weather_forecast':
        return '🌤️ Formatting weather report...';
      case 'get_news_headlines':
      case 'search_news':
        return '📰 Formatting news summary...';
      case 'web_search':
        return '🔍 Formatting search results...';
      case 'get_daily_briefing':
        return '📋 Formatting briefing...';
      default:
        return '⚙️ Generating response...';
    }
  }

  /// Load a conversation from history
  Future<void> loadConversation(int conversationId) async {
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final conversation = await _apiService.getConversation(conversationId);
      _conversationId = conversation.id;
      _messages = conversation.messages
          .map((msg) => ChatMessage(
                content: msg.content,
                isUser: msg.role == 'user',
                timestamp: msg.createdAt,
              ))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Clear conversation and start fresh
  void clearConversation() {
    _messages = [];
    _conversationId = null;
    _conversationTitle = null;
    _error = null;
    _safeNotifyListeners();
  }

  /// Add a system message (for actions, etc.)
  void addSystemMessage(String content) {
    _messages = [
      ..._messages,
      ChatMessage(
        content: content,
        isUser: false,
      )
    ];
    _safeNotifyListeners();
  }

  /// Regenerate the last assistant response
  Future<void> regenerateLastResponse() async {
    if (_messages.isEmpty) return;

    // Find the last user message
    int lastUserIndex = -1;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        lastUserIndex = i;
        break;
      }
    }

    if (lastUserIndex == -1) return;

    final lastUserMessage = _messages[lastUserIndex].content;

    // Remove all messages after the user message
    _messages = _messages.sublist(0, lastUserIndex + 1);
    _safeNotifyListeners();

    // Resend the message
    await _resendLastUserMessage(lastUserMessage);
  }

  /// Edit and resend a message (removes it and all following messages)
  Future<void> editMessage(int messageIndex, String newContent) async {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    if (!_messages[messageIndex].isUser) return;

    // Remove this message and all following
    _messages = _messages.sublist(0, messageIndex);
    _safeNotifyListeners();

    // Send the edited message
    await sendMessage(newContent);
  }

  /// Internal: resend a message without adding it again
  Future<void> _resendLastUserMessage(String message) async {
    if (message.trim().isEmpty) return;

    _isLoading = true;
    _isStreaming = true;
    _error = null;
    _safeNotifyListeners();

    // Add placeholder for assistant response
    _messages = [
      ..._messages,
      ChatMessage(
        content: '',
        isUser: false,
        isStreaming: true,
        processingStatus: '⚙️ Processing...',
      )
    ];
    _safeNotifyListeners();

    try {
      String fullResponse = '';
      String? currentFunctionName;

      await for (final event in _apiService.streamMessage(
        message: message,
        conversationId: _conversationId,
      )) {
        switch (event.type) {
          case 'start':
            _conversationId = event.conversationId;
            _isBackendConnected = true;
            break;
          case 'function_start':
            currentFunctionName = event.functionName;
            final statusMessage =
                _getFunctionStatusMessage(event.functionName ?? 'unknown');
            _messages = [
              ..._messages.sublist(0, _messages.length - 1),
              ChatMessage(
                content: '',
                isUser: false,
                isStreaming: true,
                isFunctionCall: true,
                functionName: event.functionName,
                processingStatus: statusMessage,
              ),
            ];
            _safeNotifyListeners();
            break;
          case 'function_result':
            final completedStatusMessage = _getCompletedFunctionStatusMessage(
                event.functionName ?? currentFunctionName ?? 'unknown');
            _messages = [
              ..._messages.sublist(0, _messages.length - 1),
              ChatMessage(
                content: '',
                isUser: false,
                isStreaming: true,
                isFunctionCall: true,
                functionName: event.functionName ?? currentFunctionName,
                functionResult: event.functionResult,
                processingStatus: completedStatusMessage,
              ),
            ];
            _safeNotifyListeners();
            break;
          case 'chunk':
            if (event.content != null) {
              fullResponse += event.content!;
              final processingStatus = currentFunctionName != null
                  ? _getSynthesizingStatusMessage(currentFunctionName)
                  : null;
              _messages = [
                ..._messages.sublist(0, _messages.length - 1),
                ChatMessage(
                  content: fullResponse,
                  isUser: false,
                  isStreaming: true,
                  processingStatus: processingStatus,
                ),
              ];
              _safeNotifyListeners();
            }
            break;
          case 'done':
            _messages = [
              ..._messages.sublist(0, _messages.length - 1),
              ChatMessage(
                content: event.content ?? fullResponse,
                isUser: false,
                isStreaming: false,
              ),
            ];
            break;
          case 'title_generated':
            _conversationTitle = event.title;
            _safeNotifyListeners();
            break;
          case 'error':
            _error = event.message;
            _messages = [
              ..._messages.sublist(0, _messages.length - 1),
              ChatMessage(
                content: 'Sorry, something went wrong. Please try again.',
                isUser: false,
                isStreaming: false,
              ),
            ];
            break;
        }
      }
    } catch (e) {
      _error = e.toString();
      _isBackendConnected = false;
      if (_messages.isNotEmpty && _messages.last.isStreaming) {
        _messages = [
          ..._messages.sublist(0, _messages.length - 1),
          ChatMessage(
            content: 'Connection error. Backend may be offline.',
            isUser: false,
            isStreaming: false,
          ),
        ];
      }
    } finally {
      _isLoading = false;
      _isStreaming = false;
      _safeNotifyListeners();
    }
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _apiService.dispose();
    super.dispose();
  }
}
