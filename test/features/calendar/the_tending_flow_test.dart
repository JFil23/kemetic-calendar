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
    'detail text stays action-focused without source or private-storage copy',
    () {
      final event = kTheTendingEvents.first;
      final detail = theTendingDetailText(event, lens: TheTendingLens.heru);

      expect(detail, contains('Purpose\n'));
      expect(detail, contains('Words\n"${event.spokenLine}"'));
      expect(detail, contains('Steps\n1. Speak the line'));
      expect(detail, contains('2. Name who is in your care'));
      expect(detail, isNot(contains('Private note:')));
      expect(detail, isNot(contains('Source\n')));
      expect(detail, contains('Lens\nLet Heru'));
      expect(detail, isNot(contains('CareListEntry')));
    },
  );

  test('stage directions removed from words are preserved as steps', () {
    expect(
      kTheTendingEvents[0].spokenLine,
      'I look for who is in my care. I do not let need become invisible.',
    );
    expect(
      kTheTendingEvents[0].steps,
      contains('Speak the line before writing anything.'),
    );

    expect(
      kTheTendingEvents[8].spokenLine,
      'I have not turned away from those placed in my care.',
    );
    expect(
      kTheTendingEvents[8].steps,
      containsAll(<String>[
        'Speak the line once before writing any closing line.',
        'Check whether the line is true.',
      ]),
    );
  });

  test('specific tending copy guardrails stay explicit', () {
    expect(kTheTendingEvents[4].steps.take(2).toList(), <String>[
      'Do one small tending act now.',
      'If you cannot do it now, name the exact time it will happen today.',
    ]);
    expect(
      kTheTendingEvents[7].steps,
      containsAll(<String>[
        'Write what moved.',
        'Write what did not move.',
        'Write what still belongs to you.',
        'If the repair is blocked by another person, write what remains yours.',
        'Release what is not yours to repair.',
      ]),
    );
    expect(kTheTendingEvents[7].optionalSteps, isEmpty);
    expect(
      kTheTendingEvents[8].optionalSteps,
      contains(
        'If you share, share only the generic restoration line. Do not share names or care-list details.',
      ),
    );
  });

  test('words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];

    for (final event in kTheTendingEvents) {
      for (final pattern in _wordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('optional steps do not duplicate required steps', () {
    final duplicates = <String>[];

    for (final event in kTheTendingEvents) {
      final required = event.steps.map(_normalizedCopyStep).toSet();
      for (final optional in event.optionalSteps) {
        if (required.contains(_normalizedCopyStep(optional))) {
          duplicates.add('Event ${event.eventNumber}: $optional');
        }
      }
    }

    expect(duplicates, isEmpty);
  });

  test('steps avoid source-note explanation phrases', () {
    final issues = <String>[];

    for (final event in kTheTendingEvents) {
      for (final step in event.steps) {
        if (_sourceNotePhrasePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('timing labels preserve anchors in plain language', () {
    expect(TheTendingTimingSlot.openMorning.label, '30 minutes after dawn');
    expect(
      TheTendingTimingSlot.checkMidday.label,
      'around 11 AM where you are',
    );
    expect(TheTendingTimingSlot.sealEvening.label, '30 minutes after sunset');
    expect(
      theTendingTimingLabel(kTheTendingEvents[0]),
      'Day 1 · 30 minutes after dawn',
    );
    expect(
      theTendingTimingLabel(kTheTendingEvents[1]),
      'Day 5 · around 11 AM where you are',
    );
    expect(
      theTendingTimingLabel(kTheTendingEvents[2]),
      'Day 9 · 30 minutes after sunset',
    );
  });

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

final _wordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*before\b', caseSensitive: false),
  RegExp(r'\bbefore writing\b', caseSensitive: false),
  RegExp(r'\bspeak it once\b', caseSensitive: false),
  RegExp(r'\bthen check\b', caseSensitive: false),
];

final _sourceNotePhrasePattern = RegExp(
  r'\b(in Kemetic|the Kemite|Pyramid Texts|Amenemope|Spell 125|source|because)\b',
  caseSensitive: false,
);

String _normalizedCopyStep(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
