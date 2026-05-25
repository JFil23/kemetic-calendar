import 'package:flutter/material.dart';

import '../../widgets/kemetic_date_picker.dart';
import 'the_days_outside_year_scheduler.dart';
import 'track_sky_flow.dart';

class DaysOutsideYearEnrollmentWindow {
  final int closingKYear;
  final DateTime opensAtLocal;
  final DateTime closesAtLocal;
  final DateTime anchorLocalDate;
  final TrackSkyTimeZone timezone;

  const DaysOutsideYearEnrollmentWindow({
    required this.closingKYear,
    required this.opensAtLocal,
    required this.closesAtLocal,
    required this.anchorLocalDate,
    required this.timezone,
  });
}

DateTime defaultTheDaysOutsideYearStartDate(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final window = daysOutsideYearNextEnrollmentWindow(timezone, now: now);
  return DateUtils.dateOnly(window.opensAtLocal);
}

DaysOutsideYearEnrollmentWindow daysOutsideYearEnrollmentWindowForClosingYear(
  int closingKYear,
  TrackSkyTimeZone timezone,
) {
  final anchor = daysOutsideEnrollmentOpenGregorian(closingKYear);
  final epi1 = daysOutsideEventGregorian(
    closingKYear: closingKYear,
    kMonth: 13,
    kDay: 1,
  );
  final opens = DateTime(anchor.year, anchor.month, anchor.day);
  final closes = DateTime(epi1.year, epi1.month, epi1.day);
  return DaysOutsideYearEnrollmentWindow(
    closingKYear: closingKYear,
    opensAtLocal: opens,
    closesAtLocal: closes,
    anchorLocalDate: opens,
    timezone: timezone,
  );
}

DaysOutsideYearEnrollmentWindow? daysOutsideYearCurrentEnrollmentWindow(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = daysOutsideNowInZone(timezone, now: now);
  final current = KemeticMath.fromGregorian(nowLocal).kYear;
  for (var kYear = current - 1; kYear <= current + 1; kYear++) {
    final window = daysOutsideYearEnrollmentWindowForClosingYear(
      kYear,
      timezone,
    );
    if (daysOutsideYearEnrollmentIsOpen(window, now: now)) return window;
  }
  return null;
}

DaysOutsideYearEnrollmentWindow daysOutsideYearNextEnrollmentWindow(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = daysOutsideNowInZone(timezone, now: now);
  final current = KemeticMath.fromGregorian(nowLocal).kYear;
  for (var kYear = current - 1; kYear <= current + 6; kYear++) {
    final window = daysOutsideYearEnrollmentWindowForClosingYear(
      kYear,
      timezone,
    );
    if (!window.closesAtLocal.isBefore(nowLocal)) return window;
  }
  throw StateError('No Days Outside the Year enrollment window found.');
}

bool daysOutsideYearEnrollmentIsOpen(
  DaysOutsideYearEnrollmentWindow window, {
  DateTime? now,
}) {
  final nowLocal = daysOutsideNowInZone(window.timezone, now: now);
  return !nowLocal.isBefore(window.opensAtLocal) &&
      nowLocal.isBefore(window.closesAtLocal);
}

DaysOutsideYearEnrollmentWindow? daysOutsideYearEnrollmentWindowForStartDate(
  DateTime startDate,
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final selected = DateUtils.dateOnly(startDate);
  for (final window in daysOutsideYearUpcomingEnrollmentWindows(
    timezone,
    now: now,
    count: 6,
    includeRecentlyClosed: true,
  )) {
    if (DateUtils.isSameDay(selected, window.opensAtLocal)) return window;
  }
  return null;
}

List<DaysOutsideYearEnrollmentWindow> daysOutsideYearUpcomingEnrollmentWindows(
  TrackSkyTimeZone timezone, {
  DateTime? now,
  int count = 6,
  bool includeRecentlyClosed = false,
}) {
  final nowLocal = daysOutsideNowInZone(timezone, now: now);
  final current = KemeticMath.fromGregorian(nowLocal).kYear;
  final windows = <DaysOutsideYearEnrollmentWindow>[];
  for (
    var kYear = current - (includeRecentlyClosed ? 1 : 0);
    kYear <= current + count + 2;
    kYear++
  ) {
    final window = daysOutsideYearEnrollmentWindowForClosingYear(
      kYear,
      timezone,
    );
    if (includeRecentlyClosed || !window.closesAtLocal.isBefore(nowLocal)) {
      windows.add(window);
      if (windows.length >= count) break;
    }
  }
  return windows;
}

String daysOutsideYearEnrollmentClosedMessage(
  DaysOutsideYearEnrollmentWindow next,
) {
  return 'The Days Outside the Year begins only at the close of the Kemetic year. The next enrollment window opens on ${_isoDate(next.opensAtLocal)}, two days before the year closes.';
}

String _isoDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
