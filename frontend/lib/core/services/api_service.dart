import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/api_response.dart';

/// API Service for communicating with the Speda backend.
class ApiService {
  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  ApiService({
    required this.baseUrl,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      };

  // ==================== Health Check ====================

  /// Check if backend is reachable
  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/health'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==================== Authentication ====================

  /// Get combined auth status
  Future<Map<String, bool>> getAuthStatus() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/auth/status'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'google': data['google']?['authenticated'] ?? false,
        'microsoft': data['microsoft']?['authenticated'] ?? false,
      };
    }
    return {'google': false, 'microsoft': false};
  }

  /// Get Google auth URL
  Future<String?> getGoogleAuthUrl(
      {String? redirectUri, String platform = 'web'}) async {
    final uri = Uri.parse('$baseUrl/api/auth/google/login').replace(
      queryParameters: {
        if (redirectUri != null) 'redirect_uri': redirectUri,
        'platform': platform,
      },
    );
    final response = await _client.get(
      uri,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['auth_url'];
    }
    return null;
  }

  /// Logout from Google
  Future<void> logoutGoogle() async {
    await _client.post(
      Uri.parse('$baseUrl/api/auth/google/logout'),
      headers: _headers,
    );
  }

  /// Send mobile Google access token to backend
  Future<bool> sendGoogleMobileToken(String accessToken,
      {String? idToken}) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/auth/google/mobile-token'),
        headers: _headers,
        body: jsonEncode({
          'access_token': accessToken,
          if (idToken != null) 'id_token': idToken,
        }),
      );
      print(
          'sendGoogleMobileToken response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('sendGoogleMobileToken error: $e');
      return false;
    }
  }

  // ==================== Settings ====================

  /// Get the active LLM settings
  Future<LlmSettings> getLlmSettings() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/settings/llm'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return LlmSettings.fromJson(jsonDecode(response.body));
    }
    throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to load LLM settings');
  }

  /// Update the LLM provider/model
  Future<LlmSettings> updateLlm({
    required String provider,
    String? model,
    String? llmBaseUrl,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/settings/llm'),
      headers: _headers,
      body: jsonEncode({
        'provider': provider,
        if (model != null) 'model': model,
        if (llmBaseUrl != null) 'base_url': llmBaseUrl,
      }),
    );
    if (response.statusCode == 200) {
      return LlmSettings.fromJson(jsonDecode(response.body));
    }
    throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to update LLM settings');
  }

  // ==================== Files ====================

  /// Upload a file and return its ID
  Future<String> uploadFile(String filePath) async {
    final uri = Uri.parse('$baseUrl/api/files/upload');
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll({
      'X-API-Key': apiKey,
    });

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['file_id'] as String;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: 'Failed to upload file: ${response.body}',
    );
  }

  /// Get file content URL
  String getFileUrl(String fileId) {
    return '$baseUrl/api/files/$fileId/content';
  }

  /// Open URL in browser
  Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ==================== Google Calendar ====================

  /// Get Google Calendar events
  Future<List<GoogleCalendarEvent>> getGoogleCalendarEvents({
    String? startDate,
    String? endDate,
    int maxResults = 50,
  }) async {
    final queryParams = <String>[];
    if (startDate != null) queryParams.add('start_date=$startDate');
    if (endDate != null) queryParams.add('end_date=$endDate');
    queryParams.add('max_results=$maxResults');

    final response = await _client.get(
      Uri.parse(
          '$baseUrl/api/integrations/calendar/events?${queryParams.join('&')}'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['events'] as List)
          .map((e) => GoogleCalendarEvent.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      throw ApiException(statusCode: 401, message: 'Google not connected');
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to get calendar events',
      );
    }
  }

  /// Get today's Google Calendar events
  Future<List<GoogleCalendarEvent>> getGoogleTodayEvents() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/integrations/calendar/today'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['events'] as List)
          .map((e) => GoogleCalendarEvent.fromJson(e))
          .toList();
    } else if (response.statusCode == 401) {
      throw ApiException(statusCode: 401, message: 'Google not connected');
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to get today events',
      );
    }
  }

  /// Create a Google Calendar event
  Future<GoogleCalendarEvent> createGoogleCalendarEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    String? location,
    String calendarId = 'primary',
  }) async {
    final response = await _client.post(
      Uri.parse(
          '$baseUrl/api/integrations/calendar/events?calendar_id=$calendarId&summary=$title&start_time=${startTime.toIso8601String()}&end_time=${endTime.toIso8601String()}${description != null ? '&description=$description' : ''}${location != null ? '&location=$location' : ''}'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return GoogleCalendarEvent.fromJson(data['event']);
    } else if (response.statusCode == 401) {
      throw ApiException(statusCode: 401, message: 'Google not connected');
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to create calendar event',
      );
    }
  }

  // ==================== Google Tasks ====================

  /// Get Google Tasks
  Future<List<GoogleTask>> getGoogleTasks({
    bool showCompleted = false,
    int maxResults = 100,
  }) async {
    final response = await _client.get(
      Uri.parse(
          '$baseUrl/api/integrations/tasks?show_completed=$showCompleted&max_results=$maxResults'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['tasks'] as List)
          .map((t) => GoogleTask.fromJson(t))
          .toList();
    } else if (response.statusCode == 401) {
      throw ApiException(statusCode: 401, message: 'Google not connected');
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to get tasks',
      );
    }
  }

  /// Create a Google Task
  Future<GoogleTask> createGoogleTask({
    required String title,
    String? notes,
    DateTime? dueDate,
  }) async {
    final queryParams = <String>['title=${Uri.encodeComponent(title)}'];
    if (notes != null) queryParams.add('notes=${Uri.encodeComponent(notes)}');
    if (dueDate != null)
      queryParams.add('due_date=${dueDate.toIso8601String()}');

    final response = await _client.post(
      Uri.parse('$baseUrl/api/integrations/tasks?${queryParams.join('&')}'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return GoogleTask.fromJson(data['task']);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to create task',
      );
    }
  }

  /// Complete a Google Task
  Future<void> completeGoogleTask(String taskId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/integrations/tasks/$taskId/complete'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to complete task',
      );
    }
  }

  // ==================== Chat ====================

  /// Send a chat message
  Future<ChatResponse> sendMessage({
    required String message,
    String timezone = 'Europe/Istanbul',
    int? conversationId,
  }) async {
    final queryParams =
        conversationId != null ? '?conversation_id=$conversationId' : '';

    final response = await _client.post(
      Uri.parse('$baseUrl/chat$queryParams'),
      headers: _headers,
      body: jsonEncode({
        'message': message,
        'timezone': timezone,
      }),
    );

    if (response.statusCode == 200) {
      return ChatResponse.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to send message',
      );
    }
  }

  // ==================== Voice ====================

  /// Send a voice message (for voice mode)
  /// Uses the streaming endpoint and collects the full response
  /// Optional onStatus callback is called with function status updates
  Future<String> sendVoiceMessage(
    String message, {
    void Function(String functionName)? onFunctionStart,
  }) async {
    // Create a dedicated client for this streaming request
    final streamClient = http.Client();

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/chat/stream'),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
        'Accept': 'text/event-stream',
      });
      request.body = jsonEncode({
        'message': message,
        'timezone': 'Europe/Istanbul',
      });

      final streamedResponse = await streamClient.send(request);

      if (streamedResponse.statusCode != 200) {
        throw ApiException(
          statusCode: streamedResponse.statusCode,
          message: 'Failed to send voice message',
        );
      }

      // Collect all chunks from the stream
      final StringBuffer fullResponse = StringBuffer();

      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        // Parse SSE events
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6);
            if (dataStr == '[DONE]') continue;
            try {
              final data = jsonDecode(dataStr);
              final type = data['type'];

              // Handle function start events
              if (type == 'function_start' && onFunctionStart != null) {
                final functionName =
                    data['function_name'] ?? data['name'] ?? 'unknown';
                onFunctionStart(functionName);
              }

              // Handle text chunks
              if (type == 'chunk' && data['content'] != null) {
                fullResponse.write(data['content']);
              }
            } catch (_) {
              // Skip malformed JSON
            }
          }
        }
      }

      return fullResponse.toString();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 500,
        message: 'Failed to send voice message: $e',
      );
    } finally {
      streamClient.close();
    }
  }

  /// Get TTS audio URL from backend
  /// Backend generates audio using OpenAI gpt-4o-mini-tts and returns a URL
  Future<String> getTTSAudio(
    String text, {
    String voice = 'marin',
    String instructions =
        'Speak in an energetic, happy, and upbeat tone. Be enthusiastic and friendly.',
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/voice/tts'),
      headers: _headers,
      body: jsonEncode({
        'text': text,
        'voice': voice,
        'instructions': instructions,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['audio_url'] ?? '';
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to generate TTS audio',
      );
    }
  }

  // ==================== Tasks ====================

  /// Get all tasks
  Future<List<TaskModel>> getTasks({bool includeDone = false}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/tasks?include_completed=$includeDone'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => TaskModel.fromJson(json)).toList();
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to get tasks',
      );
    }
  }

  /// Create a task
  Future<TaskModel> createTask({
    required String title,
    String? notes,
    DateTime? dueDate,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/tasks'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'notes': notes,
        'due_date': dueDate?.toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return TaskModel.fromJson(data['task']);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to create task',
      );
    }
  }

  /// Complete a task
  Future<TaskModel> completeTask(int taskId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/tasks/$taskId/complete?confirmed=true'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return TaskModel.fromJson(data['task']);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to complete task',
      );
    }
  }

  /// Delete a task
  Future<void> deleteTask(int taskId, {bool confirmed = false}) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/tasks/$taskId?confirmed=$confirmed'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to delete task',
      );
    }
  }

  // ==================== Calendar ====================

  /// Get calendar events
  Future<List<EventModel>> getEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String>[];
    if (startDate != null) {
      queryParams.add('start_date=${startDate.toIso8601String()}');
    }
    if (endDate != null) {
      queryParams.add('end_date=${endDate.toIso8601String()}');
    }
    final queryString =
        queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

    final response = await _client.get(
      Uri.parse('$baseUrl/calendar$queryString'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => EventModel.fromJson(json)).toList();
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to get events',
      );
    }
  }

  /// Get today's events
  Future<List<EventModel>> getTodayEvents() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/calendar/today'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => EventModel.fromJson(json)).toList();
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to get today events',
      );
    }
  }

  /// Create an event
  Future<EventModel> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    String? location,
    bool allDay = false,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/calendar'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'description': description,
        'location': location,
        'all_day': allDay,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return EventModel.fromJson(data['event']);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to create event',
      );
    }
  }

  // ==================== Briefing ====================

  /// Get today's briefing with optional location for weather
  Future<BriefingModel> getTodayBriefing({
    String timezone = 'Europe/Istanbul',
    double? latitude,
    double? longitude,
  }) async {
    String url = '$baseUrl/briefing/today?timezone=$timezone';
    if (latitude != null && longitude != null) {
      url += '&latitude=$latitude&longitude=$longitude';
    }

    final response = await _client.get(
      Uri.parse(url),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return BriefingModel.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to get briefing',
      );
    }
  }

  // ==================== Email ====================

  /// Draft an email
  Future<EmailModel> draftEmail({
    required String to,
    required String subject,
    required String body,
    String? cc,
    String mailbox = 'personal',
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/email/draft'),
      headers: _headers,
      body: jsonEncode({
        'to_address': to,
        'subject': subject,
        'body': body,
        'cc_address': cc,
        'mailbox': mailbox,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return EmailModel.fromJson(data['email']);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to draft email',
      );
    }
  }

  /// Send an email (requires confirmation)
  Future<Map<String, dynamic>> sendEmail(int emailId,
      {bool confirmed = false}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/email/send?email_id=$emailId&confirmed=$confirmed'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to send email',
      );
    }
  }

  // ==================== Streaming Chat ====================

  /// Stream a chat message response
  Stream<StreamEvent> streamMessage({
    required String message,
    String timezone = 'Europe/Istanbul',
    int? conversationId,
    List<String>? images,
    Map<String, dynamic>? location,
  }) async* {
    final queryParams =
        conversationId != null ? '?conversation_id=$conversationId' : '';

    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/chat/stream$queryParams'),
    );
    request.headers.addAll(_headers);
    request.body = jsonEncode({
      'message': message,
      'timezone': timezone,
      if (images != null && images.isNotEmpty) 'images': images,
      if (location != null) 'location': location,
    });

    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode != 200) {
      throw ApiException(
        statusCode: streamedResponse.statusCode,
        message: 'Failed to stream message',
      );
    }

    final stream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in stream) {
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6);
        if (jsonStr.isNotEmpty) {
          try {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            yield StreamEvent.fromJson(data);
          } catch (e) {
            // Skip malformed JSON
          }
        }
      }
    }
  }

  // ==================== Notifications (SSE) ====================

  /// Stream realtime notifications
  Stream<NotificationEvent> streamNotifications() async* {
    final request = http.Request(
      'GET',
      Uri.parse('$baseUrl/notifications/stream'),
    );
    request.headers.addAll({
      ..._headers,
      'Accept': 'text/event-stream',
    });

    final streamedResponse = await _client.send(request);
    if (streamedResponse.statusCode != 200) {
      throw ApiException(
        statusCode: streamedResponse.statusCode,
        message: 'Failed to stream notifications',
      );
    }

    final stream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in stream) {
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6);
        if (jsonStr.isNotEmpty) {
          try {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            yield NotificationEvent.fromJson(data);
          } catch (_) {
            // ignore malformed
          }
        }
      }
    }
  }

  // ==================== Uploads ====================

  /// Upload a document or image to knowledge base
  Future<Map<String, dynamic>> uploadDocument({
    required String filePath,
    int chunkSize = 1000,
  }) async {
    final uri = Uri.parse('$baseUrl/api/knowledge/documents');
    final request = http.MultipartRequest('POST', uri);
    // Only add auth header, not Content-Type (multipart sets its own)
    request.headers['X-API-Key'] = apiKey;
    request.fields['chunk_size'] = chunkSize.toString();
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    // Send with timeout
    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw ApiException(
            statusCode: 408,
            message: 'Upload timed out after 60 seconds',
          ),
        );

    final body = await streamedResponse.stream.bytesToString();
    if (streamedResponse.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    throw ApiException(
        statusCode: streamedResponse.statusCode,
        message: 'Upload failed: $body');
  }

  // ==================== Conversation History ====================

  /// Get list of conversations
  Future<List<ConversationPreview>> getConversations({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/chat/conversations?limit=$limit&offset=$offset'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ConversationPreview.fromJson(json)).toList();
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to get conversations',
      );
    }
  }

  /// Get a specific conversation with all messages
  Future<ConversationDetail> getConversation(int conversationId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/chat/conversations/$conversationId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return ConversationDetail.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to get conversation',
      );
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(int conversationId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/chat/conversations/$conversationId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to delete conversation',
      );
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Stream event types
class StreamEvent {
  final String type;
  final String? content;
  final int? conversationId;
  final String? message;
  // Function calling fields
  final String? functionName;
  final Map<String, dynamic>? functionResult;
  // Title generation
  final String? title;

