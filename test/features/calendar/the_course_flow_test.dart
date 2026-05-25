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
    expect(detail, contains('Mark dusk as the transition'));
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
