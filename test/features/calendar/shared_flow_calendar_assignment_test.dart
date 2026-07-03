import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flow detail exposes a shared-calendar assignment control', () {
    final source = File(
      'lib/features/calendar/calendar_flow_pages.dart',
    ).readAsStringSync();
    final preview = _sourceBetween(
      source,
      'class _FlowPreviewPage extends StatefulWidget',
      '({bool kemetic, bool split, String overview, String? maatKey}) _metaFor',
    );

    expect(preview, contains('this.onCalendarChanged'));
    expect(preview, contains('_calendarChangeInFlight'));
    expect(preview, contains('_showCalendarChoiceSheet('));
    expect(
      preview,
      contains(r"ValueKey<String>('flow-calendar-picker-${flow.id}')"),
    );
    expect(preview, contains('flow.calendarId = chosenCalendar.id;'));
    expect(
      preview,
      contains('widget.onCalendarChanged!(flow, chosenCalendar)'),
    );
    expect(preview, contains('_eventsByFlow[flow.id] = events'));
    expect(preview, contains("'FLOW CALENDAR'"));
    expect(
      preview,
      contains(
        'final canChange = widget.onCalendarChanged != null && flow.id > 0;',
      ),
    );
    expect(source, contains('onCalendarChanged: widget.onCalendarChanged'));
    expect(
      source,
      isNot(contains('onCalendarChanged: mode == _FlowPreviewMode.active')),
    );
    expect(
      preview,
      isNot(contains('widget.mode != _FlowPreviewMode.saved &&')),
    );
  });

  test(
    'flow calendar assignment persists flow, events, and shared experience',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final moveHelper = _sourceBetween(
        source,
        'Future<_Flow> _moveFlowToCalendar(',
        'Future<_Flow> _moveReadingHouseFlowToCalendar',
      );
      final readingHouseHelper = _sourceBetween(
        source,
        'Future<_Flow> _moveReadingHouseFlowToCalendar',
        'Future<DayViewSheetEventTarget?> _moveReminderEventToCalendar',
      );
      final detachedMyFlows = _sourceBetween(
        source,
        'static Widget _buildDetachedMyFlowsPage',
        'static Widget _buildDetachedMaatFlowsListPage',
      );

      expect(moveHelper, contains('_flowsRepo.updateCalendar'));
      expect(
        moveHelper,
        contains('updateCalendarForFlowEvents(flowId: flow.id'),
      );
      expect(moveHelper, contains('_ensureSharedExperienceForFlow'));
      expect(moveHelper, contains('_refreshMovedFlowEventsFromServer'));
      expect(moveHelper, contains('_notifySharedCalendarItemAdded'));
      expect(moveHelper, contains('await _loadFromDisk(source: source);'));
      expect(
        source,
        contains('Future<void> _refreshMovedFlowEventsFromServer'),
      );
      expect(
        source,
        contains('getEventsForFlow(flowId, flowEventsOnly: true)'),
      );
      expect(
        source,
        contains('Map<String, dynamic>.from(matchingEvent.behaviorPayload!)'),
      );
      expect(readingHouseHelper, contains('_moveFlowToCalendar('));
      expect(
        readingHouseHelper,
        contains("source: 'reading_house_shared_calendar_move'"),
      );
      expect(detachedMyFlows, contains('CalendarPage._mountedState'));
      expect(source, contains('_loadHeadlessEditableCalendarsForFlow'));
      expect(source, contains('_moveFlowToCalendarHeadless'));
      expect(
        detachedMyFlows,
        contains('_moveFlowToCalendarHeadless(flow, calendar, flowsRepo)'),
      );
      expect(source, contains('onCalendarChanged: _moveFlowToCalendar'));
    },
  );

  test('Flow Studio calendar row uses the shared calendar picker', () {
    final studioSource = File(
      'lib/features/calendar/calendar_flow_studio_page.dart',
    ).readAsStringSync();
    final modelsSource = File(
      'lib/features/calendar/calendar_flow_studio_models.dart',
    ).readAsStringSync();
    final pickerCall = _sourceBetween(
      studioSource,
      'final calendars = _editableCalendars;',
      'if (chosenId == null) return;',
    );

    expect(modelsSource, contains('Future<String?> _showCalendarChoiceSheet'));
    expect(modelsSource, contains("ValueKey<String>('calendar-choice-"));
    expect(modelsSource, contains('Color _calendarChoiceLabelColor'));
    expect(pickerCall, contains('_showCalendarChoiceSheet('));
    expect(pickerCall, contains('_selectedCalendarId ?? _editing?.calendarId'));
    expect(pickerCall, isNot(contains('showCupertinoModalPopup<String>')));
    expect(studioSource, contains('overflow: TextOverflow.ellipsis'));
    expect(studioSource, contains('textAlign: TextAlign.right'));
  });

  test('detached Flow Studio saves materialize rule-only custom flows', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final headlessPersist = _sourceBetween(
      source,
      'static Future<int?> _persistFlowStudioResultHeadless',
      'static Future<int?> importFlowFromShare',
    );

    expect(source, contains('_decodeHeadlessFlowNotes'));
    expect(headlessPersist, contains('materializeRuleEventsIfNeeded'));
    expect(headlessPersist, contains('!f.active || f.rules.isEmpty'));
    expect(headlessPersist, contains('r.plannedNotes.isNotEmpty'));
    expect(headlessPersist, contains('rule.matches('));
    expect(headlessPersist, contains("caller: 'flow_save_rules_headless'"));
    expect(headlessPersist, contains('flowLocalId: savedId'));
    expect(headlessPersist, contains('_fileHeadlessEventDelivery('));
    expect(headlessPersist, contains('clientEventIds.add(cid)'));
    expect(headlessPersist, contains('firstClientEventId ??='));
  });

  test(
    'long shared-calendar labels are constrained in event detail actions',
    () {
      final dayViewSource = File(
        'lib/features/calendar/day_view.dart',
      ).readAsStringSync();
      final actionRow = _sourceBetween(
        dayViewSource,
        'Widget _buildEventDetailBottomActionRow(',
        '@override\n  Widget build(BuildContext context)',
      );

      expect(actionRow, contains('Expanded('));
      expect(actionRow, contains('maxLines: 1'));
      expect(actionRow, contains('overflow: TextOverflow.ellipsis'));
      expect(actionRow, contains('textAlign: TextAlign.right'));
    },
  );

  test('shared practice opens the selected event date', () {
    final dayViewSource = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();
    final routeSource = File('lib/main.dart').readAsStringSync();
    final roomSource = File(
      'lib/features/shared_practice/shared_practice_room_page.dart',
    ).readAsStringSync();

    expect(dayViewSource, contains('required this.localDate'));
    expect(dayViewSource, contains('required this.onOpenRoute'));
    expect(dayViewSource, contains("'date': _sharedPracticeDate(localDate)"));
    expect(dayViewSource, contains('onPressed: () => onOpenRoute(route)'));
    expect(dayViewSource, contains('void _openSharedPracticeRoute'));
    expect(dayViewSource, contains('hostContext.push(route)'));
    expect(dayViewSource, contains('localDate: DateUtils.dateOnly('));
    expect(
      dayViewSource,
      contains(
        'onOpenRoute: (route) => _openSharedPracticeRoute(route, context)',
      ),
    );
    expect(routeSource, contains('DateTime? _parseLocalDateQuery'));
    expect(routeSource, contains('initialLocalDate: _parseLocalDateQuery'));
    expect(roomSource, contains('this.initialLocalDate'));
    expect(roomSource, contains('localDate: _localDate'));
    expect(roomSource, isNot(contains('localDate: DateTime.now()')));
  });
}

String _sourceBetween(String source, String startNeedle, String endNeedle) {
  final start = source.indexOf(startNeedle);
  expect(start, isNonNegative, reason: 'Missing start marker: $startNeedle');
  final end = source.indexOf(endNeedle, start + startNeedle.length);
  expect(end, isNonNegative, reason: 'Missing end marker: $endNeedle');
  return source.substring(start, end);
}
