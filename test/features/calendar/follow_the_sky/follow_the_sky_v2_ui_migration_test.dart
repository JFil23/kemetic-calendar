import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SkyCatalog catalog;

  setUpAll(() {
    catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
  });

  test('migration preserves join and stamps edited futures without duplicates', () {
    final service = TrackSkyMigrationService();
    final now = DateTime.utc(2026, 9, 1);
    final result = service.migrateExistingJoinedFlow(
      catalog: catalog,
      nowUtc: now,
      flowStillActive: true,
      existing: [
        TrackSkyExistingOccurrence(
          clientEventId: 'past-1',
          title: 'Full Moon',
          startsAtUtc: DateTime.utc(2026, 8, 28),
          isPastOrCompleted: true,
        ),
        TrackSkyExistingOccurrence(
          clientEventId: 'edited-eq',
          title: 'Autumn Equinox — Watch from Griffith',
          startsAtUtc: DateTime.utc(2026, 9, 23, 1),
          isUserEdited: true,
        ),
        TrackSkyExistingOccurrence(
          clientEventId: 'untouched-sat',
          title: 'Saturn Opposition',
          startsAtUtc: DateTime.utc(2026, 10, 4, 4),
          hasScheduledNotification: true,
        ),
      ],
      legacyCandidates: [
        LegacyTrackSkyCandidate(
          clientEventId: 'edited-eq',
          title: 'Autumn Equinox — Watch from Griffith',
          startsAtUtc: DateTime.utc(2026, 9, 23, 1),
        ),
        LegacyTrackSkyCandidate(
          clientEventId: 'untouched-sat',
          title: 'Saturn Opposition',
          startsAtUtc: DateTime.utc(2026, 10, 4, 4),
        ),
      ],
    );

    expect(result.remainedJoined, isTrue);
    expect(result.legacyMatches['edited-eq'], 'autumn-equinox-2026');
    expect(
      result.plan.actions.any(
        (a) =>
            a.type == TrackSkyReconcileActionType.stampOnly &&
            a.skyEventId == 'autumn-equinox-2026',
      ),
      isTrue,
    );
    expect(
      result.plan.actions.any(
        (a) =>
            a.type == TrackSkyReconcileActionType.add &&
            a.skyEventId == 'autumn-equinox-2026',
      ),
      isFalse,
    );
    expect(
      service.notificationClientIdsToCancel(result.plan),
      contains('untouched-sat'),
    );
  });

  testWidgets('FollowSkyDetailPage shows course picker and next turning', (
    tester,
  ) async {
    final repo = SkyCatalogRepository(
      assetLoader: (_) =>
          File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          isJoined: false,
          catalogRepository: repo,
          now: DateTime.utc(2026, 9, 1, 12),
          candidates: const [
            CourseActivitySignal(
              label: 'Kung Fu',
              sourceType: TrackSkyCourseSourceType.flow,
              sourceId: 'flow:1',
              occurrenceCount: 5,
              recentMinutes: 120,
              previousMinutes: 180,
            ),
            CourseActivitySignal(
              label: 'The Madness',
              sourceType: TrackSkyCourseSourceType.flow,
              sourceId: 'flow:2',
              occurrenceCount: 4,
              recentMinutes: 90,
              previousMinutes: 200,
            ),
            CourseActivitySignal(
              label: 'Kettlebell',
              sourceType: TrackSkyCourseSourceType.eventTitle,
              sourceId: 'event_title:kettlebell',
              occurrenceCount: 3,
              recentMinutes: 60,
              previousMinutes: 60,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Follow the sky'), findsWidgets);
    expect(find.text('ONE THING TO CARRY'), findsOneWidget);
    expect(find.text('Kung Fu'), findsOneWidget);
    expect(find.text('Carry this course'), findsOneWidget);
    expect(find.text('ALREADY IN YOUR LIFE'), findsNothing);
  });

  testWidgets('no-course sheets gate course functions; Attend stays usable', (
    tester,
  ) async {
    final catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    final pageKey = GlobalKey<FollowSkyDetailPageState>();
    final nights = catalog.upcomingNights(nowUtc: DateTime.utc(2026, 8, 1, 12));
    final reconsider = nights.firstWhere(
      (n) => n.function == SkyEventFunction.reconsider,
    );
    final mercury = nights.firstWhere(
      (n) =>
          n.function == SkyEventFunction.attend &&
          n.displayName.contains('Mercury'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          key: pageKey,
          isJoined: true,
          initialCatalog: catalog,
          now: DateTime.utc(2026, 8, 20, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(pageKey.currentState!.openTurningSheetForTest(reconsider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Set a course to use this turning'), findsOneWidget);
    expect(find.text('Reconsider what I’m carrying'), findsNothing);

    await tester.tap(find.text('Set a course to use this turning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ONE THING TO CARRY'), findsOneWidget);

    unawaited(pageKey.currentState!.openTurningSheetForTest(mercury));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Plan to watch'), findsOneWidget);
    expect(find.text('Set a course to use this turning'), findsNothing);
  });

  testWidgets('embedded joined no-course hides inline Carry CTA', (tester) async {
    final catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FollowSkyDetailPage(
              standalone: false,
              isJoined: true,
              initialCatalog: catalog,
              now: DateTime.utc(2026, 9, 1, 12),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ONE THING TO CARRY'), findsOneWidget);
    expect(find.text('Carry this course'), findsNothing);
  });

  testWidgets('free-text course reconsider sheet has no Keep/Change/Release', (
    tester,
  ) async {
    final catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    final pageKey = GlobalKey<FollowSkyDetailPageState>();
    final notes = TrackSkyCourseMetadataCodec().encode(
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
          key: pageKey,
          isJoined: true,
          initialCatalog: catalog,
          existingFlowNotes: notes,
          now: DateTime.utc(2026, 8, 20, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finish my book'), findsOneWidget);
    expect(find.textContaining('unlinked'), findsNothing);
    expect(find.text('No calendar activity connected yet'), findsOneWidget);

    unawaited(pageKey.currentState!.openTurningSheetForTest(reconsider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Keep it'), findsNothing);
    expect(find.text('Change it'), findsNothing);
    expect(find.text('Release it'), findsNothing);
    expect(find.text('Connect activity'), findsWidgets);
    expect(find.text('Continue to the eclipse'), findsOneWidget);
    expect(
      find.textContaining('There isn’t any Hꜣw activity connected'),
      findsOneWidget,
    );
    // Primary reconsider service CTA must not appear on the sheet itself.
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Reconsider what I’m carrying'),
      ),
      findsNothing,
    );
  });

  testWidgets('free-text course measure sheet has no Measure my course', (
    tester,
  ) async {
    final catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    final pageKey = GlobalKey<FollowSkyDetailPageState>();
    final notes = TrackSkyCourseMetadataCodec().encode(
      TrackSkyCourse(
        courseId: 'c-book',
        label: 'Finish my book',
        sourceType: TrackSkyCourseSourceType.freeText,
        createdAt: DateTime.utc(2026, 8, 22),
      ),
    );
    final equinox = catalog
        .upcomingNights(nowUtc: DateTime.utc(2026, 8, 1, 12))
        .firstWhere((n) => n.function == SkyEventFunction.measure);

    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          key: pageKey,
          isJoined: true,
          initialCatalog: catalog,
          existingFlowNotes: notes,
          now: DateTime.utc(2026, 8, 20, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(pageKey.currentState!.openTurningSheetForTest(equinox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Keep it'), findsNothing);
    expect(find.text('Give it more room'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Measure my course'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.textContaining(
          'compares the life you’re actually scheduling',
        ),
      ),
      findsNothing,
    );
    expect(find.text('Protect time for this course'), findsOneWidget);
    expect(find.text('Connect activity'), findsWidgets);
    expect(find.text('No calendar activity connected yet'), findsWidgets);
  });

  testWidgets('Connect empty state offers Protect time and Done only', (
    tester,
  ) async {
    final catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    final pageKey = GlobalKey<FollowSkyDetailPageState>();
    final notes = TrackSkyCourseMetadataCodec().encode(
      TrackSkyCourse(
        courseId: 'c-book',
        label: 'Finish my book',
        sourceType: TrackSkyCourseSourceType.freeText,
        createdAt: DateTime.utc(2026, 8, 22),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          key: pageKey,
          isJoined: true,
          initialCatalog: catalog,
          existingFlowNotes: notes,
          now: DateTime.utc(2026, 8, 20, 12),
          candidates: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    pageKey.currentState!.requestConnectActivity();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CONNECT ACTIVITY'), findsOneWidget);
    expect(find.text('NO ACTIVITY TO CONNECT YET'), findsOneWidget);
    expect(
      find.textContaining('Protect some time for this course'),
      findsOneWidget,
    );
    expect(find.text('Protect time for this course'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('None of these'), findsNothing);
  });

  testWidgets('Connect activity opens eligible selector and links source', (
    tester,
  ) async {
    final catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    final pageKey = GlobalKey<FollowSkyDetailPageState>();
    final notes = TrackSkyCourseMetadataCodec().encode(
      TrackSkyCourse(
        courseId: 'c-book',
        label: 'Finish my book',
        sourceType: TrackSkyCourseSourceType.freeText,
        createdAt: DateTime.utc(2026, 8, 22),
      ),
    );
    TrackSkyCourse? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          key: pageKey,
          isJoined: true,
          initialCatalog: catalog,
          existingFlowNotes: notes,
          now: DateTime.utc(2026, 8, 20, 12),
          candidates: const [
            CourseActivitySignal(
              label: 'Writing',
              sourceType: TrackSkyCourseSourceType.flow,
              sourceId: 'flow:11',
              occurrenceCount: 1,
              recentMinutes: 40,
              previousMinutes: 0,
            ),
            CourseActivitySignal(
              label: 'Morning pages',
              sourceType: TrackSkyCourseSourceType.flow,
              sourceId: 'flow:12',
              occurrenceCount: 2,
              recentMinutes: 50,
              previousMinutes: 20,
            ),
          ],
          onCourseSaved: (course, _) async {
            saved = course;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Chips stay hidden (<2 strong for suggest thresholds with low occ).
    expect(find.text('Writing'), findsNothing);

    pageKey.currentState!.requestConnectActivity();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CONNECT ACTIVITY'), findsOneWidget);
    expect(find.text('Writing'), findsOneWidget);
    expect(find.text('Morning pages'), findsOneWidget);
    expect(find.text('None of these'), findsOneWidget);

    await tester.tap(find.text('Writing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(saved, isNotNull);
    expect(saved!.label, 'Finish my book');
    expect(saved!.isLinked, isTrue);
    expect(saved!.sourceId, 'flow:11');
    expect(pageKey.currentState!.hasActiveCourse, isTrue);
    expect(find.textContaining('Connected to Writing'), findsOneWidget);
  });

  testWidgets('Connect activity cancel keeps Course active and unlinked', (
    tester,
  ) async {
    final catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    final pageKey = GlobalKey<FollowSkyDetailPageState>();
    final notes = TrackSkyCourseMetadataCodec().encode(
      TrackSkyCourse(
        courseId: 'c-sleep',
        label: 'Sleep',
        sourceType: TrackSkyCourseSourceType.freeText,
        createdAt: DateTime.utc(2026, 8, 22),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FollowSkyDetailPage(
          key: pageKey,
          isJoined: true,
          initialCatalog: catalog,
          existingFlowNotes: notes,
          now: DateTime.utc(2026, 8, 20, 12),
          candidates: const [
            CourseActivitySignal(
              label: 'Writing',
              sourceType: TrackSkyCourseSourceType.flow,
              sourceId: 'flow:11',
              occurrenceCount: 1,
              recentMinutes: 40,
              previousMinutes: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sleep'), findsOneWidget);
    expect(find.text('Carry this course'), findsNothing);

    pageKey.currentState!.requestConnectActivity();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('CONNECT ACTIVITY'), findsOneWidget);

    await tester.tap(find.text('None of these'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(pageKey.currentState!.hasActiveCourse, isTrue);
    expect(find.text('Sleep'), findsOneWidget);
    expect(find.text('Connected to Writing'), findsNothing);
    expect(find.text('No calendar activity connected yet'), findsOneWidget);
    expect(find.text('Carry this course'), findsNothing);
    expect(find.text('ONE THING TO CARRY'), findsNothing);
  });

  testWidgets('Connect from Reconsider sheet keeps Course and opens selector', (
    tester,
  ) async {
    final catalog = SkyCatalogRepository.parseJsonString(
      File('assets/follow_the_sky/sky_catalog_v2.json').readAsStringSync(),
    );
    final pageKey = GlobalKey<FollowSkyDetailPageState>();
    final notes = TrackSkyCourseMetadataCodec().encode(
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
          key: pageKey,
          isJoined: true,
          initialCatalog: catalog,
          existingFlowNotes: notes,
          now: DateTime.utc(2026, 8, 20, 12),
          candidates: const [
            CourseActivitySignal(
              label: 'Writing',
              sourceType: TrackSkyCourseSourceType.flow,
              sourceId: 'flow:11',
              occurrenceCount: 1,
              recentMinutes: 40,
              previousMinutes: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(pageKey.currentState!.openTurningSheetForTest(reconsider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('CONNECT ACTIVITY'), findsNothing);
    expect(find.text('Connect activity'), findsWidgets);

    await tester.tap(find.text('Connect activity').last);
    await tester.pump(); // start pop
    await tester.pump(const Duration(milliseconds: 50)); // endOfFrame
    await tester.pump(); // show connect sheet
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CONNECT ACTIVITY'), findsOneWidget);
    expect(find.text('Writing'), findsOneWidget);
    expect(pageKey.currentState!.hasActiveCourse, isTrue);
    expect(find.text('ONE THING TO CARRY'), findsNothing);
  });
}
