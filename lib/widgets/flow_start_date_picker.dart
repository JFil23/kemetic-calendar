// lib/widgets/flow_start_date_picker.dart
// Reusable date picker for flow start dates.

import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/shared/date_picker/kemetic_picker_labels.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';

class FlowStartDatePicker {
  const FlowStartDatePicker._();

  static Future<DateTime?> show(BuildContext context, {DateTime? initialDate}) {
    final today = DateUtils.dateOnly(DateTime.now());
    final seed = DateUtils.dateOnly(initialDate ?? _defaultTomorrow(today));
    final kemeticSeed = KemeticMath.fromGregorian(seed);

    return StoneRegisterDatePicker.show<DateTime>(
      context,
      initialValue: seed,
      adapter: FlowStartDatePickerAdapter(
        today: today,
        kemeticYearStart: kemeticSeed.kYear,
      ),
      initialMode: StoneDatePickerCalendarMode.gregorian,
      title: 'Start date',
    );
  }

  static DateTime _defaultTomorrow(DateTime today) {
    var year = today.year;
    var month = today.month;
    var day = today.day + 1;
    final maxDay = DateUtils.getDaysInMonth(year, month);
    if (day > maxDay) {
      day = 1;
      month = month == 12 ? 1 : month + 1;
      if (month == 1) year++;
    }
    return DateTime(year, month, day);
  }
}

class FlowStartDatePickerAdapter extends StoneDatePickerAdapter<DateTime> {
  const FlowStartDatePickerAdapter({
    required this.today,
    required this.kemeticYearStart,
    this.gregorianYearCount = 40,
    this.kemeticYearCount = 401,
  }) : assert(gregorianYearCount > 0),
       assert(kemeticYearCount > 0);

  final DateTime today;
  final int kemeticYearStart;
  final int gregorianYearCount;
  final int kemeticYearCount;

  int get gregorianYearStart => today.year;

  static const Map<int, String> _gregorianMonthNames = {
    1: 'Jan',
    2: 'Feb',
    3: 'Mar',
    4: 'Apr',
    5: 'May',
    6: 'Jun',
    7: 'Jul',
    8: 'Aug',
    9: 'Sep',
    10: 'Oct',
    11: 'Nov',
    12: 'Dec',
  };

  static const TextStyle _monthTextStyle = TextStyle(
    fontFamily: StoneRegisterDatePickerTheme.serifFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.05,
  );

  @override
  List<StoneWheelColumn> buildColumns(
    DateTime value,
    StoneDatePickerCalendarMode mode,
  ) {
    return switch (mode) {
      StoneDatePickerCalendarMode.gregorian => _buildGregorianColumns(value),
      StoneDatePickerCalendarMode.kemetic => _buildKemeticColumns(value),
    };
  }

  @override
  DateTime clampOrNormalize(DateTime value, StoneDatePickerCalendarMode mode) {
    return switch (mode) {
      StoneDatePickerCalendarMode.gregorian => _clampedGregorian(value),
      StoneDatePickerCalendarMode.kemetic => _fromKemetic(
        _clampedKemetic(value),
      ),
    };
  }

  @override
  String formatValue(DateTime value, StoneDatePickerCalendarMode mode) {
    final normalized = clampOrNormalize(value, mode);
    return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
  }

  @override
  StoneWheelSelection selectionFromValue(
    DateTime value,
    StoneDatePickerCalendarMode mode,
  ) {
    return switch (mode) {
      StoneDatePickerCalendarMode.gregorian => _gregorianSelection(value),
      StoneDatePickerCalendarMode.kemetic => _kemeticSelection(value),
    };
  }

  @override
  DateTime valueFromSelection(
    StoneWheelSelection selection,
    StoneDatePickerCalendarMode mode,
  ) {
    return switch (mode) {
      StoneDatePickerCalendarMode.gregorian => _gregorianFromSelection(
        selection,
      ),
      StoneDatePickerCalendarMode.kemetic => _kemeticFromSelection(selection),
    };
  }

  List<StoneWheelColumn> _buildGregorianColumns(DateTime value) {
    final date = _clampedGregorian(value);
    final maxDay = DateUtils.getDaysInMonth(date.year, date.month);
    return [
      StoneWheelColumn(
        id: 'month',
        values: List<String>.generate(
          12,
          (index) => _gregorianMonthNames[index + 1]!,
        ),
        selectedIndex: date.month - 1,
        flex: 4,
        looping: true,
        textStyle: _monthTextStyle,
      ),
      StoneWheelColumn(
        id: 'day',
        values: List<String>.generate(maxDay, (index) => '${index + 1}'),
        selectedIndex: date.day - 1,
        flex: 3,
        looping: true,
      ),
      StoneWheelColumn(
        id: 'year',
        values: List<String>.generate(
          gregorianYearCount,
          (index) => '${gregorianYearStart + index}',
        ),
        selectedIndex: (date.year - gregorianYearStart)
            .clamp(0, gregorianYearCount - 1)
            .toInt(),
        flex: 4,
        looping: true,
      ),
    ];
  }