  StreamEvent({
    required this.type,
    this.content,
    this.conversationId,
    this.message,
    this.functionName,
    this.functionResult,
    this.title,
  });

  factory StreamEvent.fromJson(Map<String, dynamic> json) {
    return StreamEvent(
      type: json['type'] as String,
      content: json['content'] as String?,
      conversationId: json['conversation_id'] as int?,
      message: json['message'] as String?,
      functionName: json['name'] as String?,
      functionResult: json['result'] as Map<String, dynamic>?,
      title: json['title'] as String?,
    );
  }
}

/// Notification event
class NotificationEvent {
  final String type;
  final String? message;
  final List<dynamic>? items;
  final String? timestamp;

  NotificationEvent({
    required this.type,
    this.message,
    this.items,
    this.timestamp,
  });

  factory NotificationEvent.fromJson(Map<String, dynamic> json) {
    return NotificationEvent(
      type: json['type'] as String? ?? 'unknown',
      message: json['message'] as String?,
      items: json['items'] as List<dynamic>?,
      timestamp: json['timestamp'] as String?,
    );
  }
}

/// LLM settings model
class LlmSettings {
  final String provider;
  final List<String> availableProviders;
  final List<String> availableModels;
  final String? model;
  final String? baseUrl;

  LlmSettings({
    required this.provider,
    required this.availableProviders,
    required this.availableModels,
    this.model,
    this.baseUrl,
  });

