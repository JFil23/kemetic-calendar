const String eventWorkspacePresentationDetail = 'detail';
const String eventWorkspacePresentationWorkspace = 'workspace';

const List<Duration> eventWorkspaceExtensionChoices = <Duration>[
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
];

bool noteHasCanonicalSchedule({
  required bool allDay,
  required int? startHour,
  required int? startMinute,
  required int? endHour,
  required int? endMinute,
}) {
  return !allDay &&
      startHour != null &&
      startMinute != null &&
      endHour != null &&
      endMinute != null;
}

String normalizeEventWorkspacePresentation(String? raw) {
  return raw == eventWorkspacePresentationWorkspace
      ? eventWorkspacePresentationWorkspace
      : eventWorkspacePresentationDetail;
}

DateTime? canonicalEventDateTime({
  required DateTime day,
  required int minutesSinceMidnight,
}) {
  if (minutesSinceMidnight < 0 || minutesSinceMidnight > (23 * 60 + 59)) {
    return null;
  }
  return DateTime(
    day.year,
    day.month,
    day.day,
    minutesSinceMidnight ~/ 60,
    minutesSinceMidnight % 60,
  );
}

Duration? eventWorkspaceRemaining({
  required DateTime canonicalEnd,
  required DateTime now,
}) {
  final remaining = canonicalEnd.difference(now);
  if (remaining.isNegative) return Duration.zero;
  return remaining;
}

bool eventWorkspaceHasEnded({
  required DateTime canonicalEnd,
  required DateTime now,
}) {
  return !now.isBefore(canonicalEnd);
}

bool eventWorkspaceIsSessionGovernable({
  required bool presentable,
  required bool allDay,
  required bool hasCanonicalSchedule,
}) {
  return presentable && !allDay && hasCanonicalSchedule;
}
