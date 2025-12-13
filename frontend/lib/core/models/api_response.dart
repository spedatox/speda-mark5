import 'package:equatable/equatable.dart';

/// Chat response from the API
class ChatResponse extends Equatable {
  final String reply;
  final List<ChatAction> actions;
  final int conversationId;

  const ChatResponse({
    required this.reply,
    required this.actions,
    required this.conversationId,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      reply: json['reply'] as String,
      actions: (json['actions'] as List<dynamic>?)
              ?.map((a) => ChatAction.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      conversationId: json['conversation_id'] as int,
    );
  }

  @override
  List<Object?> get props => [reply, actions, conversationId];
}

/// Action returned from chat
class ChatAction extends Equatable {
  final String type;
  final Map<String, dynamic> payload;
  final String? message;

  const ChatAction({
    required this.type,
    required this.payload,
    this.message,
  });

  factory ChatAction.fromJson(Map<String, dynamic> json) {
    return ChatAction(
      type: json['type'] as String,
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      message: json['message'] as String?,
    );
  }

  @override
  List<Object?> get props => [type, payload, message];
}

/// Task model
class TaskModel extends Equatable {
  final int id;
  final String title;
  final String? notes;
  final DateTime? dueDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskModel({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now()) && isPending;

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as int,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [id, title, notes, dueDate, status, createdAt, updatedAt];
}

/// Calendar event model
class EventModel extends Equatable {
  final int id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final bool allDay;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    required this.allDay,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      location: json['location'] as String?,
      allDay: json['all_day'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        startTime,
        endTime,
        location,
        allDay,
        createdAt,
        updatedAt
      ];
}

/// Briefing model
class BriefingModel extends Equatable {
  final DateTime date;
  final String greeting;
  final List<BriefingTask> tasksPending;
  final List<BriefingTask> tasksOverdue;
  final List<BriefingEvent> eventsToday;
  final List<BriefingEmail> pendingEmails;
  final WeatherInfo? weather;
  final List<String>? newsSummary;

  const BriefingModel({
    required this.date,
    required this.greeting,
    required this.tasksPending,
    required this.tasksOverdue,
    required this.eventsToday,
    required this.pendingEmails,
    this.weather,
    this.newsSummary,
  });

  factory BriefingModel.fromJson(Map<String, dynamic> json) {
    return BriefingModel(
      date: DateTime.parse(json['date'] as String),
      greeting: json['greeting'] as String,
      tasksPending: (json['tasks_pending'] as List<dynamic>?)
              ?.map((t) => BriefingTask.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      tasksOverdue: (json['tasks_overdue'] as List<dynamic>?)
              ?.map((t) => BriefingTask.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      eventsToday: (json['events_today'] as List<dynamic>?)
              ?.map((e) => BriefingEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pendingEmails: (json['pending_emails'] as List<dynamic>?)
              ?.map((e) => BriefingEmail.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      weather: json['weather'] != null
          ? WeatherInfo.fromJson(json['weather'] as Map<String, dynamic>)
          : null,
      newsSummary: (json['news_summary'] as List<dynamic>?)?.cast<String>(),
    );
  }

  @override
  List<Object?> get props => [
        date,
        greeting,
        tasksPending,
        tasksOverdue,
        eventsToday,
        pendingEmails,
        weather,
        newsSummary
      ];
}

class BriefingTask extends Equatable {
  final int id;
  final String title;
  final DateTime? dueDate;
  final bool isOverdue;

  const BriefingTask({
    required this.id,
    required this.title,
    this.dueDate,
    this.isOverdue = false,
  });

  factory BriefingTask.fromJson(Map<String, dynamic> json) {
    return BriefingTask(
      id: json['id'] as int,
      title: json['title'] as String,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      isOverdue: json['is_overdue'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, title, dueDate, isOverdue];
}

class BriefingEvent extends Equatable {
  final int id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;

  const BriefingEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
  });

  factory BriefingEvent.fromJson(Map<String, dynamic> json) {
    return BriefingEvent(
      id: json['id'] as int,
      title: json['title'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      location: json['location'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, title, startTime, endTime, location];
}

class BriefingEmail extends Equatable {
  final int id;
  final String subject;
  final String status;

  const BriefingEmail({
    required this.id,
    required this.subject,
    required this.status,
  });

  factory BriefingEmail.fromJson(Map<String, dynamic> json) {
    return BriefingEmail(
      id: json['id'] as int,
      subject: json['subject'] as String,
      status: json['status'] as String,
    );
  }

  @override
  List<Object?> get props => [id, subject, status];
}

class WeatherInfo extends Equatable {
  final double temperature;
  final String condition;
  final double high;
  final double low;
  final String location;

  const WeatherInfo({
    required this.temperature,
    required this.condition,
    required this.high,
    required this.low,
    required this.location,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      temperature: (json['temperature'] as num).toDouble(),
      condition: json['condition'] as String,
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      location: json['location'] as String,
    );
  }

  @override
  List<Object?> get props => [temperature, condition, high, low, location];
}

/// Email model
class EmailModel extends Equatable {
  final int id;
  final String mailbox;
  final String toAddress;
  final String? ccAddress;
  final String subject;
  final String body;
  final String status;
  final bool confirmationRequired;
  final DateTime? sentAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmailModel({
    required this.id,
    required this.mailbox,
    required this.toAddress,
    this.ccAddress,
    required this.subject,
    required this.body,
    required this.status,
    required this.confirmationRequired,
    this.sentAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmailModel.fromJson(Map<String, dynamic> json) {
    return EmailModel(
      id: json['id'] as int,
      mailbox: json['mailbox'] as String,
      toAddress: json['to_address'] as String,
      ccAddress: json['cc_address'] as String?,
      subject: json['subject'] as String,
      body: json['body'] as String,
      status: json['status'] as String,
      confirmationRequired: json['confirmation_required'] as bool,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        mailbox,
        toAddress,
        ccAddress,
        subject,
        body,
        status,
        confirmationRequired,
        sentAt,
        createdAt,
        updatedAt
      ];
}
