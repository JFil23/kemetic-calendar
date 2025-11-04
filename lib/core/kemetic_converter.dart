import 'package:flutter/material.dart' show DateUtils;

import 'package:intl/intl.dart';
import 'package:mobile/features/calendar/kemetic_time_constants.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';

/// Kemetic month numbers 1..12; 0 means epagomenal.
/// Use deprecated shim for backward compatibility (one release cycle)
@Deprecated('Use getMonthById(id).hellenized - removes in v3.0')
final kemeticMonths = kemeticMonthsHellenized;

// Removed - use getMonthById(id).season instead
@Deprecated('Use getSeasonName(id) - removes in v3.0')
final kemeticSeasonsByMonth = <int, String>{
  1: 'Akhet', 2: 'Akhet', 3: 'Akhet', 4: 'Akhet',
  5: 'Peret', 6: 'Peret', 7: 'Peret', 8: 'Peret',
  9: 'Shemu', 10: 'Shemu', 11: 'Shemu', 12: 'Shemu',
};

/// Season meanings for UI.
const seasonMeaning = <String, String>{
  'Akhet': 'Inundation — the Nile floods.',
  'Peret': 'Emergence — fields emerge; growth.',
  'Shemu': 'Low Water — harvest season.',
};

// Removed - now using centralized kKemeticEpochUtc from kemetic_time_constants.dart

class KemeticDate {
  final int year;
  final int month; // 1..12, or 0 if epagomenal
  final int day;
  final bool epagomenal;

  const KemeticDate({
    required this.year,
    required this.month,
    required this.day,
    required this.epagomenal,
  });

  String get monthName => epagomenal ? 'Epagomenal' : getMonthById(month).hellenized;
  String? get season => epagomenal ? null : getSeasonName(month);

  @override
  String toString() {
    if (epagomenal) {
      return 'Kemetic Y$year • Epagomenal Day $day';
    }
    return 'Kemetic Y$year • ${getMonthById(month).hellenized} $day'
        '${season != null ? " (${season})" : ""}';
  }
}

class KemeticConverter {
  KemeticConverter({DateTime? epochLocal})
      : _epochLocal = toUtcDateOnly(epochLocal ?? kKemeticEpochUtc);

  final DateTime _epochLocal;

  KemeticDate fromGregorian(DateTime localDate) {
    // FIXED: Normalize to UTC first to avoid DST issues
    final d = toUtcDateOnly(localDate);
    int days = _daysBetween(_epochLocal, d);

    int kYear = 1;
    DateTime kYearStart = _epochLocal;

    if (days >= 0) {
      while (true) {
        final len = _kemeticYearLength(kYearStart);
        if (days < len) break;
        days -= len;
        kYear++;
        kYearStart = kYearStart.add(Duration(days: len));
      }
    } else {
      while (days < 0) {
        final prevStart = _prevKemeticYearStart(kYearStart);
        final lenPrev = _kemeticYearLength(prevStart);
        days += lenPrev;
        kYear--;
        kYearStart = prevStart;
      }
    }

    if (days < 360) {
      final month = (days ~/ 30) + 1;
      final day = (days % 30) + 1;
      return KemeticDate(year: kYear, month: month, day: day, epagomenal: false);
    } else {
      final len = _kemeticYearLength(kYearStart);
      final epiDay = (days - 360) + 1;
      return KemeticDate(year: kYear, month: 0, day: epiDay, epagomenal: true);
    }
  }

  DateTime toGregorianMidnight(KemeticDate kd) {
    // FIXED: Compute using integer arithmetic, then convert to UTC
    int totalDays = 0;
    int y = 1;
    DateTime start = _epochLocal;
    
    if (kd.year >= 1) {
      while (y < kd.year) {
        totalDays += _kemeticYearLength(start);
        start = start.add(Duration(days: _kemeticYearLength(start)));
        y++;
      }
    } else {
      while (y > kd.year) {
        start = _prevKemeticYearStart(start);
        totalDays -= _kemeticYearLength(start);
        y--;
      }
    }
    
    final offset = kd.month == 0
        ? 360 + (kd.day - 1)
        : (kd.month - 1) * 30 + (kd.day - 1);
    totalDays += offset;
    
    return utcFromEpochDay(epochDayFromUtc(_epochLocal) + totalDays);
  }

  /// LEAP LOGIC & NEW-YEAR DRIFT (gregorian-based)
  ///
  /// We add a 6th epagomenal day when the GREGORIAN year containing
  /// days 361–365 is leap. That makes the Kemetic year length 366.
  /// Consequence: the next Kemetic New Year shifts forward by 1 day.
  ///
  /// Example (Pacific, from our epoch):
  ///   Y1 start 2025-03-20
  ///   Y2 start 2026-03-20
  ///   Y3 start 2027-03-20  (leap → Epi-6 on 2028-03-20)
  ///   Y4 start 2028-03-21  (shifted)
  ///   Y5 start 2029-03-21
  ///   Y6 start 2030-03-21
  ///   Y7 start 2031-03-21  (leap → Epi-6 on 2032-03-21)
  ///   Y8 start 2032-03-22  (shifted again)
  ///
  /// This intentionally follows Gregorian leap years (not a fixed 4-year Kemetic cycle).
  int _kemeticYearLength(DateTime kYearStartLocal) {
    final epagomenalStart = kYearStartLocal.add(const Duration(days: 360));
    final gYear = epagomenalStart.year;
    return _isGregorianLeap(gYear) ? 366 : 365;
  }

  DateTime _prevKemeticYearStart(DateTime currentStart) {
    final guess = currentStart.subtract(const Duration(days: 365));
    final prevLen = _kemeticYearLength(guess);
    return currentStart.subtract(Duration(days: prevLen));
  }

  static bool _isGregorianLeap(int year) {
    if (year % 4 != 0) return false;
    if (year % 100 == 0 && year % 400 != 0) return false;
    return true;
  }

  static int _daysBetween(DateTime a, DateTime b) {
    final da = toUtcDateOnly(a);
    final db = toUtcDateOnly(b);
    return db.difference(da).inDays;
  }
}

String formatKemeticToday({DateTime? todayLocal, KemeticConverter? conv}) {
  final converter = conv ?? KemeticConverter();
  final local = DateUtils.dateOnly(todayLocal ?? DateTime.now());
  final kd = converter.fromGregorian(local);

  if (kd.epagomenal) {
    return 'Y${kd.year} • Epagomenal Day ${kd.day}';
  }
  final monthName = getMonthById(kd.month).hellenized;
  final season = getSeasonName(kd.month);
  return 'Y${kd.year} • $monthName ${kd.day} • $season';
}
