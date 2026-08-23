import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';

/// Cut 3 migration policy. Proves the existing-user contract holds for the
/// actions the policy is willing to apply, and that the destructive actions the
/// reconciler plans are withheld rather than run.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const policy = FollowSkyMigrationPolicy();
  const reconciler = TrackSkyReconciler();
  final nowUtc = DateTime.utc(2026, 3, 1);

  late SkyCatalog catalog;

  setUpAll(() async {
    catalog = await SkyCatalogRepository().load();
  });

  TrackSkyExistingOccurrence occ({
    required String id,
    required String title,
    required DateTime startsAtUtc,
    String? skyEventId,
    bool isPastOrCompleted = false,
    bool isUserEdited = false,
    bool hasScheduledNotification = false,
  }) {
    return TrackSkyExistingOccurrence(
      clientEventId: id,
      title: title,
      startsAtUtc: startsAtUtc,
      skyEventId: skyEventId,
      isPastOrCompleted: isPastOrCompleted,
      isUserEdited: isUserEdited,
      hasScheduledNotification: hasScheduledNotification,
    );
  }

  /// A future catalog event we can build a realistic legacy row against.
  SkyEvent futureEvent() {
    final upcoming = catalog.upcoming(nowUtc: nowUtc);
    expect(upcoming, isNotEmpty, reason: 'catalog must have future events');
    return upcoming.first;
  }

  group('non-destructive reduction', () {
    test('replace is never applied; it becomes an ownership stamp', () {
      final event = futureEvent();
      final legacy = occ(
        id: 'legacy-1',
        title: event.name,
        startsAtUtc: event.primaryInstantUtc,
        hasScheduledNotification: true,
      );

      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: [legacy],
        legacySkyEventIds: {'legacy-1': event.id},
      );

      // The reconciler really does want to replace this row.
      expect(
        raw.actions.any(
          (a) =>
              a.type == TrackSkyReconcileActionType.replace &&
              a.existingClientEventId == 'legacy-1',
        ),
        isTrue,
      );

      final reduced = policy.reduce(plan: raw, catalog: catalog);

      // Policy withholds it and records why.
      expect(reduced.deferredReplaceCount, 1);
      expect(
        reduced.deferrals.first.reason,
        FollowSkyMigrationDeferralReason.replaceCannotProveUntouched,
      );

      // The row is still claimed for V2 — just without a rewrite.
      final stamp = reduced.stamps.singleWhere(
        (s) => s.clientEventId == 'legacy-1',
      );
      expect(stamp.skyEventId, event.id);
      expect(
        TrackSkyEventOwnership.skyEventIdFromPayload(stamp.behaviorPayload),
        event.id,
      );
      expect(
        TrackSkyEventOwnership.isLegacyPreserved(stamp.behaviorPayload),
        isTrue,
        reason: 'a migrated row must be marked as legacy-preserved',
      );
    });

    test('add is never applied while legacy futures exist', () {
      final event = futureEvent();
      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: [
          occ(
            id: 'legacy-1',
            title: event.name,
            startsAtUtc: event.primaryInstantUtc,
          ),
        ],
        legacySkyEventIds: {'legacy-1': event.id},
      );

      final reduced = policy.reduce(plan: raw, catalog: catalog);

      expect(
        reduced.deferredAddCount,
        greaterThan(0),
        reason: 'catalog has more upcoming events than the legacy flow had',
      );
      // No stamp may point at an event the user does not already have a row for.
      final stampedIds = reduced.stamps.map((s) => s.skyEventId).toSet();
      expect(stampedIds, {event.id});
    });

    test('cancelNotification never survives reduction', () {
      final event = futureEvent();
      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: [
          occ(
            id: 'legacy-1',
            title: event.name,
            startsAtUtc: event.primaryInstantUtc,
            hasScheduledNotification: true,
          ),
        ],
        legacySkyEventIds: {'legacy-1': event.id},
      );

      // The reconciler asked for a cancel...
      expect(
        TrackSkyMigrationService().notificationClientIdsToCancel(raw),
        contains('legacy-1'),
      );

      // ...but the policy applies no replace, so nothing is cancelled and the
      // user's existing alert keeps firing.
      final reduced = policy.reduce(plan: raw, catalog: catalog);
      expect(reduced.stamps.single.clientEventId, 'legacy-1');
      expect(reduced.deferredReplaceCount, 1);
    });
  });

  group('existing-user contract', () {
    test('past and completed rows are preserved, never stamped', () {
      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: [
          occ(
            id: 'past-1',
            title: 'March Equinox',
            startsAtUtc: DateTime.utc(2025, 3, 20),
            isPastOrCompleted: true,
          ),
        ],
        legacySkyEventIds: const {},
      );

      final reduced = policy.reduce(plan: raw, catalog: catalog);

      expect(reduced.preservedClientEventIds, contains('past-1'));
      expect(
        reduced.stamps.any((s) => s.clientEventId == 'past-1'),
        isFalse,
        reason: 'history must not be rewritten',
      );
    });

    test('a user-edited future keeps its own content and only gains a stamp',
        () {
      final event = futureEvent();
      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: [
          occ(
            id: 'edited-1',
            title: 'My own name for this night',
            startsAtUtc: event.primaryInstantUtc,
            isUserEdited: true,
          ),
        ],
        legacySkyEventIds: {'edited-1': event.id},
      );

      expect(
        raw.actions.any(
          (a) =>
              a.type == TrackSkyReconcileActionType.stampOnly &&
              a.existingClientEventId == 'edited-1',
        ),
        isTrue,
      );

      final reduced = policy.reduce(plan: raw, catalog: catalog);
      final stamp = reduced.stamps.singleWhere(
        (s) => s.clientEventId == 'edited-1',
      );
      expect(stamp.skyEventId, event.id);
      expect(
        TrackSkyEventOwnership.isLegacyPreserved(stamp.behaviorPayload),
        isTrue,
      );
      expect(reduced.deferredReplaceCount, 0);
    });

    test('an unmatched future is preserved, never guessed at', () {
      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: [
          occ(
            id: 'mystery-1',
            title: 'Something the matcher cannot place',
            startsAtUtc: DateTime.utc(2026, 6, 15),
          ),
        ],
        legacySkyEventIds: const {},
      );

      final reduced = policy.reduce(plan: raw, catalog: catalog);
      expect(reduced.preservedClientEventIds, contains('mystery-1'));
      expect(reduced.stamps.any((s) => s.clientEventId == 'mystery-1'), isFalse);
    });
  });

  group('idempotency', () {
    test('a second pass over an already-stamped flow writes nothing', () {
      final event = futureEvent();
      final existing = [
        occ(
          id: 'legacy-1',
          title: event.name,
          startsAtUtc: event.primaryInstantUtc,
          skyEventId: event.id,
          isUserEdited: true,
        ),
        // Everything else the catalog knows about is already represented.
        for (final e in catalog.upcoming(nowUtc: nowUtc).skip(1))
          occ(
            id: 'v2-${e.id}',
            title: e.name,
            startsAtUtc: e.primaryInstantUtc,
            skyEventId: e.id,
            isUserEdited: true,
          ),
      ];

      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: existing,
        legacySkyEventIds: {
          for (final o in existing) o.clientEventId: o.skyEventId,
        },
      );

      final reduced = policy.reduce(plan: raw, catalog: catalog);
      expect(
        reduced.writesNothing,
        isTrue,
        reason: 'reopening a migrated flow must not touch the database',
      );
      expect(reduced.deferredAddCount, 0);
      expect(reduced.deferredReplaceCount, 0);
    });

    test('alreadyOwned recognises a V2-stamped payload', () {
      final owned = TrackSkyEventOwnership.behaviorPayload(
        skyEventId: 'sky-1',
        legacyPreserved: true,
      );
      expect(policy.alreadyOwned(owned), isTrue);
      expect(policy.alreadyOwned(null), isFalse);
      expect(policy.alreadyOwned(const {'kind': 'something_else'}), isFalse);
    });
  });

  group('full migration through TrackSkyMigrationService', () {
    test('a legacy joined flow stays joined and is claimed without rewrites',
        () {
      final event = futureEvent();
      final result = TrackSkyMigrationService().migrateExistingJoinedFlow(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: [
          occ(
            id: 'legacy-past',
            title: 'March Equinox',
            startsAtUtc: DateTime.utc(2025, 3, 20),
            isPastOrCompleted: true,
          ),
          occ(
            id: 'legacy-future',
            title: event.name,
            startsAtUtc: event.primaryInstantUtc,
          ),
        ],
        legacyCandidates: [
          LegacyTrackSkyCandidate(
            clientEventId: 'legacy-future',
            title: event.name,
            startsAtUtc: event.primaryInstantUtc,
          ),
        ],
      );

      expect(result.remainedJoined, isTrue);
      expect(result.legacyMatches['legacy-future'], event.id);

      final reduced = policy.reduce(plan: result.plan, catalog: catalog);
      expect(reduced.preservedClientEventIds, contains('legacy-past'));
      expect(
        reduced.stamps.map((s) => s.clientEventId),
        contains('legacy-future'),
      );
      expect(reduced.deferredReplaceCount, 1);
      expect(reduced.auditLine, contains('stamps=1'));
    });
  });
}
