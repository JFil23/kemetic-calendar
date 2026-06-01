import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_wag_enrollment.dart';
import 'package:mobile/features/calendar/the_wag_flow.dart';
import 'package:mobile/features/calendar/the_wag_scheduler.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

void main() {
  test('defines nine annual Wag events on fixed Kemetic Month 1 days', () {
    expect(kWagEvents, hasLength(9));
    expect(kWagEvents.map((event) => event.kemeticDay).toList(), <int>[
      1,
      5,
      9,
      11,
      17,
      18,
      21,
      25,
      29,
    ]);
    expect(kWagEvents[4].schedule, WagScheduleKind.solarDusk);
    expect(kWagEvents[5].schedule, WagScheduleKind.feastMorning);
    expect(kWagEvents.last.sharePromptOnComplete, isTrue);
  });

  test('maps M1 D18 through KemeticMath for the enrolled kYear', () {
    final gregorian = wagEventGregorian(2, 18);
    final kemetic = KemeticMath.fromGregorian(gregorian);

    expect(kemetic.kYear, 2);
    expect(kemetic.kMonth, 1);
    expect(kemetic.kDay, 18);
  });

  test('schedules D17 vigil at dusk and D18 feast in the morning', () {
    final vigil = wagScheduleForEvent(
      event: kWagEvents[4],
      kYear: 2,
      timezone: TrackSkyTimeZone.pacific,
    );
    final feast = wagScheduleForEvent(
      event: kWagEvents[5],
      kYear: 2,
      timezone: TrackSkyTimeZone.pacific,
    );

    expect(vigil.scheduleType, 'local_dusk');
    expect(vigil.startLocal.hour, inInclusiveRange(17, 21));
    expect(vigil.startLocal.hour, isNot(11));
    expect(feast.scheduleType, 'fixed_local_feast_morning');
    expect(feast.startLocal.hour, 9);
  });

  test('Wep Ronpet picker rows are valid before their 48h window opens', () {
    final window = wagNextEnrollmentWindow(
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 5, 23, 18),
    );

    expect(window.closesAtLocal.difference(window.opensAtLocal).inHours, 48);
    expect(
      wagEnrollmentIsOpen(window, now: DateTime.utc(2026, 5, 23, 18)),
      isFalse,
    );
    expect(
      wagEnrollmentWindowForStartDate(
        DateTime(
          window.opensAtLocal.year,
          window.opensAtLocal.month,
          window.opensAtLocal.day,
        ),
        TrackSkyTimeZone.pacific,
        now: DateTime.utc(2026, 5, 23, 18),
      )?.kYear,
      window.kYear,
    );
  });

  test(
    'safe enrollment resolver returns null for unavailable selected dates',
    () {
      final window = resolveWagEnrollmentWindowSafely(
        timezone: TrackSkyTimeZone.pacific,
        startDate: DateTime(2099, 1, 1),
        now: DateTime.utc(2026, 5, 23, 18),
      );

      expect(window, isNull);
    },
  );

  test('payloads are JSON-safe and Event 6 supports names_spoken', () {
    final event = kWagEvents[5];
    final schedule = wagScheduleForEvent(
      event: event,
      kYear: 2,
      timezone: TrackSkyTimeZone.eastern,
    );
    final payload = wagBehaviorPayload(
      event: event,
      kYear: 2,
      timezoneKey: TrackSkyTimeZone.eastern.key,
      ianaTimezone: TrackSkyTimeZone.eastern.ianaName,
      scheduleType: schedule.scheduleType,
      referenceLocationName: schedule.referenceLocationName,
      usedFallback: schedule.usedFallback,
      lens: WagLens.ausar,
      variant: wagCopyVariantForEvent(event: event, kYear: 2),
    );

    expect(jsonDecode(jsonEncode(payload)), isA<Map<String, dynamic>>());
    expect(payload['kind'], 'maat_wag_event');
    expect(payload['flow_key'], 'the-wag');
    expect(payload['completion_options'], contains('names_spoken'));
    expect(payload.toString(), isNot(contains('grandmother')));
  });

  test(
    'detail text names offerings, private note, lens, next Wag, and no source',
    () {
      final event = kWagEvents.last;
      final detail = wagDetailText(
        event,
        lens: WagLens.anpu,
        nextWagDate: wagNextFeastGregorian(2),
      );

      expect(detail, contains(kTheWagConfidenceLabel));
      expect(detail, contains('Private note: keep ancestor names'));
      expect(detail, isNot(contains('Source\n')));
      expect(detail, isNot(contains('stay on this device')));
      expect(detail, contains('Water first'));
      expect(detail, contains('Lens\nLet Anpu'));
      expect(detail, contains('Next Wag\n'));
    },
  );

  test(
    'calendar UI and join branch use designated Wag windows and M1 dates',
    () {
      final detailSource = File(
        'lib/features/calendar/calendar_maat_flows.dart',
      ).readAsStringSync();
      final pageSource = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final schedulerSource = File(
        'lib/features/calendar/the_wag_scheduler.dart',
      ).readAsStringSync();

      expect(detailSource, contains('_pickWagWindowDate'));
      expect(
        detailSource,
        contains('designated Wep Ronpet enrollment windows'),
      );
      expect(detailSource, contains('Add Flow'));
      expect(detailSource, isNot(contains('Kemetic Year')));
      expect(pageSource, contains('_MaatFlowTemplateKind.theWag'));
      expect(pageSource, contains('_resolveMountedWagJoinWindow'));
      expect(pageSource, contains('resolveWagEnrollmentWindowSafely'));
      expect(pageSource, isNot(contains('wagEnrollmentIsOpen')));
      expect(schedulerSource, contains('wagEventGregorian'));
      expect(pageSource, contains('wag_kyear='));
      expect(
        pageSource,
        isNot(contains('startDate.add(Duration(days: event.kemeticDay')),
      );
    },
  );
}
