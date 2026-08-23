import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/follow_the_sky/follow_the_sky.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Cut 3.1 migration policy: stamp-only preservation + safe additive adds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FollowSkyMigrationPolicy policy;
  late TrackSkyMaterializer materializer;
  const reconciler = TrackSkyReconciler();
  final nowUtc = DateTime.utc(2026, 9, 1);
  late SkyCatalog catalog;

  setUpAll(() async {
    tzdata.initializeTimeZones();
    catalog = await SkyCatalogRepository().load();
    materializer = TrackSkyMaterializer(
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
    policy = FollowSkyMigrationPolicy();
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

  SkyEvent futureEvent() {
    final upcoming = catalog.upcoming(nowUtc: nowUtc);
    expect(upcoming, isNotEmpty);
    return upcoming.first;
  }

  FollowSkyMigrationPlan reduce({
    required TrackSkyReconcilePlan raw,
    required List<TrackSkyExistingOccurrence> existing,
    Map<String, String> legacyMatches = const {},
    List<LegacyTrackSkyCandidate> unmatchedLegacy = const [],
  }) {
    return policy.reduce(
      plan: raw,
      catalog: catalog,
      nowUtc: nowUtc,
      existing: existing,
      legacyMatches: legacyMatches,
      unmatchedLegacy: unmatchedLegacy,
      materializer: materializer,
      ianaTimeZone: 'America/Los_Angeles',
    );
  }

  group('preservation', () {
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
      expect(
        raw.actions.any((a) => a.type == TrackSkyReconcileActionType.replace),
        isTrue,
      );

      final reduced = reduce(
        raw: raw,
        existing: [legacy],
        legacyMatches: {'legacy-1': event.id},
      );
      expect(reduced.deferredReplaceCount, 1);
      expect(
        reduced.stamps.singleWhere((s) => s.clientEventId == 'legacy-1').skyEventId,
        event.id,
      );
      expect(
        TrackSkyEventOwnership.isLegacyPreserved(
          reduced.stamps.single.behaviorPayload,
        ),
        isTrue,
      );
    });

    test('cancelNotification never survives reduction', () {
      final event = futureEvent();
      final existing = [
        occ(
          id: 'legacy-1',
          title: event.name,
          startsAtUtc: event.primaryInstantUtc,
          hasScheduledNotification: true,
        ),
      ];
      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: existing,
        legacySkyEventIds: {'legacy-1': event.id},
      );
      expect(
        TrackSkyMigrationService().notificationClientIdsToCancel(raw),
        contains('legacy-1'),
      );
      final reduced = reduce(
        raw: raw,
        existing: existing,
        legacyMatches: {'legacy-1': event.id},
      );
      expect(reduced.deferredReplaceCount, greaterThan(0));
      // No cancel action exists on the reduced plan.
      expect(reduced.adds.every((a) => a.skyEventId != event.id), isTrue);
    });

    test('past and completed rows are preserved, never stamped', () {
      final existing = [
        occ(
          id: 'past-1',
          title: 'March Equinox',
          startsAtUtc: DateTime.utc(2025, 3, 20),
          isPastOrCompleted: true,
        ),
      ];
      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: existing,
        legacySkyEventIds: const {},
      );
      final reduced = reduce(raw: raw, existing: existing);
      expect(reduced.preservedClientEventIds, contains('past-1'));
      expect(
        reduced.stamps.any((s) => s.clientEventId == 'past-1'),
        isFalse,
      );
    });
  });

  group('additive future coverage', () {
    test('matched legacy night is not duplicated; other nights are added', () {
      final event = futureEvent();
      final existing = [
        occ(
          id: 'legacy-1',
          title: event.name,
          startsAtUtc: event.primaryInstantUtc,
          isUserEdited: true,
        ),
      ];
      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: existing,
        legacySkyEventIds: {'legacy-1': event.id},
      );
      final reduced = reduce(
        raw: raw,
        existing: existing,
        legacyMatches: {'legacy-1': event.id},
      );

      expect(reduced.coverage.representedByLegacy, greaterThanOrEqualTo(1));
      expect(reduced.adds.any((a) => a.skyEventId == event.id), isFalse);
      expect(
        reduced.coverage.newlyAdded,
        reduced.coverage.canonicalNightsInWindow -
            reduced.coverage.representedByLegacy -
            reduced.coverage.deferredAmbiguous,
      );
      expect(reduced.coverage.duplicatesCreated, 0);
      expect(reduced.adds, isNotEmpty);
      // Every add carries full V2 ownership.
      for (final add in reduced.adds) {
        expect(
          TrackSkyEventOwnership.skyEventIdFromPayload(
            add.occurrence.behaviorPayload,
          ),
          add.skyEventId,
        );
      }
    });

    test('unmatched nearby legacy defers that night; far nights still add', () {
      final nights = catalog.upcomingNights(nowUtc: nowUtc);
      expect(nights.length, greaterThan(2));
      final near = nights.first;
      final far = nights.last;
      expect(
        far.primaryInstantUtc.difference(near.primaryInstantUtc).abs(),
        greaterThan(const Duration(hours: 36)),
      );

      final unmatched = [
        LegacyTrackSkyCandidate(
          clientEventId: 'mystery',
          title: 'Something odd',
          startsAtUtc: near.primaryInstantUtc,
        ),
      ];
      final existing = [
        occ(
          id: 'mystery',
          title: 'Something odd',
          startsAtUtc: near.primaryInstantUtc,
          isUserEdited: true,
        ),
      ];
      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: existing,
        legacySkyEventIds: const {},
      );
      final reduced = reduce(
        raw: raw,
        existing: existing,
        unmatchedLegacy: unmatched,
      );

      expect(
        reduced.coverage.deferredSkyEventIds,
        contains(near.skyEventId),
      );
      expect(reduced.adds.any((a) => a.skyEventId == near.skyEventId), isFalse);
      expect(reduced.adds.any((a) => a.skyEventId == far.skyEventId), isTrue);
      expect(reduced.coverage.deferredAmbiguous, greaterThan(0));
    });

    test('nights beyond the V1 horizon are safe additive candidates', () {
      final beyond = catalog.upcomingNights(nowUtc: nowUtc).where(
            (n) => !n.primaryInstantUtc
                .isBefore(FollowSkyMigrationPolicy.defaultV1HorizonEnd),
          );
      expect(beyond, isNotEmpty);

      final existing = <TrackSkyExistingOccurrence>[];
      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: existing,
        legacySkyEventIds: const {},
      );
      final reduced = reduce(raw: raw, existing: existing);
      for (final night in beyond) {
        expect(
          reduced.adds.any((a) => a.skyEventId == night.skyEventId),
          isTrue,
          reason: '${night.skyEventId} is past V1 horizon and unmatched',
        );
      }
    });

    test('merged eclipse/full-Moon night stays one add', () {
      final eclipseNights = catalog.upcomingNights(nowUtc: nowUtc).where(
            (n) => n.isEclipseFullMoon,
          );
      expect(eclipseNights, isNotEmpty);
      final night = eclipseNights.first;

      final existing = <TrackSkyExistingOccurrence>[];
      final raw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: existing,
        legacySkyEventIds: const {},
      );
      final reduced = reduce(raw: raw, existing: existing);
      final matching =
          reduced.adds.where((a) => a.skyEventId == night.skyEventId);
      expect(matching.length, 1);
      expect(
        TrackSkyEventOwnership.companionIdsFromPayload(
          matching.single.occurrence.behaviorPayload,
        ),
        contains(night.companion!.id),
      );
      // Companion never gets its own add row.
      expect(
        reduced.adds.any((a) => a.skyEventId == night.companion!.id),
        isFalse,
      );
    });
  });

  group('idempotency', () {
    test('a second pass over a fully covered flow writes nothing', () {
      final firstExisting = <TrackSkyExistingOccurrence>[];
      final firstRaw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: firstExisting,
        legacySkyEventIds: const {},
      );
      final first = reduce(raw: firstRaw, existing: firstExisting);
      expect(first.adds, isNotEmpty);

      final secondExisting = [
        for (final add in first.adds)
          occ(
            id: 'v2-${add.skyEventId}',
            title: add.occurrence.title,
            startsAtUtc: add.occurrence.startsAtUtc,
            skyEventId: add.skyEventId,
            isUserEdited: true,
          ),
      ];
      final secondRaw = reconciler.plan(
        catalog: catalog,
        nowUtc: nowUtc,
        existing: secondExisting,
        legacySkyEventIds: {
          for (final o in secondExisting) o.clientEventId: o.skyEventId,
        },
      );
      final second = reduce(
        raw: secondRaw,
        existing: secondExisting,
        legacyMatches: {
          for (final o in secondExisting)
            if (o.skyEventId != null) o.clientEventId: o.skyEventId!,
        },
      );
      expect(second.writesNothing, isTrue);
      expect(second.coverage.newlyAdded, 0);
      expect(second.coverage.deferredAmbiguous, 0);
      expect(second.coverage.duplicatesCreated, 0);
    });
  });
}
