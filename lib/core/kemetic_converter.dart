import 'package:flutter/material.dart' show DateUtils;

import 'package:intl/intl.dart';

/// Kemetic month numbers 1..12; 0 means epagomenal.
const kemeticMonths = <int, String>{
  1: 'Thoth',
  2: 'Phaophi',
  3: 'Athyr',
  4: 'Choiak',
  5: 'Tybi',
  6: 'Mechir',
  7: 'Phamenoth',
  8: 'Pharmuthi',
  9: 'Pachons',
  10: 'Payni',
  11: 'Epiphi',
  12: 'Mesore',
};

const kemeticSeasonsByMonth = <int, String>{
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

/// Epoch: Kemetic Y1 D1 = 2025-03-20 (local midnight).
final DateTime kemeticEpochLocal = DateTime(2025, 3, 20);

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

  String get monthName => epagomenal ? 'Epagomenal' : kemeticMonths[month]!;
  String? get season => epagomenal ? null : kemeticSeasonsByMonth[month];

  @override
  String toString() {
    if (epagomenal) {
      return 'Kemetic Y$year • Epagomenal Day $day';
    }
    return 'Kemetic Y$year • ${kemeticMonths[month]} $day'
        '${season != null ? " (${season})" : ""}';
  }
}

class KemeticConverter {
  KemeticConverter({DateTime? epochLocal})
      : _epochLocal = DateUtils.dateOnly(epochLocal ?? kemeticEpochLocal);

  final DateTime _epochLocal;

  KemeticDate fromGregorian(DateTime localDate) {
    final d = DateUtils.dateOnly(localDate);
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
    DateTime start = _epochLocal;
    int y = 1;
    if (kd.year >= 1) {
      while (y < kd.year) {
        final len = _kemeticYearLength(start);
        start = start.add(Duration(days: len));
        y++;
      }
    } else {
      while (y > kd.year) {
        start = _prevKemeticYearStart(start);
        y--;
      }
    }
    final offset = kd.month == 0
        ? 360 + (kd.day - 1)
        : (kd.month - 1) * 30 + (kd.day - 1);
    return start.add(Duration(days: offset));
  }

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
    final da = DateUtils.dateOnly(a);
    final db = DateUtils.dateOnly(b);
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
  final monthName = kemeticMonths[kd.month]!;
  final season = kemeticSeasonsByMonth[kd.month]!;
  return 'Y${kd.year} • $monthName ${kd.day} • $season';
}
