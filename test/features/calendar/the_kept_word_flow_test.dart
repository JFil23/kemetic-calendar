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
    'detail text stays action-focused without source or private-storage copy',
    () {
      final event = kKeptWordEvents.first;
      final detail = keptWordDetailText(event, lens: KeptWordLens.maat);

      expect(detail, contains('Purpose\n'));
      expect(detail, contains('Words\n"${event.spokenLine}"'));
      expect(detail, isNot(contains('Private note:')));
      expect(detail, isNot(contains('Source\n')));
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

  test('copy keeps conversation guardrails and safety branches clear', () {
    final event2 = keptWordEventByNumber(2)!;
    final event3 = keptWordEventByNumber(3)!;
    final event4 = keptWordEventByNumber(4)!;
    final event5 = keptWordEventByNumber(5)!;
    final event6 = keptWordEventByNumber(6)!;
    final event7 = keptWordEventByNumber(7)!;
    final event8 = keptWordEventByNumber(8)!;
    final event9 = keptWordEventByNumber(9)!;

    expect(event2.steps, <String>[
      'Name one shared rhythm that used to hold the household or relationship together and has drifted or stopped.',
      'Name who was affected by the rhythm stopping.',
      'Write one sentence about whether anyone has named the change directly.',
    ]);
    expect(
      keptWordDetailText(event2, lens: KeptWordLens.neutral),
      contains('small regular pattern'),
    );

    expect(
      event3.steps,
      contains(
        'Choose one agreement or shared rhythm to address first in the next ten-day section.',
      ),
    );
    expect(
      event3.optionalSteps,
      contains(
        'Before this ten-day section closes, tell the person involved that you want a clear conversation about one thing in the next ten days.',
      ),
    );

    expect(event4.steps, <String>[
      'Write the specific fact: We agreed to X. What has been happening is Y. I want to understand the gap.',
      'Keep the message that short.',
      'Choose the least escalating medium that still counts as direct: spoken conversation, voice message, text, or written note.',
      'Send or schedule the message before marking this event prepared.',
    ]);
    expect(
      event4.optionalSteps,
      contains(
        'If the conversation is not safe or possible, pause the flow locally and seek appropriate support.',
      ),
    );
    expect(
      event4.steps.join(' '),
      isNot(contains('started editing the truth')),
    );
    expect(
      keptWordDetailText(event4, lens: KeptWordLens.neutral),
      contains('A longer message can start editing the truth'),
    );

    expect(event5.steps, <String>[
      'If the conversation happened, write three private sentences: what I said, what they said, and what was agreed.',
      'If it has not happened and can happen safely, mark conversation pending.',
      'If it has not happened and can happen safely, schedule it before this ten-day section closes.',
      'If no conversation can happen safely, keep the flow paused locally rather than forcing contact.',
      'Name one thing that surprised you, if anything did.',
    ]);
    expect(event5.optionalSteps, isEmpty);
    expect(event5.requiresConversation, isTrue);

    expect(event6.steps, <String>[
      'Name the current status of the break: resolved, in process, or named but unresolved.',
      'If it remains unresolved, write the next concrete step as an agreement.',
      'Name who does what by when.',
      'Name one accurate thing the other person said that you had been holding differently.',
    ]);

    expect(event7.steps, contains('Read the written agreement aloud.'));
    expect(
      keptWordDetailText(event7, lens: KeptWordLens.neutral),
      contains('Reading it aloud makes the word operative'),
    );

    expect(
      event8.steps,
      contains(
        'If the weight has shifted, name the small correction before the closing sitting.',
      ),
    );
    expect(event8.optionalSteps, isEmpty);
    expect(
      keptWordDetailText(event8, lens: KeptWordLens.neutral),
      contains('Healthy agreements need small adjustments as they settle'),
    );

    expect(event9.steps, <String>[
      'Return to your Day 1 inventory.',
      'Speak only the current status that is true: kept, repaired, in process, or still broken.',
      'For the shared rhythm named in the first ten-day section, name whether it returned.',
      'Name what made it possible or what remains in the way.',
      'Write one line that is now true that was not true at the start of this flow.',
    ]);
    expect(
      event9.optionalSteps,
      contains(
        'If you share, share only the generic closing line. Do not share names, agreements, or conversation content.',
      ),
    );
    expect(event9.sharePromptOnComplete, isTrue);
  });

  test('words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];

    for (final event in kKeptWordEvents) {
      for (final pattern in _keptWordWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add('Event ${event.eventNumber} ${event.title}');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('steps keep rationale and source-note phrases out of actions', () {
    final issues = <String>[];

    for (final event in kKeptWordEvents) {
      for (final step in event.steps) {
        if (_keptWordRationaleOrSourcePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
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

final _keptWordWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*write\b', caseSensitive: false),
  RegExp(r'^\s*before\b', caseSensitive: false),
  RegExp(r'^\s*if\b', caseSensitive: false),
  RegExp(r'\boptional\b', caseSensitive: false),
  RegExp(r'\bdo not share\b', caseSensitive: false),
];

final _keptWordRationaleOrSourcePattern = RegExp(
  r'\b(Merikare|Ptahhotep|Eloquent Peasant|Blinding of Truth|because|started editing the truth|more present than the written one|Healthy agreements)\b',
  caseSensitive: false,
);
