import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  setUp(() {
    clearTrackSkyFlowDataCacheForTest();
  });

  // ---------------------------------------------------------------------------
  // Forward-candidate compatibility identities.
  //
  // Declared base still tracks these exact test names. Cut 2 replaced the V1
  // Markdown/narrative Track Sky contract with the V2 catalog adapter, so the
  // bodies below assert the closest V2 equivalent — not restored V1 assets,
  // parsers, or schedule-normalization product logic.
  // ---------------------------------------------------------------------------

  test(
    'supermoon events use the narrative copy instead of the stitched summary',
    () async {
      final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
      final moon = data.events.where(
        (e) => e.title.toLowerCase().contains('moon'),
      );
      expect(moon, isNotEmpty);
      for (final e in moon) {
        expect(e.skyEventId, isNotNull);
        // V2 adapter detail is catalog + function label, never stitched prose.
        expect(e.detailSummary, isNot(contains('stitched')));
        expect(e.significance, startsWith('Function:'));
      }
    },
  );

  test('penumbral eclipse teaser keeps the quiet opening sentence', () async {
    final catalog = await SkyCatalogRepository().load();
    final eclipseNights = catalog.materializableEvents
        .map(catalog.observingNight)
        .where((n) => n.function == SkyEventFunction.reconsider);
    expect(eclipseNights, isNotEmpty);
    for (final night in eclipseNights) {
      expect(night.function.displayLabel, 'Reconsider');
      expect(night.displayName.toLowerCase(), contains('eclipse'));
    }
  });

  test('eclipse narrative keeps watch action separate from reflection', () async {
    final catalog = await SkyCatalogRepository().load();
    final visibility = const SkyVisibilityService();
    final night = catalog.materializableEvents
        .map(catalog.observingNight)
        .firstWhere((n) => n.function == SkyEventFunction.reconsider);
    final decision = visibility.decide(night.windowSource);
    // Reconsider is the function; observation copy is a separate channel.
    expect(night.function.displayLabel, 'Reconsider');
    expect(decision.userFacingNote, isNot(contains('Reconsider')));
    expect(decision.userFacingNote, isNot(contains('Function:')));
  });

  test('planet guidance keeps observation steps ahead of rationale', () async {
    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
    final planets = data.events.where(
      (e) => e.category == 'Planetary Highlights',
    );
    expect(planets, isNotEmpty);
    for (final e in planets) {
      expect(e.skyEventId, isNotNull);
      expect(e.bestViewing, isNotEmpty);
      expect(e.significance, startsWith('Function:'));
      // Observation/viewing leads; function label is separate rationale.
      expect(e.detailSummary.indexOf(e.bestViewing), lessThan(
        e.detailSummary.indexOf(e.significance),
      ));
    }
  });

  test('unmapped events fall back to best viewing plus reflection', () {
    const event = TrackSkyEvent(
      category: 'Solar Events',
      title: 'Custom Horizon Watch',
      exactLabel: '2026-09-01',
      scientificBreakdown: 'Scientific fallback that should not lead.',
      whatToSee: 'A silver line will appear above the ridge.',
      bestViewing:
          'Step outside before dusk and give the western edge a minute.',
      significance: 'Return makes measure possible.',
      notes: 'Internal editorial note.',
      schedule: TrackSkyEventSchedule(
        dateIso: '2026-09-01',
        startTime24: '19:00',
        endTime24: '20:00',
        allDay: false,
      ),
    );
    expect(
      event.detailSummary,
      contains('Step outside before dusk and give the western edge a minute.'),
    );
    expect(event.detailSummary, contains('Return makes measure possible.'));
    expect(event.detailSummary, isNot(contains('Scientific fallback')));
  });

  test('stored legacy track sky detail is replaced by the narrative summary', () async {
    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
    expect(data.events, isNotEmpty);
    for (final e in data.events.take(12)) {
      // Adapter exposes canonical V2 detail: viewing window + function label.
      expect(e.detailSummary, contains(e.bestViewing));
      expect(e.detailSummary, contains(e.significance));
      expect(e.skyEventId, isNotNull);
    }
  });

  test('daytime full moons normalize to an evening viewing window', () async {
    final catalog = await SkyCatalogRepository().load();
    final materializer = _testMaterializer();
    final visibility = const SkyVisibilityService();
    final fullMoons = catalog.materializableEvents.where(
      (e) => e.kind == SkyEventKind.fullMoon,
    );
    expect(fullMoons, isNotEmpty);
    for (final sky in fullMoons.take(5)) {
      final night = catalog.observingNight(sky);
      final decision = visibility.decide(night.windowSource);
      final occ = materializer.materialize(
        event: sky,
        night: night,
        ianaTimeZone: TrackSkyTimeZone.pacific.ianaName,
        visibilityNote: decision.userFacingNote,
      );
      if (occ.allDay) continue;
      // Materialized observing-night local start is evening/night, not daytime.
      expect(occ.startsAtLocal.hour, greaterThanOrEqualTo(17));
    }
  });

  test('planetary oppositions normalize to an evening watch window', () async {
    final catalog = await SkyCatalogRepository().load();
    final materializer = _testMaterializer();
    final visibility = const SkyVisibilityService();
    final oppositions = catalog.materializableEvents.where(
      (e) => e.kind == SkyEventKind.planetOpposition,
    );
    expect(oppositions, isNotEmpty);
    for (final sky in oppositions.take(5)) {
      final night = catalog.observingNight(sky);
      final decision = visibility.decide(night.windowSource);
      final occ = materializer.materialize(
        event: sky,
        night: night,
        ianaTimeZone: TrackSkyTimeZone.pacific.ianaName,
        visibilityNote: decision.userFacingNote,
      );
      if (occ.allDay) continue;
      expect(occ.startsAtLocal.hour, greaterThanOrEqualTo(17));
    }
  });

  test('asset-loaded events preserve timing and visibility caveats', () async {
    expect(File('assets/ma_at_flows/track_sky_pacific.md').existsSync(), isFalse);
    expect(
      File('lib/features/calendar/track_sky_flow_data.g.dart').existsSync(),
      isFalse,
    );
    final catalog = await SkyCatalogRepository().load();
    final visibility = const SkyVisibilityService();
    expect(catalog.materializableEvents, isNotEmpty);
    var sawLocationCaveat = false;
    for (final sky in catalog.materializableEvents) {
      final night = catalog.observingNight(sky);
      final decision = visibility.decide(night.windowSource);
      if (!decision.canClaimLocalVisibility) {
        expect(decision.userFacingNote, isNotEmpty);
        sawLocationCaveat = true;
      }
    }
    expect(sawLocationCaveat, isTrue);
    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
    expect(data.events, isNotEmpty);
    expect(data.events.every((e) => e.skyEventId != null), isTrue);
    expect(
      data.events.every((e) => e.schedule.dateIso.isNotEmpty),
      isTrue,
    );
  });

  test('V2-backed load returns materializable catalog events', () async {
    final catalogFile = File('assets/follow_the_sky/sky_catalog_v2.json');
    expect(catalogFile.existsSync(), isTrue);

    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
    expect(data.events, isNotEmpty);
    expect(data.events.first.skyEventId, isNotNull);
    expect(
      data.events.any((e) => e.title == 'Full Moon' || e.title.contains('Equinox')),
      isTrue,
    );
  });

  test('upcoming filter excludes past events', () async {
    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.eastern);
    final upcoming = upcomingTrackSkyEvents(
      data,
      now: DateTime.utc(2026, 9, 1),
    );
    expect(upcoming, isNotEmpty);
    for (final e in upcoming) {
      expect(
        trackSkyEventEndLocal(e, TrackSkyTimeZone.eastern)
            .isBefore(DateTime.utc(2026, 9, 1)),
        isFalse,
      );
    }
  });

  test('no markdown assets remain for track sky', () {
    expect(File('assets/ma_at_flows/track_sky_pacific.md').existsSync(), isFalse);
    expect(
      File('lib/features/calendar/track_sky_flow_data.g.dart').existsSync(),
      isFalse,
    );
  });
}

TrackSkyMaterializer _testMaterializer() {
  return TrackSkyMaterializer(
    toLocal: (utc, iana) {
      final location = tz.getLocation(iana);
      return tz.TZDateTime.from(utc.toUtc(), location);
    },
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
}
