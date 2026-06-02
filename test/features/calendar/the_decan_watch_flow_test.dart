import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    expect(payload['completion_options'], contains('observed_from_inside'));
    expect(payload.toString(), isNot(contains('sky_note')));
    expect(payload.toString(), isNot(contains('decan_intention')));
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

  test('detail text carries six steps without confidence copy', () {
    final occurrence = decanWatchOccurrenceFor(
      kYear: 1,
      kMonth: 1,
      decanStartDay: 1,
      timezone: TrackSkyTimeZone.eastern,
    );
    final detail = decanWatchDetailText(occurrence, lens: DecanWatchLens.nut);

    expect(detail, isNot(contains('Confidence\n')));
    expect(detail, contains(kDecanWatchRequiredLine));
    expect(detail, contains('1. Go outside.'));
    expect(detail, contains('6. Reset intention.'));
  });

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
    expect(dayView, isNot(contains('Kemetic Year')));
  });
}
