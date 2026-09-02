import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/calendar/maat_flow_identity.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_policy.dart';
import 'package:mobile/features/calendar/maat_flow_temporal_resolver.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:mobile/features/calendar/track_sky_timezone.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SkyCatalog catalog;
  late TrackSkyEnrollmentService enrollment;
  const resolver = MaatFlowTemporalResolver();

  MaatFlowTemporalContext context(DateTime nowUtc) {
    return MaatFlowTemporalContext.fromInstant(
      nowUtc: nowUtc,
      ianaTimeZone: TrackSkyTimeZone.pacific.ianaName,
    );
  }

  MaatFlowTemporalResolution resolve(MaatFlowKind kind, DateTime nowUtc) {
    return resolver.resolve(
      kind: kind,
      context: context(nowUtc),
      skyCatalog: kind == MaatFlowKind.trackSky ? catalog : null,
      skyEnrollment: kind == MaatFlowKind.trackSky ? enrollment : null,
      scheduleTimeZone: TrackSkyTimeZone.pacific,
    );
  }

  setUpAll(() {
    tzdata.initializeTimeZones();
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    enrollment = TrackSkyEnrollmentService(
      materializer: TrackSkyMaterializer(
        toLocal: (utc, iana) =>
            tz.TZDateTime.from(utc.toUtc(), tz.getLocation(iana)),
        toUtc: (local, iana) => tz.TZDateTime(
          tz.getLocation(iana),
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
          local.second,
          local.millisecond,
          local.microsecond,
        ).toUtc(),
      ),
      visibilityService: const SkyVisibilityService(),
    );
  });

  test('every registered Flow declares one temporal policy', () {
    expect(kMaatFlowCatalog.keys.toSet(), MaatFlowKind.values.toSet());
    expect(
      kMaatFlowCatalog.values
          .where(
            (entry) =>
                entry.temporalPolicy.kind ==
                    MaatFlowTemporalPolicyKind.relativeCalendarDays &&
                entry.temporalPolicy.dayOffset == null,
          )
          .toList(),
      isEmpty,
    );
    expect(
      maatFlowCatalogEntry(MaatFlowKind.offeringTable).temporalPolicy.dayOffset,
      1,
    );
    expect(
      maatFlowCatalogEntry(MaatFlowKind.readingHouse).temporalPolicy.dayOffset,
      3,
    );
    expect(
      maatFlowCatalogEntry(MaatFlowKind.trackSky).temporalPolicy.kind,
      MaatFlowTemporalPolicyKind.nextEligibleSkyEvent,
    );
  });

  test('one captured clock instant owns the local and Kemetic present day', () {
    var clockCalls = 0;
    final captured = MaatFlowTemporalContext.capture(
      ianaTimeZone: TrackSkyTimeZone.pacific.ianaName,
      clock: () {
        clockCalls += 1;
        return DateTime.utc(2026, 9, 2, 18, 45);
      },
    );

    expect(clockCalls, 1);
    expect(captured.nowUtc, DateTime.utc(2026, 9, 2, 18, 45));
    expect(captured.presentLocalDate, DateTime(2026, 9, 2));
    expect(captured.presentKemeticDate, (kYear: 2, kMonth: 6, kDay: 17));
  });

  test('Offering Table is always tomorrow with civil boundary arithmetic', () {
    final cases = <(DateTime, DateTime)>[
      (DateTime.utc(2026, 9, 2, 14), DateTime(2026, 9, 3)),
      (DateTime.utc(2026, 9, 3, 6, 59), DateTime(2026, 9, 3)),
      (DateTime.utc(2026, 9, 3, 7, 1), DateTime(2026, 9, 4)),
      (DateTime.utc(2026, 2, 1, 4), DateTime(2026, 2, 1)),
      (DateTime.utc(2027, 1, 1, 4), DateTime(2027, 1, 1)),
      (DateTime.utc(2026, 3, 8, 8, 30), DateTime(2026, 3, 9)),
    ];

    for (final (nowUtc, expected) in cases) {
      expect(
        resolve(MaatFlowKind.offeringTable, nowUtc).startDate,
        expected,
        reason: nowUtc.toIso8601String(),
      );
    }
  });

  test('Reading House starts in three days, then uses ten-day checkpoints', () {
    final resolution = resolve(
      MaatFlowKind.readingHouse,
      DateTime.utc(2026, 9, 2, 18),
    );
    final dates = readingHouseResolvedStarterDates(
      resolution.startDate,
      kReadingHouseSittings,
    );

    expect(resolution.startDate, DateTime(2026, 9, 5));
    expect(dates, <DateTime>[
      DateTime(2026, 9, 5),
      DateTime(2026, 9, 15),
      DateTime(2026, 9, 25),
    ]);
    expect(dates[1].difference(dates[0]).inDays, 10);
    expect(dates[2].difference(dates[1]).inDays, 10);
  });

  test('Reading House preserves an explicit sitting date', () {
    final sittings = <ReadingHouseSitting>[
      kReadingHouseSittings[0],
      kReadingHouseSittings[1].copyWith(scheduledDate: DateTime(2026, 10, 4)),
      kReadingHouseSittings[2],
    ];

    expect(
      readingHouseResolvedStarterDates(DateTime(2026, 9, 5), sittings),
      <DateTime>[
        DateTime(2026, 9, 5),
        DateTime(2026, 10, 4),
        DateTime(2026, 9, 25),
      ],
    );
  });

  test('Follow the Sky starts with the autumn equinox on September 2', () {
    final resolution = resolve(
      MaatFlowKind.trackSky,
      DateTime.utc(2026, 9, 2, 18),
    );

    expect(resolution.firstSkyNight?.skyEventId, 'autumn-equinox-2026');
    expect(
      resolution.skyNights.map((night) => night.skyEventId),
      isNot(contains('full-moon-2026-08-28')),
    );
    expect(
      resolution.skyNights.map((night) => night.skyEventId),
      isNot(contains('lunar-eclipse-2026-08-28')),
    );
  });

  test('specialist policies require an explicit schedule timezone', () {
    expect(
      () => resolver.resolve(
        kind: MaatFlowKind.trackSky,
        context: MaatFlowTemporalContext.fromInstant(
          nowUtc: DateTime.utc(2026, 9, 2, 18),
          ianaTimeZone: 'Asia/Kathmandu',
        ),
        skyCatalog: catalog,
        skyEnrollment: enrollment,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('Follow the Sky advances only after the effective event window', () {
    final equinoxNight = catalog.observingNight(
      catalog.byId('autumn-equinox-2026')!,
    );
    final equinoxOccurrence = enrollment
        .buildCanonicalOccurrences(
          catalog: catalog,
          ianaTimeZone: TrackSkyTimeZone.pacific.ianaName,
          nights: <SkyObservingNight>[equinoxNight],
        )
        .single;

    final during = resolve(MaatFlowKind.trackSky, equinoxOccurrence.endsAtUtc);
    final after = resolve(
      MaatFlowKind.trackSky,
      equinoxOccurrence.endsAtUtc.add(const Duration(microseconds: 1)),
    );

    expect(during.firstSkyNight?.skyEventId, 'autumn-equinox-2026');
    expect(after.firstSkyNight?.skyEventId, 'full-moon-2026-09-26');
    expect(after.startDate, DateTime(2026, 9, 26));
    expect(
      after.context.localDateForUtc(after.firstSkyNight!.primaryInstantUtc),
      DateTime(2026, 9, 26),
    );
    expect(KemeticMath.fromGregorian(after.startDate), (
      kYear: 2,
      kMonth: 7,
      kDay: 11,
    ));
  });

  test('Follow the Sky preview list is the exact Carry occurrence source', () {
    final resolution = resolve(
      MaatFlowKind.trackSky,
      DateTime.utc(2026, 9, 2, 18),
    );
    final draft = enrollment.buildJoinDraft(
      catalog: catalog,
      eligibleNights: resolution.skyNights,
      ianaTimeZone: TrackSkyTimeZone.pacific.ianaName,
    );

    expect(draft.occurrences.first.skyEventId, 'autumn-equinox-2026');
    expect(
      draft.occurrences.map((occurrence) => occurrence.skyEventId),
      resolution.skyNights.map((night) => night.skyEventId),
    );
  });

  testWidgets(
    'Follow the Sky worked example, first preview, and Carry share one result',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TrackSkyEnrollmentDraft? carriedDraft;

      await tester.pumpWidget(
        MaterialApp(
          home: FollowSkyDetailPage(
            initialCatalog: catalog,
            now: DateTime.utc(2026, 9, 2, 18),
            onJoin: (draft) async => carriedDraft = draft,
          ),
        ),
      );
      await tester.pumpAndSettle();

      const equinoxMeaning = TurningMeaning(
        observation:
            'Day and night come nearly even. Then the balance begins to turn.',
        significanceLabel: 'BALANCE',
        personalQuestion:
            'What do you want to make more room for so it can grow?',
      );
      expect(
        find.byKey(
          const ValueKey<String>('follow-sky-preview-autumn-equinox-2026'),
        ),
        findsOneWidget,
      );
      expect(find.text(equinoxMeaning.observation), findsWidgets);
      expect(find.text(equinoxMeaning.personalQuestion), findsWidgets);
      expect(
        find.text(TurningMeaningResolver.approvedLunarEclipse.observation),
        findsNothing,
      );

      await tester
          .state<FollowSkyDetailPageState>(find.byType(FollowSkyDetailPage))
          .joinFromDock();
      await tester.pumpAndSettle();

      expect(carriedDraft, isNotNull);
      expect(carriedDraft!.occurrences.first.skyEventId, 'autumn-equinox-2026');
    },
  );
}
