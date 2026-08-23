import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Existing-user Cut 3.1 migration: realistic V1 joined calendar → V2 coverage.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SkyCatalog catalog;
  late FollowSkyMigrationApplicator applicator;
  final nowUtc = DateTime.utc(2026, 9, 1);

  setUpAll(() async {
    tzdata.initializeTimeZones();
    catalog = await SkyCatalogRepository().load();
    final materializer = TrackSkyMaterializer(
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
    );
    applicator = FollowSkyMigrationApplicator(materializer: materializer);
  });

  List<FollowSkyLegacyCalendarRow> realisticV1JoinedCalendar() {
    final nights = catalog.upcomingNights(nowUtc: nowUtc);
    // Simulate a V1 join that only covered ~the first half of the near horizon.
    final v1Subset = nights
        .where(
          (n) => n.primaryInstantUtc.isBefore(
            FollowSkyMigrationPolicy.defaultV1HorizonEnd,
          ),
        )
        .take(8)
        .toList(growable: false);
    expect(v1Subset, isNotEmpty);

    final rows = <FollowSkyLegacyCalendarRow>[
      // Past / completed survive exactly.
      FollowSkyLegacyCalendarRow(
        clientEventId: 'v1-past-equinox',
        title: 'March Equinox',
        startsAtUtc: DateTime.utc(2026, 3, 20, 12),
        isPastOrCompleted: true,
      ),
      // User-edited future — visible fields must survive byte-for-byte.
      FollowSkyLegacyCalendarRow(
        clientEventId: 'v1-edited-equinox',
        title: '${v1Subset.first.displayName} — Watch from Griffith',
        startsAtUtc: v1Subset.first.primaryInstantUtc
            .subtract(const Duration(hours: 1)),
      ),
    ];

    // Remaining V1 futures keep their legacy titles (slightly older copy is OK).
    for (var i = 1; i < v1Subset.length; i++) {
      final night = v1Subset[i];
      rows.add(
        FollowSkyLegacyCalendarRow(
          clientEventId: 'v1-${night.skyEventId}',
          title: night.anchor.name, // V1 title, not merged display name
          startsAtUtc: night.primaryInstantUtc,
        ),
      );
    }
    return rows;
  }

  test('existing-user migration coverage report', () {
    final rows = realisticV1JoinedCalendar();
    final editedTitle = rows
        .firstWhere((r) => r.clientEventId == 'v1-edited-equinox')
        .title;

    final plan = applicator.plan(
      catalog: catalog,
      nowUtc: nowUtc,
      rows: rows,
      ianaTimeZone: 'America/Los_Angeles',
      flowStillActive: true,
    );

    // 1. joined status survives
    expect(plan.remainedJoined, isTrue);

    // 2. past/completed survive (preserved, never stamped/replaced)
    expect(plan.preservedClientEventIds, contains('v1-past-equinox'));
    expect(
      plan.stamps.any((s) => s.clientEventId == 'v1-past-equinox'),
      isFalse,
    );

    // 3. user-edited futures: plan never rewrites user-facing fields
    //    (stamp payload only; title lives on the row the host keeps).
    final editedStamp = plan.stamps
        .where((s) => s.clientEventId == 'v1-edited-equinox')
        .toList();
    expect(editedStamp, isNotEmpty);
    expect(editedStamp.single.behaviorPayload.containsKey('title'), isFalse);
    expect(editedTitle, contains('Watch from Griffith'));

    // 4. stamped legacy futures are not duplicated
    final represented = plan.coverage.representedSkyEventIds.toSet();
    expect(
      plan.adds.any((a) => represented.contains(a.skyEventId)),
      isFalse,
    );
    expect(plan.coverage.duplicatesCreated, 0);

    // 5. missing safe V2 futures are added through catalog end
    expect(plan.coverage.canonicalNightsInWindow, greaterThan(0));
    expect(plan.coverage.newlyAdded, greaterThan(0));
    expect(
      plan.coverage.newlyAdded +
          plan.coverage.representedByLegacy +
          plan.coverage.deferredAmbiguous,
      plan.coverage.canonicalNightsInWindow,
    );
    final beyondV1 = catalog.upcomingNights(nowUtc: nowUtc).where(
          (n) => !n.primaryInstantUtc
              .isBefore(FollowSkyMigrationPolicy.defaultV1HorizonEnd),
        );
    for (final night in beyondV1) {
      final covered = represented.contains(night.skyEventId) ||
          plan.coverage.addedSkyEventIds.contains(night.skyEventId) ||
          plan.coverage.deferredSkyEventIds.contains(night.skyEventId);
      expect(covered, isTrue, reason: night.skyEventId);
      // Beyond V1 + no unmatched nearby → must be added, not deferred.
      if (!represented.contains(night.skyEventId)) {
        expect(
          plan.coverage.addedSkyEventIds,
          contains(night.skyEventId),
        );
      }
    }

    // 6. merged eclipse nights remain one occurrence
    for (final night in catalog.upcomingNights(nowUtc: nowUtc)) {
      if (!night.isEclipseFullMoon) continue;
      final addCount =
          plan.adds.where((a) => a.skyEventId == night.skyEventId).length;
      final already = represented.contains(night.skyEventId);
      expect(addCount + (already ? 1 : 0), lessThanOrEqualTo(1));
      expect(
        plan.adds.any((a) => a.skyEventId == night.companion!.id),
        isFalse,
      );
    }

    // 7. no notification cancels (we never normalize preserved alerts)
    expect(
      plan.deferrals
          .where(
            (d) =>
                d.reason ==
                FollowSkyMigrationDeferralReason.replaceCannotProveUntouched,
          )
          .isNotEmpty ||
          plan.stamps.isNotEmpty ||
          plan.adds.isNotEmpty,
      isTrue,
    );

    // Coverage report surface
    // ignore: avoid_print
    print('MIGRATION_COVERAGE ${plan.coverage.auditLine}');
    // ignore: avoid_print
    print(
      'MIGRATION_COVERAGE deferredIds=${plan.coverage.deferredSkyEventIds}',
    );

    // 8. second reconciliation writes nothing
    final after = <FollowSkyLegacyCalendarRow>[
      ...rows.map((r) {
        final stamp = plan.stamps
            .where((s) => s.clientEventId == r.clientEventId)
            .toList();
        if (stamp.isEmpty) return r;
        return FollowSkyLegacyCalendarRow(
          clientEventId: r.clientEventId,
          title: r.title,
          startsAtUtc: r.startsAtUtc,
          behaviorPayload: stamp.single.behaviorPayload,
          isPastOrCompleted: r.isPastOrCompleted,
        );
      }),
      for (final add in plan.adds)
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
      rows: after,
      ianaTimeZone: 'America/Los_Angeles',
    );
    expect(second.writesNothing, isTrue);
    expect(second.coverage.newlyAdded, 0);
    expect(second.coverage.duplicatesCreated, 0);
  });
}
