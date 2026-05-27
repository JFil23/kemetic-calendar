import '../../widgets/kemetic_date_picker.dart';
import 'the_decan_watch_flow.dart';
import 'the_decan_watch_scheduler.dart';
import 'track_sky_flow.dart';

class DecanWatchEnrollmentWindow {
  final DateTime opensAtLocal;
  final DateTime closesAtLocal;
  final DecanWatchOccurrence openingOccurrence;

  const DecanWatchEnrollmentWindow({
    required this.opensAtLocal,
    required this.closesAtLocal,
    required this.openingOccurrence,
  });
}

DateTime defaultTheDecanWatchStartDate(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final window = decanWatchNextEnrollmentWindow(timezone, now: now);
  return DateTime(
    window.opensAtLocal.year,
    window.opensAtLocal.month,
    window.opensAtLocal.day,
  );
}

DecanWatchEnrollmentWindow decanWatchWindowForOccurrence(
  DecanWatchOccurrence occurrence,
) {
  final opens = DateTime(
    occurrence.startLocal.year,
    occurrence.startLocal.month,
    occurrence.startLocal.day,
  );
  return DecanWatchEnrollmentWindow(
    opensAtLocal: opens,
    closesAtLocal: opens.add(const Duration(hours: 24)),
    openingOccurrence: occurrence,
  );
}

DecanWatchEnrollmentWindow? decanWatchCurrentEnrollmentWindow(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = decanWatchNowInZone(timezone, now: now);
  final k = KemeticMath.fromGregorian(nowLocal);
  if (!isDecanOpeningKemeticDay(k.kMonth, k.kDay)) return null;
  final occurrence = decanWatchOccurrenceFor(
    kYear: k.kYear,
    kMonth: k.kMonth,
    decanStartDay: k.kDay,
    timezone: timezone,
  );
  final window = decanWatchWindowForOccurrence(occurrence);
  if (!nowLocal.isBefore(window.opensAtLocal) &&
      nowLocal.isBefore(window.closesAtLocal)) {
    return window;
  }
  return null;
}

DecanWatchEnrollmentWindow decanWatchNextEnrollmentWindow(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = decanWatchNowInZone(timezone, now: now);
  final occurrences = upcomingDecanWatchOccurrences(
    timezone: timezone,
    fromLocal: nowLocal,
    count: 12,
  );
  for (final occurrence in occurrences) {
    final window = decanWatchWindowForOccurrence(occurrence);
    if (!window.closesAtLocal.isBefore(nowLocal)) return window;
  }
  throw StateError('No Decan Watch enrollment window found.');
}

bool decanWatchEnrollmentIsOpen(
  DecanWatchEnrollmentWindow window, {
  DateTime? now,
}) {
  final nowLocal = decanWatchNowInZone(
    window.openingOccurrence.timezone,
    now: now,
  );
  return !nowLocal.isBefore(window.opensAtLocal) &&
      nowLocal.isBefore(window.closesAtLocal);
}

DecanWatchEnrollmentWindow? decanWatchEnrollmentWindowForStartDate(
  DateTime startDate,
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final selected = DateTime(startDate.year, startDate.month, startDate.day);
  for (final window in decanWatchUpcomingEnrollmentWindows(
    timezone,
    now: now,
    count: 18,
    includeRecentlyClosed: true,
  )) {
    if (_sameDate(selected, window.opensAtLocal)) return window;
  }
  return null;
}

List<DecanWatchEnrollmentWindow> decanWatchUpcomingEnrollmentWindows(
  TrackSkyTimeZone timezone, {
  DateTime? now,
  int count = 12,
  bool includeRecentlyClosed = false,
}) {
  final nowLocal = decanWatchNowInZone(timezone, now: now);
  final start = includeRecentlyClosed
      ? nowLocal.subtract(const Duration(days: 11))
      : nowLocal;
  final occurrences = upcomingDecanWatchOccurrences(
    timezone: timezone,
    fromLocal: DateTime(start.year, start.month, start.day),
    count: count + (includeRecentlyClosed ? 3 : 0),
  );
  final windows = <DecanWatchEnrollmentWindow>[];
  for (final occurrence in occurrences) {
    final window = decanWatchWindowForOccurrence(occurrence);
    if (includeRecentlyClosed || !window.closesAtLocal.isBefore(nowLocal)) {
      windows.add(window);
      if (windows.length >= count) break;
    }
  }
  return windows;
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
