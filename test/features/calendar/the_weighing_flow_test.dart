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

  test('detail text contains spoken line, steps, optional, and no source', () {
    final event = kTheWeighingEvents.first;
    final detail = theWeighingDetailText(event, lens: TheWeighingLens.djehuty);

    expect(detail, contains('Purpose\n'));
    expect(detail, contains('Words\n"${event.spokenLine}"'));
    expect(detail, contains('Steps\n1. Place a cup of water'));
    expect(
      detail,
      contains('4. Write one number you have not looked at directly'),
    );
    expect(detail, isNot(contains('Optional\n- Place a cup of water')));
    expect(detail, contains('Lens\nLet Djehuty'));
    expect(detail, isNot(contains('Privacy\n')));
    expect(detail, isNot(contains('Source\n')));
  });

  test('water promotion is primary for the specified reckoning events', () {
    final expectedWater = <int, List<String>>{
      1: <String>[
        'Place a cup of water on your surface before you begin.',
        'Keep the water there while you write.',
      ],
      4: <String>['Place water on your surface before sitting.'],
      9: <String>[
        'Place a cup of water on your surface.',
        'Let the water stand as the final offering.',
      ],
    };

    for (final entry in expectedWater.entries) {
      final event = kTheWeighingEvents.singleWhere(
        (event) => event.eventNumber == entry.key,
      );

      for (final waterStep in entry.value) {
        expect(event.steps, contains(waterStep));
        expect(event.optionalSteps, isNot(contains(waterStep)));
      }
    }
  });

  test('stage directions removed from words are preserved as steps', () {
    expect(
      kTheWeighingEvents[0].spokenLine,
      'I open my record without fear. What is here is what is true.',
    );
    expect(
      kTheWeighingEvents[0].steps,
      contains('Speak the line before opening any record.'),
    );
    expect(
      kTheWeighingEvents[3].spokenLine,
      'My tongue is the plummet. My heart is the weight. I do not utter falsehood, for I am a balance.',
    );
    expect(
      kTheWeighingEvents[3].steps,
      contains('Speak the line before writing anything.'),
    );
    expect(
      kTheWeighingEvents[6].spokenLine,
      'I have come before you, my lord, bringing Truth, having repelled for you falsehood.',
    );
    expect(
      kTheWeighingEvents[6].steps,
      containsAll(<String>[
        'Stand before reading the four lines.',
        'Speak the line before reading the four lines.',
      ]),
    );
    expect(
      kTheWeighingEvents[8].spokenLine,
      'I am pure. I am pure. I am pure. I am pure.',
    );
    expect(
      kTheWeighingEvents[8].steps,
      containsAll(<String>[
        'Speak only the truth-check lines you can speak honestly.',
        'Remain silent on any truth-check line that is not accurate.',
        'Speak the closing declaration after the truth-check lines.',
      ]),
    );
  });

  test('conditional guardrails stay before risky actions', () {
    expect(
      kTheWeighingEvents[4].steps[2],
      'Only if the gap can close with one clear message, send it before this ten-day section ends.',
    );
  });

  test('words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];

    for (final event in kTheWeighingEvents) {
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

    for (final event in kTheWeighingEvents) {
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

    for (final event in kTheWeighingEvents) {
      for (final step in event.steps) {
        if (_sourceNotePhrasePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('timing labels preserve anchors in plain language', () {
    expect(TheWeighingTimingSlot.openMorning.label, '30 minutes after dawn');
    expect(
      TheWeighingTimingSlot.checkMidday.label,
      'around 11 AM where you are',
    );
    expect(TheWeighingTimingSlot.sealEvening.label, '30 minutes after sunset');
    expect(
      theWeighingTimingLabel(kTheWeighingEvents[0]),
      'Day 1 · 30 minutes after dawn',
    );
    expect(
      theWeighingTimingLabel(kTheWeighingEvents[1]),
      'Day 5 · around 11 AM where you are',
    );
    expect(
      theWeighingTimingLabel(kTheWeighingEvents[2]),
      'Day 9 · 30 minutes after sunset',
    );
  });

  test('representative source note upgrade is stored', () {
    expect(
      kTheWeighingEvents.first.sourceNote,
      'The Kemite placed water first because the record must be witnessed before it can be weighed — not examined, not solved, but witnessed. What sustains you is named before anything else is counted.',
    );
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

final _wordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*speak this\b', caseSensitive: false),
  RegExp(r'^\s*before\b.*\bspeak this\b', caseSensitive: false),
  RegExp(
    r'\bbefore (opening|writing|reading|beginning)\b',
    caseSensitive: false,
  ),
  RegExp(r'\bthen\s*:', caseSensitive: false),
  RegExp(r'\btruth-check line', caseSensitive: false),
  RegExp(r'\bclosing declaration\b', caseSensitive: false),
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
