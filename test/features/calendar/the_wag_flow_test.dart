import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_wag_enrollment.dart';
import 'package:mobile/features/calendar/the_wag_flow.dart';
import 'package:mobile/features/calendar/the_wag_scheduler.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

void main() {
  test('defines nine annual Wag events on fixed Kemetic Month 1 days', () {
    expect(kWagEvents, hasLength(9));
    expect(kWagEvents.map((event) => event.kemeticDay).toList(), <int>[
      1,
      5,
      9,
      11,
      17,
      18,
      21,
      25,
      29,
    ]);
    expect(kWagEvents[4].schedule, WagScheduleKind.solarDusk);
    expect(kWagEvents[5].schedule, WagScheduleKind.feastMorning);
    expect(kWagEvents.last.sharePromptOnComplete, isTrue);
  });

  test('maps M1 D18 through KemeticMath for the enrolled kYear', () {
    final gregorian = wagEventGregorian(2, 18);
    final kemetic = KemeticMath.fromGregorian(gregorian);

    expect(kemetic.kYear, 2);
    expect(kemetic.kMonth, 1);
    expect(kemetic.kDay, 18);
  });

  test('schedules D17 vigil at dusk and D18 feast in the morning', () {
    final vigil = wagScheduleForEvent(
      event: kWagEvents[4],
      kYear: 2,
      timezone: TrackSkyTimeZone.pacific,
    );
    final feast = wagScheduleForEvent(
      event: kWagEvents[5],
      kYear: 2,
      timezone: TrackSkyTimeZone.pacific,
    );

    expect(vigil.scheduleType, 'local_dusk');
    expect(vigil.startLocal.hour, inInclusiveRange(17, 21));
    expect(vigil.startLocal.hour, isNot(11));
    expect(feast.scheduleType, 'fixed_local_feast_morning');
    expect(feast.startLocal.hour, 9);
  });

  test('Wep Ronpet picker rows are valid before their 48h window opens', () {
    final window = wagNextEnrollmentWindow(
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 5, 23, 18),
    );

    expect(window.closesAtLocal.difference(window.opensAtLocal).inHours, 48);
    expect(
      wagEnrollmentIsOpen(window, now: DateTime.utc(2026, 5, 23, 18)),
      isFalse,
    );
    expect(
      wagEnrollmentWindowForStartDate(
        DateTime(
          window.opensAtLocal.year,
          window.opensAtLocal.month,
          window.opensAtLocal.day,
        ),
        TrackSkyTimeZone.pacific,
        now: DateTime.utc(2026, 5, 23, 18),
      )?.kYear,
      window.kYear,
    );
  });

  test(
    'safe enrollment resolver returns null for unavailable selected dates',
    () {
      final window = resolveWagEnrollmentWindowSafely(
        timezone: TrackSkyTimeZone.pacific,
        startDate: DateTime(2099, 1, 1),
        now: DateTime.utc(2026, 5, 23, 18),
      );

      expect(window, isNull);
    },
  );

  test('payloads are JSON-safe and Event 6 supports names_spoken', () {
    final event = kWagEvents[5];
    final schedule = wagScheduleForEvent(
      event: event,
      kYear: 2,
      timezone: TrackSkyTimeZone.eastern,
    );
    final payload = wagBehaviorPayload(
      event: event,
      kYear: 2,
      timezoneKey: TrackSkyTimeZone.eastern.key,
      ianaTimezone: TrackSkyTimeZone.eastern.ianaName,
      scheduleType: schedule.scheduleType,
      referenceLocationName: schedule.referenceLocationName,
      usedFallback: schedule.usedFallback,
      lens: WagLens.ausar,
      variant: wagCopyVariantForEvent(event: event, kYear: 2),
    );

    expect(jsonDecode(jsonEncode(payload)), isA<Map<String, dynamic>>());
    expect(payload['kind'], 'maat_wag_event');
    expect(payload['flow_key'], 'the-wag');
    expect(payload['completion_options'], contains('names_spoken'));
    expect(payload.toString(), isNot(contains('grandmother')));
  });

  test(
    'detail text names offerings, lens, next Wag, and no disclaimer copy',
    () {
      final event = kWagEvents.last;
      final detail = wagDetailText(
        event,
        lens: WagLens.anpu,
        nextWagDate: wagNextFeastGregorian(2),
      );

      expect(detail, isNot(contains('Confidence\n')));
      expect(detail, isNot(contains('Private note:')));
      expect(detail, isNot(contains('Source\n')));
      expect(detail, isNot(contains('stay on this device')));
      expect(detail, contains('Water first'));
      expect(detail, contains('Lens\nLet Anpu'));
      expect(detail, contains('Next Wag\n'));
    },
  );

  test('table water instruction is primary and source note is upgraded', () {
    final table = kWagEvents.singleWhere((event) => event.eventNumber == 3);
    const waterText = 'Set water before you read any names.';

    expect(table.steps.first, waterText);
    expect(table.optionalSteps, isNot(contains(waterText)));
    expect(
      kWagEvents.first.sourceNote,
      'The Kemite understood the ren — the name — as a constituent part of the person, as real as the body. A name not spoken eventually becomes as if it never existed. This sitting is not commemorative — it is active. Speaking the name continues what the name holds.',
    );
  });

  test('Wag copy preserves offering, reversion, and truth-check order', () {
    final event1 = kWagEvents.singleWhere((event) => event.eventNumber == 1);
    final event2 = kWagEvents.singleWhere((event) => event.eventNumber == 2);
    final event3 = kWagEvents.singleWhere((event) => event.eventNumber == 3);
    final event5 = kWagEvents.singleWhere((event) => event.eventNumber == 5);
    final event6 = kWagEvents.singleWhere((event) => event.eventNumber == 6);
    final event7 = kWagEvents.singleWhere((event) => event.eventNumber == 7);
    final event8 = kWagEvents.singleWhere((event) => event.eventNumber == 8);
    final event9 = kWagEvents.singleWhere((event) => event.eventNumber == 9);

    expect(event1.steps, contains('Read each name aloud once.'));
    expect(event1.steps, contains('Do not read silently for this rite.'));
    expect(event1.steps.join(' '), isNot(contains('name doing its work')));

    expect(
      event2.steps.last,
      'Place water on the surface while you add to the list.',
    );
    expect(_wagPurposeText(event2), contains('water is already present'));

    expect(event3.steps, <String>[
      'Set water before you read any names.',
      'Read the complete list of names aloud.',
      'After each name, say: I speak your name. You live.',
    ]);
    expect(_wagPurposeText(event3), contains('Water is the first provision'));

    expect(event5.kemeticDay, 17);
    expect(event5.schedule, WagScheduleKind.solarDusk);
    expect(event5.steps, <String>[
      'Go to the surface prepared on Day 11.',
      'Place water, bread or food, and anything fragrant there now.',
      'Read the complete list of names aloud at dusk.',
      'Do not hurry the reading.',
      'Leave the offerings on the surface through the night.',
    ]);
    expect(_wagPurposeText(event5), contains('call the dead to the table'));

    expect(event6.kemeticDay, 18);
    expect(event6.schedule, WagScheduleKind.feastMorning);
    expect(event6.steps, <String>[
      'Return to the prepared surface.',
      'Add fresh water.',
      'Read the complete list of names slowly.',
      'After each name, speak: [Name] - this bread is yours. This water is yours. You live.',
      'Sit with memory before eating.',
      'Eat the bread and drink the water as reversion.',
    ]);
    expect(
      event6.steps.where((step) => step.contains('Sit with memory')),
      hasLength(1),
    );
    expect(
      event6.steps.where((step) => step.contains('reversion')),
      hasLength(1),
    );
    expect(_wagPurposeText(event6), contains('The reversion is not rushed'));

    expect(event7.steps.last, 'Drink water.');
    expect(
      _wagPurposeText(event7),
      contains('still responsible for the transmission'),
    );

    expect(event8.steps, <String>[
      'Write one sentence you would want spoken after your name at a future Wag.',
      'Ask whether that sentence is true of you now, partly true, or not yet true.',
    ]);
    expect(event8.optionalSteps, <String>[
      'Add your own name to the continuity, not as dead, but as one who will eventually be spoken for.',
    ]);

    expect(event9.steps, <String>[
      'Read the complete list of names one final time.',
      'Speak only the lines that are true.',
      'Say, if true: I have made invocation-offerings for the blessed dead.',
      'Say, if true: Their names have been spoken.',
      'Say, if true: They live.',
      'Say, if true: I am their continuation.',
      'Say, if true: They are my foundation.',
      'Write next year\'s Wag date somewhere you will see it.',
      'Place water one more time.',
      'Drink it.',
    ]);
    expect(_wagPurposeText(event9), contains('fact-check'));
  });

  test('Wag words and steps keep field-purity guardrails', () {
    final issues = <String>[];

    for (final event in kWagEvents) {
      final requiredSteps = event.steps.toSet();
      for (final pattern in _wagWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
      for (final step in event.steps) {
        if (step.startsWith('Optional:')) {
          issues.add('Event ${event.eventNumber}: $step');
        }
        if (_wagRequiredStepRationalePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
      for (final optionalStep in event.optionalSteps) {
        if (requiredSteps.contains(optionalStep)) {
          issues.add('Event ${event.eventNumber}: $optionalStep');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test(
    'calendar UI and join branch use designated Wag windows and M1 dates',
    () {
      final detailSource = File(
        'lib/features/calendar/calendar_maat_flows.dart',
      ).readAsStringSync();
      final pageSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final schedulerSource = File(
        'lib/features/calendar/the_wag_scheduler.dart',
      ).readAsStringSync();

      expect(detailSource, contains('_pickWagWindowDate'));
      expect(
        detailSource,
        contains('designated Wep Ronpet enrollment windows'),
      );
      expect(detailSource, contains('Add Flow'));
      expect(detailSource, isNot(contains('Kemetic Year')));
      expect(pageSource, contains('_MaatFlowTemplateKind.theWag'));
      expect(pageSource, contains('_resolveMountedWagJoinWindow'));
      expect(pageSource, contains('resolveWagEnrollmentWindowSafely'));
      expect(pageSource, isNot(contains('wagEnrollmentIsOpen')));
      expect(schedulerSource, contains('wagEventGregorian'));
      expect(pageSource, contains('wag_kyear='));
      expect(
        pageSource,
        isNot(contains('startDate.add(Duration(days: event.kemeticDay')),
      );
    },
  );
}

String _wagPurposeText(WagEvent event) {
  return wagDetailText(event, lens: WagLens.neutral).split('\n\n').first;
}

final _wagWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*before\b', caseSensitive: false),
  RegExp(r'^\s*read\b', caseSensitive: false),
  RegExp(r'^\s*speak only\b', caseSensitive: false),
  RegExp(r'\bif true\b', caseSensitive: false),
  RegExp(r'\bthen\b', caseSensitive: false),
];

final _wagRequiredStepRationalePattern = RegExp(
  r'\b(name doing its work|water is the first provision|water is already doing|call the dead to the table|offering returning|rite completing|living version of the autobiography|declaration of success|cycle closes|source note)\b',
  caseSensitive: false,
);
