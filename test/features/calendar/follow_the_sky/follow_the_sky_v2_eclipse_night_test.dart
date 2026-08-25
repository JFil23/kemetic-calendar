import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Cut 1.1: one observing night / one function when Full Moon merges a lunar eclipse.
void main() {
  late SkyCatalog catalog;
  late TrackSkyMaterializer materializer;
  late TrackSkyEnrollmentService enrollment;

  const mergedNights = <(String fullMoonId, String eclipseId, String title)>[
    (
      'full-moon-2026-08-28',
      'lunar-eclipse-2026-08-28',
      'Full Moon + Partial Lunar Eclipse',
    ),
    (
      'full-moon-2027-02-20',
      'lunar-eclipse-2027-02-20',
      'Full Moon + Penumbral Lunar Eclipse',
    ),
    (
      'full-moon-2027-07-18',
      'lunar-eclipse-2027-07-18',
      'Full Moon + Slight Penumbral Lunar Eclipse',
    ),
    (
      'full-moon-2027-08-17',
      'lunar-eclipse-2027-08-17',
      'Full Moon + Penumbral Lunar Eclipse',
    ),
    (
      'full-moon-2028-01-12',
      'lunar-eclipse-2028-01-12',
      'Full Moon + Partial Lunar Eclipse',
    ),
  ];

  setUpAll(() {
    tzdata.initializeTimeZones();
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    materializer = TrackSkyMaterializer(
      toLocal: (utc, iana) => tz.TZDateTime.from(utc.toUtc(), tz.getLocation(iana)),
      toUtc: (local, iana) {
        final location = tz.getLocation(iana);
        return tz.TZDateTime(
          location,
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
          local.second,
        ).toUtc();
      },
    );
    enrollment = TrackSkyEnrollmentService(
      materializer: materializer,
      visibilityService: const SkyVisibilityService(),
    );
  });

  test('canonical catalog stays 70; observing nights stay 65', () {
    expect(catalog.events.length, 70);
    expect(catalog.observingNightCount, 65);
    expect(catalog.eclipseFullMoonNightCount, 5);
    expect(catalog.materializableEvents.length, 65);
  });

  test('all five merged nights: one occurrence, Reconsider, companion preserved', () {
    final materializedIds = <String>{};

    for (final row in mergedNights) {
      final anchor = catalog.byId(row.$1)!;
      expect(anchor.function, SkyEventFunction.reveal,
          reason: 'raw Full Moon fact remains Reveal');

      final night = catalog.observingNight(anchor);
      expect(night.companion?.id, row.$2);
      expect(night.function, SkyEventFunction.reconsider);
      expect(night.displayName, row.$3);
      expect(night.skyEventId, row.$1);

      final occ = materializer.materialize(
        event: anchor,
        night: night,
        ianaTimeZone: 'America/Los_Angeles',
      );

      expect(occ.skyEventId, row.$1);
      expect(occ.title, row.$3);
      expect(materializedIds.add(occ.skyEventId), isTrue,
          reason: 'exactly one materialized occurrence per night');

      final payload = occ.behaviorPayload;
      expect(TrackSkyEventOwnership.skyEventIdFromPayload(payload), row.$1);
      expect(
        TrackSkyEventOwnership.companionIdsFromPayload(payload),
        [row.$2],
      );
      expect(
        TrackSkyEventOwnership.resolvedFunctionFromPayload(payload),
        'reconsider',
      );
      expect(
        TrackSkyEventOwnership.displayNameFromPayload(payload),
        row.$3,
      );
      expect(TrackSkyEventOwnership.isEclipseObservingNight(payload), isTrue);

      // History / day sheet: eclipse night, not ordinary Full Moon.
      final teaser = FollowSkyDayDetail.teaser(
        title: 'Full Moon',
        skyEventId: row.$1,
        catalog: catalog,
        behaviorPayload: payload,
      );
      final meaning = const TurningMeaningResolver().forNight(night);
      expect(teaser, contains(row.$3));
      expect(teaser, contains(meaning.titledSignificanceLabel));
      expect(teaser, isNot(contains('Reconsider')));

      final detail = FollowSkyDayDetail.displayDetail(
        eventDetail: occ.detail,
        skyEventId: row.$1,
        catalog: catalog,
        behaviorPayload: payload,
      );
      expect(detail, contains(meaning.significanceLabel));
      expect(detail, isNot(contains('Function: Reconsider')));
      expect(detail, contains(row.$2));
    }

    expect(materializedIds.length, 5);
  });

  test('enrollment never double-books eclipse companions as separate nights', () {
    final draft = enrollment.buildJoinDraft(
      catalog: catalog,
      nowUtc: DateTime.utc(2026, 8, 1),
      ianaTimeZone: 'America/Los_Angeles',
      timezoneKey: 'pacific',
    );

    final ids = draft.occurrences.map((o) => o.skyEventId).toList();
    expect(ids.toSet().length, ids.length, reason: 'no duplicate skyEventId');

    for (final row in mergedNights) {
      expect(ids.where((id) => id == row.$1).length, 1);
      expect(ids.contains(row.$2), isFalse,
          reason: 'companion eclipse must not materialize alone');
    }

    // One notification surface per observing night (unique client identity = skyEventId).
    final eclipseOccs = [
      for (final o in draft.occurrences)
        if (TrackSkyEventOwnership.isEclipseObservingNight(o.behaviorPayload)) o,
    ];
    expect(eclipseOccs.length, 5);
    expect(
      eclipseOccs.map((o) => o.skyEventId).toSet().length,
      5,
      reason: 'no duplicate notification identity for eclipse nights',
    );
  });
}
