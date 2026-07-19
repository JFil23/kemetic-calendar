import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/evening_threshold_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('default start date advances after the threshold time has passed', () {
    final beforeThreshold = defaultEveningThresholdStartDate(
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 6, 2, 1),
    );
    final afterThreshold = defaultEveningThresholdStartDate(
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 6, 2, 3),
    );

    expect(beforeThreshold, DateTime(2026, 6, 1));
    expect(afterThreshold, DateTime(2026, 6, 2));
  });

  test('daily schedule places the carry event the next morning', () {
    final first = dailyEveningThresholdScheduleForDate(
      localDate: DateTime(2026, 6, 1),
      timezone: TrackSkyTimeZone.eastern,
      event: kEveningThresholdEvents.first,
    );
    final second = dailyEveningThresholdScheduleForDate(
      localDate: DateTime(2026, 6, 1),
      timezone: TrackSkyTimeZone.eastern,
      event: kEveningThresholdEvents.last,
    );

    expect(first.startLocal.hour, 19);
    expect(first.startLocal.minute, 0);
    expect(second.startLocal, DateTime(2026, 6, 2, 7));
    expect(
      second.endUtc.difference(second.startUtc),
      const Duration(minutes: 1),
    );
    expect(second.orientationLocalDate, DateTime(2026, 6, 2));
    expect(second.previousOrientationLocalDate, DateTime(2026, 6, 1));
  });

  test('return event keeps spoken line speakable and reading in delivery', () {
    final event = kEveningThresholdEvents.first;
    final detail = eveningThresholdDetailText(event);

    expect(event.spokenLine, 'This was what I named. This is what I met.');
    expect(
      event.deliveryBeat,
      startsWith('Read your morning return aloud or silently.'),
    );
    expect(
      detail,
      contains('Spoken line\n"This was what I named. This is what I met."'),
    );
    expect(detail, isNot(contains('Spoken line\n"Read your morning return')));
  });

  test('return and carry payloads preserve exact threshold choices', () {
    final schedule = dailyEveningThresholdScheduleForDate(
      localDate: DateTime(2026, 6, 1),
      timezone: TrackSkyTimeZone.central,
      event: kEveningThresholdEvents.first,
    );
    final returnPayload = eveningThresholdBehaviorPayload(
      event: kEveningThresholdEvents.first,
      schedule: schedule,
    );
    final carryPayload = eveningThresholdBehaviorPayload(
      event: kEveningThresholdEvents.last,
      schedule: dailyEveningThresholdScheduleForDate(
        localDate: DateTime(2026, 6, 1),
        timezone: TrackSkyTimeZone.central,
        event: kEveningThresholdEvents.last,
      ),
    );

    expect(jsonDecode(jsonEncode(returnPayload)), isA<Map<String, dynamic>>());
    expect(returnPayload['flow_key'], kEveningThresholdFlowKey);
    expect(returnPayload['linked_to'], 'daily_orientation.chosen_return');
    expect(
      returnPayload['carryover_field'],
      'daily_orientation.carryover_choice',
    );
    expect(returnPayload['landing_field'], 'daily_orientation.landing_status');
    expect(returnPayload['completion_options'], <String>[
      'held',
      'slipped',
      'working',
    ]);
    expect(returnPayload['completion_status_labels'], {
      'held': 'I held it.',
      'slipped': 'I slipped.',
      'working': 'I\'m still working on it.',
    });
    expect(carryPayload['completion_options'], <String>[
      'carry_forward',
      'release',
    ]);
    expect(
      carryPayload['schedule'],
      containsPair('type', 'morning_after_landing'),
    );
    expect(carryPayload['previous_orientation_local_date'], '2026-06-01');
    expect(carryPayload['orientation_local_date'], '2026-06-02');
    expect(carryPayload['decision_table'], 'evening_threshold_decisions');
    expect(carryPayload['journal_entry_required'], isFalse);
  });

  test('headless join materializes two threshold events per day', () async {
    final flowCalls = <Map<String, dynamic>>[];
    final eventCalls = <Map<String, dynamic>>[];
    final carryCalls = <Map<String, dynamic>>[];
    final service = FlowJoinService(
      upsertFlow:
          ({
            int? id,
            required String name,
            required int color,
            required bool active,
            String? calendarId,
            DateTime? startDate,
            DateTime? endDate,
            String? notes,
            required String rules,
            String? originType,
          }) async {
            flowCalls.add(<String, dynamic>{
              'name': name,
              'notes': notes,
              'rules': jsonDecode(rules),
              'startDate': startDate,
              'endDate': endDate,
              'originType': originType,
            });
            return 42;
          },
      upsertEvent:
          ({
            required String clientEventId,
            required String title,
            required DateTime startsAtUtc,
            String? detail,
            bool allDay = false,
            DateTime? endsAtUtc,
            int? flowLocalId,
            String? category,
            String? actionId,
            Map<String, dynamic>? behaviorPayload,
            String? calendarId,
            String? caller,
          }) async {
            eventCalls.add(<String, dynamic>{
              'clientEventId': clientEventId,
              'title': title,
              'startsAtUtc': startsAtUtc,
              'flowLocalId': flowLocalId,
              'actionId': actionId,
              'behaviorPayload': behaviorPayload,
              'caller': caller,
            });
          },
      publishHeadlessCalendarInvalidation:
          ({
            required CalendarInvalidationReason reason,
            required int flowId,
            required List<String> clientEventIds,
          }) {},
      persistEveningThresholdInitialCarry:
          ({required DateTime localDate, required String carryText}) async {
            carryCalls.add(<String, dynamic>{
              'localDate': localDate,
              'carryText': carryText,
            });
          },
    );

    final result = await service.joinEveningThresholdHeadless(
      templateKey: kEveningThresholdFlowKey,
      templateTitle: kEveningThresholdTitle,
      templateOverview: kEveningThresholdOverview,
      templateColor: const Color(0xFFC2673F),
      personalCalendarId: 'personal',
      timezone: TrackSkyTimeZone.pacific,
      startDate: DateTime(2026, 6, 1),
      materializedDays: 2,
      initialCarryText: 'Patience with my mother',
    );

    expect(result.succeeded, isTrue);
    expect(result.flowId, 42);
    expect(flowCalls.single['notes'], contains('maat=evening_threshold'));
    expect(flowCalls.single['notes'], contains('materialized_days=2'));
    expect(
      flowCalls.single['notes'],
      isNot(contains('Patience with my mother')),
    );
    expect(carryCalls, hasLength(1));
    expect(carryCalls.single['localDate'], DateTime(2026, 6, 1));
    expect(carryCalls.single['carryText'], 'Patience with my mother');
    expect(
      flowCalls.single['notes'],
      contains('evening_threshold_morning_default=420'),
    );
    expect(eventCalls, hasLength(4));
    expect(eventCalls[0]['title'], 'How did it land?');
    expect(eventCalls[1]['title'], 'What crosses with you?');
    expect(eventCalls[2]['title'], 'How did it land?');
    expect(eventCalls[3]['title'], 'What crosses with you?');
    expect(eventCalls[0]['actionId'], 'evening-threshold-event-01');
    expect(eventCalls[1]['actionId'], 'evening-threshold-event-02');
    expect(
      eventCalls[1]['behaviorPayload'],
      containsPair('event_key', 'carry'),
    );
    expect(
      eventCalls[1]['behaviorPayload'],
      containsPair('previous_orientation_local_date', '2026-06-01'),
    );
    expect(
      eventCalls[1]['behaviorPayload'],
      containsPair('orientation_local_date', '2026-06-02'),
    );
  });
}
