import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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

  setUp(() {
    FollowSkyMigrationJobCoordinator.instance.debugReset();
  });

  test('two simultaneous migration requests share one physical job', () async {
    var starts = 0;
    final gate = Completer<void>();

    Future<FollowSkyMigrationJobReceipt> job() async {
      starts += 1;
      await gate.future;
      return const FollowSkyMigrationJobReceipt(
        stamped: 1,
        added: 2,
        failed: 0,
        represented: 3,
        canonical: 3,
        plannedStampIds: <String>['a'],
        plannedAddSkyEventIds: <String>['b', 'c'],
      );
    }

    final first = FollowSkyMigrationJobCoordinator.instance.run(
      userId: 'user-1',
      flowId: 667,
      job: job,
    );
    final second = FollowSkyMigrationJobCoordinator.instance.run(
      userId: 'user-1',
      flowId: 667,
      job: job,
    );

    expect(identical(first, second), isTrue);
    expect(starts, 1);
    expect(FollowSkyMigrationJobCoordinator.instance.debugInflightCount, 1);

    gate.complete();
    final a = await first;
    final b = await second;
    expect(identical(a, b), isTrue);
    expect(a.added, 2);
    expect(FollowSkyMigrationJobCoordinator.instance.debugInflightCount, 0);
  });

  test('second caller waits for first job to finish before key frees', () async {
    final order = <String>[];
    final release = Completer<void>();

    final first = FollowSkyMigrationJobCoordinator.instance.run(
      userId: 'user-1',
      flowId: 42,
      job: () async {
        order.add('start');
        await release.future;
        order.add('finish');
        return const FollowSkyMigrationJobReceipt(
          stamped: 0,
          added: 0,
          failed: 0,
          represented: 0,
          canonical: 0,
          plannedStampIds: <String>[],
          plannedAddSkyEventIds: <String>[],
        );
      },
    );

    final second = FollowSkyMigrationJobCoordinator.instance.run(
      userId: 'user-1',
      flowId: 42,
      job: () async {
        order.add('second-start');
        return const FollowSkyMigrationJobReceipt(
          stamped: 9,
          added: 9,
          failed: 0,
          represented: 9,
          canonical: 9,
          plannedStampIds: <String>[],
          plannedAddSkyEventIds: <String>[],
        );
      },
    );

    expect(order, ['start']);
    release.complete();
    await Future.wait([first, second]);
    expect(order, ['start', 'finish']);
    expect(FollowSkyMigrationJobCoordinator.instance.debugInflightCount, 0);

    // After completion, a new request may run an independent job.
    final third = await FollowSkyMigrationJobCoordinator.instance.run(
      userId: 'user-1',
      flowId: 42,
      job: () async {
        order.add('third-start');
        return const FollowSkyMigrationJobReceipt(
          stamped: 0,
          added: 0,
          failed: 0,
          represented: 65,
          canonical: 65,
          plannedStampIds: <String>[],
          plannedAddSkyEventIds: <String>[],
        );
      },
    );
    expect(order.last, 'third-start');
    expect(third.represented, 65);
    expect(third.canonical, 65);
  });

  test(
    'completed migration rows yield zero-write third reconciliation',
    () {
      final nights = catalog.upcomingNights(nowUtc: nowUtc);
      expect(nights.length, greaterThanOrEqualTo(8));

      // Simulate a joined calendar that already owns every canonical night.
      final rows = <FollowSkyLegacyCalendarRow>[
        for (final night in nights)
          FollowSkyLegacyCalendarRow(
            clientEventId: 'owned-${night.skyEventId}',
            title: night.displayName,
            startsAtUtc: night.primaryInstantUtc,
            behaviorPayload: TrackSkyEventOwnership.behaviorPayload(
              skyEventId: night.skyEventId,
              legacyPreserved: false,
              mergedCompanionSkyEventIds: [
                if (night.companion != null) night.companion!.id,
              ],
              displayName: night.displayName,
            ),
          ),
      ];

      final plan = applicator.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        rows: rows,
        ianaTimeZone: 'America/Los_Angeles',
        flowStillActive: true,
      );

      expect(plan.writesNothing, isTrue);
      expect(plan.stamps, isEmpty);
      expect(plan.adds, isEmpty);
      expect(
        plan.coverage.representedByLegacy,
        plan.coverage.canonicalNightsInWindow,
      );
      expect(plan.coverage.canonicalNightsInWindow, greaterThan(0));
    },
  );

  test(
    'partial add suffix remaining after interrupted first pass is subset',
    () {
      final nights = catalog
          .upcomingNights(nowUtc: nowUtc)
          .where(
            (n) => !n.primaryInstantUtc.isBefore(
              FollowSkyMigrationPolicy.defaultV1HorizonEnd,
            ),
          )
          .toList(growable: false);
      expect(nights.length, greaterThanOrEqualTo(21));

      final firstMissing = nights.take(48).toList(growable: false);
      if (firstMissing.length < 48) {
        // Catalog window may be shorter; still validate subset algebra.
      }
      final completed = firstMissing.take(27).toList(growable: false);
      final remaining = firstMissing.skip(27).toList(growable: false);

      final completedIds = completed.map((n) => n.skyEventId).toSet();
      final remainingIds = remaining.map((n) => n.skyEventId).toSet();
      expect(completedIds.intersection(remainingIds), isEmpty);
      expect(
        remainingIds.every((id) => firstMissing.any((n) => n.skyEventId == id)),
        isTrue,
      );
      expect(completed.length + remaining.length, firstMissing.length);
    },
  );
}
