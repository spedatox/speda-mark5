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

  ChatProvider(this._apiService) {
    _checkBackendConnection();
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

  /// Send a message with streaming response
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Add user message
    _messages = [..._messages, ChatMessage(
      content: message,
      isUser: true,
    )];
    _isLoading = true;
    _isStreaming = true;
    _error = null;
    _safeNotifyListeners();

    // Add placeholder for assistant response with processing status
    _messages = [..._messages, ChatMessage(
      content: '',
      isUser: false,
      isStreaming: true,
      processingStatus: 'Processing...',
    )];
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
            final statusMessage = _getFunctionStatusMessage(event.functionName ?? 'unknown');
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
            // Function completed, store result (response will follow)
            _messages = [
              ..._messages.sublist(0, _messages.length - 1),
              ChatMessage(
                content: '',
                isUser: false,
                isStreaming: true,
                isFunctionCall: false,
                functionName: event.functionName,
                functionResult: event.functionResult,
                processingStatus: 'Generating response...',
              ),
            ];
            _safeNotifyListeners();
            break;
          case 'chunk':
            if (event.content != null) {
              fullResponse += event.content!;
              // Update the last message with accumulated content
              _messages = [
                ..._messages.sublist(0, _messages.length - 1),
                ChatMessage(
                  content: fullResponse,
                  isUser: false,
                  isStreaming: true,
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
      case 'get_daily_briefing':
        return '📋 Preparing your briefing...';
      default:
        return '⚡ Processing...';
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
      _messages = conversation.messages.map((msg) => ChatMessage(
        content: msg.content,
        isUser: msg.role == 'user',
        timestamp: msg.createdAt,
      )).toList();
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
    _messages = [..._messages, ChatMessage(
      content: content,
      isUser: false,
    )];
    _safeNotifyListeners();
  }
}
