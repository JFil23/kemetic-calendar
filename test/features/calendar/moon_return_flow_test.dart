import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/moon_return_astronomy.dart';
import 'package:mobile/features/calendar/moon_return_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('enrollment window opens two local dawns before new moon day', () {
    final window = moonReturnEnrollmentWindowForStartDate(
      DateTime(2026, 8, 10),
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 8, 1, 12),
    );

    expect(window, isNotNull);
    expect(window!.newMoonDateIso, '2026-08-12');
    expect(window.enrollProminence, MoonReturnCopyVariant.wepRonpetNew);
    expect(window.opensAtLocal.year, 2026);
    expect(window.opensAtLocal.month, 8);
    expect(window.opensAtLocal.day, 10);
    expect(window.closesAtLocal.year, 2026);
    expect(window.closesAtLocal.month, 8);
    expect(window.closesAtLocal.day, 12);
    expect(window.closesAtLocal.hour, 23);
  });

  test('future new moon window rows are selectable before they open', () {
    final window = moonReturnNextEnrollmentWindow(
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 5, 23, 18),
    );
    final selected = moonReturnEnrollmentWindowForStartDate(
      window.opensAtLocal,
      TrackSkyTimeZone.pacific,
      now: DateTime.utc(2026, 5, 23, 18),
    );

    expect(window.newMoonDateIso, '2026-06-14');
    expect(selected?.newMoonDateIso, window.newMoonDateIso);
    expect(
      moonReturnEnrollmentIsOpen(window, now: DateTime.utc(2026, 5, 23, 18)),
      isFalse,
    );
  });

  test(
    'safe enrollment resolver returns null for unavailable selected dates',
    () {
      final window = resolveMoonReturnEnrollmentWindowSafely(
        timezone: TrackSkyTimeZone.pacific,
        startDate: DateTime(2099, 1, 1),
        now: DateTime.utc(2026, 5, 23, 18),
      );

      expect(window, isNull);
    },
  );

  test('enrollment creates Empty Eye first and following Whole Eye events', () {
    final window = moonReturnEnrollmentWindowForStartDate(
      DateTime(2026, 8, 10),
      TrackSkyTimeZone.eastern,
      now: DateTime.utc(2026, 8, 1, 12),
    )!;
    final occurrences = moonReturnOccurrencesForWindow(
      window: window,
      horizonMonths: 2,
    );

    expect(occurrences.first.kind, MoonReturnEventKind.emptyEye);
    expect(occurrences.first.phaseDateIso, '2026-08-12');
    expect(occurrences.first.startLocal.hour, inInclusiveRange(18, 21));
    expect(occurrences.first.variant, MoonReturnCopyVariant.wepRonpetNew);
    final wholeEye = occurrences.firstWhere(
      (occurrence) => occurrence.kind == MoonReturnEventKind.wholeEye,
    );
    expect(wholeEye.scheduleType, 'local_moonrise');
    expect(
      occurrences.any(
        (occurrence) =>
            occurrence.kind == MoonReturnEventKind.wholeEye &&
            occurrence.variant == MoonReturnCopyVariant.lunarEclipseFull,
      ),
      isTrue,
    );
  });

  test(
    'blue moon is a bonus only for users enrolled before first full moon',
    () {
      final aprilWindow = moonReturnEnrollmentWindowForStartDate(
        DateTime(2026, 4, 15),
        TrackSkyTimeZone.eastern,
        now: DateTime.utc(2026, 4, 1, 12),
      )!;
      final aprilOccurrences = moonReturnOccurrencesForWindow(
        window: aprilWindow,
        horizonMonths: 3,
      );
      expect(
        aprilOccurrences.any(
          (occurrence) =>
              occurrence.phaseDateIso == '2026-05-31' &&
              occurrence.isBonusBlueMoon &&
              occurrence.variant == MoonReturnCopyVariant.blueMoonFull,
        ),
        isTrue,
      );

      final mayWindow = moonReturnEnrollmentWindowForStartDate(
        DateTime(2026, 5, 14),
        TrackSkyTimeZone.eastern,
        now: DateTime.utc(2026, 5, 1, 12),
      )!;
      final mayOccurrences = moonReturnOccurrencesForWindow(
        window: mayWindow,
        horizonMonths: 2,
      );
      expect(
        mayOccurrences.any(
          (occurrence) => occurrence.phaseDateIso == '2026-05-31',
        ),
        isFalse,
      );
    },
  );

  test('payloads are JSON-safe and omit observed_partly', () {
    final window = moonReturnEnrollmentWindowForStartDate(
      DateTime(2025, 3, 27),
      TrackSkyTimeZone.eastern,
      now: DateTime.utc(2025, 3, 1, 12),
    )!;
    final occurrence = moonReturnOccurrencesForWindow(
      window: window,
      horizonMonths: 1,
    ).first;
    final payload = moonReturnBehaviorPayload(
      occurrence: occurrence,
      lens: MoonReturnLens.heru,
    );

    expect(occurrence.variant, MoonReturnCopyVariant.solarEclipseNew);
    expect(payload['flow_key'], 'the-moon-return');
    expect(payload['completion_options'], <String>['observed', 'skipped']);
    expect(payload.toString(), isNot(contains('observed_partly')));
    expect(jsonDecode(jsonEncode(payload)), isA<Map<String, dynamic>>());
    final detail = moonReturnDetailText(occurrence, lens: MoonReturnLens.heru);
    expect(detail, contains('Purpose\n'));
    expect(detail, isNot(contains('Confidence\n')));
  });

  test('calendar UI and join branch enforce designated windows', () {
    final detailSource = File(
      'lib/features/calendar/calendar_maat_flows.dart',
    ).readAsStringSync();
    final pageSource = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();

    expect(detailSource, contains('_pickMoonReturnWindowDate'));
    expect(detailSource, contains('designated new-moon enrollment windows'));
    expect(detailSource, contains('Add Flow'));
    expect(pageSource, contains('_MaatFlowTemplateKind.moonReturn'));
    expect(pageSource, contains('_resolveMountedMoonReturnJoinWindow'));
    expect(pageSource, contains('resolveMoonReturnEnrollmentWindowSafely'));
    expect(pageSource, isNot(contains('moonReturnEnrollmentIsOpen')));
    expect(pageSource, contains('moonReturnClientEventId'));
    expect(pageSource, isNot(contains('kMoonReturnDays')));
  });
}
