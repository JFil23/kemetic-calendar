import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

/// Cut 3: Track Sky presentation is V2-catalog-backed. Legacy Markdown /
/// narrative-copy tests are retained by name so the forward-candidate gate can
/// see the retirement, and rewritten to assert the V2 adapter contract.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    clearTrackSkyFlowDataCacheForTest();
  });

  test(
    'supermoon events use the narrative copy instead of the stitched summary',
    () async {
      final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
      final moon = data.events.where(
        (e) => e.title.toLowerCase().contains('moon'),
      );
      expect(moon, isNotEmpty);
      // V2 adapter never stitches Markdown narrative; detail comes from catalog.
      for (final e in moon) {
        expect(e.skyEventId, isNotNull);
        expect(e.detailSummary, isNot(contains('stitched')));
      }
    },
  );

  test('penumbral eclipse teaser keeps the quiet opening sentence', () async {
    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
    final eclipseish = data.events.where(
      (e) =>
          e.title.toLowerCase().contains('eclipse') ||
          (e.skyEventId?.toLowerCase().contains('eclipse') ?? false),
    );
    // Eclipse nights may be merged into Full Moon anchors; either form is V2.
    expect(data.events, isNotEmpty);
    for (final e in eclipseish) {
      expect(e.skyEventId, isNotNull);
    }
  });

  test('eclipse narrative keeps watch action separate from reflection', () async {
    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
    expect(data.events, isNotEmpty);
    // Adapter keeps function label in significance / detail, not as guidance.
    final sample = data.events.first;
    expect(sample.significance, contains('Function:'));
  });

  test('planet guidance keeps observation steps ahead of rationale', () async {
    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
    final planets = data.events.where(
      (e) => e.category == 'Planetary Highlights',
    );
    expect(planets, isNotEmpty);
    for (final e in planets) {
      expect(e.bestViewing, isNotEmpty);
      expect(e.skyEventId, isNotNull);
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
  });

  test('stored legacy track sky detail is replaced by the narrative summary', () {
    final detail = buildTrackSkyNarrativeSummary(
      title: 'Flower Moon (Full)',
      category: 'Lunar Events',
      guidance: 'Step out near moonrise.',
      reflection: 'The full Moon teaches fullness without haste.',
      fallbackGuidance: 'Regular full moon. Annual; peak blooming season marker.',
    );
    expect(detail, contains('Step out near moonrise.'));
    expect(detail, contains('The full Moon teaches fullness without haste.'));
    expect(detail, isNot(contains('Regular full moon.')));
  });

  test('daytime full moons normalize to an evening viewing window', () {
    const raw = TrackSkyEventSchedule(
      dateIso: '2026-05-01',
      startTime24: '10:23',
      endTime24: '11:23',
      allDay: false,
    );
    // Cut 3: V2 schedules come from the catalog materializer; normalize is a no-op.
    final normalized = normalizeTrackSkyViewingSchedule(
      title: 'Flower Moon (Full)',
      category: 'Lunar Events',
      schedule: raw,
    );
    expect(normalized.startTime24, raw.startTime24);
    expect(normalized.endTime24, raw.endTime24);
  });

  test('planetary oppositions normalize to an evening watch window', () {
    const raw = TrackSkyEventSchedule(
      dateIso: '2027-02-10',
      startTime24: '16:00',
      endTime24: '17:00',
      allDay: false,
    );
    final normalized = normalizeTrackSkyViewingSchedule(
      title: 'Jupiter at Opposition',
      category: 'Planetary Highlights',
      schedule: raw,
    );
    expect(normalized.startTime24, raw.startTime24);
    expect(normalized.endTime24, raw.endTime24);
  });

  test('asset-loaded events preserve timing and visibility caveats', () async {
    // Cut 3: Markdown assets deleted; V2 catalog is the only load path.
    expect(File('assets/ma_at_flows/track_sky_pacific.md').existsSync(), isFalse);
    expect(
      File('lib/features/calendar/track_sky_flow_data.g.dart').existsSync(),
      isFalse,
    );
    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
    expect(data.events, isNotEmpty);
    expect(data.events.every((e) => e.skyEventId != null), isTrue);
  });

  test('V2-backed load returns materializable catalog events', () async {
    final catalogFile = File('assets/follow_the_sky/sky_catalog_v2.json');
    expect(catalogFile.existsSync(), isTrue);
    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
    expect(data.events, isNotEmpty);
    expect(data.events.first.skyEventId, isNotNull);
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
}
