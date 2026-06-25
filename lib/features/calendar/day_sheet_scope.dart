class DaySheetDayWindow {
  const DaySheetDayWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class DaySheetListCandidate {
  const DaySheetListCandidate({
    required this.title,
    required this.sourceType,
    required this.allDay,
    required this.startsAtLocal,
    required this.endsAtLocal,
    this.eventId,
    this.clientEventId,
    this.flowId,
    this.reminderId,
  });

  final String title;
  final String sourceType;
  final bool allDay;
  final DateTime startsAtLocal;
  final DateTime endsAtLocal;
  final String? eventId;
  final String? clientEventId;
  final int? flowId;
  final String? reminderId;
}

DateTime daySheetDateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DaySheetDayWindow daySheetWindowFor(DateTime selectedDate) {
  final start = daySheetDateOnly(selectedDate);
  return DaySheetDayWindow(
    start: start,
    end: start.add(const Duration(days: 1)),
  );
}

DateTime daySheetEndAfterStart(DateTime start, DateTime end) {
  if (end.isAfter(start)) return end;
  return end.add(const Duration(days: 1));
}

bool daySheetCandidateOverlapsWindow(
  DaySheetListCandidate candidate,
  DaySheetDayWindow window,
) {
  return candidate.startsAtLocal.isBefore(window.end) &&
      candidate.endsAtLocal.isAfter(window.start);
}

List<String> daySheetOccurrenceIdentityKeys(DaySheetListCandidate candidate) {
  final keys = <String>[];
  final eventId = candidate.eventId?.trim();
  if (eventId != null && eventId.isNotEmpty) {
    keys.add('event:$eventId');
  }

  final clientEventId = candidate.clientEventId?.trim();
  if (clientEventId != null && clientEventId.isNotEmpty) {
    keys.add('client:$clientEventId');
  }

  final flowId = candidate.flowId;
  if (flowId != null && flowId > 0) {
    keys.add('flow:$flowId:${candidate.startsAtLocal.toIso8601String()}');
  }

  final reminderId = candidate.reminderId?.trim();
  if (reminderId != null && reminderId.isNotEmpty) {
    keys.add(
      'reminder:$reminderId:${candidate.startsAtLocal.toIso8601String()}',
    );
  }

  if (keys.isEmpty) {
    keys.add(
      [
        'fallback',
        candidate.title.trim().toLowerCase(),
        candidate.startsAtLocal.toIso8601String(),
        candidate.endsAtLocal.toIso8601String(),
        candidate.sourceType.trim().toLowerCase(),
      ].join('|'),
    );
  }

  return keys;
}

List<T> filterAndDedupeDaySheetCandidates<T>(
  Iterable<T> items, {
  required DaySheetDayWindow window,
  required DaySheetListCandidate Function(T item) candidateOf,
}) {
  final visible = <T>[];
  final seen = <String>{};

  for (final item in items) {
    final candidate = candidateOf(item);
    if (!daySheetCandidateOverlapsWindow(candidate, window)) continue;

    final keys = daySheetOccurrenceIdentityKeys(candidate);
    if (keys.any(seen.contains)) continue;
    seen.addAll(keys);
    visible.add(item);
  }

  return visible;
}
