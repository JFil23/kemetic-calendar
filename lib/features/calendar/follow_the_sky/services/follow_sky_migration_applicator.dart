import '../domain/sky_catalog.dart';
import 'follow_sky_migration_policy.dart';
import 'legacy_track_sky_migration_matcher.dart';
import 'sky_visibility_service.dart';
import 'track_sky_materializer.dart';
import 'track_sky_migration_service.dart';
import 'track_sky_reconciler.dart';

/// One calendar row owned by a joined Follow the Sky flow, as seen by the host.
///
/// Title / time / payload are taken as the user has them. The applicator never
/// invents content for existing rows — it stamps ownership and, when safe,
/// adds missing V2 observing nights.
class FollowSkyLegacyCalendarRow {
  const FollowSkyLegacyCalendarRow({
    required this.clientEventId,
    required this.title,
    required this.startsAtUtc,
    this.behaviorPayload,
    this.isPastOrCompleted = false,
  });

  final String clientEventId;
  final String title;
  final DateTime startsAtUtc;
  final Map<String, dynamic>? behaviorPayload;
  final bool isPastOrCompleted;
}

/// Builds the Cut 3.1 migration plan: stamp-only preservation + additive future
/// coverage. Persistence is caller-owned.
class FollowSkyMigrationApplicator {
  FollowSkyMigrationApplicator({
    TrackSkyMigrationService? migration,
    FollowSkyMigrationPolicy? policy,
    TrackSkyMaterializer? materializer,
    SkyVisibilityService? visibilityService,
  })  : migration = migration ?? TrackSkyMigrationService(),
        policy = policy ?? FollowSkyMigrationPolicy(),
        materializer = materializer ??
            TrackSkyMaterializer(
              toLocal: (utc, _) => utc.toLocal(),
              toUtc: (local, _) => local.toUtc(),
            ),
        visibilityService = visibilityService ?? const SkyVisibilityService();

  final TrackSkyMigrationService migration;
  final FollowSkyMigrationPolicy policy;
  final TrackSkyMaterializer materializer;
  final SkyVisibilityService visibilityService;

  FollowSkyMigrationPlan plan({
    required SkyCatalog catalog,
    required DateTime nowUtc,
    required List<FollowSkyLegacyCalendarRow> rows,
    required String ianaTimeZone,
    bool flowStillActive = true,
    bool hasObservingLocation = false,
  }) {
    final existing = <TrackSkyExistingOccurrence>[];
    final candidates = <LegacyTrackSkyCandidate>[];

    for (final row in rows) {
      final skyEventId =
          TrackSkyEventOwnership.skyEventIdFromPayload(row.behaviorPayload);
      existing.add(
        TrackSkyExistingOccurrence(
          clientEventId: row.clientEventId,
          title: row.title,
          startsAtUtc: row.startsAtUtc,
          skyEventId: skyEventId,
          isPastOrCompleted: row.isPastOrCompleted,
          // V1 never recorded as-generated title/time, so "untouched" cannot
          // be proven. Treat every live future as edited → stamp-only path;
          // already-owned rows then become a no-op on the second pass.
          isUserEdited: !row.isPastOrCompleted,
        ),
      );
      if (skyEventId == null && !row.isPastOrCompleted) {
        candidates.add(
          LegacyTrackSkyCandidate(
            clientEventId: row.clientEventId,
            title: row.title,
            startsAtUtc: row.startsAtUtc,
          ),
        );
      }
    }

    final raw = migration.migrateExistingJoinedFlow(
      catalog: catalog,
      nowUtc: nowUtc,
      existing: existing,
      legacyCandidates: candidates,
      flowStillActive: flowStillActive,
    );

    final unmatched = [
      for (final c in candidates)
        if (!raw.legacyMatches.containsKey(c.clientEventId)) c,
    ];

    return policy.reduce(
      plan: raw.plan,
      catalog: catalog,
      nowUtc: nowUtc,
      existing: existing,
      legacyMatches: raw.legacyMatches,
      unmatchedLegacy: unmatched,
      materializer: materializer,
      ianaTimeZone: ianaTimeZone,
      visibilityNoteFor: (event) => visibilityService
          .decide(event, hasObservingLocation: hasObservingLocation)
          .userFacingNote,
      flowStillActive: raw.remainedJoined,
    );
  }
}
