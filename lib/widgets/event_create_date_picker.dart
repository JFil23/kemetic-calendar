import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/shared/date_picker/kemetic_picker_labels.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';

enum EventCreateDatePickerMode { kemetic, gregorian }

class EventCreateDatePickerResult {
  const EventCreateDatePickerResult({required this.date, required this.mode});

  final DateTime date;
  final EventCreateDatePickerMode mode;
}

class EventCreateDatePicker {
  const EventCreateDatePicker._();

  static Future<EventCreateDatePickerResult?> show({
    required BuildContext context,
    required DateTime initialDate,
    required EventCreateDatePickerMode initialMode,
  }) async {
    final seed = DateUtils.dateOnly(initialDate);
    final kSeed = KemeticMath.fromGregorian(seed);
    final picked =
        await StoneRegisterDatePicker.show<EventCreateDatePickerValue>(
          context,
          initialValue: EventCreateDatePickerValue(
            date: seed,
            mode: initialMode,
          ),
          adapter: EventCreateDatePickerAdapter(
            gregorianYearStart: seed.year - 200,
            kemeticYearStart: kSeed.kYear - 200,
          ),
          initialMode: initialMode._stoneMode,
          title: 'Event date',
        );
    if (picked == null) return null;
    return EventCreateDatePickerResult(
      date: DateUtils.dateOnly(picked.date),
      mode: picked.mode,
    );
  }
}

class EventCreateDatePickerValue {
  const EventCreateDatePickerValue({required this.date, required this.mode});

  final DateTime date;
  final EventCreateDatePickerMode mode;
}

