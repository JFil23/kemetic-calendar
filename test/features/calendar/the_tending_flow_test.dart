import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_tending_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('defines nine canonical tending sittings on the correct flow days', () {
    expect(kTheTendingEvents, hasLength(9));
    expect(kTheTendingEvents.map((event) => event.flowDay).toList(), <int>[
      1,
      5,
      9,
      11,
      15,
      19,
      21,
      25,
      29,
    ]);
    expect(kTheTendingEvents.first.localPrompt.key, 'care_inventory');
    expect(kTheTendingEvents.last.sharePromptOnComplete, isTrue);
  });

  test('schedules morning, midday, and evening slots in local time', () {
    final startDate = DateTime(2026, 6, 1);
    final morning = theTendingScheduleForDate(
      kTheTendingEvents[0],
      startDate,
      TrackSkyTimeZone.pacific,
    );
    final midday = theTendingScheduleForDate(
      kTheTendingEvents[1],
      startDate.add(const Duration(days: 4)),
      TrackSkyTimeZone.pacific,
    );
    final evening = theTendingScheduleForDate(
      kTheTendingEvents[2],
      startDate.add(const Duration(days: 8)),
      TrackSkyTimeZone.pacific,
    );

    expect(morning.scheduleType, 'local_astronomical_dawn_plus_30_minutes');
    expect(morning.startLocal.hour, inInclusiveRange(3, 6));
    expect(midday.startLocal.hour, 11);
    expect(midday.startLocal.minute, 0);
    expect(midday.scheduleType, 'fixed_local_midday');
    expect(evening.scheduleType, 'local_sunset_plus_30_minutes');
    expect(evening.startLocal.hour, inInclusiveRange(19, 21));
  });

  test(
    'builds JSON-safe behavior payloads and action ids without care names',
    () {
      final startDate = DateTime(2026, 6, 1);
      final ids = <String>{};

      for (final event in kTheTendingEvents) {
        final schedule = theTendingScheduleForDate(
          event,
          startDate.add(Duration(days: event.flowDay - 1)),
          TrackSkyTimeZone.eastern,
        );
        final payload = theTendingBehaviorPayload(
          event: event,
          schedule: schedule,
          lens: TheTendingLens.aset,
        );

        final encoded = jsonEncode(payload);
        expect(jsonDecode(encoded), isA<Map<String, dynamic>>());
        expect(payload['kind'], 'maat_the_tending_event');
        expect(payload['flow_key'], 'the-tending');
        expect(payload['missed_event_rule'], 'expire_quietly');
        expect(payload['local_prompt'], event.localPrompt.key);
        expect(encoded, isNot(contains('Name One')));
        expect(encoded, isNot(contains('medicine')));
        ids.add(theTendingActionId(event));
      }

      expect(ids, hasLength(9));
      expect(ids.first, 'the-tending-event-01');
      expect(ids.last, 'the-tending-event-09');
    },
  );

  test(
    'detail text keeps a private note without source sections or user care data',
    () {
      final event = kTheTendingEvents.first;
      final detail = theTendingDetailText(event, lens: TheTendingLens.heru);

      expect(detail, contains('Purpose\n'));
      expect(detail, contains('Words\n"${event.spokenLine}"'));
      expect(detail, contains('Steps\n1. Name who is in your care'));
      expect(detail, contains('Private note: keep names and care details'));
      expect(detail, isNot(contains('Source\n')));
      expect(detail, contains('Lens\nLet Heru'));
      expect(detail, isNot(contains('CareListEntry')));
    },
  );

  test('canonical detail rebuilds a stored tending event', () {
    final detail = canonicalTheTendingDetailTextForEvent(
      flowName: kTheTendingTitle,
      flowNotes: 'mode=gregorian;maat=the-tending;tending_lens=aset',
      title: 'Tending 1: The First Seeing',
      actionId: 'the-tending-event-01',
      behaviorPayload: const <String, dynamic>{
        'kind': 'maat_the_tending_event',
        'flow_key': 'the-tending',
        'event_number': 1,
      },
    );

    expect(detail, isNotNull);
    expect(detail, contains('I look for who is in my care'));
    expect(detail, contains('Lens\nLet Aset'));
  });

  test('calendar join branch creates nine events without placeholders', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final methodStart = source.indexOf('Future<int> _addMaatFlowInstance({');
    expect(methodStart, isNonNegative);
    final branchStart = source.indexOf(
      'if (template.kind == _MaatFlowTemplateKind.theTending)',
      methodStart,
    );
    expect(branchStart, isNonNegative);
    final branchEnd = source.indexOf('if (startDate == null)', branchStart);
    expect(branchEnd, isNonNegative);
    final branch = source.substring(branchStart, branchEnd);

    expect(branch, contains('kTheTendingEvents'));
    expect(branch, contains('await repo.upsertByClientId'));
    expect(branch, isNot(contains('Future.microtask')));
    expect(branch, contains('repo.deleteFlow(serverFlowId)'));
    expect(branch, contains('firstG.add(const Duration(days: 29))'));
  });
}
