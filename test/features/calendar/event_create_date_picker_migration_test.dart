import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'event create dialog date picker is isolated to Stone Register wrapper',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final dialog = _sourceBetween(
        source,
        'Future<bool> _openCalendarScopedNoteDialog',
        'String? _normalizeCalendarId',
      );
      final picker = _sourceBetween(
        dialog,
        'Widget datePicker()',
        'Future<void> saveNote()',
      );

      expect(picker, contains('EventCreateDatePicker.show'));
      expect(picker, contains('initialDate: KemeticMath.toGregorian'));
      expect(picker, contains('initialMode: dateMode'));
      expect(picker, contains('setSelectedEventDate(picked.date)'));
      expect(picker, contains('showGregorianDates ='));
      expect(picker, contains('EventCreateDatePickerMode.gregorian'));
      expect(picker, isNot(contains('CupertinoPicker')));
      expect(picker, isNot(contains('FixedExtentScrollController')));
      expect(_occurrences(source, 'EventCreateDatePicker.show'), 1);

      final saveNote = _sourceBetween(
        dialog,
        'Future<void> saveNote()',
        'final keyboardInset = keyboardInsetOf(dialogCtx);',
      );
      expect(saveNote, contains('_saveSingleNoteOnly'));
      expect(saveNote, contains('selYear: selYear'));
      expect(saveNote, contains('selMonth: selMonth'));
      expect(saveNote, contains('selDay: selDay'));
      expect(saveNote, contains('title: title'));
      expect(saveNote, contains('detail: detail.isEmpty ? null : detail'));
      expect(
        saveNote,
        contains('location: location.isEmpty ? null : location'),
      );
      expect(saveNote, contains('calendarId: calendarId'));
      expect(saveNote, contains('calendarName: lockedCalendar.name'));
      expect(saveNote, contains('allDay: allDay'));
      expect(saveNote, contains('startTime: startTime'));
      expect(saveNote, contains('endTime: endTime'));
      expect(saveNote, contains('color: _flowPalette[selectedColorIndex]'));
      expect(saveNote, contains('category: selectedCategory'));
      expect(saveNote, contains('alertMinutesBefore: alertMinutesBefore'));
    },
  );

  test(
    'event create migration stays isolated from Day sheet date picker',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final daySheet = _sourceBetween(
        source,
        'void _openDaySheet',
        'Future<void> _openQuickAddSheet',
      );

      expect(daySheet, contains('Widget datePicker()'));
      expect(daySheet, contains('DaySheetDatePicker.show'));
      expect(daySheet, isNot(contains('EventCreateDatePicker.show')));
    },
  );

  test('audit records event create preservation contract', () async {
    final audit = await File(
      'docs/stone_register_date_picker_audit.md',
    ).readAsString();

    expect(
      audit,
      contains('### Event Create Dialog Date Preservation Contract'),
    );
    expect(audit, contains('EventCreateDatePicker.show'));
    expect(audit, contains('title/location/detail'));
    expect(audit, contains('shared-calendar event creation'));
    expect(audit, contains('Day sheet date picker'));
  });
}

String _sourceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: 'Missing start needle: $startNeedle');
  final end = source.indexOf(endNeedle, start + startNeedle.length);
  expect(end, isNonNegative, reason: 'Missing end needle: $endNeedle');
  return source.substring(start, end);
}

int _occurrences(String source, String needle) {
  var count = 0;
  var index = 0;
  while (true) {
    index = source.indexOf(needle, index);
    if (index < 0) return count;
    count += 1;
    index += needle.length;
  }
}
