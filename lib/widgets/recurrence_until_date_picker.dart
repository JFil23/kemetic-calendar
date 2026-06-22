import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';

class RecurrenceUntilDatePicker {
  const RecurrenceUntilDatePicker._();

  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    bool allowPast = false,
    DateTime? firstDate,
    DateTime? lastDate,
    String title = 'End repeat date',
  }) async {
    final seed = DateUtils.dateOnly(initialDate);
    final today = DateUtils.dateOnly(DateTime.now());
    final kemeticSeed = KemeticMath.fromGregorian(seed);
    final gregorianYearStart = allowPast && seed.year < today.year
        ? seed.year
        : today.year;
    final gregorianYearCount = today.year - gregorianYearStart + 40;
    final picked = await StoneRegisterDatePicker.show<DateTime>(
      context,
      initialValue: seed,
      adapter: RecurrenceUntilDatePickerAdapter(
        today: today,
        kemeticYearStart: kemeticSeed.kYear,
        gregorianYearStartOverride: gregorianYearStart,
        gregorianYearCount: gregorianYearCount,
      ),
      initialMode: StoneDatePickerCalendarMode.gregorian,
      title: title,
    );
    if (picked == null) return null;

    var result = DateUtils.dateOnly(picked);
    final minDate = firstDate == null ? null : DateUtils.dateOnly(firstDate);
    final maxDate = lastDate == null ? null : DateUtils.dateOnly(lastDate);
    if (!allowPast && minDate != null && result.isBefore(minDate)) {
      result = minDate;
    }
    if (maxDate != null && result.isAfter(maxDate)) {
      result = maxDate;
    }
    return result;
  }
}

class RecurrenceUntilDatePickerAdapter
    extends StoneDatePickerAdapter<DateTime> {
  const RecurrenceUntilDatePickerAdapter({
    required this.today,
    required this.kemeticYearStart,
    this.gregorianYearStartOverride,
    this.gregorianYearCount = 40,
    this.kemeticYearCount = 401,
  }) : assert(gregorianYearCount > 0),
       assert(kemeticYearCount > 0);

  final DateTime today;
  final int kemeticYearStart;
  final int? gregorianYearStartOverride;
  final int gregorianYearCount;
  final int kemeticYearCount;

  int get gregorianYearStart =>
      gregorianYearStartOverride ?? DateUtils.dateOnly(today).year;

  static const List<String> _gregorianMonthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

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
        values: _gregorianMonthNames,
        selectedIndex: date.month - 1,
        flex: 5,
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
          (index) => getMonthById(index + 1).displayFull,
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
    return _fromKemetic((kYear: year, kMonth: month, kDay: day));
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
