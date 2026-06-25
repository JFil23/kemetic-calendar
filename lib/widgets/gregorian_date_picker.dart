import 'package:flutter/material.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';

/* ═══════════════════════ GREGORIAN MONTH NAMES ═══════════════════════ */

const List<String> _gregMonthNames = [
  '',
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

/* ═══════════════════════ GREGORIAN DATE PICKER ═══════════════════════ */

Future<DateTime?> showGregorianDatePicker({
  required BuildContext context,
  DateTime? initialDate,
}) async {
  final now = DateTime.now();
  final seed = DateUtils.dateOnly(initialDate ?? now);
  return StoneRegisterDatePicker.show<DateTime>(
    context,
    initialValue: seed,
    adapter: GregorianDatePickerAdapter(yearStart: now.year - 200),
    initialMode: StoneDatePickerCalendarMode.gregorian,
    allowModeSwitch: false,
    title: 'Pick Gregorian date',
    subtitle: 'Gregorian Calendar',
  );
}

class GregorianDatePickerAdapter extends StoneDatePickerAdapter<DateTime> {
  const GregorianDatePickerAdapter({
    required this.yearStart,
    this.yearCount = 401,
  }) : assert(yearCount > 0);

  final int yearStart;
  final int yearCount;

  @override
  List<StoneWheelColumn> buildColumns(
    DateTime value,
    StoneDatePickerCalendarMode mode,
  ) {
    final normalized = clampOrNormalize(value, mode);
    final max = _daysInGregorianMonth(normalized.year, normalized.month);
    final day = normalized.day.clamp(1, max).toInt();
    return [
      StoneWheelColumn(
        id: 'month',
        values: _gregMonthNames.skip(1).toList(growable: false),
        selectedIndex: normalized.month - 1,
        flex: 5,
        looping: true,
        textStyle: const TextStyle(
          fontFamily: StoneRegisterDatePickerTheme.serifFontFamily,
          fontSize: 19,
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
          (index) => '${yearStart + index}',
        ),
        selectedIndex: (normalized.year - yearStart)
            .clamp(0, yearCount - 1)
            .toInt(),
        flex: 4,
      ),
    ];
  }

  @override
  DateTime clampOrNormalize(DateTime value, StoneDatePickerCalendarMode mode) {
    final date = DateUtils.dateOnly(value);
    final clampedYear = date.year
        .clamp(yearStart, yearStart + yearCount - 1)
        .toInt();
    final max = _daysInGregorianMonth(clampedYear, date.month);
    final clampedDay = date.day.clamp(1, max).toInt();
    return DateTime(clampedYear, date.month, clampedDay);
  }

  @override
  String formatValue(DateTime value, StoneDatePickerCalendarMode mode) {
    final date = clampOrNormalize(value, mode);
    return '${_gregMonthNames[date.month]} ${date.day}, ${date.year}';
  }

  @override
  StoneWheelSelection selectionFromValue(
    DateTime value,
    StoneDatePickerCalendarMode mode,
  ) {
    final date = clampOrNormalize(value, mode);
    return StoneWheelSelection({
      'month': date.month - 1,
      'day': date.day - 1,
      'year': (date.year - yearStart).clamp(0, yearCount - 1).toInt(),
    });
  }

  @override
  DateTime valueFromSelection(
    StoneWheelSelection selection,
    StoneDatePickerCalendarMode mode,
  ) {
    final month = selection.indexOf('month') + 1;
    final year = yearStart + selection.indexOf('year');
    final max = _daysInGregorianMonth(year, month);
    final day = (selection.indexOf('day') + 1).clamp(1, max).toInt();
    return DateTime(year, month, day);
  }

  int _daysInGregorianMonth(int year, int month) {
    final leap = (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return (month == 2 && leap) ? 29 : days[month];
  }
}
