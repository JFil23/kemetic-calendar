import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

void main() {
  const engine = CourseCandidateEngine();

  test('empty activity yields no chips — never invents labels', () {
    expect(engine.suggest(const []), isEmpty);
  });

  test('a lone strong signal still yields no chips (<2 rule)', () {
    final out = engine.suggest(const [
      CourseActivitySignal(
        label: 'Solo Practice',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: 'flow:9',
        occurrenceCount: 8,
        recentMinutes: 240,
        previousMinutes: 300,
      ),
    ]);
    expect(out, isEmpty);
  });

  test('label with no corresponding activity never appears', () {
    final out = engine.suggest(const [
      CourseActivitySignal(
        label: 'Kung Fu',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: 'flow:1',
        occurrenceCount: 5,
        recentMinutes: 180,
        previousMinutes: 200,
      ),
      CourseActivitySignal(
        label: 'Kettlebell',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: 'flow:2',
        occurrenceCount: 4,
        recentMinutes: 120,
        previousMinutes: 150,
      ),
    ]);
    expect(out.map((c) => c.label), isNot(contains('The Madness')));
    expect(
      out.every((c) => c.label == 'Kung Fu' || c.label == 'Kettlebell'),
      isTrue,
    );
  });

  test('system/maat and hidden signals are excluded', () {
    final out = engine.suggest(const [
      CourseActivitySignal(
        label: 'Follow the sky',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: 'flow:77',
        occurrenceCount: 10,
        recentMinutes: 400,
        previousMinutes: 400,
        isSystemOrMaat: true,
      ),
      CourseActivitySignal(
        label: 'Hidden Drill',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: 'flow:78',
        occurrenceCount: 10,
        recentMinutes: 400,
        previousMinutes: 400,
        isHidden: true,
      ),
      CourseActivitySignal(
        label: 'Real A',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: 'flow:1',
        occurrenceCount: 5,
        recentMinutes: 120,
        previousMinutes: 100,
      ),
      CourseActivitySignal(
        label: 'Real B',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: 'flow:2',
        occurrenceCount: 5,
        recentMinutes: 90,
        previousMinutes: 90,
      ),
    ]);
    expect(out.map((c) => c.label).toList(), ['Real A', 'Real B']);
  });

  test('preserves exact user label and exposes provenance', () {
    final out = engine.suggest(const [
      CourseActivitySignal(
        label: 'Kung Fu',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: 'flow:184',
        occurrenceCount: 5,
        recentMinutes: 240,
        previousMinutes: 300,
      ),
      CourseActivitySignal(
        label: 'Morning Pages',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: 'flow:185',
        occurrenceCount: 4,
        recentMinutes: 90,
        previousMinutes: 120,
      ),
    ]);
    expect(out.map((c) => c.label).toList(), ['Kung Fu', 'Morning Pages']);
    expect(out.first.provenance, contains('flow:184'));
    for (final c in out) {
      expect(c.provenance, contains('source=${c.sourceId}'));
      expect(c.provenance, contains('${c.occurrenceCount} occurrences'));
    }
  });

  test('caps at 4 candidates', () {
    final signals = [
      for (var i = 1; i <= 8; i++)
        CourseActivitySignal(
          label: 'Practice $i',
          sourceType: TrackSkyCourseSourceType.flow,
          sourceId: 'flow:$i',
          occurrenceCount: 5 + i,
          recentMinutes: 60 * i,
          previousMinutes: 50 * i,
        ),
    ];
    expect(engine.suggest(signals), hasLength(4));
  });

  test('connect list can show a single eligible activity', () {
    final out = engine.eligibleForConnect(const [
      CourseActivitySignal(
        label: 'Writing',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: 'flow:3',
        occurrenceCount: 1,
        recentMinutes: 45,
        previousMinutes: 0,
      ),
    ]);
    expect(out.map((c) => c.label).toList(), ['Writing']);
    expect(
      engine.suggest(const [
        CourseActivitySignal(
          label: 'Writing',
          sourceType: TrackSkyCourseSourceType.flow,
          sourceId: 'flow:3',
          occurrenceCount: 1,
          recentMinutes: 45,
          previousMinutes: 0,
        ),
      ]),
      isEmpty,
    );
  });

  test('connect list still excludes maat/system/hidden', () {
    final out = engine.eligibleForConnect(const [
      CourseActivitySignal(
        label: 'Follow the sky',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: 'flow:77',
        occurrenceCount: 10,
        recentMinutes: 400,
        previousMinutes: 400,
        isSystemOrMaat: true,
      ),
      CourseActivitySignal(
        label: 'Book work',
        sourceType: TrackSkyCourseSourceType.flow,
        sourceId: 'flow:4',
        occurrenceCount: 2,
        recentMinutes: 60,
        previousMinutes: 30,
      ),
    ]);
    expect(out.map((c) => c.label).toList(), ['Book work']);
  });
}
