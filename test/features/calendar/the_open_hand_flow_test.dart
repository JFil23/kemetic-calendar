import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_open_hand_enrollment.dart';
import 'package:mobile/features/calendar/the_open_hand_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

void main() {
  test('Open Hand has nine events on the sparse 30-day rhythm', () {
    expect(kOpenHandEvents, hasLength(9));
    expect(kOpenHandEvents.map((event) => event.flowDay), <int>[
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
    expect(openHandEventDate(start, kOpenHandEvents.first), start);
    expect(
      openHandEventDate(start, kOpenHandEvents.last),
      DateTime(2026, 3, 29),
    );
  });

  test('midpoint and close timing use Weighing-style slots', () {
    final start = DateTime(2026, 3, 1);
    final first = openHandScheduleForEvent(
      kOpenHandEvents[0],
      start,
      TrackSkyTimeZone.pacific,
    );
    final midpoint = openHandScheduleForEvent(
      kOpenHandEvents[1],
      start,
      TrackSkyTimeZone.pacific,
    );
    final close = openHandScheduleForEvent(
      kOpenHandEvents[2],
      start,
      TrackSkyTimeZone.pacific,
    );

    expect(first.scheduleType, 'local_astronomical_dawn_plus_30_minutes');
    expect(midpoint.scheduleType, 'fixed_local_midday');
    expect(midpoint.startLocal.hour, 11);
    expect(close.scheduleType, 'local_sunset_plus_30_minutes');
  });

  test('payload carries outward-act flags but no recipient detail', () {
    final start = DateTime(2026, 3, 1);
    final schedule = openHandScheduleForEvent(
      kOpenHandEvents[4],
      start,
      TrackSkyTimeZone.eastern,
    );
    final payload = openHandBehaviorPayload(
      event: kOpenHandEvents[4],
      schedule: schedule,
      lens: OpenHandLens.hapy,
    );

    expect(payload['kind'], 'maat_open_hand_event');
    expect(payload['flow_key'], kTheOpenHandFlowKey);
    expect(payload['requires_outward_act'], isTrue);
    expect(payload['stranger_act'], isTrue);
    expect(payload.toString(), isNot(contains('recipient')));
    expect(payload.toString(), isNot(contains('stranger_act_record')));
  });

  test('copy keeps provision gates and truth checks explicit', () {
    final event1 = kOpenHandEvents[0];
    final event2 = kOpenHandEvents[1];
    final event3 = kOpenHandEvents[2];
    final event4 = kOpenHandEvents[3];
    final event5 = kOpenHandEvents[4];
    final event6 = kOpenHandEvents[5];
    final event7 = kOpenHandEvents[6];
    final event8 = kOpenHandEvents[7];
    final event9 = kOpenHandEvents[8];

    expect(
      event1.steps.last,
      'Write: This ten-day section, I will give ___ to ___.',
    );
    expect(
      event2.steps.first,
      'Complete the act of provision identified on Day 1 before marking this event observed.',
    );
    expect(event2.requiresOutwardAct, isTrue);
    expect(
      event3.steps,
      contains(
        'Carry it into the second ten-day section without excuse or editing.',
      ),
    );
    expect(event4.steps, <String>[
      'Write three named acts of outward provision for this ten-day section.',
      'For each act, write what will be given and who or what receives it.',
      'Write when each act will happen before Day 19.',
      'Mark which act is easiest, which is most needed, and which one resists you.',
    ]);
    expect(event5.steps, <String>[
      'Choose one act from the Day 11 list that benefits someone outside your circle of obligation.',
      'Name any resistance to giving without a relational claim.',
      'Complete the act before marking this event observed.',
      'If it cannot be completed today, write the exact date it will be completed instead of claiming it as done.',
    ]);
    expect(event5.requiresOutwardAct, isTrue);
    expect(event5.strangerAct, isTrue);
    expect(
      event6.steps.last,
      'Name one thing the giving of this ten-day section taught you about capacity, resistance, or need.',
    );
    expect(event7.steps, <String>[
      'Map one kind of provision that entered your life this month: money, food, attention, skill, help, access, or time.',
      'Name the threshold where provision tends to stop with you as a material observation, not self-criticism.',
      'Choose one specific act that moves provision beyond you in the final ten-day section.',
    ]);
    expect(
      openHandDetailText(event8, lens: OpenHandLens.neutral),
      contains(
        'The midpoint keeps attention on what changed because provision moved.',
      ),
    );
    expect(
      event9.steps,
      contains('Speak only the truth-check lines that are true.'),
    );
    expect(event9.steps, contains('Say, if true: I saw need.'));
    expect(event9.steps, contains('Say, if true: I gave outside obligation.'));
    expect(
      event9.steps,
      contains('Say, if true: I gave to someone I do not know.'),
    );
    expect(event9.steps, contains('Say, if true: Provision is less blocked.'));
    expect(
      event9.steps.any(
        (step) => step.contains('I saw need; I gave outside obligation'),
      ),
      isFalse,
    );
    expect(
      openHandDetailText(event5, lens: OpenHandLens.neutral),
      contains(
        'Resistance marks where obligation has been mistaken for the edge of provision.',
      ),
    );
  });

  test('words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];

    for (final event in kOpenHandEvents) {
      for (final pattern in _openHandWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('steps keep rationale and optional sharing out of required actions', () {
    final issues = <String>[];

    for (final event in kOpenHandEvents) {
      for (final step in event.steps) {
        if (_openHandRequiredStepRationalePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
        if (_openHandRequiredStepOptionalSharingPattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
    expect(
      kOpenHandEvents
          .where((event) => event.sharePromptOnComplete)
          .map((event) => event.eventNumber),
      <int>[9],
    );
  });

  test('enrollment wrapper accepts picker rows and rejects ordinary dates', () {
    final window = openHandNextEnrollmentWindow(TrackSkyTimeZone.pacific);
    final selected = DateTime(
      window.opensAtLocal.year,
      window.opensAtLocal.month,
      window.opensAtLocal.day,
    );
    final picked = openHandEnrollmentWindowForStartDate(
      selected,
      TrackSkyTimeZone.pacific,
    );
    expect(picked, isNotNull);
    expect(
      openHandStartDateIsValid(selected, TrackSkyTimeZone.pacific),
      isTrue,
    );

    var ordinary = selected.add(const Duration(days: 1));
    while (openHandStartDateIsValid(ordinary, TrackSkyTimeZone.pacific)) {
      ordinary = ordinary.add(const Duration(days: 1));
    }
    expect(
      openHandStartDateIsValid(ordinary, TrackSkyTimeZone.pacific),
      isFalse,
    );
  });

  test('enrollment helper still reports the 24h decan window', () {
    final openingDate = KemeticMath.toGregorian(1, 3, 11);
    final window = openHandEnrollmentWindowForStartDate(
      openingDate,
      TrackSkyTimeZone.pacific,
      now: openingDate,
    );
    expect(window, isNotNull);
    expect(
      openHandEnrollmentIsOpen(
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
      openHandEnrollmentIsOpen(
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
      final window = resolveOpenHandEnrollmentWindowSafely(
        timezone: TrackSkyTimeZone.pacific,
        startDate: DateTime(2099, 1, 1),
        now: DateTime.utc(2026, 5, 23, 18),
      );

      expect(window, isNull);
    },
  );

  test('source wires template, window-only picker, join, and local store', () {
    final calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final enrollmentSource = File(
      'lib/features/calendar/the_open_hand_enrollment.dart',
    ).readAsStringSync();
    final detailPage = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();

    expect(calendarPage, contains('_MaatFlowTemplateKind.theOpenHand'));
    expect(calendarPage, contains('_resolveMountedOpenHandJoinWindow'));
    expect(calendarPage, contains('resolveOpenHandEnrollmentWindowSafely'));
    expect(enrollmentSource, contains('openHandNextEnrollmentWindow'));
    expect(enrollmentSource, contains('openHandEnrollmentWindowForStartDate'));
    expect(calendarPage, isNot(contains('openHandEnrollmentIsOpen')));
    expect(calendarPage, contains('openHandClientEventId'));
    expect(detailPage, contains('_pickOpenHandWindowDate'));
    expect(detailPage, contains('designated decan-opening enrollment windows'));
    expect(detailPage, contains('Add Flow'));
    expect(detailPage, isNot(contains("'KYear ")));
    expect(dayView, contains('TheOpenHandLocalStore'));
  });
}

final _openHandWordsStageDirectionPatterns = <RegExp>[
  RegExp(
    r'^\s*(speak|say|write|name|before|after|then)\b',
    caseSensitive: false,
  ),
  RegExp(r'\btruth-check\b', caseSensitive: false),
  RegExp(r'\bif true\b', caseSensitive: false),
  RegExp(r'\bmarking this event\b', caseSensitive: false),
];

final _openHandRequiredStepRationalePattern = RegExp(
  r'\b(The act is the event|logging follows|Named acts become commitments|The commitment becomes the record|The resistance to giving|exactly what this act is designed|The threshold is where|flood is pooling|Naming it is the first step|source note|Spell 125|Ptahhotep|Harkhuf|Hapidjefa|Eloquent Peasant|Hymns to Hapy)\b',
  caseSensitive: false,
);

final _openHandRequiredStepOptionalSharingPattern = RegExp(
  r'\b(optionally|if desired|share|post|feed|public)\b',
  caseSensitive: false,
);
