import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

/// Cut 2 P0: Change / Release must persist notes without the Course, otherwise
/// a relaunch decodes the old `sky_course` tokens and restores it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SkyCatalog catalog;

  setUpAll(() {
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
  });

  final now = DateTime.utc(2026, 8, 28, 12);

  /// Linked course with enough carried-forward activity for Reconsider.
  final linkedCourseNotes = TrackSkyCourseMetadataCodec().encode(
    TrackSkyCourse(
      courseId: 'c-studio',
      label: 'Studio Practice',
      sourceType: TrackSkyCourseSourceType.flow,
      sourceId: 'flow:12',
      createdAt: DateTime.utc(2026, 7, 1),
    ),
    existingNotes: 'mode=gregorian;split=1;maat=track-the-sky;sky_tz=pacific',
  );

  final intervals = <CourseMeasurementInterval>[
    CourseMeasurementInterval(
      start: DateTime.utc(2026, 8, 5, 10),
      end: DateTime.utc(2026, 8, 5, 12),
      minutes: 120,
    ),
    CourseMeasurementInterval(
      start: DateTime.utc(2026, 8, 12, 10),
      end: DateTime.utc(2026, 8, 12, 11, 30),
      minutes: 90,
    ),
    CourseMeasurementInterval(
      start: DateTime.utc(2026, 8, 20, 10),
      end: DateTime.utc(2026, 8, 20, 12),
      minutes: 120,
    ),
    CourseMeasurementInterval(
      start: DateTime.utc(2026, 8, 26, 9),
      end: DateTime.utc(2026, 8, 26, 10),
      minutes: 60,
    ),
  ];

  Future<
    ({
      GlobalKey<FollowSkyDetailPageState> key,
      List<({TrackSkyCourse? course, String notes})> saves,
    })
  >
  pumpReconsiderSheet(WidgetTester tester) async {
    final key = GlobalKey<FollowSkyDetailPageState>();
    final saves = <({TrackSkyCourse? course, String notes})>[];
    final reconsider = catalog
        .upcomingNights(nowUtc: DateTime.utc(2026, 8, 1, 12))
        .firstWhere((n) => n.function == SkyEventFunction.reconsider);

    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          key: key,
          isJoined: true,
          initialCatalog: catalog,
          existingFlowNotes: linkedCourseNotes,
          measurementIntervals: intervals,
          now: now,
          onCourseSaved: (course, notes) async {
            saves.add((course: course, notes: notes));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(key.currentState!.openTurningSheetForTest(reconsider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    return (key: key, saves: saves);
  }

  testWidgets('Release it persists notes without the Course', (tester) async {
    final harness = await pumpReconsiderSheet(tester);

    expect(find.text('Release it'), findsOneWidget);
    await tester.tap(find.text('Release it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // A completed function closes with a ritual naming the decision.
    expect(find.text('RITUAL'), findsOneWidget);
    expect(find.text('Released for now.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(harness.saves, hasLength(1));
    expect(harness.saves.single.course, isNull);
    expect(harness.saves.single.notes, isNot(contains('sky_course')));
    // Releasing must not invent a replacement Course.
    expect(
      TrackSkyCourseMetadataCodec().decode(harness.saves.single.notes),
      isNull,
    );
    expect(harness.saves.single.notes, contains('maat=track-the-sky'));
    expect(harness.key.currentState!.hasActiveCourse, isFalse);
    expect(find.text('Studio Practice'), findsNothing);

    final history = harness.key.currentState!.turningHistory;
    expect(history.functionsCompleted, hasLength(1));
    expect(
      history.functionsCompleted.single.choice,
      FollowSkyProductChoice.releaseCourse,
    );
    expect(history.functionsCompleted.single.courseId, 'c-studio');
    expect(history.witnessed, isEmpty);
  });

  testWidgets('Change it persists notes without the Course and re-prompts', (
    tester,
  ) async {
    final harness = await pumpReconsiderSheet(tester);

    expect(find.text('Change it'), findsOneWidget);
    await tester.tap(find.text('Change it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The ritual acknowledges setting the old course down; the picker must not
    // open underneath it.
    expect(find.text('RITUAL'), findsOneWidget);
    expect(find.text('Set down, to choose again.'), findsOneWidget);
    expect(find.text('ONE THING TO CARRY'), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(harness.saves, hasLength(1));
    expect(harness.saves.single.course, isNull);
    expect(harness.saves.single.notes, isNot(contains('sky_course')));
    expect(harness.key.currentState!.hasActiveCourse, isFalse);
    // Change re-opens the course picker; Release does not.
    expect(find.text('ONE THING TO CARRY'), findsOneWidget);

    final history = harness.key.currentState!.turningHistory;
    expect(
      history.functionsCompleted.single.choice,
      FollowSkyProductChoice.changeCourse,
    );
  });

  testWidgets('Keep it records a decision and leaves the Course persisted', (
    tester,
  ) async {
    final harness = await pumpReconsiderSheet(tester);

    expect(find.text('Keep it'), findsOneWidget);
    await tester.tap(find.text('Keep it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('RITUAL'), findsOneWidget);
    expect(find.text('Kept.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(harness.saves, isEmpty);
    expect(harness.key.currentState!.hasActiveCourse, isTrue);

    final history = harness.key.currentState!.turningHistory;
    expect(
      history.functionsCompleted.single.choice,
      FollowSkyProductChoice.keepCourse,
    );
    expect(history.witnessed, isEmpty);
  });

  testWidgets('Continue to the eclipse records witnessed only', (tester) async {
    final key = GlobalKey<FollowSkyDetailPageState>();
    final freeTextNotes = TrackSkyCourseMetadataCodec().encode(
      TrackSkyCourse(
        courseId: 'c-book',
        label: 'Finish my book',
        sourceType: TrackSkyCourseSourceType.freeText,
        createdAt: DateTime.utc(2026, 8, 22),
      ),
    );
    final reconsider = catalog
        .upcomingNights(nowUtc: DateTime.utc(2026, 8, 1, 12))
        .firstWhere((n) => n.function == SkyEventFunction.reconsider);

    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          key: key,
          isJoined: true,
          initialCatalog: catalog,
          existingFlowNotes: freeTextNotes,
          now: now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(key.currentState!.openTurningSheetForTest(reconsider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Continue to the eclipse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final history = key.currentState!.turningHistory;
    expect(history.witnessed, hasLength(1));
    expect(history.functionsCompleted, isEmpty);
    expect(history.wasOnlyWitnessed(reconsider.skyEventId), isTrue);
    expect(key.currentState!.hasActiveCourse, isTrue);
  });
}