class EventCreateDatePickerAdapter
    extends StoneDatePickerAdapter<EventCreateDatePickerValue> {
  const EventCreateDatePickerAdapter({
    required this.gregorianYearStart,
    required this.kemeticYearStart,
    this.yearCount = 401,
  }) : assert(yearCount > 0);

  final int gregorianYearStart;
  final int kemeticYearStart;
  final int yearCount;

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
    EventCreateDatePickerValue value,
    StoneDatePickerCalendarMode mode,
  ) {
    return switch (mode) {
      StoneDatePickerCalendarMode.gregorian => _buildGregorianColumns(value),
      StoneDatePickerCalendarMode.kemetic => _buildKemeticColumns(value),
    };
  }

  @override
  EventCreateDatePickerValue clampOrNormalize(
    EventCreateDatePickerValue value,
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
    EventCreateDatePickerValue value,
    StoneDatePickerCalendarMode mode,
  ) {
    final normalized = clampOrNormalize(value, mode);
    if (normalized.mode == EventCreateDatePickerMode.gregorian) {
      final date = normalized.date;
      return '${_gregorianMonthNames[date.month - 1]} ${date.day}, ${date.year}';
    }
    final k = KemeticMath.fromGregorian(normalized.date);
    return '${kemeticPickerMonthLabel(k.kMonth)} ${k.kDay}, ${normalized.date.year}';
  }

  @override
  StoneWheelSelection selectionFromValue(
    EventCreateDatePickerValue value,
    StoneDatePickerCalendarMode mode,
  ) {
    return switch (mode) {
      StoneDatePickerCalendarMode.gregorian => _gregorianSelection(value.date),
      StoneDatePickerCalendarMode.kemetic => _kemeticSelection(value.date),
    };
  }

  @override
  EventCreateDatePickerValue valueFromSelection(
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

  List<StoneWheelColumn> _buildGregorianColumns(
    EventCreateDatePickerValue value,
  ) {
    final date = _clampedGregorian(value.date);
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
          yearCount,
          (index) => '${gregorianYearStart + index}',
        ),
        selectedIndex: (date.year - gregorianYearStart)
            .clamp(0, yearCount - 1)
            .toInt(),
        flex: 4,
      ),
    ];
  }

  List<StoneWheelColumn> _buildKemeticColumns(
    EventCreateDatePickerValue value,
  ) {
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
          yearCount,
          (index) =>
              _gregorianYearLabelForKemetic(kemeticYearStart + index, k.kMonth),
        ),
        selectedIndex: (k.kYear - kemeticYearStart)
            .clamp(0, yearCount - 1)
            .toInt(),
        flex: 4,
      ),
    ];
  }

  StoneWheelSelection _gregorianSelection(DateTime value) {
    final date = _clampedGregorian(value);
    return StoneWheelSelection({
      'month': date.month - 1,
      'day': date.day - 1,
      'year': (date.year - gregorianYearStart).clamp(0, yearCount - 1).toInt(),
    });
  }

  StoneWheelSelection _kemeticSelection(DateTime value) {
    final k = _clampedKemetic(value);
    return StoneWheelSelection({
      'month': k.kMonth - 1,
      'day': k.kDay - 1,
      'year': (k.kYear - kemeticYearStart).clamp(0, yearCount - 1).toInt(),
    });
  }

  EventCreateDatePickerValue _fromGregorianSelection(
    StoneWheelSelection selection,
  ) {
    final month = (selection.indexOf('month') % 12) + 1;
    final year = gregorianYearStart + selection.indexOf('year');
    final maxDay = DateUtils.getDaysInMonth(year, month);
    final day = (selection.indexOf('day') + 1).clamp(1, maxDay).toInt();
    return _fromGregorian(DateTime(year, month, day));
  }

  EventCreateDatePickerValue _fromKemeticSelection(
    StoneWheelSelection selection,
  ) {
    final year = kemeticYearStart + selection.indexOf('year');
    final month = (selection.indexOf('month') % 13) + 1;
    final maxDay = _kemeticDayMax(year, month);
    final day = (selection.indexOf('day') + 1).clamp(1, maxDay).toInt();
    return _fromKemetic((kYear: year, kMonth: month, kDay: day));
  }

  DateTime _clampedGregorian(DateTime value) {
    final date = DateUtils.dateOnly(value);
    final year = date.year
        .clamp(gregorianYearStart, gregorianYearStart + yearCount - 1)
        .toInt();
    final maxDay = DateUtils.getDaysInMonth(year, date.month);
    return DateTime(year, date.month, date.day.clamp(1, maxDay).toInt());
  }

  ({int kYear, int kMonth, int kDay}) _clampedKemetic(DateTime value) {
    final k = KemeticMath.fromGregorian(value);
    final year = k.kYear
        .clamp(kemeticYearStart, kemeticYearStart + yearCount - 1)
        .toInt();
    final maxDay = _kemeticDayMax(year, k.kMonth);
    return (
      kYear: year,
      kMonth: k.kMonth,
      kDay: k.kDay.clamp(1, maxDay).toInt(),
    );
  }

  EventCreateDatePickerValue _fromGregorian(DateTime date) {
    return EventCreateDatePickerValue(
      date: DateUtils.dateOnly(date),
      mode: EventCreateDatePickerMode.gregorian,
    );
  }

  EventCreateDatePickerValue _fromKemetic(
    ({int kYear, int kMonth, int kDay}) value,
  ) {
    return EventCreateDatePickerValue(
      date: DateUtils.dateOnly(
        KemeticMath.toGregorian(value.kYear, value.kMonth, value.kDay),
      ),
      mode: EventCreateDatePickerMode.kemetic,
    );
  }

  int _kemeticDayMax(int year, int month) {
    return month == 13 ? (KemeticMath.isLeapKemeticYear(year) ? 6 : 5) : 30;
  }

  String _gregorianYearLabelForKemetic(int kYear, int kMonth) {
    final lastDay = _kemeticDayMax(kYear, kMonth);
    final startYear = KemeticMath.toGregorian(kYear, kMonth, 1).year;
    final endYear = KemeticMath.toGregorian(kYear, kMonth, lastDay).year;
    return startYear == endYear ? '$startYear' : '$startYear/$endYear';
  }
}

extension on EventCreateDatePickerMode {
  StoneDatePickerCalendarMode get _stoneMode {
    return switch (this) {
      EventCreateDatePickerMode.gregorian =>
        StoneDatePickerCalendarMode.gregorian,
      EventCreateDatePickerMode.kemetic => StoneDatePickerCalendarMode.kemetic,
    };
  }
}
