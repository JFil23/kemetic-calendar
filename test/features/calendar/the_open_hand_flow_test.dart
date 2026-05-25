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

  test('selected start date must be inside its 24h decan window', () {
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

  test('source wires template, window-only picker, join, and local store', () {
    final calendarPage = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final detailPage = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final dayView = File(
      'lib/features/calendar/day_view.dart',
    ).readAsStringSync();

    expect(calendarPage, contains('_MaatFlowTemplateKind.theOpenHand'));
    expect(calendarPage, contains('openHandEnrollmentIsOpen'));
    expect(calendarPage, contains('openHandClientEventId'));
    expect(detailPage, contains('_pickOpenHandWindowDate'));
    expect(detailPage, contains('designated decan-opening enrollment windows'));
    expect(dayView, contains('TheOpenHandLocalStore'));
  });
}
