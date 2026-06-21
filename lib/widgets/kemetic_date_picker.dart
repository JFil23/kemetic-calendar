import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/kemetic_time_constants.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';

/* ═══════════════════════ KEMETIC MATH (FIXED) ═══════════════════════ */

class KemeticMath {
  // Repeating 4-year cycle lengths starting at Year 1: [365, 365, 366, 365]
  static const List<int> _cycle = [365, 365, 366, 365];
  static const int _cycleSum = 1461; // 365*4 + 1

  static int _mod(int a, int n) => ((a % n) + n) % n;

  static int _daysBeforeYear(int kYear) {
    if (kYear == 1) return 0;
    final y = kYear - 1;

    if (y > 0) {
      final full = y ~/ 4;
      final rem = y % 4;
      var sum = full * _cycleSum;
      for (int i = 0; i < rem; i++) {
        sum += _cycle[i];
      }
      return sum;
    } else {
      final n = -y;
      final full = n ~/ 4;
      final rem = n % 4;
      var sum = full * _cycleSum;
      for (int i = 0; i < rem; i++) {
        sum += _cycle[3 - i];
      }
      return -sum;
    }
  }

  static ({int kYear, int kMonth, int kDay}) fromGregorian(DateTime gLocal) {
    // FIXED: Normalize to UTC noon first to avoid DST gaps/ambiguities
    final gUtcNoon = DateTime.utc(gLocal.year, gLocal.month, gLocal.day, 12);
    final g = toUtcDateOnly(gUtcNoon);
    final diff = epochDayFromUtc(g);

    if (diff >= 0) {
      int kYear = 1;
      int rem = diff;

      final cycles = rem ~/ _cycleSum;
      kYear += cycles * 4;
      rem -= cycles * _cycleSum;

      int idx = 0;
      while (rem >= _cycle[idx]) {
        rem -= _cycle[idx];
        kYear++;
        idx = (idx + 1) & 3;
      }

      final dayOfYear = rem;
      if (dayOfYear < 360) {
        final kMonth = (dayOfYear ~/ 30) + 1;
        final kDay = (dayOfYear % 30) + 1;
        return (kYear: kYear, kMonth: kMonth, kDay: kDay);
      } else {
        final kMonth = 13;
        final kDay = dayOfYear - 360 + 1;
        return (kYear: kYear, kMonth: kMonth, kDay: kDay);
      }
    }

    int rem = -diff - 1;
    rem %= _cycleSum;

    int year = 0;
    final rev = [_cycle[3], _cycle[2], _cycle[1], _cycle[0]];

    for (int i = 0; i < 4; i++) {
      final len = rev[i];
      if (rem < len) {
        final dayOfYear = len - 1 - rem;
        year -= i;
        if (dayOfYear < 360) {
          final kMonth = (dayOfYear ~/ 30) + 1;
          final kDay = (dayOfYear % 30) + 1;
          return (kYear: year, kMonth: kMonth, kDay: kDay);
        } else {
          final kMonth = 13;
          final kDay = dayOfYear - 360 + 1;
          return (kYear: year, kMonth: kMonth, kDay: kDay);
        }
      }
      rem -= len;
    }

    return (kYear: -3, kMonth: 13, kDay: 1);
  }

  static DateTime toGregorian(int kYear, int kMonth, int kDay) {
    if (kMonth < 1 || kMonth > 13) {
      throw ArgumentError('kMonth 1..13');
    }
    if (kMonth == 13) {
      final maxEpi = isLeapKemeticYear(kYear) ? 6 : 5;
      if (kDay < 1 || kDay > maxEpi) {
        throw ArgumentError('kDay 1..$maxEpi for epagomenal in year $kYear');
      }
    } else {
      if (kDay < 1 || kDay > 30) throw ArgumentError('kDay 1..30');
    }

    // FIXED: Use integer epoch-day arithmetic
    final base = _daysBeforeYear(kYear);
    final dayIndex = (kMonth == 13)
        ? (360 + (kDay - 1))
        : ((kMonth - 1) * 30 + (kDay - 1));
    final epochDays = base + dayIndex;
    return utcFromEpochDay(epochDays);
  }

  // ✅ FIXED: Simple one-liner, no circular dependency
  static bool isLeapKemeticYear(int kYear) => _mod(kYear - 1, 4) == 2;
}

/* ═══════════════════════ STYLING CONSTANTS ═══════════════════════ */
// Colors and gradients are now imported from shared/glossy_text.dart

/* ═══════════════════════ KEMETIC MONTH NAMES ═══════════════════════ */

// Removed - use getMonthById(m).displayFull instead

