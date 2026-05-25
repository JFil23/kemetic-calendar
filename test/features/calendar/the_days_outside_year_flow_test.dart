import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_days_outside_year_enrollment.dart';
import 'package:mobile/features/calendar/the_days_outside_year_flow.dart';
import 'package:mobile/features/calendar/the_days_outside_year_scheduler.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

void main() {
  test('defines seven fixed Kemetic threshold events', () {
    expect(kDaysOutsideEvents, hasLength(7));
    expect(kDaysOutsideEvents.map((event) => event.eventNumber).toList(), <int>[
      0,
      1,
      2,
      3,
      4,
      5,
      6,
    ]);
    expect(
      kDaysOutsideEvents.map((event) => (event.kMonth, event.kDay)).toList(),
      <(int, int)>[
        (12, 30),
        (13, 1),
        (13, 2),
        (13, 3),
        (13, 4),
        (13, 5),
        (1, 1),
      ],
    );
    expect(
      kDaysOutsideEvents.first.schedule,
      DaysOutsideScheduleKind.solarDusk,
    );
    expect(
      kDaysOutsideEvents.skip(1).map((event) => event.schedule),
      everyElement(DaysOutsideScheduleKind.solarDawn),
    );
    expect(kDaysOutsideEvents.last.optionalShareOnComplete, isTrue);
  });

  test('maps events through KemeticMath instead of Gregorian offsets', () {
    final closing = daysOutsideScheduleForEvent(
      event: kDaysOutsideEvents.first,
      closingKYear: 2,
      timezone: TrackSkyTimeZone.pacific,
    );
    final setDay = daysOutsideScheduleForEvent(
      event: kDaysOutsideEvents[3],
      closingKYear: 2,
      timezone: TrackSkyTimeZone.pacific,
    );
    final wep = daysOutsideScheduleForEvent(
      event: kDaysOutsideEvents.last,
      closingKYear: 2,
      timezone: TrackSkyTimeZone.pacific,
    );

    final closingK = KemeticMath.fromGregorian(closing.startLocal);
    final setK = KemeticMath.fromGregorian(setDay.startLocal);
    final wepK = KemeticMath.fromGregorian(wep.startLocal);

    expect((closingK.kYear, closingK.kMonth, closingK.kDay), (2, 12, 30));
    expect((setK.kYear, setK.kMonth, setK.kDay), (2, 13, 3));
    expect((wepK.kYear, wepK.kMonth, wepK.kDay), (3, 1, 1));
    expect(closing.scheduleType, 'local_dusk');
    expect(setDay.scheduleType, 'local_astronomical_dawn');
    expect(wep.scheduleType, 'local_astronomical_dawn');
  });

  test('enrollment window is M12 D28 through before M13 D1', () {
    final window = daysOutsideYearEnrollmentWindowForClosingYear(
      2,
      TrackSkyTimeZone.pacific,
    );
    final openK = KemeticMath.fromGregorian(window.opensAtLocal);
    final closeK = KemeticMath.fromGregorian(window.closesAtLocal);

    expect((openK.kYear, openK.kMonth, openK.kDay), (2, 12, 28));
    expect((closeK.kYear, closeK.kMonth, closeK.kDay), (2, 13, 1));
    expect(
      daysOutsideYearEnrollmentWindowForStartDate(
        window.opensAtLocal,
        TrackSkyTimeZone.pacific,
        now: window.opensAtLocal,
      )?.closingKYear,
      2,
    );
    expect(
      daysOutsideYearEnrollmentWindowForStartDate(
        window.opensAtLocal.add(const Duration(days: 1)),
        TrackSkyTimeZone.pacific,
        now: window.opensAtLocal,
      ),
      isNull,
    );
    expect(
      daysOutsideYearEnrollmentIsOpen(
        window,
        now: window.opensAtLocal.add(const Duration(hours: 1)),
      ),
      isTrue,
    );
    expect(
      daysOutsideYearEnrollmentIsOpen(window, now: window.closesAtLocal),
      isFalse,
    );
  });

  test('payloads are JSON-safe and do not carry private reflections', () {
    final event = kDaysOutsideEvents.last;
    final schedule = daysOutsideScheduleForEvent(
      event: event,
      closingKYear: 2,
      timezone: TrackSkyTimeZone.eastern,
    );
    final payload = daysOutsideBehaviorPayload(
      event: event,
      closingKYear: 2,
      timezoneKey: TrackSkyTimeZone.eastern.key,
      ianaTimezone: TrackSkyTimeZone.eastern.ianaName,
      scheduleType: schedule.scheduleType,
      referenceLocationName: schedule.referenceLocationName,
      usedFallback: schedule.usedFallback,
      variant: DaysOutsideCopyVariant.standard,
    );

    expect(jsonDecode(jsonEncode(payload)), isA<Map<String, dynamic>>());
    expect(payload['kind'], 'maat_days_outside_year');
    expect(payload['flow_key'], kDaysOutsideTheYearFlowKey);
    expect(payload['closing_k_year'], 2);
    expect(payload['event_k_year'], 3);
    expect(payload['missed_event_rule'], 'expire_no_replay');
    expect(payload.toString(), isNot(contains('year intention text')));
  });

  test('Set solar eclipse copy variant is date flagged', () {
    final event = kDaysOutsideEvents[3];
    expect(event.kind, DaysOutsideEventKind.birthSet);
    expect(
      daysOutsideCopyVariantForEvent(
        event: event,
        gregorianDate: DateTime(2026, 8, 12),
      ),
      DaysOutsideCopyVariant.setSolarEclipse2026,
    );
  });

  test('detail text names confidence, privacy, and one-word share', () {
    final detail = daysOutsideDetailText(
      kDaysOutsideEvents.last,
      closingKYear: 2,
      variant: DaysOutsideCopyVariant.standard,
    );

    expect(detail, contains(kDaysOutsideTheYearConfidenceLabel));
    expect(detail, contains('Server events contain only generic steps'));
    expect(detail, contains('share one word only'));
  });

  test('calendar UI and join branch use designated year-closing windows', () {
    final detailSource = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final pageSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final schedulerSource = File(
      'lib/features/calendar/the_days_outside_year_scheduler.dart',
    ).readAsStringSync();

    expect(detailSource, contains('_pickDaysOutsideYearWindowDate'));
    expect(
      detailSource,
      contains('designated year-closing enrollment windows'),
    );
    expect(detailSource, contains('Locked Until Year Close'));
    expect(pageSource, contains('_MaatFlowTemplateKind.daysOutsideTheYear'));
    expect(pageSource, contains('daysOutsideYearEnrollmentIsOpen'));
    expect(pageSource, contains('doy_kyear='));
    expect(schedulerSource, contains('daysOutsideEventGregorian'));
    expect(
      pageSource,
      isNot(contains('startDate.add(Duration(days: event.eventNumber')),
    );
  });
}
