import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_course_context.dart';
import 'package:mobile/features/calendar/the_course_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('defines nine canonical Course sittings on the correct flow days', () {
    expect(kTheCourseEvents, hasLength(9));
    expect(kTheCourseEvents.map((event) => event.flowDay).toList(), <int>[
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
    expect(kTheCourseEvents.every((event) => event.requiresDayCard), isTrue);
    expect(kTheCourseEvents[1].scheduleKind, CourseScheduleKind.solarDusk);
    expect(kTheCourseEvents[6].seasonAware, isTrue);
    expect(kTheCourseEvents[7].seasonAware, isTrue);
    expect(kTheCourseEvents.last.sharePromptOnComplete, isTrue);
  });

  test('schedules event two at dusk, not 11 AM', () {
    final startDate = DateTime(2026, 6, 1);
    final dawn = courseScheduleForDate(
      kTheCourseEvents[0],
      startDate,
      TrackSkyTimeZone.pacific,
    );
    final dusk = courseScheduleForDate(
      kTheCourseEvents[1],
      startDate.add(const Duration(days: 4)),
      TrackSkyTimeZone.pacific,
    );
    final midday = courseScheduleForDate(
      kTheCourseEvents[4],
      startDate.add(const Duration(days: 14)),
      TrackSkyTimeZone.pacific,
    );
    final seal = courseScheduleForDate(
      kTheCourseEvents[5],
      startDate.add(const Duration(days: 18)),
      TrackSkyTimeZone.pacific,
    );

    expect(dawn.scheduleType, 'local_astronomical_dawn');
    expect(dawn.startLocal.hour, inInclusiveRange(3, 6));
    expect(dusk.scheduleType, 'local_sunset');
    expect(dusk.startLocal.hour, isNot(11));
    expect(dusk.startLocal.hour, inInclusiveRange(18, 21));
    expect(midday.startLocal.hour, 11);
    expect(midday.scheduleType, 'fixed_local_midday');
    expect(seal.scheduleType, 'local_sunset_plus_30_minutes');
  });

  test('builds JSON-safe behavior payloads and action ids', () {
    final startDate = DateTime(2026, 6, 1);
    final ids = <String>{};

    for (final event in kTheCourseEvents) {
      final schedule = courseScheduleForDate(
        event,
        startDate.add(Duration(days: event.flowDay - 1)),
        TrackSkyTimeZone.eastern,
      );
      final context = courseContextForGregorianDate(schedule.startLocal);
      final payload = courseBehaviorPayload(
        event: event,
        schedule: schedule,
        lens: CourseLens.ra,
        context: context,
      );

      final encoded = jsonEncode(payload);
      expect(jsonDecode(encoded), isA<Map<String, dynamic>>());
      expect(payload['kind'], 'maat_course_event');
      expect(payload['flow_key'], 'the-course');
      expect(payload['requires_day_card'], isTrue);
      expect(payload['schedule_kind'], event.scheduleKind.key);
      expect(payload['missed_event_rule'], 'expire_quietly');
      ids.add(courseActionId(event));
    }

    expect(ids, hasLength(9));
    expect(ids.first, 'the-course-event-01');
    expect(ids.last, 'the-course-event-09');
  });

  test(
    'detail text includes live calendar context, day card, and season branch',
    () {
      final context = courseContextForKemeticDate(kYear: 2, kMonth: 9, kDay: 2);
      final detail = courseDetailText(
        kTheCourseEvents[6],
        lens: CourseLens.khepri,
        context: context,
      );

      expect(detail, contains('Current ḥꜣw Context'));
      expect(detail, contains('Day Card\nOpen the ḥꜣw day card'));
      expect(detail, contains('Season Instruction'));
      expect(detail, contains(context.seasonInstruction));
      expect(detail, contains('Lens\nLet Khepri'));
    },
  );

  test('Course copy keeps orientation, season, and closing lines explicit', () {
    final event1 = kTheCourseEvents[0];
    final event4 = kTheCourseEvents[3];
    final event7 = kTheCourseEvents[6];
    final event9 = kTheCourseEvents[8];

    expect(
      event1.spokenLine,
      'Riser, Riser! Beetle, Beetle! Your life is related to mine; my life is related to yours. Sustenance is for my morning, Abundance is for my evening. Famine will not have control of this life.',
    );
    expect(event1.steps, <String>[
      'Face east, or face the window.',
      'Open the ḥꜣw day card. Read the Kemetic date, decan name, and Ma\'at principle before you close it.',
      'Name one thing appropriate for the morning part of this particular day.',
      'Do one opening act that matches the day instead of only the task list.',
    ]);
    expect(event1.optionalSteps, isEmpty);
    expect(_coursePurpose(event1), contains('Facing east or the window'));

    expect(event4.steps, <String>[
      'Open the ḥꜣw day card before anything else.',
      'Read the current decan name, ten-day theme, and Ma\'at principle.',
      'Name what this ten-day decan calls for in your life right now.',
    ]);

    expect(
      event7.spokenLine,
      'I ordered everything in its proper place. Hapy gave me honor on every field, so that none hungered during my years, none thirsted therein.',
    );
    expect(event7.steps, <String>[
      'Open the ḥꜣw day card and locate the current season before speaking.',
      'Read the season branch shown here and name what this season asks in your life.',
      'Write one active sentence: This is [season]. It asks me to ___.',
    ]);
    expect(event7.seasonAware, isTrue);

    expect(event9.steps, <String>[
      'Open the ḥꜣw day card. Let it be the first thing you read.',
      'Speak only the closing truth lines that are true.',
      'Say, if true: I know the decan.',
      'Say, if true: I know the season.',
      'Say, if true: I greeted dawn.',
      'Say, if true: I did a decan act.',
      'Say, if true: I did a seasonal act.',
      'Name one practice from these thirty days that you will continue past the flow.',
      'Speak the final line: The course is continuous. I am in it.',
    ]);
    expect(event9.sharePromptOnComplete, isTrue);
  });

  test('Course words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];

    for (final event in kTheCourseEvents) {
      for (final pattern in _courseWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Course steps keep source-note phrases out of actions', () {
    final issues = <String>[];

    for (final event in kTheCourseEvents) {
      for (final step in event.steps) {
        if (_courseSourceNotePhrasePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Course optional steps do not duplicate required steps', () {
    final issues = <String>[];

    for (final event in kTheCourseEvents) {
      final requiredSteps = event.steps.toSet();
      for (final optionalStep in event.optionalSteps) {
        if (requiredSteps.contains(optionalStep)) {
          issues.add('Event ${event.eventNumber}: $optionalStep');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Course timing labels preserve day anchors and solar meanings', () {
    expect(courseTimingLabel(kTheCourseEvents[0]), 'Day 1 · dawn');
    expect(courseTimingLabel(kTheCourseEvents[1]), 'Day 5 · dusk');
    expect(courseTimingLabel(kTheCourseEvents[4]), 'Day 15 · 11:00 local');
    expect(courseTimingLabel(kTheCourseEvents[5]), 'Day 19 · sunset + 30 min');
    expect(courseTimingLabel(kTheCourseEvents[8]), 'Day 29 · dawn');
  });

  test('canonical detail rebuilds a stored Course event', () {
    final context = courseContextForKemeticDate(kYear: 2, kMonth: 9, kDay: 2);
    final detail = canonicalCourseDetailTextForEvent(
      flowName: kTheCourseTitle,
      flowNotes: 'mode=gregorian;maat=the-course;course_lens=ra',
      title: 'Course 2: The Solar Course: Mark the Transition',
      actionId: 'the-course-event-02',
      behaviorPayload: const <String, dynamic>{
        'kind': 'maat_course_event',
        'flow_key': 'the-course',
        'event_number': 2,
      },
      context: context,
    );

    expect(detail, isNotNull);
    expect(detail, contains('The visible day has actually ended.'));
    expect(detail, contains('Lens\nLet Ra'));
  });

  test('calendar join branch creates nine events without placeholders', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final methodStart = source.indexOf('Future<int> _addMaatFlowInstance({');
    expect(methodStart, isNonNegative);
    final branchStart = source.indexOf(
      'if (template.kind == _MaatFlowTemplateKind.theCourse)',
      methodStart,
    );
    expect(branchStart, isNonNegative);
    final branchEnd = source.indexOf('if (startDate == null)', branchStart);
    expect(branchEnd, isNonNegative);
    final branch = source.substring(branchStart, branchEnd);

    expect(branch, contains('kTheCourseEvents'));
    expect(branch, contains('courseScheduleForDate'));
    expect(branch, contains('courseContextForKemeticDate'));
    expect(branch, contains('await repo.upsertByClientId'));
    expect(branch, contains('repo.deleteFlow(serverFlowId)'));
    expect(branch, contains('firstG.add(const Duration(days: 29))'));
    expect(branch, isNot(contains('kDawnHouseRiteDays')));
  });
}

String _coursePurpose(CourseEvent event) {
  return courseDetailText(event, lens: CourseLens.neutral).split('\n\n').first;
}

final _courseWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*face east\b', caseSensitive: false),
  RegExp(r'^\s*locate\b', caseSensitive: false),
  RegExp(r'\bthen speak\b', caseSensitive: false),
  RegExp(r'\bbefore speaking\b', caseSensitive: false),
  RegExp(r'\bspeak only\b', caseSensitive: false),
];

final _courseSourceNotePhrasePattern = RegExp(
  r'\b(Pyramid Texts|Utterance 388|source note|astronomer-priest|Kemetic clock|not metaphorical|not finished|not from the completion)\b',
  caseSensitive: false,
);
