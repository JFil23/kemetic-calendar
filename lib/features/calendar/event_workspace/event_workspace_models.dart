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

const double eventWorkspacePlayerAspectRatio = 16 / 9;

String formatEventWorkspaceRemaining(Duration remaining) {
  final clamped = remaining.isNegative ? Duration.zero : remaining;
  final total = clamped.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} remaining';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')} remaining';
}

String? eventWorkspacePurposeFromDetail(String? detail) {
  var text = detail?.trim() ?? '';
  if (text.startsWith('flowLocalId=')) {
    final semi = text.indexOf(';');
    if (semi >= 0 && semi < text.length - 1) {
      text = text.substring(semi + 1).trim();
    } else {
      text = '';
    }
  }
  if (text.isEmpty) return null;
  return text;
}
