import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'day sheet date picker routes only through DaySheetDatePicker',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final daySheet = _sourceBetween(
        source,
        'void _openDaySheet',
        'Future<void> _openQuickAddSheet',
      );
      final picker = _sourceBetween(
        daySheet,
        'Future<void> openDaySheetDatePicker()',
        'final keyboardInset = keyboardInsetOf(sheetCtx);',
      );

      expect(
        source,
        contains("import '../../widgets/day_sheet_date_picker.dart';"),
      );
      expect(picker, contains('DaySheetDatePicker.show'));
      expect(picker, contains('initialDate: KemeticMath.toGregorian'));
      expect(picker, contains('initialMode: showGregorianDates'));
      expect(picker, contains('DaySheetDatePickerMode.gregorian'));
      expect(picker, contains('KemeticMath.fromGregorian(picked.date)'));
      expect(picker, contains('showGregorianDates ='));
      expect(picker, contains('persistDaySheetSession()'));
      expect(picker, isNot(contains('CupertinoPicker')));
      expect(picker, isNot(contains('FixedExtentScrollController')));
      expect(_occurrences(source, 'DaySheetDatePicker.show'), 1);
    },
  );

  test('allowDateChange continues to gate Day sheet date mutation', () async {
    final source = await File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsString();
    final daySheet = _sourceBetween(
      source,
      'void _openDaySheet',
      'Future<void> _openQuickAddSheet',
    );
    final picker = _sourceBetween(
      daySheet,
      'Future<void> openDaySheetDatePicker()',
      'Widget datePicker()',
    );
    final dateButton = _sourceBetween(
      daySheet,
      'Widget datePicker()',
      'return titleWidget;',
    );

    expect(picker, contains('if (!allowDateChange) return;'));
    expect(dateButton, contains('button: allowDateChange'));
    expect(
      dateButton,
      contains('onTap: allowDateChange ? openDaySheetDatePicker : null'),
    );
  });

  test(
    'Day sheet restoration session and save payloads remain caller-owned',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final daySheet = _sourceBetween(
        source,
        'void _openDaySheet',
        'Future<void> _openQuickAddSheet',
      );

      final payload = _sourceBetween(
        daySheet,
        'Map<String, dynamic> daySheetSessionPayload()',
        'void persistDaySheetSession()',
      );
      expect(payload, contains("'kYear': selYear"));
      expect(payload, contains("'kMonth': selMonth"));
      expect(payload, contains("'kDay': selDay"));
      expect(payload, contains("'showGregorianDates': showGregorianDates"));
      expect(payload, contains("'allowDateChange': allowDateChange"));
      expect(
        payload,
        contains(
          "'editingSourceKYear': editingIndex == null ? null : sourceEditingKYear",
        ),
      );
      expect(payload, contains("'editingSourceKMonth': editingIndex == null"));
      expect(
        payload,
        contains(
          "'editingSourceKDay': editingIndex == null ? null : sourceEditingKDay",
        ),
      );

      final persist = _sourceBetween(
        daySheet,
        'void persistDaySheetSession()',
        'controllerTitle.addListener',
      );
      expect(
        persist,
        contains('AppRestorationService.instance.saveDaySheetState'),
      );
      expect(persist, contains('SessionResumeService.saveResumeEntry'));
      expect(persist, contains('payload: daySheetSessionPayload()'));

      final saveHandler = _sourceBetween(
        daySheet,
        'final bucketKey = _kKey(',
        "if (!sheetCtx.mounted) return;",
      );
      expect(saveHandler, contains('sourceEditingKYear'));
      expect(saveHandler, contains('sourceEditingKMonth'));
      expect(saveHandler, contains('sourceEditingKDay'));
      expect(saveHandler, contains('selYear: selYear'));
      expect(saveHandler, contains('selMonth: selMonth'));
      expect(saveHandler, contains('selDay: selDay'));
      expect(saveHandler, contains('_updateSingleNoteOnly'));
      expect(saveHandler, contains('_saveSingleNoteOnly'));
      expect(saveHandler, contains('_saveRepeatingNoteAsHiddenFlow'));
      expect(saveHandler, contains('_applyRepeatingNoteEditScope'));
    },
  );

  test(
    'Day sheet migration keeps neighboring high-risk surfaces isolated',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final eventCreate = _sourceBetween(
        source,
        'Future<bool> _openCalendarScopedNoteDialog',
        'String? _normalizeCalendarId',
      );
      final daySheet = _sourceBetween(
        source,
        'void _openDaySheet',
        'Future<void> _openQuickAddSheet',
      );

      expect(eventCreate, contains('EventCreateDatePicker.show'));
      expect(eventCreate, isNot(contains('DaySheetDatePicker.show')));
      expect(daySheet, isNot(contains('EventCreateDatePicker.show')));
      expect(source, contains("part 'calendar_maat_flows.dart';"));
      expect(_occurrences(source, 'DaySheetDatePicker.show'), 1);
    },
  );

  test('audit records Day sheet preservation contract', () async {
    final audit = await File(
      'docs/stone_register_date_picker_audit.md',
    ).readAsString();

    expect(audit, contains('### Day Sheet Date Picker Preservation Contract'));
    expect(audit, contains('DaySheetDatePicker.show'));
    expect(audit, contains('AppRestorationService.saveDaySheetState'));
    expect(audit, contains('SessionResumeService.saveResumeEntry'));
    expect(audit, contains('editing source date'));
    expect(audit, contains("Ma'at flow date picker"));
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
