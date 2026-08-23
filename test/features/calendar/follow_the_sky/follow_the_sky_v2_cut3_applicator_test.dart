import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

/// Cut 3 applicator: host calendar rows → stamp-only migration plan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SkyCatalog catalog;
  final nowUtc = DateTime.utc(2026, 3, 1);
  final applicator = FollowSkyMigrationApplicator();

  setUpAll(() async {
    catalog = await SkyCatalogRepository().load();
  });

  SkyEvent futureEvent() {
    final upcoming = catalog.upcoming(nowUtc: nowUtc);
    expect(upcoming, isNotEmpty);
    return upcoming.first;
  }

  test('matched legacy future gets an ownership stamp only', () {
    final event = futureEvent();
    final plan = applicator.plan(
      catalog: catalog,
      nowUtc: nowUtc,
      rows: [
        FollowSkyLegacyCalendarRow(
          clientEventId: 'legacy-future',
          title: event.name,
          startsAtUtc: event.primaryInstantUtc,
        ),
        FollowSkyLegacyCalendarRow(
          clientEventId: 'legacy-past',
          title: 'March Equinox',
          startsAtUtc: DateTime.utc(2025, 3, 20),
          isPastOrCompleted: true,
        ),
      ],
    );

    expect(plan.preservedClientEventIds, contains('legacy-past'));
    expect(
      plan.stamps.map((s) => s.clientEventId),
      contains('legacy-future'),
    );
    final stamp = plan.stamps.singleWhere(
      (s) => s.clientEventId == 'legacy-future',
    );
    expect(stamp.skyEventId, event.id);
    expect(
      TrackSkyEventOwnership.isLegacyPreserved(stamp.behaviorPayload),
      isTrue,
    );
    // No title/time fields exist on the stamp — payload only.
    expect(stamp.behaviorPayload.containsKey('title'), isFalse);
  });

  test('already-owned rows write nothing on a second pass', () {
    final event = futureEvent();
    final owned = TrackSkyEventOwnership.behaviorPayload(
      skyEventId: event.id,
      legacyPreserved: true,
    );
    final plan = applicator.plan(
      catalog: catalog,
      nowUtc: nowUtc,
      rows: [
        FollowSkyLegacyCalendarRow(
          clientEventId: 'owned',
          title: event.name,
          startsAtUtc: event.primaryInstantUtc,
          behaviorPayload: owned,
        ),
        for (final e in catalog.upcoming(nowUtc: nowUtc).skip(1))
          FollowSkyLegacyCalendarRow(
            clientEventId: 'v2-${e.id}',
            title: e.name,
            startsAtUtc: e.primaryInstantUtc,
            behaviorPayload: TrackSkyEventOwnership.behaviorPayload(
              skyEventId: e.id,
            ),
          ),
      ],
    );

    expect(plan.writesNothing, isTrue);
    expect(FollowSkyCutFreeze.cut3MigrationApplyPending, isFalse);
  });
}
