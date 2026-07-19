import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_djed_enrollment.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

void main() {
  test('Djed has nine events on the sparse 30-day rhythm', () {
    expect(kDjedEvents, hasLength(9));
    expect(kDjedEvents.map((event) => event.flowDay), <int>[
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
  });

  test('event dates are flow-relative from selected decan opening', () {
    final start = DateTime(2026, 3, 1);
    expect(djedEventDate(start, kDjedEvents.first), start);
    expect(djedEventDate(start, kDjedEvents.last), DateTime(2026, 3, 29));
  });

  test('timing slots follow Djed exceptions', () {
    final start = DateTime(2026, 3, 1);
    final event3 = djedScheduleForEvent(
      kDjedEvents[2],
      start,
      TrackSkyTimeZone.pacific,
    );
    final event5 = djedScheduleForEvent(
      kDjedEvents[4],
      start,
      TrackSkyTimeZone.pacific,
    );
    final event6 = djedScheduleForEvent(
      kDjedEvents[5],
      start,
      TrackSkyTimeZone.pacific,
    );
    final event9 = djedScheduleForEvent(
      kDjedEvents[8],
      start,
      TrackSkyTimeZone.pacific,
    );

    expect(event3.scheduleType, 'local_astronomical_dawn_plus_30_minutes');
    expect(event5.scheduleType, 'fixed_local_midday');
    expect(event5.startLocal.hour, 11);
    expect(event6.scheduleType, 'local_sunset_plus_30_minutes');
    expect(event9.scheduleType, 'local_astronomical_dawn_plus_30_minutes');
  });

  test('Event 9 payload exposes physical raising and raised completion', () {
    final start = DateTime(2026, 3, 1);
    final event = kDjedEvents[8];
    final schedule = djedScheduleForEvent(
      event,
      start,
      TrackSkyTimeZone.eastern,
    );
    final payload = djedBehaviorPayload(
      event: event,
      schedule: schedule,
      lens: DjedLens.ausar,
    );

    expect(payload['kind'], 'maat_djed_event');
    expect(payload['flow_key'], kTheDjedFlowKey);
    expect(payload['physical_raising'], isTrue);
    expect(payload['raising_seconds'], kDjedRaisingSeconds);
    expect(payload['completion_options'], contains('raised'));
    expect(payload.toString(), isNot(contains('spine')));
    expect(payload.toString(), isNot(contains('battle_commitment')));
  });

  test('Event 5 keeps invocation in words and commitment check in steps', () {
    final event = kDjedEvents.singleWhere((event) => event.eventNumber == 5);

    expect(
      event.spokenLine,
      'Unis, raise yourself from your side! Do my command, you who hate sleep but were made slack.',
    );
    expect(event.steps, <String>[
      'Speak the invocation before checking the commitment.',
      'Check whether the direct engagement committed on Day 11 has happened.',
      'Answer whether the engagement happened.',
      'If yes, record what occurred in one honest sentence.',
      'If no, name the obstacle and the next action that moves the engagement before Day 19.',
      'Do that next action today if possible.',
    ]);

    final detail = djedDetailText(event, lens: DjedLens.neutral);
    expect(detail, contains('Words\n"${event.spokenLine}"'));
    expect(detail, contains('Steps\n1. Speak the invocation before checking'));
    expect(detail, isNot(contains('Words\n"Before checking')));
    expect(detail, isNot(contains('Then check: has the engagement happened?')));
  });

  test('Djed allows spoken Stand up invocation while banning wrappers', () {
    final issues = <String>[];

    expect(
      kDjedEvents.singleWhere((event) => event.eventNumber == 6).spokenLine,
      'Stand up! Raise yourself like Ausar (Osiris)!',
    );
    expect(
      kDjedEvents.singleWhere((event) => event.eventNumber == 9).spokenLine,
      contains('Stand up! Raise yourself like Ausar (Osiris)!'),
    );

    for (final event in kDjedEvents) {
      for (final pattern in _djedWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Djed steps keep optional and rationale text separated', () {
    final issues = <String>[];
    final event8 = kDjedEvents.singleWhere((event) => event.eventNumber == 8);
    final event9 = kDjedEvents.singleWhere((event) => event.eventNumber == 9);

    expect(event8.steps, <String>[
      'Name one moment in the last 10 days when a load-bearing element was tested.',
      'Name one way your relationship to what holds you upright has changed.',
      'Prepare standing room: the next event requires standing and raising the arms for about 30 seconds.',
    ]);
    expect(event8.optionalSteps, <String>[
      'Place a hand on the physical spine and notice what holds without announcement.',
    ]);

    expect(event9.steps, <String>[
      'Name the spine elements that held across the full cycle.',
      'Stand upright with your spine straight.',
      'Raise your arms and hold for approximately thirty seconds.',
      'Speak the closing line while standing.',
      'Choose the maintenance practice that keeps the Djed upright.',
    ]);

    for (final event in kDjedEvents) {
      final requiredSteps = event.steps.toSet();
      for (final step in event.steps) {
        if (_djedRequiredStepRationalePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
        if (step.startsWith('Optional:')) {
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

  test('enrollment wrapper accepts picker rows and rejects ordinary dates', () {
    final window = djedNextEnrollmentWindow(TrackSkyTimeZone.pacific);
    final selected = DateTime(
      window.opensAtLocal.year,
      window.opensAtLocal.month,
      window.opensAtLocal.day,
    );
    final picked = djedEnrollmentWindowForStartDate(
      selected,
      TrackSkyTimeZone.pacific,
    );
    expect(picked, isNotNull);
    expect(djedStartDateIsValid(selected, TrackSkyTimeZone.pacific), isTrue);

    var ordinary = selected.add(const Duration(days: 1));
    while (djedStartDateIsValid(ordinary, TrackSkyTimeZone.pacific)) {
      ordinary = ordinary.add(const Duration(days: 1));
    }
    expect(djedStartDateIsValid(ordinary, TrackSkyTimeZone.pacific), isFalse);
  });

  test('enrollment helper still reports the 24h decan window', () {
    final openingDate = KemeticMath.toGregorian(1, 3, 11);
    final window = djedEnrollmentWindowForStartDate(
      openingDate,
      TrackSkyTimeZone.pacific,
      now: openingDate,
    );
    expect(window, isNotNull);
    expect(
      djedEnrollmentIsOpen(
        window!,
        now: DateTime.utc(
          window.opensAtLocal.year,
          window.opensAtLocal.month,
          window.opensAtLocal.day,
          20,
        ),
      ),
      isTrue,
    );
    expect(
      djedEnrollmentIsOpen(
        window,
        now: DateTime.utc(
          window.opensAtLocal.year,
          window.opensAtLocal.month,
          window.opensAtLocal.day + 2,
          20,
        ),
      ),
      isFalse,
    );
  });

  test(
    'safe enrollment resolver returns null for unavailable selected dates',
    () {
      final window = resolveDjedEnrollmentWindowSafely(
        timezone: TrackSkyTimeZone.pacific,
        startDate: DateTime(2099, 1, 1),
        now: DateTime.utc(2026, 5, 23, 18),
      );

      expect(window, isNull);
    },
  );

  test('source wires template, picker, local store, and raised completion', () {
    final calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final enrollmentSource = File(
      'lib/features/calendar/the_djed_enrollment.dart',
    ).readAsStringSync();
    final detailPage = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();

    expect(calendarPage, contains('_MaatFlowTemplateKind.theDjed'));
    expect(calendarPage, contains('_resolveMountedDjedJoinWindow'));
    expect(calendarPage, contains('resolveDjedEnrollmentWindowSafely'));
    expect(enrollmentSource, contains('djedNextEnrollmentWindow'));
    expect(enrollmentSource, contains('djedEnrollmentWindowForStartDate'));
    expect(calendarPage, isNot(contains('djedEnrollmentIsOpen')));
    expect(calendarPage, contains('djedClientEventId'));
    expect(detailPage, contains('_pickDjedWindowDate'));
    expect(detailPage, contains('Djed Start Windows'));
    expect(detailPage, contains('designated decan-opening enrollment windows'));
    expect(detailPage, contains('Add Flow'));
    expect(detailPage, isNot(contains("'KYear ")));
    expect(dayView, contains('TheDjedLocalStore'));
    expect(dayView, contains("'raised': 'Raised'"));
  });
}

final _djedWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*before checking\b', caseSensitive: false),
  RegExp(r'\bspeak:\b', caseSensitive: false),
  RegExp(r'\bthen check\b', caseSensitive: false),
  RegExp(r'\bhas the engagement happened\b', caseSensitive: false),
];

final _djedRequiredStepRationalePattern = RegExp(
  r'\b(Pyramid Texts|source note|The body declares|what the record produced|The battle must occur)\b',
  caseSensitive: false,
);
