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

  test('selected start date must be inside its 24h decan window', () {
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

  test('source wires template, picker, local store, and raised completion', () {
    final calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final detailPage = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();

    expect(calendarPage, contains('_MaatFlowTemplateKind.theDjed'));
    expect(calendarPage, contains('djedEnrollmentIsOpen'));
    expect(calendarPage, contains('djedClientEventId'));
    expect(detailPage, contains('_pickDjedWindowDate'));
    expect(detailPage, contains('Djed Start Windows'));
    expect(detailPage, contains('designated decan-opening enrollment windows'));
    expect(dayView, contains('TheDjedLocalStore'));
    expect(dayView, contains("'raised': 'Raised'"));
  });
}
