import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_weighing_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('defines nine canonical sittings on the correct flow days', () {
    expect(kTheWeighingEvents, hasLength(9));
    expect(kTheWeighingEvents.map((event) => event.flowDay).toList(), <int>[
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
    expect(kTheWeighingEvents.last.sharePromptOnComplete, isTrue);
  });

  test('schedules morning, midday, and evening slots in local time', () {
    final startDate = DateTime(2026, 6, 1);
    final morning = theWeighingScheduleForDate(
      kTheWeighingEvents[0],
      startDate,
      TrackSkyTimeZone.pacific,
    );
    final midday = theWeighingScheduleForDate(
      kTheWeighingEvents[1],
      startDate.add(const Duration(days: 4)),
      TrackSkyTimeZone.pacific,
    );
    final evening = theWeighingScheduleForDate(
      kTheWeighingEvents[2],
      startDate.add(const Duration(days: 8)),
      TrackSkyTimeZone.pacific,
    );

    expect(morning.startLocal.hour, inInclusiveRange(3, 6));
    expect(morning.scheduleType, 'local_astronomical_dawn_plus_30_minutes');
    expect(midday.startLocal.hour, 11);
    expect(midday.startLocal.minute, 0);
    expect(midday.scheduleType, 'fixed_local_midday');
    expect(evening.startLocal.hour, inInclusiveRange(19, 21));
    expect(evening.scheduleType, 'local_sunset_plus_30_minutes');
  });

  test('builds JSON-safe behavior payloads and action ids', () {
    final startDate = DateTime(2026, 6, 1);
    final ids = <String>{};

    for (final event in kTheWeighingEvents) {
      final schedule = theWeighingScheduleForDate(
        event,
        startDate.add(Duration(days: event.flowDay - 1)),
        TrackSkyTimeZone.eastern,
      );
      final payload = theWeighingBehaviorPayload(
        event: event,
        schedule: schedule,
        lens: TheWeighingLens.djehuty,
      );

      expect(jsonDecode(jsonEncode(payload)), isA<Map<String, dynamic>>());
      expect(payload['kind'], 'maat_the_weighing_event');
      expect(payload['flow_key'], 'the-weighing');
      expect(payload['missed_event_rule'], 'expire_quietly');
      ids.add(theWeighingActionId(event));
    }

    expect(ids, hasLength(9));
    expect(ids.first, 'the-weighing-event-01');
    expect(ids.last, 'the-weighing-event-09');
  });

  test('detail text contains spoken line, steps, optional, and source', () {
    final event = kTheWeighingEvents.first;
    final detail = theWeighingDetailText(event, lens: TheWeighingLens.djehuty);

    expect(detail, contains('Purpose\n'));
    expect(detail, contains('Words\n"${event.spokenLine}"'));
    expect(detail, contains('Steps\n1. Write down one number'));
    expect(detail, contains('Optional\n- Place a cup of water'));
    expect(detail, contains('Lens\nLet Djehuty'));
    expect(detail, contains('Source\n'));
  });

  test('canonical detail rebuilds a stored weighing event', () {
    final detail = canonicalTheWeighingDetailTextForEvent(
      flowName: kTheWeighingTitle,
      flowNotes: 'mode=gregorian;maat=the-weighing;weighing_lens=djehuty',
      title: 'Weighing 1: Open the Material Ledger',
      actionId: 'the-weighing-event-01',
      behaviorPayload: const <String, dynamic>{
        'kind': 'maat_the_weighing_event',
        'flow_key': 'the-weighing',
        'event_number': 1,
      },
    );

    expect(detail, isNotNull);
    expect(detail, contains('I open my record'));
    expect(detail, contains('Lens\nLet Djehuty'));
  });

  test('calendar join branch creates nine events without placeholders', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final methodStart = source.indexOf('Future<int> _addMaatFlowInstance({');
    expect(methodStart, isNonNegative);
    final branchStart = source.indexOf(
      'if (template.kind == _MaatFlowTemplateKind.theWeighing)',
      methodStart,
    );
    expect(branchStart, isNonNegative);
    final branchEnd = source.indexOf('if (startDate == null)', branchStart);
    expect(branchEnd, isNonNegative);
    final branch = source.substring(branchStart, branchEnd);

    expect(branch, contains('kTheWeighingEvents'));
    expect(branch, contains('await repo.upsertByClientId'));
    expect(branch, isNot(contains('Future.microtask')));
    expect(branch, contains('repo.deleteFlow(serverFlowId)'));
    expect(branch, contains('firstG.add(const Duration(days: 29))'));
  });
}
