import '../../widgets/kemetic_date_picker.dart';
import 'the_decan_watch_enrollment.dart';
import 'the_decan_watch_scheduler.dart';
import 'track_sky_flow.dart';

typedef DjedEnrollmentWindow = DecanWatchEnrollmentWindow;

DateTime defaultTheDjedStartDate(TrackSkyTimeZone timezone, {DateTime? now}) {
  return defaultTheDecanWatchStartDate(timezone, now: now);
}

DjedEnrollmentWindow? djedCurrentEnrollmentWindow(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  return decanWatchCurrentEnrollmentWindow(timezone, now: now);
}

DjedEnrollmentWindow djedNextEnrollmentWindow(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  return decanWatchNextEnrollmentWindow(timezone, now: now);
}

bool djedEnrollmentIsOpen(DjedEnrollmentWindow window, {DateTime? now}) {
  return decanWatchEnrollmentIsOpen(window, now: now);
}

DjedEnrollmentWindow? djedEnrollmentWindowForStartDate(
  DateTime startDate,
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  return decanWatchEnrollmentWindowForStartDate(startDate, timezone, now: now);
}

List<DjedEnrollmentWindow> djedUpcomingEnrollmentWindows(
  TrackSkyTimeZone timezone, {
  DateTime? now,
  int count = 12,
  bool includeRecentlyClosed = false,
}) {
  return decanWatchUpcomingEnrollmentWindows(
    timezone,
    now: now,
    count: count,
    includeRecentlyClosed: includeRecentlyClosed,
  );
}

bool djedStartDateIsValid(DateTime start, TrackSkyTimeZone timezone) {
  final local = DateTime(start.year, start.month, start.day);
  final k = KemeticMath.fromGregorian(local);
  return isDecanOpeningKemeticDay(k.kMonth, k.kDay);
}

String djedEnrollmentClosedMessage(DjedEnrollmentWindow next) {
  return 'The Djed begins at the opening of a new decan. The next window opens on ${_isoDate(next.opensAtLocal)}, when ${next.openingOccurrence.decanName} begins.';
}

String _isoDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
