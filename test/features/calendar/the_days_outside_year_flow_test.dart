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

  test(
    'safe enrollment resolver returns null for unavailable selected dates',
    () {
      final window = resolveDaysOutsideYearEnrollmentWindowSafely(
        timezone: TrackSkyTimeZone.pacific,
        startDate: DateTime(2099, 1, 1),
        now: DateTime.utc(2026, 5, 23, 18),
      );

      expect(window, isNull);
    },
  );

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

  test(
    'detail text names one-word share without disclaimer copy or source',
    () {
      final detail = daysOutsideDetailText(
        kDaysOutsideEvents.last,
        closingKYear: 2,
        variant: DaysOutsideCopyVariant.standard,
      );

      expect(detail, isNot(contains('Confidence\n')));
      expect(detail, isNot(contains('Private note:')));
      expect(detail, isNot(contains('Source\n')));
      expect(
        detail,
        isNot(contains('Server events contain only generic steps')),
      );
      expect(detail, contains('share one word only'));
    },
  );

  test('copy keeps fixed dates and no-replay timing anchors explicit', () {
    final yearClose = kDaysOutsideEvents.first;
    final outsideDays = kDaysOutsideEvents.skip(1).take(5).toList();
    final wepRonpet = kDaysOutsideEvents.last;

    expect((yearClose.kMonth, yearClose.kDay), (12, 30));
    expect(
      outsideDays.map((event) => (event.kMonth, event.kDay)).toList(),
      <(int, int)>[(13, 1), (13, 2), (13, 3), (13, 4), (13, 5)],
    );
    expect((wepRonpet.kMonth, wepRonpet.kDay), (1, 1));
    expect(wepRonpet.title, contains('Wep Ronpet'));

    final yearCloseDetail = daysOutsideDetailText(
      yearClose,
      closingKYear: 2,
      variant: DaysOutsideCopyVariant.standard,
    );
    final firstOutsideDetail = daysOutsideDetailText(
      outsideDays.first,
      closingKYear: 2,
      variant: DaysOutsideCopyVariant.standard,
    );
    final wepRonpetDetail = daysOutsideDetailText(
      wepRonpet,
      closingKYear: 2,
      variant: DaysOutsideCopyVariant.standard,
    );

    expect(yearCloseDetail, contains('Year 2 · Month 12 · Day 30'));
    expect(firstOutsideDetail, contains('Year 2 · Month 13 · Day 1'));
    expect(wepRonpetDetail, contains('Year 3 · Month 1 · Day 1'));
    expect(
      yearCloseDetail,
      contains(
        'This event belongs to this Kemetic calendar day only; missed days are not replayed later in the year.',
      ),
    );
  });

  test('copy keeps water, birth-day, and Wep Ronpet actions clean', () {
    final event0 = kDaysOutsideEvents[0];
    final event1 = kDaysOutsideEvents[1];
    final event2 = kDaysOutsideEvents[2];
    final event3 = kDaysOutsideEvents[3];
    final event4 = kDaysOutsideEvents[4];
    final event5 = kDaysOutsideEvents[5];
    final event6 = kDaysOutsideEvents[6];

    expect(event0.steps, <String>[
      'Place water on the surface as you begin naming.',
      'Name one thing the year gave you that you did not expect.',
      'Name one thing the year asked of you that you did not fully give.',
      'Name one thing that carries across the threshold into the five days.',
    ]);
    expect(
      daysOutsideDetailText(
        event0,
        closingKYear: 2,
        variant: DaysOutsideCopyVariant.standard,
      ),
      contains('The water witnesses the closing while it is happening.'),
    );

    expect(event1.steps.first, 'Pause at dawn before ordinary work begins.');
    expect(event2.steps.take(3).toList(), <String>[
      'Go outside at dawn.',
      'Face east.',
      'Look at the horizon before looking at anything else.',
    ]);
    expect(
      event3.steps,
      contains('Ask where force in you or around you has been misdirected.'),
    );
    expect(
      event4.steps,
      contains('Name the preparation your unspoken truth requires.'),
    );
    expect(
      event5.steps,
      contains('Name the threshold you have avoided looking at directly.'),
    );

    expect(event6.steps, <String>[
      'At dawn, wash your hands and face before anything else.',
      'Set fresh water on the surface.',
      'Say: This water is for the year that opens.',
      'Speak each of the five names.',
      'Speak one word for the specific quality you received as it applies to your life entering this year.',
      'Name one orienting intention for the new year.',
      'Drink the water.',
    ]);
    expect(
      daysOutsideDetailText(
        event6,
        closingKYear: 2,
        variant: DaysOutsideCopyVariant.standard,
      ),
      contains('ordinary time restarts clean'),
    );
  });

  test('words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];

    for (final event in kDaysOutsideEvents) {
      for (final pattern in _daysOutsideWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add('Event ${event.eventNumber}: ${event.spokenLine}');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('steps keep source-note and rationale phrases out of actions', () {
    final issues = <String>[];

    for (final event in kDaysOutsideEvents) {
      for (final step in event.steps) {
        if (_daysOutsideRationalePhrasePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('optional detail copy does not duplicate required steps', () {
    for (final event in <DaysOutsideEvent>[
      kDaysOutsideEvents.first,
      kDaysOutsideEvents.last,
    ]) {
      final detail = daysOutsideDetailText(
        event,
        closingKYear: 2,
        variant: DaysOutsideCopyVariant.standard,
      );

      for (final step in event.steps) {
        final occurrences = RegExp(RegExp.escape(step)).allMatches(detail);
        expect(occurrences, hasLength(1), reason: step);
      }
    }
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
    expect(detailSource, contains('Add Flow'));
    expect(detailSource, isNot(contains('Closing Kemetic Year')));
    expect(detailSource, isNot(contains('Kemetic Year')));
    expect(pageSource, contains('_MaatFlowTemplateKind.daysOutsideTheYear'));
    expect(pageSource, contains('_resolveMountedDaysOutsideYearJoinWindow'));
    expect(
      pageSource,
      contains('resolveDaysOutsideYearEnrollmentWindowSafely'),
    );
    expect(pageSource, isNot(contains('daysOutsideYearEnrollmentIsOpen')));
    expect(pageSource, contains('doy_kyear='));
    expect(schedulerSource, contains('daysOutsideEventGregorian'));
    expect(
      pageSource,
      isNot(contains('startDate.add(Duration(days: event.eventNumber')),
    );
  });
}

final _daysOutsideWordsStageDirectionPatterns = <RegExp>[
  RegExp(
    r'^\s*(name one|place|wash|set fresh|speak each|drink)\b',
    caseSensitive: false,
  ),
  RegExp(r'\bbefore anything else\b', caseSensitive: false),
];

final _daysOutsideRationalePhrasePattern = RegExp(
  r'\b(The first day of the five|ordinary logic|This is not symbolic|directional and physical|Undirected force does not disappear|Aset did not|prepared the conditions|Nebet-Het.s role|Opening of the Year begins|ordinary time restarts|source|because)\b',
  caseSensitive: false,
);
