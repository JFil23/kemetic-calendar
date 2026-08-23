import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

void main() {
  test('witnessing a turning is not completing its function', () {
    final history = FollowSkyTurningHistory();
    history.recordWitnessed(
      skyEventId: 'total-lunar-eclipse-2026',
      function: SkyEventFunction.reconsider,
      nowUtc: DateTime.utc(2026, 3, 3, 4),
    );

    expect(history.entries, hasLength(1));
    expect(history.witnessed, hasLength(1));
    expect(history.functionsCompleted, isEmpty);
    expect(history.hasFunctionCompleted('total-lunar-eclipse-2026'), isFalse);
    expect(history.wasOnlyWitnessed('total-lunar-eclipse-2026'), isTrue);
    expect(history.entries.single.choice, isNull);
    expect(history.entries.single.courseId, isNull);
  });

  test('a real decision records the choice and the course it was about', () {
    final history = FollowSkyTurningHistory();
    history.recordFunctionCompleted(
      skyEventId: 'autumn-equinox-2026',
      function: SkyEventFunction.measure,
      choice: FollowSkyProductChoice.keepCourse,
      courseId: 'course-1',
      nowUtc: DateTime.utc(2026, 9, 23, 1),
    );

    final entry = history.entries.single;
    expect(entry.kind, FollowSkyTurningEntryKind.functionCompleted);
    expect(entry.choice, FollowSkyProductChoice.keepCourse);
    expect(entry.courseId, 'course-1');
    expect(entry.function, SkyEventFunction.measure);
    expect(history.hasFunctionCompleted('autumn-equinox-2026'), isTrue);
    expect(history.wasOnlyWitnessed('autumn-equinox-2026'), isFalse);
    expect(history.witnessed, isEmpty);
  });

  test('witnessing then deciding keeps both entries distinguishable', () {
    final history = FollowSkyTurningHistory();
    history.recordWitnessed(
      skyEventId: 'winter-solstice-2026',
      function: SkyEventFunction.turn,
      nowUtc: DateTime.utc(2026, 12, 21),
    );
    history.recordFunctionCompleted(
      skyEventId: 'winter-solstice-2026',
      function: SkyEventFunction.turn,
      choice: FollowSkyProductChoice.releaseCourse,
      courseId: 'course-2',
      nowUtc: DateTime.utc(2026, 12, 21, 1),
    );

    expect(history.entries, hasLength(2));
    expect(history.witnessed, hasLength(1));
    expect(history.functionsCompleted, hasLength(1));
    expect(history.hasFunctionCompleted('winter-solstice-2026'), isTrue);
    expect(history.wasOnlyWitnessed('winter-solstice-2026'), isFalse);
  });

  test('an empty history invents nothing', () {
    final history = FollowSkyTurningHistory();
    expect(history.entries, isEmpty);
    expect(history.hasFunctionCompleted('anything'), isFalse);
    expect(history.wasOnlyWitnessed('anything'), isFalse);
  });

  test('recorded timestamps are normalized to UTC', () {
    final history = FollowSkyTurningHistory();
    history.recordWitnessed(
      skyEventId: 'perseids-2026',
      function: SkyEventFunction.attend,
      nowUtc: DateTime(2026, 8, 12, 22),
    );
    expect(history.entries.single.recordedAtUtc.isUtc, isTrue);
  });
}
