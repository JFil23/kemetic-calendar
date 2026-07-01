import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schedule = TrackSkyEventSchedule(
    dateIso: '2026-05-01',
    startTime24: '20:00',
    endTime24: '21:00',
    allDay: false,
  );

  TrackSkyEvent buildEvent({
    required String title,
    required String category,
    String exactLabel = 'May 1, 2026, 8:00 PM PDT',
    String scientificBreakdown = 'Scientific note.',
    String whatToSee = 'What to see.',
    String bestViewing = 'Best viewing.',
    String significance = 'Reflective note.',
    String notes = 'Future.',
  }) {
    return TrackSkyEvent(
      category: category,
      title: title,
      exactLabel: exactLabel,
      scientificBreakdown: scientificBreakdown,
      whatToSee: whatToSee,
      bestViewing: bestViewing,
      significance: significance,
      notes: notes,
      schedule: schedule,
    );
  }

  test(
    'supermoon events use the narrative copy instead of the stitched summary',
    () {
      final event = buildEvent(
        title: 'Cold Supermoon (Full)',
        category: 'Lunar Events',
        scientificBreakdown: 'Technical description that should stay hidden.',
        whatToSee: 'Old what-to-see copy.',
        bestViewing: 'Old best-viewing copy.',
        significance: 'Old significance copy.',
        notes: 'Future. Corrected timing retained from the cross-check.',
      );

      expect(
        event.detailSummary,
        contains('Step out near moonrise, while the eastern horizon'),
      );
      expect(
        event.detailSummary,
        contains('The full Moon teaches fullness without haste.'),
      );
      expect(
        event.detailSummary,
        isNot(contains('Technical description that should stay hidden.')),
      );
      expect(
        event.detailSummary,
        isNot(
          contains('Future. Corrected timing retained from the cross-check.'),
        ),
      );
    },
  );

  test('penumbral eclipse teaser keeps the quiet opening sentence', () {
    final event = buildEvent(
      title: 'Snow Supermoon + Penumbral Lunar Eclipse',
      category: 'Lunar Events',
    );

    expect(event.teaserText, 'This is a quiet event.');
    expect(
      event.detailSummary,
      contains('The careful observer may see what the hurried eye misses.'),
    );
  });

  test('eclipse narrative keeps watch action separate from reflection', () {
    final event = buildEvent(
      title: 'Worm Moon + Total Lunar Eclipse ("Blood Moon")',
      category: 'Lunar Events',
    );

    expect(
      event.trackingGuidance,
      contains('Begin before the deepest hour of the eclipse'),
    );
    expect(
      event.trackingGuidance,
      contains('Stay through the change rather than treating it'),
    );
    expect(event.trackingGuidance, isNot(contains('Its meaning is')));
    expect(
      event.maatReflection,
      contains('Its meaning is in the transformation.'),
    );
  });

  test('planet guidance keeps observation steps ahead of rationale', () {
    final parade = buildEvent(
      title: '6-Planet Parade (Alignment)',
      category: 'Planetary Highlights',
    );

    expect(parade.trackingGuidance, contains('Step out in evening twilight'));
    expect(parade.trackingGuidance, contains('Begin low in the west'));
    expect(
      parade.trackingGuidance,
      contains('use binoculars and patience for the faintest'),
    );
    expect(parade.trackingGuidance, isNot(contains('The meaning is')));
    expect(parade.maatReflection, contains('briefly share one visible path'));

    final venus = buildEvent(
      title: 'Venus at Greatest Western Elongation',
      category: 'Planetary Highlights',
    );
    expect(
      venus.trackingGuidance,
      contains('Look low toward the bright edge of dawn before sunrise.'),
    );
    expect(
      venus.trackingGuidance,
      contains('Watch it across several mornings'),
    );
    expect(venus.trackingGuidance, isNot(contains('Its lesson is')));
    expect(
      venus.maatReflection,
      contains('Its lesson is movement as well as brightness.'),
    );

    final saturn = buildEvent(
      title: 'Saturn at Opposition',
      category: 'Planetary Highlights',
    );
    expect(
      saturn.trackingGuidance,
      contains('Watch the whole arc rather than one moment.'),
    );
    expect(
      saturn.trackingGuidance,
      contains('give the rings your attention in this season'),
    );
    expect(
      saturn.trackingGuidance,
      isNot(contains('rewards the longer watch')),
    );
    expect(saturn.maatReflection, contains('Saturn rewards the longer watch.'));
  });

  test('unmapped events fall back to best viewing plus reflection', () {
    final event = buildEvent(
      title: 'Custom Horizon Watch',
      category: 'Solar Events',
      scientificBreakdown: 'Scientific fallback that should not lead.',
      whatToSee: 'A silver line will appear above the ridge.',
      bestViewing:
          'Step outside before dusk and give the western edge a minute.',
      significance: 'Return makes measure possible.',
      notes: 'Internal editorial note.',
    );

    expect(
      event.detailSummary,
      'Step outside before dusk and give the western edge a minute. A silver line will appear above the ridge.\n\nReturn makes measure possible.',
    );
  });

  test('stored legacy track sky detail is replaced by the narrative summary', () {
    final detail = buildTrackSkyNarrativeSummary(
      title: 'Flower Moon (Full)',
      category: 'Lunar Events',
      fallbackGuidance:
          'All night; rises near sunset. Bright all-night illumination; no special effects. Regular full moon. Annual; peak blooming season marker.',
    );

    expect(
      detail,
      contains(
        'Step out near moonrise while the eastern horizon is still holding the last color of day.',
      ),
    );
    expect(
      detail,
      contains(
        'The full Moon teaches fullness without haste. What has been growing in silence now becomes visible.',
      ),
    );
    expect(detail, isNot(contains('Regular full moon.')));
  });

  test('daytime full moons normalize to an evening viewing window', () {
    const raw = TrackSkyEventSchedule(
      dateIso: '2026-05-01',
      startTime24: '10:23',
      endTime24: '11:23',
      allDay: false,
    );

    final normalized = normalizeTrackSkyViewingSchedule(
      title: 'Flower Moon (Full)',
      category: 'Lunar Events',
      schedule: raw,
    );

    expect(normalized.startTime24, '20:00');
    expect(normalized.endTime24, '21:00');
    expect(normalized.allDay, isFalse);
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

    expect(normalized.startTime24, '21:00');
    expect(normalized.endTime24, '22:00');
  });

  test('asset-loaded events preserve timing and visibility caveats', () async {
    clearTrackSkyFlowCache(TrackSkyTimeZone.pacific);

    final markdown = await rootBundle.loadString(
      TrackSkyTimeZone.pacific.assetPath,
    );
    expect(
      markdown,
      contains('Safety: Eclipse glasses ONLY for solar events.'),
    );
    expect(
      markdown,
      contains('not visible from Pacific mainland U.S. locations'),
    );
    expect(markdown, contains('Eclipse visibility remains location-specific.'));

    final data = await loadTrackSkyFlowData(TrackSkyTimeZone.pacific);
    expect(data.timezone, TrackSkyTimeZone.pacific);
    expect(
      data.events.any((event) => event.title == 'Total Solar Eclipse'),
      isFalse,
    );

    final partialEclipse = data.events.singleWhere(
      (event) => event.title.contains('Deep Partial Lunar Eclipse'),
    );
    expect(partialEclipse.schedule.dateIso, '2026-08-27');
    expect(partialEclipse.schedule.startTime24, '19:17');
    expect(partialEclipse.schedule.endTime24, '23:59');
    expect(partialEclipse.schedule.allDay, isFalse);
    expect(partialEclipse.trackingGuidance, contains('Watch the Moon before'));

    final mercury = data.events.singleWhere(
      (event) => event.title == 'Mercury at Greatest Western Elongation',
    );
    expect(mercury.schedule.dateIso, '2027-03-16');
    expect(mercury.schedule.startTime24, '05:00');
    expect(mercury.schedule.endTime24, '06:00');
  });
}
