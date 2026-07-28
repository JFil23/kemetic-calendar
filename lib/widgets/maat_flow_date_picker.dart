import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/shared/date_picker/kemetic_picker_labels.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';

enum MaatFlowDatePickerMode { kemetic, gregorian }

class MaatFlowDatePickerResult {
  const MaatFlowDatePickerResult({required this.date, required this.mode});

  final DateTime date;
  final MaatFlowDatePickerMode mode;
}

class MaatFlowDatePicker {
  const MaatFlowDatePicker._();

  static Future<MaatFlowDatePickerResult?> show({
    required BuildContext context,
    DateTime? initialDate,
    required MaatFlowDatePickerMode initialMode,
  }) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final seed = DateUtils.dateOnly(initialDate ?? _defaultTomorrow(today));
    final kemeticSeed = KemeticMath.fromGregorian(seed);
    final picked = await StoneRegisterDatePicker.show<MaatFlowDatePickerValue>(
      context,
      initialValue: MaatFlowDatePickerValue(date: seed, mode: initialMode),
      adapter: MaatFlowDatePickerAdapter(
        today: today,
        kemeticYearStart: kemeticSeed.kYear,
      ),
      initialMode: initialMode._stoneMode,
      title: 'Start date',
    );
    if (picked == null) return null;
    return MaatFlowDatePickerResult(
      date: DateUtils.dateOnly(picked.date),
      mode: picked.mode,
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

class MaatFlowDatePickerValue {
  const MaatFlowDatePickerValue({required this.date, required this.mode});

  final DateTime date;
  final MaatFlowDatePickerMode mode;
}

class MaatFlowDatePickerAdapter
    extends StoneDatePickerAdapter<MaatFlowDatePickerValue> {
  const MaatFlowDatePickerAdapter({
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
    MaatFlowDatePickerValue value,
    StoneDatePickerCalendarMode mode,
  ) {
    return switch (mode) {
      StoneDatePickerCalendarMode.gregorian => _buildGregorianColumns(value),
      StoneDatePickerCalendarMode.kemetic => _buildKemeticColumns(value),
    };
  }

  @override
  MaatFlowDatePickerValue clampOrNormalize(
    MaatFlowDatePickerValue value,
    StoneDatePickerCalendarMode mode,
  ) {
    return switch (mode) {
      StoneDatePickerCalendarMode.gregorian => _fromGregorian(
        _clampedGregorian(value.date),
      ),
      StoneDatePickerCalendarMode.kemetic => _fromKemetic(
        _clampedKemetic(value.date),
      ),
    };
  }

  @override
  String formatValue(
    MaatFlowDatePickerValue value,
    StoneDatePickerCalendarMode mode,
  ) {
    final normalized = clampOrNormalize(value, mode);
    final date = normalized.date;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  StoneWheelSelection selectionFromValue(
    MaatFlowDatePickerValue value,
    StoneDatePickerCalendarMode mode,
  ) {
    return switch (mode) {
      StoneDatePickerCalendarMode.gregorian => _gregorianSelection(value.date),
      StoneDatePickerCalendarMode.kemetic => _kemeticSelection(value.date),
    };
  }

  @override
  MaatFlowDatePickerValue valueFromSelection(
    StoneWheelSelection selection,
    StoneDatePickerCalendarMode mode,
  ) {
    return switch (mode) {
      StoneDatePickerCalendarMode.gregorian => _fromGregorianSelection(
        selection,
      ),
      StoneDatePickerCalendarMode.kemetic => _fromKemeticSelection(selection),
    };
  }

  List<StoneWheelColumn> _buildGregorianColumns(MaatFlowDatePickerValue value) {
    final date = _clampedGregorian(value.date);
    final maxDay = DateUtils.getDaysInMonth(date.year, date.month);
    return [
      StoneWheelColumn(
        id: 'month',
        values: _gregorianMonthNames,
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

  List<StoneWheelColumn> _buildKemeticColumns(MaatFlowDatePickerValue value) {
    final k = _clampedKemetic(value.date);
    final maxDay = _kemeticDayMax(k.kYear, k.kMonth);
    return [
      StoneWheelColumn(
        id: 'month',
        values: List<String>.generate(
          13,
          (index) => kemeticPickerMonthLabel(index + 1),
        ),
        selectedIndex: k.kMonth - 1,
        flex: 4,
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

  MaatFlowDatePickerValue _fromGregorianSelection(
    StoneWheelSelection selection,
  ) {
    final year = gregorianYearStart + selection.indexOf('year');
    final month = (selection.indexOf('month') % 12) + 1;
    final maxDay = DateUtils.getDaysInMonth(year, month);
    final day = (selection.indexOf('day') + 1).clamp(1, maxDay).toInt();
    return _fromGregorian(DateTime(year, month, day));
  }

  MaatFlowDatePickerValue _fromKemeticSelection(StoneWheelSelection selection) {
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

  MaatFlowDatePickerValue _fromGregorian(DateTime date) {
    return MaatFlowDatePickerValue(
      date: DateUtils.dateOnly(date),
      mode: MaatFlowDatePickerMode.gregorian,
    );
  }

  MaatFlowDatePickerValue _fromKemetic(
    ({int kYear, int kMonth, int kDay}) value,
  ) {
    return MaatFlowDatePickerValue(
      date: DateUtils.dateOnly(
        KemeticMath.toGregorian(value.kYear, value.kMonth, value.kDay),
      ),
      mode: MaatFlowDatePickerMode.kemetic,
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

extension on MaatFlowDatePickerMode {
  StoneDatePickerCalendarMode get _stoneMode {
    return switch (this) {
      MaatFlowDatePickerMode.gregorian => StoneDatePickerCalendarMode.gregorian,
      MaatFlowDatePickerMode.kemetic => StoneDatePickerCalendarMode.kemetic,
    };
  }
}
