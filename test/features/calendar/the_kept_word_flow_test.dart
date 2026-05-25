import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_kept_word_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('defines nine canonical kept word sittings on the correct days', () {
    expect(kKeptWordEvents, hasLength(9));
    expect(kKeptWordEvents.map((event) => event.flowDay).toList(), <int>[
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
    expect(kKeptWordEvents.first.localPrompt.key, 'agreement_inventory');
    expect(kKeptWordEvents[4].eventNumber, 5);
    expect(kKeptWordEvents[4].requiresConversation, isTrue);
    expect(kKeptWordEvents.last.sharePromptOnComplete, isTrue);
  });

  test('schedules morning, midday, and evening slots in local time', () {
    final startDate = DateTime(2026, 6, 1);
    final morning = keptWordScheduleForDate(
      kKeptWordEvents[0],
      startDate,
      TrackSkyTimeZone.pacific,
    );
    final midday = keptWordScheduleForDate(
      kKeptWordEvents[1],
      startDate.add(const Duration(days: 4)),
      TrackSkyTimeZone.pacific,
    );
    final evening = keptWordScheduleForDate(
      kKeptWordEvents[2],
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

  test('builds JSON-safe payloads with conversation pending on event five', () {
    final startDate = DateTime(2026, 6, 1);
    final ids = <String>{};

    for (final event in kKeptWordEvents) {
      final schedule = keptWordScheduleForDate(
        event,
        startDate.add(Duration(days: event.flowDay - 1)),
        TrackSkyTimeZone.eastern,
      );
      final payload = keptWordBehaviorPayload(
        event: event,
        schedule: schedule,
        lens: KeptWordLens.djehuty,
      );

      final encoded = jsonEncode(payload);
      expect(jsonDecode(encoded), isA<Map<String, dynamic>>());
      expect(payload['kind'], 'maat_kept_word_event');
      expect(payload['flow_key'], 'the-kept-word');
      expect(payload['local_prompt'], event.localPrompt.key);
      expect(encoded, isNot(contains('Alex')));
      expect(encoded, isNot(contains('rent agreement')));
      if (event.eventNumber == 5) {
        expect(payload['completion_options'], contains('conversation_pending'));
      }
      ids.add(keptWordActionId(event));
    }

    expect(ids, hasLength(9));
    expect(ids.first, 'the-kept-word-event-01');
    expect(ids.last, 'the-kept-word-event-09');
  });

  test(
    'detail text contains privacy boundary and no private agreement data',
    () {
      final event = kKeptWordEvents.first;
      final detail = keptWordDetailText(event, lens: KeptWordLens.maat);

      expect(detail, contains('Purpose\n'));
      expect(detail, contains('Words\n"${event.spokenLine}"'));
      expect(
        detail,
        contains('Privacy\nYour household notes stay on this device.'),
      );
      expect(detail, contains('Lens\nLet Ma\'at'));
      expect(detail, isNot(contains('KeptWordAgreementEntry')));
    },
  );

  test('canonical detail rebuilds a stored kept word event', () {
    final detail = canonicalKeptWordDetailTextForEvent(
      flowName: kKeptWordTitle,
      flowNotes: 'mode=gregorian;maat=the-kept-word;kept_word_lens=djehuty',
      title: 'Kept Word 5: The Conversation: Confirm It Was Had',
      actionId: 'the-kept-word-event-05',
      behaviorPayload: const <String, dynamic>{
        'kind': 'maat_kept_word_event',
        'flow_key': 'the-kept-word',
        'event_number': 5,
      },
    );

    expect(detail, isNotNull);
    expect(detail, contains('The dispute between Truth and Falsehood'));
    expect(detail, contains('Conversation pending'));
    expect(detail, contains('Lens\nLet Djehuty'));
  });

  test('calendar join branch creates nine events without placeholders', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final methodStart = source.indexOf('Future<int> _addMaatFlowInstance({');
    expect(methodStart, isNonNegative);
    final branchStart = source.indexOf(
      'if (template.kind == _MaatFlowTemplateKind.keptWord)',
      methodStart,
    );
    expect(branchStart, isNonNegative);
    final branchEnd = source.indexOf('if (startDate == null)', branchStart);
    expect(branchEnd, isNonNegative);
    final branch = source.substring(branchStart, branchEnd);

    expect(branch, contains('kKeptWordEvents'));
    expect(branch, contains('await repo.upsertByClientId'));
    expect(branch, contains('repo.deleteFlow(serverFlowId)'));
    expect(branch, contains('firstG.add(const Duration(days: 29))'));
    expect(branch, isNot(contains('kDawnHouseRiteDays')));
  });
}
