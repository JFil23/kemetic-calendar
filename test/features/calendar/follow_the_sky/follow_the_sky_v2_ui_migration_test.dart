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

    expect(find.text('Follow the Sky'), findsWidgets);
    expect(find.text('ALREADY IN YOUR LIFE'), findsOneWidget);
    expect(find.text('Kung Fu'), findsOneWidget);
    expect(find.text('FIRST COURSE'), findsOneWidget);
  });
}