import '../../widgets/kemetic_date_picker.dart';
import 'the_decan_watch_enrollment.dart';
import 'the_decan_watch_scheduler.dart';
import 'track_sky_flow.dart';

typedef OpenHandEnrollmentWindow = DecanWatchEnrollmentWindow;

DateTime defaultTheOpenHandStartDate(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  return defaultTheDecanWatchStartDate(timezone, now: now);
}

OpenHandEnrollmentWindow? openHandCurrentEnrollmentWindow(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  return decanWatchCurrentEnrollmentWindow(timezone, now: now);
}

OpenHandEnrollmentWindow openHandNextEnrollmentWindow(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  return decanWatchNextEnrollmentWindow(timezone, now: now);
}

bool openHandEnrollmentIsOpen(
  OpenHandEnrollmentWindow window, {
  DateTime? now,
}) {
  return decanWatchEnrollmentIsOpen(window, now: now);
}

OpenHandEnrollmentWindow? openHandEnrollmentWindowForStartDate(
  DateTime startDate,
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  return decanWatchEnrollmentWindowForStartDate(startDate, timezone, now: now);
}

List<OpenHandEnrollmentWindow> openHandUpcomingEnrollmentWindows(
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

bool openHandStartDateIsValid(DateTime start, TrackSkyTimeZone timezone) {
  final local = DateTime(start.year, start.month, start.day);
  final k = KemeticMath.fromGregorian(local);
  return isDecanOpeningKemeticDay(k.kMonth, k.kDay);
}
