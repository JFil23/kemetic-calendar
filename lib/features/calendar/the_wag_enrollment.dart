import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../widgets/kemetic_date_picker.dart';
import 'dawn_house_rite_flow.dart';
import 'the_wag_scheduler.dart';
import 'track_sky_flow.dart';

bool _wagEnrollmentTimeZonesInitialized = false;

void _ensureWagEnrollmentTimeZonesInitialized() {
  if (_wagEnrollmentTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _wagEnrollmentTimeZonesInitialized = true;
}

class WagEnrollmentWindow {
  final int kYear;
  final DateTime opensAtLocal;
  final DateTime closesAtLocal;
  final DateTime wepRonpetLocalDate;
  final TrackSkyTimeZone timezone;

  const WagEnrollmentWindow({
    required this.kYear,
    required this.opensAtLocal,
    required this.closesAtLocal,
    required this.wepRonpetLocalDate,
    required this.timezone,
  });
}

DateTime wagNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureWagEnrollmentTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return DateTime(
    zoned.year,
    zoned.month,
    zoned.day,
    zoned.hour,
    zoned.minute,
    zoned.second,
    zoned.millisecond,
    zoned.microsecond,
  );
}

DateTime defaultTheWagStartDate(TrackSkyTimeZone timezone, {DateTime? now}) {
  final window = wagNextEnrollmentWindow(timezone, now: now);
  return DateTime(
    window.opensAtLocal.year,
    window.opensAtLocal.month,
    window.opensAtLocal.day,
  );
}

WagEnrollmentWindow wagEnrollmentWindowForKYear(
  int kYear,
  TrackSkyTimeZone timezone,
) {
  // The Wag's event dates are fixed to the app's Kemetic civil Month 1.
  // Keep enrollment on that same M1 D1 anchor so joining cannot create
  // already-past Month 1 events from a separate astronomical new-moon window.
  final wepRonpet = wagYearStartGregorian(kYear);
  final dawn = dawnHouseRiteScheduleForDate(wepRonpet, timezone);
  return WagEnrollmentWindow(
    kYear: kYear,
    opensAtLocal: dawn.startLocal,
    closesAtLocal: dawn.startLocal.add(const Duration(hours: 48)),
    wepRonpetLocalDate: DateTime(
      dawn.startLocal.year,
      dawn.startLocal.month,
      dawn.startLocal.day,
    ),
    timezone: timezone,
  );
}

WagEnrollmentWindow wagNextEnrollmentWindow(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = wagNowInZone(timezone, now: now);
  final current = KemeticMath.fromGregorian(nowLocal).kYear;
  for (var kYear = current; kYear <= current + 5; kYear++) {
    final window = wagEnrollmentWindowForKYear(kYear, timezone);
    if (!window.closesAtLocal.isBefore(nowLocal)) return window;
  }
  throw StateError('No Wag enrollment window found.');
}

WagEnrollmentWindow? wagCurrentEnrollmentWindow(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = wagNowInZone(timezone, now: now);
  final current = KemeticMath.fromGregorian(nowLocal).kYear;
  for (var kYear = current - 1; kYear <= current + 1; kYear++) {
    final window = wagEnrollmentWindowForKYear(kYear, timezone);
    if (!nowLocal.isBefore(window.opensAtLocal) &&
        !nowLocal.isAfter(window.closesAtLocal)) {
      return window;
    }
  }
  return null;
}

bool wagEnrollmentIsOpen(WagEnrollmentWindow window, {DateTime? now}) {
  final nowLocal = wagNowInZone(window.timezone, now: now);
  return !nowLocal.isBefore(window.opensAtLocal) &&
      !nowLocal.isAfter(window.closesAtLocal);
}

WagEnrollmentWindow? wagEnrollmentWindowForStartDate(
  DateTime startDate,
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final selected = DateTime(startDate.year, startDate.month, startDate.day);
  for (final window in wagUpcomingEnrollmentWindows(
    timezone,
    now: now,
    count: 6,
    includeRecentlyClosed: true,
  )) {
    if (_sameDate(selected, window.opensAtLocal) ||
        _sameDate(selected, window.wepRonpetLocalDate)) {
      return window;
    }
  }
  return null;
}

List<WagEnrollmentWindow> wagUpcomingEnrollmentWindows(
  TrackSkyTimeZone timezone, {
  DateTime? now,
  int count = 6,
  bool includeRecentlyClosed = false,
}) {
  final nowLocal = wagNowInZone(timezone, now: now);
  final current = KemeticMath.fromGregorian(nowLocal).kYear;
  final windows = <WagEnrollmentWindow>[];
  for (
    var kYear = current - (includeRecentlyClosed ? 1 : 0);
    kYear <= current + count + 1;
    kYear++
  ) {
    final window = wagEnrollmentWindowForKYear(kYear, timezone);
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
