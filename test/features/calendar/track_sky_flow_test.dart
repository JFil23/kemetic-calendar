import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
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
}