  factory LlmSettings.fromJson(Map<String, dynamic> json) {
    return LlmSettings(
      provider: json['provider'] as String? ?? 'mock',
      availableProviders: (json['available_providers'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['available'] as List?)?.map((e) => e.toString()).toList() ??
          const ['mock'],
      availableModels: (json['available_models'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['gpt-4-turbo-preview'],
      model: json['model'] as String?,
      baseUrl: json['base_url'] as String?,
    );
  }
}

/// Conversation preview for list
class ConversationPreview {
  final int id;
  final String title;
  final DateTime startedAt;
  final String preview;
  final int messageCount;

  ConversationPreview({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.preview,
    required this.messageCount,
  });

  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    return ConversationPreview(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Yeni Sohbet',
      startedAt: DateTime.parse(json['started_at'] as String),
      preview: json['preview'] as String,
      messageCount: json['message_count'] as int,
    );
  }
}

/// Full conversation with messages
class ConversationDetail {
  final int id;
  final DateTime startedAt;
  final List<ConversationMessage> messages;

  ConversationDetail({
    required this.id,
    required this.startedAt,
    required this.messages,
  });

  factory ConversationDetail.fromJson(Map<String, dynamic> json) {
    return ConversationDetail(
      id: json['id'] as int,
      startedAt: DateTime.parse(json['started_at'] as String),
      messages: (json['messages'] as List)
          .map((m) => ConversationMessage.fromJson(m))
          .toList(),
    );
  }
}

/// Message in a conversation
class ConversationMessage {
  final int id;
  final String role;
  final String content;
  final DateTime createdAt;

  ConversationMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: json['id'] as int,
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// API Exception
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Google Calendar Event model
class GoogleCalendarEvent {
  final String id;
  final String summary;
  final String? description;
  final DateTime? start;
  final DateTime? end;
  final String? location;
  final bool isAllDay;

  GoogleCalendarEvent({
    required this.id,
    required this.summary,
    this.description,
    this.start,
    this.end,
    this.location,
    this.isAllDay = false,
  });

  factory GoogleCalendarEvent.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        // Convert to local time if it's UTC
        return parsed?.toLocal();
      }
      if (value is Map) {
        // Google returns {dateTime: "...", timeZone: "..."} or {date: "..."}
        if (value['dateTime'] != null) {
          final parsed = DateTime.tryParse(value['dateTime']);
          // Convert to local time if it's UTC
          return parsed?.toLocal();
        } else if (value['date'] != null) {
          // All-day events, keep as is (no time component)
          return DateTime.tryParse(value['date']);
        }
      }
      return null;
    }

    final startData = json['start'];
    final endData = json['end'];
    final isAllDay = startData is Map && startData['date'] != null;

    return GoogleCalendarEvent(
      id: json['id'] ?? '',
      summary: json['summary'] ?? 'Untitled Event',
      description: json['description'],
      start: parseDateTime(startData),
      end: parseDateTime(endData),
      location: json['location'],
      isAllDay: isAllDay,
    );
  }
}

