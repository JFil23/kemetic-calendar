// Foundation models for in-app reminders (Flutter-side only)

import 'dart:convert';

/// Delivery channel for a reminder. Push can be layered later; for now this
/// simply documents intent.
enum ReminderChannel { pushAndInApp, inAppOnly, none }

/// Lifecycle state of a reminder.
enum ReminderStatus { pending, sentPush, shownInApp, completed }

class Reminder {
  final String id;
  final String title;
  final String? detail;
  final DateTime alertAtUtc;
  final String? eventId;
  final String? flowId;
  final ReminderChannel channel;
  final ReminderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Reminder({
    required this.id,
    required this.title,
    this.detail,
    required this.alertAtUtc,
    this.eventId,
    this.flowId,
    this.channel = ReminderChannel.pushAndInApp,
    this.status = ReminderStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  Reminder copyWith({
    String? title,
    String? detail,
    DateTime? alertAtUtc,
    String? eventId,
    String? flowId,
    ReminderChannel? channel,
    ReminderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      alertAtUtc: alertAtUtc ?? this.alertAtUtc,
      eventId: eventId ?? this.eventId,
      flowId: flowId ?? this.flowId,
      channel: channel ?? this.channel,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'detail': detail,
      'alert_at_utc': alertAtUtc.toIso8601String(),
      'event_id': eventId,
      'flow_id': flowId,
      'channel': channel.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      title: json['title'] as String,
      detail: json['detail'] as String?,
      alertAtUtc: DateTime.parse(json['alert_at_utc'] as String),
      eventId: json['event_id'] as String?,
      flowId: json['flow_id'] as String?,
      channel: ReminderChannel.values.firstWhere(
        (c) => c.name == (json['channel'] as String? ?? 'pushAndInApp'),
        orElse: () => ReminderChannel.pushAndInApp,
      ),
      status: ReminderStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String? ?? 'pending'),
        orElse: () => ReminderStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static String encodeList(List<Reminder> list) =>
      jsonEncode(list.map((r) => r.toJson()).toList());

  static List<Reminder> decodeList(String raw) {
    final data = jsonDecode(raw) as List<dynamic>;
    return data.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
  }
}
