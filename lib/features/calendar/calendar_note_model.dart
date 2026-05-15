part of 'calendar_page.dart';

/* ───────────────────────── Simple Note model ───────────────────────── */

class _Note {
  final String? id; // optional persistent id
  final String? clientEventId;
  final String? calendarId;
  final String? calendarName;
  final String title;
  final String? detail;
  final String? location;
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;

  /// which flow created this note (for Ma'at flow cleanup). null for normal notes.
  final int? flowId;

  /// Manual color for notes that aren't driven by a flow.
  final Color? manualColor;
  final String? category; // optional category label
  final bool isReminder;
  final String? reminderId;
  final int?
  alertOffsetMinutes; // minutes before start; -1 = none, null = default
  final String? actionId;
  final Map<String, dynamic>? behaviorPayload;

  const _Note({
    this.id,
    this.clientEventId,
    this.calendarId,
    this.calendarName,
    required this.title,
    this.detail,
    this.location,
    required this.allDay,
    this.start,
    this.end,
    this.flowId,
    this.manualColor,
    this.category,
    this.isReminder = false,
    this.reminderId,
    this.alertOffsetMinutes,
    this.actionId,
    this.behaviorPayload,
  });

  _Note copyWith({
    String? id,
    String? clientEventId,
    String? calendarId,
    String? calendarName,
    String? title,
    String? detail,
    String? location,
    bool? allDay,
    TimeOfDay? start,
    TimeOfDay? end,
    int? flowId,
    Color? manualColor,
    String? category,
    bool? isReminder,
    String? reminderId,
    int? alertOffsetMinutes,
    String? actionId,
    Map<String, dynamic>? behaviorPayload,
  }) {
    return _Note(
      id: id ?? this.id,
      clientEventId: clientEventId ?? this.clientEventId,
      calendarId: calendarId ?? this.calendarId,
      calendarName: calendarName ?? this.calendarName,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      location: location ?? this.location,
      allDay: allDay ?? this.allDay,
      start: start ?? this.start,
      end: end ?? this.end,
      flowId: flowId ?? this.flowId,
      manualColor: manualColor ?? this.manualColor,
      category: category ?? this.category,
      isReminder: isReminder ?? this.isReminder,
      reminderId: reminderId ?? this.reminderId,
      alertOffsetMinutes: alertOffsetMinutes ?? this.alertOffsetMinutes,
      actionId: actionId ?? this.actionId,
      behaviorPayload: behaviorPayload ?? this.behaviorPayload,
    );
  }
}
