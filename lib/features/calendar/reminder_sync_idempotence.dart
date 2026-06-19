class ReminderOccurrencePayload {
  const ReminderOccurrencePayload({
    required this.clientEventId,
    required this.title,
    required this.startsAtUtc,
    required this.allDay,
    this.detail,
    this.location,
    this.endsAtUtc,
    this.calendarId,
    this.category,
    this.flowLocalId,
  });

  final String clientEventId;
  final String title;
  final String? detail;
  final String? location;
  final DateTime startsAtUtc;
  final DateTime? endsAtUtc;
  final bool allDay;
  final String? calendarId;
  final String? category;
  final int? flowLocalId;
}

bool reminderOccurrencePayloadMatches({
  required ReminderOccurrencePayload desired,
  required ReminderOccurrencePayload existing,
}) {
  return existing.clientEventId == desired.clientEventId &&
      existing.title == desired.title &&
      existing.detail == desired.detail &&
      existing.location == desired.location &&
      existing.allDay == desired.allDay &&
      _sameInstant(existing.startsAtUtc, desired.startsAtUtc) &&
      _sameNullableInstant(existing.endsAtUtc, desired.endsAtUtc) &&
      existing.calendarId == desired.calendarId &&
      existing.category == desired.category &&
      existing.flowLocalId == desired.flowLocalId;
}

bool _sameInstant(DateTime left, DateTime right) {
  return left.toUtc().isAtSameMomentAs(right.toUtc());
}

bool _sameNullableInstant(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return left == null && right == null;
  }
  return _sameInstant(left, right);
}
