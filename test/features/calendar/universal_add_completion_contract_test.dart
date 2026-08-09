import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/staged_flow_lifecycle.dart';

void main() {
  group('universal add completion policy', () {
    test('first calendar add completes independently of database identity', () {
      expect(
        shouldCompleteStagedFlowAdd(
          hasSavedFlow: true,
          completionRequired: true,
          hasPlannedNotes: true,
        ),
        isTrue,
      );
    });

    test('edits and empty results do not request Day View completion', () {
      expect(
        shouldCompleteStagedFlowAdd(
          hasSavedFlow: true,
          completionRequired: false,
          hasPlannedNotes: true,
        ),
        isFalse,
      );
      expect(
        shouldCompleteStagedFlowAdd(
          hasSavedFlow: true,
          completionRequired: true,
          hasPlannedNotes: false,
        ),
        isFalse,
      );
    });
  });

  group('universal import materialization', () {
    test('saved and shared rule imports produce equivalent planned writes', () {
      final rule = CalendarPage.ruleFromJson(<String, dynamic>{
        'type': 'week',
        'weekdays': <int>[1],
        'allDay': false,
        'startHour': 6,
        'startMinute': 30,
        'endHour': 7,
        'endMinute': 15,
      });
      final start = DateTime(2026, 8, 10);
      final end = DateTime(2026, 8, 24);

      final saved = materializeFlowRuleWrites(
        flowId: 42,
        rules: <FlowRule>[rule],
        startDate: start,
        endDate: end,
        title: 'Rule flow',
        notes: 'A rule-backed import',
        calendarId: 'calendar-1',
        calendarName: 'Personal',
        manualColor: const Color(0xFF4DD0E1),
        caller: 'saved_flow_import_rules',
        alertDebugLabel: 'savedFlowImportRules',
      );
      final shared = materializeFlowRuleWrites(
        flowId: 42,
        rules: <FlowRule>[rule],
        startDate: start,
        endDate: end,
        title: 'Rule flow',
        notes: 'A rule-backed import',
        calendarId: 'calendar-1',
        calendarName: 'Personal',
        manualColor: const Color(0xFF4DD0E1),
        caller: 'shared_flow_import_rules',
        alertDebugLabel: 'sharedFlowImportRules',
      );

      expect(saved, hasLength(3));
      expect(shared, hasLength(saved.length));
      for (var i = 0; i < saved.length; i++) {
        expect(shared[i].clientEventId, saved[i].clientEventId);
        expect(shared[i].title, saved[i].title);
        expect(shared[i].startsAtLocal, saved[i].startsAtLocal);
        expect(shared[i].endsAtLocal, saved[i].endsAtLocal);
        expect(shared[i].detail, saved[i].detail);
        expect(shared[i].calendarId, saved[i].calendarId);
        expect(shared[i].flowId, saved[i].flowId);
      }
    });

    test('rule materialization preserves the inclusive 90-day horizon', () {
      final daily = CalendarPage.ruleFromJson(<String, dynamic>{
        'type': 'week',
        'weekdays': <int>[1, 2, 3, 4, 5, 6, 7],
        'allDay': true,
      });
      final writes = materializeFlowRuleWrites(
        flowId: 7,
        rules: <FlowRule>[daily],
        startDate: DateTime(2026, 8, 9),
        title: 'Daily rule',
        caller: 'test',
        alertDebugLabel: 'test',
      );

      expect(writes, hasLength(91));
      expect(writes.last.startsAtLocal, DateTime(2026, 11, 7, 9));
      expect(writes.map((write) => write.clientEventId).toSet(), hasLength(91));
    });

    test('snapshot materialization preserves event behavior and ordering', () {
      final writes = materializeFlowSnapshotWrites(
        flowId: 88,
        events: <dynamic>[
          <String, dynamic>{
            'offset_days': 0,
            'title': 'First block',
            'all_day': false,
            'start_time': '06:00',
            'end_time': '06:45',
            'action_id': 'reflect',
            'behavior_payload': <String, dynamic>{'prompt': 'Begin'},
          },
          <String, dynamic>{
            'offset_days': 2,
            'title': 'Third-day block',
            'all_day': true,
          },
        ],
        startDate: DateTime(2026, 8, 9),
        fallbackTitle: 'Shared flow',
        calendarId: 'calendar-1',
        caller: 'shared_flow_import_snapshot',
        alertDebugLabel: 'sharedFlowImportSnapshot',
      );

      expect(writes, hasLength(2));
      expect(writes.first.startsAtLocal, DateTime(2026, 8, 9, 6));
      expect(writes.first.endsAtLocal, DateTime(2026, 8, 9, 6, 45));
      expect(writes.first.actionId, 'reflect');
      expect(writes.first.behaviorPayload, <String, dynamic>{
        'prompt': 'Begin',
      });
      expect(writes.last.startsAtLocal, DateTime(2026, 8, 11, 9));
      expect(writes.last.allDay, isTrue);
    });
  });
}
