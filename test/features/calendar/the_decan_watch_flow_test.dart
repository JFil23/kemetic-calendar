import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';
import 'package:mobile/features/calendar/the_course_context.dart';
import 'package:mobile/features/calendar/the_decan_watch_enrollment.dart';
import 'package:mobile/features/calendar/the_decan_watch_flow.dart';
import 'package:mobile/features/calendar/the_decan_watch_scheduler.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

void main() {
  test('Decan Watch only opens on Month 1-12 decan starts', () {
    expect(isDecanOpeningKemeticDay(3, 11), isTrue);
    expect(isDecanOpeningKemeticDay(3, 10), isFalse);
    expect(isDecanOpeningKemeticDay(13, 1), isFalse);
  });

  test('occurrence has stable default schedule and payload', () {
    final occurrence = decanWatchOccurrenceFor(
      kYear: 1,
      kMonth: 3,
      decanStartDay: 11,
      timezone: TrackSkyTimeZone.pacific,
    );

    expect(occurrence.startLocal.hour, 21);
    expect(occurrence.startLocal.minute, 0);
    expect(decanWatchActionId(occurrence), 'the-decan-watch-1-m3-d11');
    expect(
      decanWatchClientEventId(flowId: 42, occurrence: occurrence),
      'decan-watch:42:1:3:2',
    );

    final payload = decanWatchBehaviorPayload(
      occurrence: occurrence,
      lens: DecanWatchLens.neutral,
    );
    expect(payload['kind'], 'maat_decan_watch');
    expect(payload['flow_key'], kDecanWatchFlowKey);
    expect(payload['outdoor_required'], isTrue);
    expect(payload['completion_options'], <String>[
      'observed',
      'observed_from_inside',
      'skipped',
    ]);
    expect(payload.toString(), isNot(contains('sky_note')));
    expect(payload.toString(), isNot(contains('decan_intention')));
    final schedule = payload['schedule'] as Map<String, dynamic>;
    expect(schedule['type'], 'local_time');
    expect(schedule['editable_from_hour'], kDecanWatchEditableFromHour);
    expect(schedule['editable_to_hour'], kDecanWatchEditableToHour);
  });

  test('schedule clamps to 6 PM through 11:59 PM local', () {
    expect(normalizeDecanWatchScheduleTime(hour: 17).hour, 18);
    final late = normalizeDecanWatchScheduleTime(hour: 24);
    expect(late.hour, 23);
    expect(late.minute, 59);
    final normal = normalizeDecanWatchScheduleTime(hour: 22, minute: 75);
    expect(normal.hour, 22);
    expect(normal.minute, 59);
  });

  test('upcoming occurrences skip Month 13', () {
    final start = KemeticMath.toGregorian(1, 12, 21);
    final occurrences = upcomingDecanWatchOccurrences(
      timezone: TrackSkyTimeZone.pacific,
      fromLocal: start,
      count: 3,
    );

    expect(occurrences, hasLength(3));
    expect(occurrences.map((o) => o.kMonth), everyElement(lessThan(13)));
    expect(
      occurrences.map((o) => o.decanStartDay),
      everyElement(isIn([1, 11, 21])),
    );
  });

  test('enrollment window is open only for the first 24h of opening day', () {
    final occurrence = decanWatchOccurrenceFor(
      kYear: 1,
      kMonth: 1,
      decanStartDay: 1,
      timezone: TrackSkyTimeZone.pacific,
    );
    final window = decanWatchWindowForOccurrence(occurrence);

    expect(
      decanWatchEnrollmentIsOpen(window, now: DateTime.utc(2025, 3, 20, 19)),
      isTrue,
    );
    expect(
      decanWatchEnrollmentIsOpen(window, now: DateTime.utc(2025, 3, 21, 8, 30)),
      isFalse,
    );
  });

  test(
    'safe enrollment resolver returns null for unavailable selected dates',
    () {
      final window = resolveDecanWatchEnrollmentWindowSafely(
        timezone: TrackSkyTimeZone.pacific,
        startDate: DateTime(2099, 1, 1),
        now: DateTime.utc(2026, 5, 23, 18),
      );

      expect(window, isNull);
    },
  );

  test('detail text keeps Decan Watch generated sections field-pure', () {
    final occurrence = decanWatchOccurrenceFor(
      kYear: 1,
      kMonth: 1,
      decanStartDay: 1,
      timezone: TrackSkyTimeZone.eastern,
    );
    final detail = decanWatchDetailText(occurrence, lens: DecanWatchLens.nut);

    expect(detail, isNot(contains('Confidence\n')));
    expect(
      detail,
      contains(
        'Purpose\n'
        'The opening of ${occurrence.decanName} is a night-sky boundary: the sky has been counting, and one bearing can be taken for the next ten days.',
      ),
    );
    expect(detail, isNot(contains('Purpose\nStand under')));
    expect(
      detail,
      contains(
        'Outdoor\n'
        'Go outside if you can. If safety, access, or weather prevents that, stand at a window or threshold. Inside observation still counts; mark the completion as observed from inside. A clouded sky is still a valid record.',
      ),
    );
    expect(detail, contains('safety, access, or weather'));
    expect(detail, contains('observed from inside'));
    expect(detail, contains('A clouded sky is still a valid record.'));
    expect(detail, contains(kDecanWatchRequiredLine));
    expect(detail, contains('Words\n"$kDecanWatchRequiredLine"'));
    expect(detail, isNot(contains('Words\n"Go outside')));
    expect(detail, contains('1. Go outside.'));
    expect(detail, contains('2. Put the phone down.'));
    expect(
      detail,
      contains('3. Stand under open sky for at least one minute.'),
    );
    expect(detail, contains('7. Speak the line.'));
    expect(detail, isNot(contains('Speak the required line.')));
    expect(detail, contains('8. Note the sky in one line.'));
    expect(detail, contains('9. Open the ḥꜣw day card.'));
    expect(
      detail,
      contains('10. Read the decan name, quality, and Ma’at principle.'),
    );
    expect(detail, contains('12. Name one bearing for the coming ten days.'));
    expect(
      detail,
      contains(
        'Day Card\n'
        'The ḥꜣw day card is the calendar card for this decan opening. Open it. Read the decan name, quality, and Ma’at principle.',
      ),
    );
  });

  test('contextual day card copy defines ḥꜣw and preserves decan reading', () {
    final occurrence = decanWatchOccurrenceFor(
      kYear: 1,
      kMonth: 1,
      decanStartDay: 1,
      timezone: TrackSkyTimeZone.eastern,
    );
    final context = courseContextForKemeticDate(
      kYear: occurrence.kYear,
      kMonth: occurrence.kMonth,
      kDay: occurrence.decanStartDay,
    );

    final detail = decanWatchDetailText(
      occurrence,
      lens: DecanWatchLens.neutral,
      context: context,
    );

    expect(
      detail,
      contains(
        'Day Card\n'
        'The ḥꜣw day card is the calendar card for ${context.kemeticDateLabel}. Open it. Read the decan name and quality shown there, including ${context.decanName}, and the Ma’at principle: ${context.maatPrinciple}',
      ),
    );
  });

  test(
    'response specs preserve visibility, sky note, and bearing contract',
    () {
      final specs = resolveMaatFlowResponseSpecs(
        flowKey: kDecanWatchFlowKey,
        surface: MaatFlowResponseSurface.calendarSheet,
      );

      expect(specs.map((spec) => spec.id), <String>[
        kDecanWatchResponseVisibilitySpecId,
        kDecanWatchResponseSkyNoteSpecId,
        kDecanWatchResponseBearingSpecId,
      ]);
      final visibility = specs.firstWhere(
        (spec) => spec.id == kDecanWatchResponseVisibilitySpecId,
      );
      expect(visibility.label, 'Visibility');
      expect(visibility.options.map((option) => option.id), <String>[
        kDecanWatchVisibilityOutside,
        kDecanWatchVisibilityInside,
        kDecanWatchVisibilityClouded,
        kDecanWatchVisibilityNotVisible,
      ]);
      expect(
        specs
            .firstWhere((spec) => spec.id == kDecanWatchResponseSkyNoteSpecId)
            .label,
        'What did the sky show?',
      );
      expect(
        specs
            .firstWhere((spec) => spec.id == kDecanWatchResponseBearingSpecId)
            .label,
        'What bearing do you carry into the next ten days?',
      );
    },
  );

  test('source wires template, window-only picker, and rolling ids', () {
    final calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final enrollmentSource = File(
      'lib/features/calendar/the_decan_watch_enrollment.dart',
    ).readAsStringSync();
    final detailPage = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();

    expect(calendarPage, contains('_MaatFlowTemplateKind.decanWatch'));
    expect(calendarPage, contains('_resolveMountedDecanWatchJoinWindow'));
    expect(calendarPage, contains('resolveDecanWatchEnrollmentWindowSafely'));
    expect(enrollmentSource, contains('decanWatchNextEnrollmentWindow'));
    expect(
      enrollmentSource,
      contains('decanWatchEnrollmentWindowForStartDate'),
    );
    expect(calendarPage, isNot(contains('decanWatchEnrollmentIsOpen')));
    expect(calendarPage, contains('decanWatchClientEventId'));
    expect(detailPage, contains('_pickDecanWatchWindowDate'));
    expect(detailPage, contains('designated decan-opening enrollment windows'));
    expect(detailPage, contains('Add Flow'));
    expect(detailPage, isNot(contains("'KYear ")));
    expect(dayView, contains('DecanWatchLocalStore'));
    expect(dayView, contains('_persistDecanWatchResponseValues'));
    expect(dayView, isNot(contains('Kemetic Year')));
  });
}