  List<StoneWheelColumn> _buildKemeticColumns(DateTime value) {
    final k = _clampedKemetic(value);
    final maxDay = _kemeticDayMax(k.kYear, k.kMonth);
    return [
      StoneWheelColumn(
        id: 'month',
        values: List<String>.generate(
          13,
          (index) => kemeticPickerMonthLabel(index + 1),
        ),
        selectedIndex: k.kMonth - 1,
        flex: 5,
        looping: true,
        textStyle: _monthTextStyle,
      ),
      StoneWheelColumn(
        id: 'day',
        values: List<String>.generate(maxDay, (index) => '${index + 1}'),
        selectedIndex: k.kDay - 1,
        flex: 3,
        looping: true,
      ),
      StoneWheelColumn(
        id: 'year',
        values: List<String>.generate(
          kemeticYearCount,
          (index) => _gregorianYearLabelFor(kemeticYearStart + index, k.kMonth),
        ),
        selectedIndex: (k.kYear - kemeticYearStart)
            .clamp(0, kemeticYearCount - 1)
            .toInt(),
        flex: 4,
        looping: true,
      ),
    ];
  }

  StoneWheelSelection _gregorianSelection(DateTime value) {
    final date = _clampedGregorian(value);
    return StoneWheelSelection({
      'month': date.month - 1,
      'day': date.day - 1,
      'year': (date.year - gregorianYearStart)
          .clamp(0, gregorianYearCount - 1)
          .toInt(),
    });
  }

  StoneWheelSelection _kemeticSelection(DateTime value) {
    final k = _clampedKemetic(value);
    return StoneWheelSelection({
      'month': k.kMonth - 1,
      'day': k.kDay - 1,
      'year': (k.kYear - kemeticYearStart)
          .clamp(0, kemeticYearCount - 1)
          .toInt(),
    });
  }

  DateTime _gregorianFromSelection(StoneWheelSelection selection) {
    final year = gregorianYearStart + selection.indexOf('year');
    final month = (selection.indexOf('month') % 12) + 1;
    final maxDay = DateUtils.getDaysInMonth(year, month);
    final day = (selection.indexOf('day') + 1).clamp(1, maxDay).toInt();
    return DateTime(year, month, day);
  }

  DateTime _kemeticFromSelection(StoneWheelSelection selection) {
    final year = kemeticYearStart + selection.indexOf('year');
    final month = (selection.indexOf('month') % 13) + 1;
    final maxDay = _kemeticDayMax(year, month);
    final day = (selection.indexOf('day') + 1).clamp(1, maxDay).toInt();
    return DateUtils.dateOnly(KemeticMath.toGregorian(year, month, day));
  }

  DateTime _clampedGregorian(DateTime value) {
    final date = DateUtils.dateOnly(value);
    final year = date.year
        .clamp(gregorianYearStart, gregorianYearStart + gregorianYearCount - 1)
        .toInt();
    final maxDay = DateUtils.getDaysInMonth(year, date.month);
    return DateTime(year, date.month, date.day.clamp(1, maxDay).toInt());
  }

  ({int kYear, int kMonth, int kDay}) _clampedKemetic(DateTime value) {
    final k = KemeticMath.fromGregorian(value);
    final year = k.kYear
        .clamp(kemeticYearStart, kemeticYearStart + kemeticYearCount - 1)
        .toInt();
    final maxDay = _kemeticDayMax(year, k.kMonth);
    return (
      kYear: year,
      kMonth: k.kMonth,
      kDay: k.kDay.clamp(1, maxDay).toInt(),
    );
  }

  DateTime _fromKemetic(({int kYear, int kMonth, int kDay}) value) {
    return DateUtils.dateOnly(
      KemeticMath.toGregorian(value.kYear, value.kMonth, value.kDay),
    );
  }

  int _kemeticDayMax(int year, int month) =>
      month == 13 ? (KemeticMath.isLeapKemeticYear(year) ? 6 : 5) : 30;

  String _gregorianYearLabelFor(int kYear, int kMonth) {
    final lastDay = _kemeticDayMax(kYear, kMonth);
    final yearStart = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final yearEnd = KemeticMath.toGregorian(kYear, kMonth, lastDay).year;
    return yearStart == yearEnd ? '$yearStart' : '$yearStart/$yearEnd';
  }
}