/* ═══════════════════════ KEMETIC DATE PICKER ═══════════════════════ */

Future<DateTime?> showKemeticDatePicker({
  required BuildContext context,
  DateTime? initialDate,
}) async {
  final seed = DateUtils.dateOnly(initialDate ?? DateTime.now());
  final initK = KemeticMath.fromGregorian(seed);
  return StoneRegisterDatePicker.show<DateTime>(
    context,
    initialValue: seed,
    adapter: KemeticDatePickerAdapter(yearStart: initK.kYear - 200),
    initialMode: StoneDatePickerCalendarMode.kemetic,
    allowModeSwitch: false,
    title: 'Pick Kemetic date',
    subtitle: 'Kemetic Calendar',
  );
}

class KemeticDatePickerAdapter extends StoneDatePickerAdapter<DateTime> {
  const KemeticDatePickerAdapter({required this.yearStart});

  final int yearStart;
  static const int yearCount = 401;

  @override
  List<StoneWheelColumn> buildColumns(
    DateTime value,
    StoneDatePickerCalendarMode mode,
  ) {
    final k = _clampedKemetic(value);
    final max = _maxDayFor(k.kYear, k.kMonth);
    final day = k.kDay.clamp(1, max).toInt();
    return [
      StoneWheelColumn(
        id: 'month',
        values: List<String>.generate(
          13,
          (index) => getMonthById(index + 1).displayFull,
        ),
        selectedIndex: k.kMonth - 1,
        flex: 5,
        looping: true,
        textStyle: const TextStyle(
          fontFamily: StoneRegisterDatePickerTheme.serifFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 1.05,
        ),
      ),
      StoneWheelColumn(
        id: 'day',
        values: List<String>.generate(max, (index) => '${index + 1}'),
        selectedIndex: day - 1,
        flex: 3,
        looping: true,
      ),
      StoneWheelColumn(
        id: 'year',
        values: List<String>.generate(
          yearCount,
          (index) => _gregYearLabelFor(yearStart + index, k.kMonth),
        ),
        selectedIndex: (k.kYear - yearStart).clamp(0, yearCount - 1).toInt(),
        flex: 4,
      ),
    ];
  }

  @override
  DateTime clampOrNormalize(DateTime value, StoneDatePickerCalendarMode mode) {
    final k = _clampedKemetic(value);
    return DateUtils.dateOnly(
      KemeticMath.toGregorian(k.kYear, k.kMonth, k.kDay),
    );
  }

  @override
  String formatValue(DateTime value, StoneDatePickerCalendarMode mode) {
    final k = _clampedKemetic(value);
    final gregorian = KemeticMath.toGregorian(k.kYear, k.kMonth, k.kDay);
    return '${getMonthById(k.kMonth).displayFull} ${k.kDay}, ${gregorian.year}';
  }

  @override
  StoneWheelSelection selectionFromValue(
    DateTime value,
    StoneDatePickerCalendarMode mode,
  ) {
    final k = _clampedKemetic(value);
    return StoneWheelSelection({
      'month': k.kMonth - 1,
      'day': k.kDay - 1,
      'year': (k.kYear - yearStart).clamp(0, yearCount - 1).toInt(),
    });
  }

  @override
  DateTime valueFromSelection(
    StoneWheelSelection selection,
    StoneDatePickerCalendarMode mode,
  ) {
    final kYear = yearStart + selection.indexOf('year');
    final kMonth = selection.indexOf('month') + 1;
    final max = _maxDayFor(kYear, kMonth);
    final kDay = (selection.indexOf('day') + 1).clamp(1, max).toInt();
    return DateUtils.dateOnly(KemeticMath.toGregorian(kYear, kMonth, kDay));
  }

  ({int kYear, int kMonth, int kDay}) _clampedKemetic(DateTime value) {
    final k = KemeticMath.fromGregorian(value);
    final year = k.kYear.clamp(yearStart, yearStart + yearCount - 1).toInt();
    final max = _maxDayFor(year, k.kMonth);
    return (kYear: year, kMonth: k.kMonth, kDay: k.kDay.clamp(1, max).toInt());
  }

  int _maxDayFor(int year, int month) =>
      (month == 13) ? (KemeticMath.isLeapKemeticYear(year) ? 6 : 5) : 30;

  String _gregYearLabelFor(int kYear, int kMonth) {
    final lastDay = _maxDayFor(kYear, kMonth);
    final yStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final yEnd = KemeticMath.toGregorian(kYear, kMonth, lastDay).year;
    return (yStart == yEnd) ? '$yStart' : '$yStart/$yEnd';
  }
}
