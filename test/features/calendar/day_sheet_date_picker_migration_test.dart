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
      'Future<bool> openReminderEditorForSelectedDay',
    );
    final daySheetFrame = await File(
      'lib/widgets/day_sheet_components.dart',
    ).readAsString();

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
    expect(picker, contains('showCalendarIcon: false'));
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

    expect(daySheet, contains('return DaySheetKeyboardSafeFrame('));
    expect(daySheetFrame, contains('class DaySheetKeyboardSafeFrame'));
    expect(daySheetFrame, contains('final viewInsetsBottom'));
    expect(daySheetFrame, contains('MediaQuery.viewInsetsOf(context).bottom'));
    expect(daySheetFrame, contains('keyboardInsetOf(context)'));
    expect(daySheetFrame, contains('SingleChildScrollView('));
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
      'Future<bool> openReminderEditorForSelectedDay',
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
      'return DaySheetKeyboardSafeFrame(',
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

    expect(builder, contains('final dayEvents = _calendarSheetEventsForDay('));
    expect(
      builder,
      contains('final dayFlowRows = _calendarSheetScheduledFlowsForDay('),
    );
    expect(builder, isNot(contains('final dayNotes = ')));
    expect(builder, contains('selYear'));
    expect(builder, contains('selMonth'));
    expect(builder, contains('selDay'));

    expect(daySheet, contains('bool scheduledFlowsExpanded = false'));
    expect(scheduledSection, contains('count: dayFlowRows.length'));
    expect(scheduledSection, contains('if (dayFlowRows.isEmpty)'));
    expect(scheduledSection, contains("for (final row in dayFlowRows)"));
    expect(scheduledSection, contains('onTap: row.flowId == null'));
    expect(scheduledSection, contains('_openDaySheetFlowDetail('));
    expect(scheduledSection, isNot(contains('Navigator.pop(sheetCtx)')));
    expect(scheduledSection, isNot(contains('_pushFlowStudioEditor')));
    expect(scheduledSection, isNot(contains('_getMyFlowsCallback()')));
    expect(
      scheduledSection.indexOf("for (final row in dayFlowRows)"),
      lessThan(scheduledSection.indexOf("'Manage flows'")),
    );

    expect(daySheet, contains('bool dayNotesExpanded = false'));
    expect(notesSection, contains('count: dayEvents.length'));
    expect(notesSection, contains('if (dayEvents.isEmpty)'));
    expect(notesSection, contains("for (final event in dayEvents)"));
    expect(notesSection, contains('color: event.color'));
    expect(notesSection, contains('_openDaySheetEventDetailInHostDayView('));
    expect(notesSection, isNot(contains('_openDayView(')));
    expect(notesSection, isNot(contains('Navigator.push')));
    expect(notesSection, isNot(contains('context.push')));
    final noteTapHelper = _sourceBetween(
      source,
      'void _openDaySheetEventDetailInHostDayView',
      '/* ───── Day Sheet ───── */',
    );
    expect(noteTapHelper, contains('eventDetailRestorationStateForTarget'));
    expect(noteTapHelper, contains("parentSurface: 'day_sheet'"));
    expect(
      noteTapHelper,
      contains('_dayViewEventDetailRequest.value = target'),
    );
    expect(
      noteTapHelper,
      contains("debugOpenSource: 'day_sheet_note_tap_fallback'"),
    );
    expect(notesSection, contains('_deleteNoteByEvent('));
  });

  test('Day sheet reminders are scoped to the selected sheet day', () async {
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
      'return DaySheetKeyboardSafeFrame(',
    );
    final remindersSection = _sourceBetween(
      daySheet,
      "label: 'Reminders'",
      "label: 'Add reminder'",
    );
    final sharedPickerPlacement = _sourceBetween(
      daySheet,
      'DaySheetTabBar(',
      'if (showReminders) ...[',
    );
    final helper = _sourceBetween(
      source,
      'List<ReminderRule> _calendarSheetReminderRulesForDay',
      '({String primary, String? subline}) _daySheetReminderRuleLines',
    );

    expect(
      builder,
      contains('final dayReminderRules = _calendarSheetReminderRulesForDay('),
    );
    expect(builder, contains('dayEvents,'));
    expect(builder, contains('selYear'));
    expect(builder, contains('selMonth'));
    expect(builder, contains('selDay'));
    expect(sharedPickerPlacement, contains('datePicker()'));
    expect(remindersSection, contains('count: dayReminderRules.length'));
    expect(remindersSection, contains('if (dayReminderRules.isEmpty)'));
    expect(remindersSection, contains('itemCount: dayReminderRules.length'));
    expect(remindersSection, contains('final r = dayReminderRules[i]'));
    expect(remindersSection, isNot(contains('Force resync reminders')));
    expect(remindersSection, isNot(contains('DaySheetCartouche')));
    expect(remindersSection, isNot(contains('count: _reminderRules.length')));
    expect(
      remindersSection,
      isNot(contains('itemCount: _reminderRules.length')),
    );

    expect(helper, contains('KemeticMath.toGregorian(kYear, kMonth, kDay)'));
    expect(helper, contains('List<EventItem> dayEvents'));
    expect(helper, contains('_generateReminderOccurrences(rule, day, day)'));
    expect(helper, contains('_endedReminderIds.contains(rule.id)'));
    expect(helper, contains('for (final event in dayEvents)'));
    expect(helper, contains('if (!event.isReminder) continue'));
    expect(helper, contains('_calendarSheetReminderRuleFromVisibleEvent'));
    expect(helper, contains('_calendarSheetReminderFallbackKeyForEvent'));
    expect(helper, contains('rules.sort'));
  });

  test('Day sheet picker state is the single list scope source', () async {
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
      'return DaySheetKeyboardSafeFrame(',
    );
    final selectedDaySources = _sourceBetween(
      builder,
      'final titleG = KemeticMath.toGregorian(',
      'final editingNote = initialEditingNote;',
    );
    final picker = _sourceBetween(
      builder,
      'Widget datePicker()',
      'Future<bool> openReminderEditorForSelectedDay',
    );
    final reminderEditor = _sourceBetween(
      daySheet,
      'Future<bool> openReminderEditorForSelectedDay',
      'const fieldScrollPadding = keyboardManagedTextFieldScrollPadding;',
    );

    expect(selectedDaySources, contains('selYear'));
    expect(selectedDaySources, contains('selMonth'));
    expect(selectedDaySources, contains('selDay'));
    expect(
      selectedDaySources,
      contains('final dayEvents = _calendarSheetEventsForDay('),
    );
    expect(
      selectedDaySources,
      contains('final dayFlowRows = _calendarSheetScheduledFlowsForDay('),
    );
    expect(
      selectedDaySources.indexOf(
        'final dayEvents = _calendarSheetEventsForDay(',
      ),
      lessThan(
        selectedDaySources.indexOf(
          'final dayFlowRows = _calendarSheetScheduledFlowsForDay(',
        ),
      ),
    );
    expect(selectedDaySources, contains('dayEvents,'));
    expect(
      selectedDaySources,
      contains('final dayReminderRules = _calendarSheetReminderRulesForDay('),
    );
    expect(selectedDaySources, contains('dayEvents,'));
    expect(selectedDaySources, isNot(contains('_getNotes(')));
    expect(selectedDaySources, isNot(contains('_getFlowOccurrences(')));

    expect(picker, contains('final seed = DateUtils.dateOnly(titleG)'));
    expect(picker, contains('value: EventCreateDatePickerValue('));
    expect(picker, contains('date: seed'));
    expect(picker, contains('showCalendarIcon: false'));
    expect(picker, contains('onChanged: (picked)'));
    expect(picker, contains('selYear = selected.kYear'));
    expect(picker, contains('selMonth = selected.kMonth'));
    expect(picker, contains('selDay = selected.kDay'));
    expect(picker, contains('persistDaySheetSession()'));

    expect(reminderEditor, contains('initialDate: titleG'));
    expect(daySheet, contains('return DaySheetKeyboardSafeFrame('));
    expect(builder, isNot(contains('DateTime.now')));
    expect(builder, isNot(contains('_today')));
    expect(builder, isNot(contains('_currentKy')));
    expect(builder, isNot(contains('_currentKm')));
    expect(builder, isNot(contains('_currentKd')));
    expect(builder, isNot(contains('_reminderRules.length')));
    expect(builder, isNot(contains('_reminderRules[i]')));
  });

  test('Day sheet forms use Flow Studio color and save chrome', () async {
    final source = await File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsString();
    final daySheet = _sourceBetween(
      source,
      'void _openDaySheet',
      'Future<void> _openQuickAddSheet',
    );
    final addNoteColorAndSave = _sourceBetween(
      daySheet,
      'DaySheetSpectrumColorPicker(',
      'final bucketKey = _kKey(',
    );
    final addNoteForm = _sourceBetween(
      daySheet,
      "label: editingIndex == null",
      'DaySheetSpectrumColorPicker(',
    );
    final reminderEditor = _sourceBetween(
      source,
      'Future<bool> _openReminderEditor',
      'Future<void> _editReminderById',
    );

    expect(daySheet, contains('Color selectedColor ='));
    expect(addNoteForm, contains("text: 'Calendar'"));
    expect(addNoteForm, contains("text: 'Alert'"));
    expect(addNoteForm, contains("text: 'Invitees'"));
    expect(addNoteForm, contains('// Repeat row'));
    expect(addNoteForm, contains("text: 'Repeat'"));
    expect(addNoteForm, contains('// End Repeat row'));
    expect(addNoteForm, contains("text: 'End Repeat'"));
    expect(addNoteForm, contains('RecurrenceUntilDatePicker.show'));
    expect(addNoteColorAndSave, contains('selectedColor: selectedColor'));
    expect(addNoteColorAndSave, contains('DaySheetSaveButton('));
    expect(addNoteColorAndSave, contains('accent: selectedColor'));
    expect(daySheet, contains('color: selectedColor'));
    expect(daySheet, isNot(contains('DaySheetColorSwatches(')));
    expect(daySheet, isNot(contains('DaySheetFab.round(')));
    expect(daySheet, isNot(contains('DaySheetCartouche')));

    expect(reminderEditor, contains('Color selectedColor ='));
    expect(reminderEditor, contains('showCalendarIcon: false'));
    expect(reminderEditor, isNot(contains('DaySheetTabBar(')));
    expect(reminderEditor, isNot(contains('DaySheetTab.notes')));
    expect(reminderEditor, contains("'New reminder'"));
    expect(reminderEditor, contains("'Edit reminder'"));
    expect(reminderEditor, contains('DaySheetSpectrumColorPicker('));
    expect(reminderEditor, contains('selectedColor: selectedColor'));
    expect(reminderEditor, contains('DaySheetSaveButton('));
    expect(reminderEditor, contains('accent: selectedColor'));
    expect(reminderEditor, contains('color: selectedColor'));
    expect(reminderEditor, isNot(contains('DaySheetColorSwatches(')));
    expect(reminderEditor, isNot(contains('DaySheetFab.round(')));
  });

  test('Day sheet flow detail stays stacked over the sheet', () async {
    final source = await File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsString();
    final daySheet = _sourceBetween(
      source,
      'void _openDaySheet',
      'Future<void> _openQuickAddSheet',
    );
    final scheduledSection = _sourceBetween(
      daySheet,
      "label: 'Scheduled flows'",
      "label: 'Notes on this day'",
    );
    final flowDetail = _sourceBetween(
      source,
      'void _openDaySheetFlowDetail',
      'Future<void> _openQuickAddSheet',
    );

    expect(scheduledSection, contains('_openDaySheetFlowDetail(flowId)'));
    expect(scheduledSection, isNot(contains('Navigator.pop(sheetCtx)')));
    expect(scheduledSection, isNot(contains('context.go')));
    expect(scheduledSection, isNot(contains('GoRouter')));
    expect(flowDetail, contains('_openFlowStudioSheet('));
    expect(flowDetail, contains('_FlowPreviewPage('));
    expect(flowDetail, contains("'source': 'day_sheet_flow_detail'"));
    expect(flowDetail, contains('showCloseButton: true'));
    expect(flowDetail, contains('_debugDaySheetSmokeEnabled'));
    expect(flowDetail, contains('_daySheetFlowDetailEventsByFlow(sequence)'));
    expect(flowDetail, contains('initialEventsByFlow:'));
    expect(flowDetail, contains('_flowEventRowFromDaySheetNote'));
  });

  test(
    'Day sheet reminders include visible shared-calendar reminders',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final helper = _sourceBetween(
        source,
        'List<ReminderRule> _calendarSheetReminderRulesForDay',
        '({String primary, String? subline}) _daySheetReminderRuleLines',
      );
      final fixture = _sourceBetween(
        source,
        'void _configureDebugDaySheetSmokeState()',
        'void _scheduleDebugDaySheetSmoke()',
      );

      expect(helper, contains('List<EventItem> dayEvents'));
      expect(helper, contains('for (final event in dayEvents)'));
      expect(helper, contains('if (!event.isReminder) continue'));
      expect(helper, contains('_calendarSheetReminderRuleFromVisibleEvent('));
      expect(helper, contains('calendarId: event.calendarId'));
      expect(helper, contains('event.manualColor ?? event.color'));
      expect(helper, contains('_calendarSheetReminderEventDedupKey'));
      expect(helper, contains('_calendarSheetReminderFallbackKeyForEvent'));

      expect(fixture, contains("name: 'Family Calendar'"));
      expect(fixture, contains('SharedCalendarRole.viewer'));
      expect(fixture, contains('const familySalonColor = Color(0xFFE85DFF)'));
      expect(fixture, contains("title: 'Family Salon'"));
      expect(fixture, contains('calendarId: sharedCalendarId'));
      expect(fixture, contains('manualColor: familySalonColor'));
      expect(fixture, contains('isReminder: true'));
    },
  );

  test(
    'filing-backed shared reminder rows keep reminder identity through hydration',
    () async {
      final calendarSource = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final repoSource = await File(
        'lib/data/user_events_repo.dart',
      ).readAsString();
      final hydrateBlock = _sourceBetween(
        calendarSource,
        'final isReminderBackboneEvent =',
        'final positiveFiledFlowId =',
      );

      expect(repoSource, contains('bool isReminder,'));
      expect(
        repoSource,
        contains("isReminder: _normalizedFilingItemKind(row) == 'reminder'"),
      );
      expect(hydrateBlock, contains('evt.isReminder ||'));
      expect(hydrateBlock, contains("cid.startsWith('reminder:')"));
      expect(hydrateBlock, contains('bool isReminderEvent ='));
    },
  );

  test('Day View preserves explicit shared reminder colors', () async {
    final dayViewSource = await File(
      'lib/features/calendar/day_view.dart',
    ).readAsString();
    final visualHelper = _sourceBetween(
      dayViewSource,
      'CalendarEventVisualStyle _dayViewVisualForEvent',
      'CalendarEventVisualStyle _dayViewMatteDetailVisual',
    );

    expect(visualHelper, contains('preserveEventColorForReminder:'));
    expect(
      visualHelper,
      contains('isReminder && (event.manualColor != null || flow != null)'),
    );
  });

  test(
    'Day View header plus passes the current Day View date to Day sheet',
    () async {
      final dayViewSource = await File(
        'lib/features/calendar/day_view.dart',
      ).readAsString();
      final calendarSource = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final headerWiring = _sourceBetween(
        dayViewSource,
        'onOpenQuickAdd: (btnCtx) async {',
        'onOpenSearch:',
      );
      final routeWiring = _sourceBetween(
        calendarSource,
        'builder: (context) => DayViewPage(',
        'onCreateTimedEvent: _handleCreateTimedEvent',
      );

      expect(headerWiring, contains('if (widget.onAddNote != null)'));
      expect(headerWiring, contains('widget.onAddNote!('));
      expect(headerWiring, contains('_currentKy'));
      expect(headerWiring, contains('_currentKm'));
      expect(headerWiring, contains('_currentKd'));
      expect(
        headerWiring.indexOf('widget.onAddNote!('),
        lessThan(
          headerWiring.indexOf('final openQuickAdd = widget.onOpenQuickAdd'),
        ),
      );
      expect(routeWiring, contains('onAddNote: (ky, km, kd) =>'));
      expect(routeWiring, contains('_openDaySheet(ky, km, kd'));
      expect(routeWiring, contains('allowDateChange: true'));
    },
  );

  test(
    'scheduled flow rows are parent flows derived from Day View events',
    () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final helper = _sourceBetween(
        source,
        'List<_DaySheetScheduledFlowRow> _calendarSheetScheduledFlowsForDay',
        'FlowRecordSnapshot _flowRecordSnapshotFromFlow',
      );

      expect(helper, contains('List<EventItem> dayEvents'));
      expect(helper, contains('for (final event in dayEvents)'));
      expect(helper, contains('_calendarSheetEventRepresentsScheduledFlow'));
      expect(helper, contains('_calendarSheetScheduledFlowKeyForEvent'));
      expect(helper, contains('rowIndexByParentKey'));
      expect(helper, contains('occurrenceCount: existing.occurrenceCount + 1'));
      expect(helper, contains("sourceType: 'day_view_flow'"));
      expect(helper, contains('startsAtLocal: range.start'));
      expect(helper, contains('endsAtLocal: range.end'));
      expect(helper, contains('final safeName = flow.name.trim().isEmpty'));
      expect(helper, contains("name: safeName.isEmpty ? 'Flow' : safeName"));
      expect(helper, contains('_displayFlowColor(flow.name, flow.color)'));
      expect(helper, contains('rows.sort'));
      expect(helper, isNot(contains('_getFlowOccurrences')));
      expect(helper, isNot(contains('filterAndDedupeDaySheetCandidates')));
    },
  );

  test(
    'Notes on this day preserves selected-day Day View event blocks',
    () async {
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
      expect(helper, contains('filterAndDedupeDaySheetCandidates'));
      expect(helper, contains("'day_view_event'"));
      expect(helper, contains("'reminder'"));
      expect(helper, contains('_calendarSheetEventItemFromNote'));
      expect(helper, isNot(contains('_calendarSheetNoteBelongsInNotes')));
      expect(helper, isNot(contains('_getNotes(ky, km, kd)')));
    },
  );

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
    expect(
      mainSource,
      contains('if (kDebugMode && _debugDaySheetSmokeBootRequested) return;'),
    );
    expect(
      mainSource.indexOf(
        'if (kDebugMode && _debugDaySheetSmokeBootRequested) return;',
      ),
      lessThan(
        mainSource.indexOf("unawaited(Events.trackIfAuthed('screen_view'"),
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
