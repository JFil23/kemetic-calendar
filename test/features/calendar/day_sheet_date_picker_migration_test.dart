import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('day sheet date control uses the shared Stone Register field', () async {
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
      'Widget datePicker()',
      'final keyboardInset = keyboardInsetOf(sheetCtx);',
    );

    expect(
      source,
      contains(
        "import '../../shared/date_picker/stone_register_date_field.dart';",
      ),
    );
    expect(
      source,
      contains(
        "import '../../shared/date_picker/stone_register_date_picker.dart'",
      ),
    );
    expect(
      source,
      contains("import '../../widgets/day_sheet_components.dart';"),
    );
    expect(
      source,
      isNot(contains("import '../../widgets/day_sheet_date_picker.dart';")),
    );
    expect(
      picker,
      contains('StoneRegisterDateField<EventCreateDatePickerValue>'),
    );
    expect(picker, contains('day_sheet_date_picker_field'));
    expect(picker, contains('DateUtils.dateOnly(titleG)'));
    expect(picker, contains('EventCreateDatePickerAdapter'));
    expect(picker, contains('enabled: allowDateChange'));
    expect(picker, contains('StoneDatePickerCalendarMode.gregorian'));
    expect(picker, contains('onChanged: (picked)'));
    expect(picker, contains('KemeticMath.fromGregorian(picked.date)'));
    expect(
      picker,
      contains('picked.mode == EventCreateDatePickerMode.gregorian'),
    );
    expect(picker, contains('persistDaySheetSession()'));
    expect(picker, isNot(contains('DaySheetDateStepper')));
    expect(picker, isNot(contains('DaySheetDatePicker.show')));
    expect(picker, isNot(contains('CupertinoPicker')));
    expect(picker, isNot(contains('FixedExtentScrollController')));
  });

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
      'Widget datePicker()',
      'final keyboardInset = keyboardInsetOf(sheetCtx);',
    );

    expect(picker, contains('enabled: allowDateChange'));
    expect(picker, contains('StoneRegisterDateField'));
    expect(picker, isNot(contains('DaySheetDateStepper')));
    expect(picker, isNot(contains('DaySheetDatePicker.show')));
  });

  test('Day sheet lists read from the selected day sources', () async {
    final source = await File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsString();
    final daySheet = _sourceBetween(
      source,
      'void _openDaySheet',
      'Future<void> _openQuickAddSheet',
    );
    final builder = _sourceBetween(
      daySheet,
      'builder: (sheetCtx, setSheetState)',
      'final keyboardInset = keyboardInsetOf(sheetCtx);',
    );
    final scheduledSection = _sourceBetween(
      daySheet,
      "label: 'Scheduled flows'",
      "label: 'Notes on this day'",
    );
    final notesSection = _sourceBetween(
      daySheet,
      "label: 'Notes on this day'",
      "label: editingIndex == null",
    );

    expect(
      builder,
      contains('final dayNotes = _calendarSheetNoteCandidatesForDay('),
    );
    expect(builder, contains('final dayEvents = _calendarSheetEventsForDay('));
    expect(
      builder,
      contains('final dayFlowRows = _calendarSheetScheduledFlowsForDay('),
    );
    expect(builder, contains('selYear'));
    expect(builder, contains('selMonth'));
    expect(builder, contains('selDay'));

    expect(daySheet, contains('bool scheduledFlowsExpanded = true'));
    expect(scheduledSection, contains('count: dayFlowRows.length'));
    expect(scheduledSection, contains('if (dayFlowRows.isEmpty)'));
    expect(scheduledSection, contains("for (final row in dayFlowRows)"));
    expect(
      scheduledSection.indexOf("for (final row in dayFlowRows)"),
      lessThan(scheduledSection.indexOf("'Manage flows'")),
    );

    expect(daySheet, contains('bool dayNotesExpanded = false'));
    expect(notesSection, contains('count: dayEvents.length'));
    expect(notesSection, contains('if (dayEvents.isEmpty)'));
    expect(notesSection, contains("for (final event in dayEvents)"));
    expect(notesSection, contains('focusEvent: event'));
    expect(notesSection, contains('_deleteNoteByEvent('));
  });

  test(
    'scheduled flow rows merge computed flows with flow-backed events',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final helper = _sourceBetween(
        source,
        'List<_DaySheetScheduledFlowRow> _calendarSheetScheduledFlowsForDay',
        'FlowRecordSnapshot _flowRecordSnapshotFromFlow',
      );

      expect(helper, contains('final window = _calendarSheetDayWindow'));
      expect(helper, contains('for (final occurrence in _getFlowOccurrences'));
      expect(helper, contains('for (final entry in dayNotes)'));
      expect(helper, contains('final flowId = note.flowId'));
      expect(helper, contains('_calendarSheetNoteBelongsInScheduledFlows'));
      expect(helper, contains('filterAndDedupeDaySheetCandidates'));
      expect(helper, contains("sourceType: 'event_backed_flow'"));
      expect(helper, contains('startsAtLocal: range.start'));
      expect(helper, contains('endsAtLocal: range.end'));
      expect(helper, contains('name: flow.name'));
      expect(helper, contains('color: _noteColor(note)'));
      expect(helper, contains('rows.sort'));
    },
  );

  test('Notes on this day uses selected-day note occurrences only', () async {
    final source = await File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsString();
    final helper = _sourceBetween(
      source,
      'List<EventItem> _calendarSheetEventsForDay',
      'DayViewSheetEventTarget? _resolveCalendarAdjacentEventTarget',
    );

    expect(helper, contains('final window = _calendarSheetDayWindow'));
    expect(helper, contains('_calendarSheetNoteCandidatesForDay'));
    expect(helper, contains('_calendarSheetNoteBelongsInNotes'));
    expect(helper, contains('filterAndDedupeDaySheetCandidates'));
    expect(helper, contains("sourceType: 'note'"));
    expect(helper, contains('_calendarSheetEventItemFromNote'));
    expect(helper, isNot(contains('_getNotes(ky, km, kd)')));
  });

  test(
    'new reminders opened from Day sheet seed from the selected day',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final reminderEditor = _sourceBetween(
        source,
        'Future<bool> _openReminderEditor',
        'Future<void> _editReminderById',
      );
      final daySheet = _sourceBetween(
        source,
        'void _openDaySheet',
        'Future<void> _openQuickAddSheet',
      );

      expect(reminderEditor, contains('DateTime? initialDate'));
      expect(
        reminderEditor,
        contains('final defaultDate = DateUtils.dateOnly(initialDate ?? now)'),
      );
      expect(daySheet, contains('openReminderEditorForSelectedDay'));
      expect(daySheet, contains('initialDate: titleG'));
      expect(daySheet, contains('await openReminderEditorForSelectedDay()'));
      expect(daySheet, contains('await openReminderEditorForSelectedDay('));
    },
  );

  test('debug smoke route seeds the real Day sheet surface', () async {
    final calendarSource = await File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsString();
    final mainSource = await File('lib/main.dart').readAsString();
    final fixture = _sourceBetween(
      calendarSource,
      'void _configureDebugDaySheetSmokeState()',
      'void _scheduleDebugDaySheetSmoke()',
    );
    final launcher = _sourceBetween(
      calendarSource,
      'void _scheduleDebugDaySheetSmoke()',
      '@override\n  void initState',
    );
    final initState = _sourceBetween(
      calendarSource,
      'void initState()',
      'void _handleCalendarInvalidated',
    );
    final route = _sourceBetween(
      mainSource,
      "if (kDebugMode)\n      _calmRoute(",
      "path: '/inbox'",
    );

    expect(calendarSource, contains('debugDaySheetSmokeOnLaunch'));
    expect(calendarSource, contains('buildDebugDaySheetSmokeRoute'));
    expect(calendarSource, contains('_debugDaySheetSmokeEnabled'));
    expect(mainSource, contains("String.fromEnvironment('H3W_DEBUG_ROUTE')"));
    expect(
      mainSource,
      contains("bool.fromEnvironment(\n  'H3W_DEBUG_DAY_SHEET_SMOKE'"),
    );
    expect(mainSource, contains('_debugDaySheetSmokeBootRequested'));
    expect(mainSource, contains('_debugDaySheetSmokeFallbackConfig'));
    expect(
      mainSource,
      contains("kIsWeb && _isDebugDaySheetSmokeLocation(Uri.base.toString())"),
    );
    expect(route, contains('if (kDebugMode)'));
    expect(route, contains('path: _kDebugDaySheetSmokeRoute'));
    expect(route, contains('SessionTrackedRoute'));
    expect(route, contains('CalendarPage.buildDebugDaySheetSmokeRoute()'));
    expect(
      mainSource,
      contains(
        'if (_debugDaySheetSmokeBootRequested) {\n      return _buildAuthedApp();',
      ),
    );

    expect(fixture, contains("name: 'The Weighing'"));
    expect(fixture, contains("name: 'journal every day'"));
    expect(fixture, contains("name: 'journal every night'"));
    expect(fixture, contains("name: 'same decan off-day flow'"));
    expect(fixture, contains("name: 'template only flow'"));
    expect(fixture, contains('rules: const <FlowRule>[]'));
    expect(fixture, contains("title: 'Smoke note: offering list'"));
    expect(fixture, contains("title: 'Smoke note: midnight overlap'"));
    expect(fixture, contains("title: 'Smoke note: next day only'"));
    expect(fixture, contains("title: 'Daily offering reminder'"));
    expect(fixture, contains("title: 'Decan reflection reminder'"));
    expect(fixture, contains('ReminderRepeatKind.everyNDays'));
    expect(fixture, contains('ReminderRepeatKind.kemeticEveryNDecans'));
    expect(fixture, contains('_calendarStateLoaded = true'));
    expect(fixture, contains('_reminderRulesLoaded = true'));
    expect(fixture, contains('_restored = true'));
    expect(fixture, contains('_initialViewportSettled = true'));

    expect(launcher, contains('_openDaySheet('));
    expect(launcher, contains('persistAsRestoration: false'));
    expect(launcher, contains("initialTitle: 'Smoke draft note'"));
    expect(launcher, contains('initialCalendarId: _personalCalendarId'));

    expect(
      initState.indexOf('_configureDebugDaySheetSmokeState()'),
      lessThan(initState.indexOf('_reminderService.load()')),
    );
    expect(
      initState.indexOf('_scheduleDebugDaySheetSmoke()'),
      lessThan(initState.indexOf('_reminderService.load()')),
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
      expect(
        daySheet,
        contains('StoneRegisterDateField<EventCreateDatePickerValue>'),
      );
      expect(daySheet, contains('EventCreateDatePickerAdapter'));
      expect(daySheet, isNot(contains('EventCreateDatePicker.show')));
      expect(daySheet, isNot(contains('DaySheetDatePicker.show')));
      expect(source, contains("part 'calendar_maat_flows.dart';"));
      expect(_occurrences(source, 'DaySheetDatePicker.show'), 0);
    },
  );

  test('audit records Day sheet preservation contract', () async {
    final audit = await File(
      'docs/stone_register_date_picker_audit.md',
    ).readAsString();

    expect(audit, contains('### Day Sheet Date Picker Preservation Contract'));
    expect(
      audit,
      contains('StoneRegisterDateField<EventCreateDatePickerValue>'),
    );
    expect(audit, contains('AppRestorationService.saveDaySheetState'));
    expect(audit, contains('SessionResumeService.saveResumeEntry'));
    expect(audit, contains('editing source date'));
    expect(audit, contains('Debug Day Sheet Smoke Route'));
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
