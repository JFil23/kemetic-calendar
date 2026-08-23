import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Cut 3.1 applicator: host calendar rows → stamp + additive plan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SkyCatalog catalog;
  late FollowSkyMigrationApplicator applicator;
  final nowUtc = DateTime.utc(2026, 9, 1);

  setUpAll(() async {
    tzdata.initializeTimeZones();
    catalog = await SkyCatalogRepository().load();
    applicator = FollowSkyMigrationApplicator(
      materializer: TrackSkyMaterializer(
        toLocal: (utc, iana) =>
            tz.TZDateTime.from(utc.toUtc(), tz.getLocation(iana)),
        toUtc: (local, iana) => tz.TZDateTime(
          tz.getLocation(iana),
          local.year,
          local.month,
          local.day,
          local.hour,
          local.minute,
          local.second,
        ).toUtc(),
      ),
    );
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
      ianaTimeZone: 'America/Los_Angeles',
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
    expect(plan.adds.any((a) => a.skyEventId == event.id), isFalse);
    expect(plan.coverage.duplicatesCreated, 0);
  });

  test('already-owned full coverage writes nothing on a second pass', () {
    final empty = applicator.plan(
      catalog: catalog,
      nowUtc: nowUtc,
      ianaTimeZone: 'America/Los_Angeles',
      rows: const [],
    );
    expect(empty.adds, isNotEmpty);

    final owned = [
      for (final add in empty.adds)
        FollowSkyLegacyCalendarRow(
          clientEventId: 'v2-${add.skyEventId}',
          title: add.occurrence.title,
          startsAtUtc: add.occurrence.startsAtUtc,
          behaviorPayload: add.occurrence.behaviorPayload,
        ),
    ];
    final second = applicator.plan(
      catalog: catalog,
      nowUtc: nowUtc,
      ianaTimeZone: 'America/Los_Angeles',
      rows: owned,
    );
    expect(second.writesNothing, isTrue);
    expect(FollowSkyCutFreeze.cut3MigrationApplyPending, isFalse);
  });
}