/// Google Task model
class GoogleTask {
  final String id;
  final String title;
  final String? notes;
  final DateTime? due;
  final String status;
  final DateTime? completed;

  GoogleTask({
    required this.id,
    required this.title,
    this.notes,
    this.due,
    required this.status,
    this.completed,
  });

  bool get isCompleted => status == 'completed';

  bool get isOverdue {
    if (due == null || isCompleted) return false;
    return due!.isBefore(DateTime.now());
  }

  factory GoogleTask.fromJson(Map<String, dynamic> json) {
    return GoogleTask(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Task',
      notes: json['notes'],
      due: json['due'] != null ? DateTime.tryParse(json['due']) : null,
      status: json['status'] ?? 'needsAction',
      completed: json['completed'] != null
          ? DateTime.tryParse(json['completed'])
          : null,
    );
  }
}

// ==================== File Upload Extensions ====================

extension FileUploadExtension on ApiService {
  /// Upload a file with optional analysis
  Future<Map<String, dynamic>> uploadFile(
    String filePath, {
    bool analyze = false,
    String? prompt,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/files/upload'),
    );

    request.headers['X-API-Key'] = apiKey;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    request.fields['analyze'] = analyze.toString();
    if (prompt != null) request.fields['prompt'] = prompt;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to upload file',
      );
    }
  }

  /// Analyze image with GPT-4 Vision
  Future<String> analyzeImage(
    String imagePath, {
    String prompt = 'What\'s in this image? Describe everything you see.',
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/files/analyze-image'),
    );

    request.headers['X-API-Key'] = apiKey;
    request.files.add(await http.MultipartFile.fromPath('file', imagePath));
    request.fields['prompt'] = prompt;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['description'] ?? '';
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to analyze image',
      );
    }
  }

  /// Analyze image from URL
  Future<String> analyzeImageUrl(
    String imageUrl, {
    String prompt = 'What\'s in this image? Describe everything you see.',
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/files/analyze-url'),
      headers: _headers,
      body: jsonEncode({
        'image_url': imageUrl,
        'prompt': prompt,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['description'] ?? '';
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to analyze image',
      );
    }
  }
}
