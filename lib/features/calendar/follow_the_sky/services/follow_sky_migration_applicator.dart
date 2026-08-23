import '../domain/sky_catalog.dart';
import 'follow_sky_migration_policy.dart';
import 'legacy_track_sky_migration_matcher.dart';
import 'track_sky_materializer.dart';
import 'track_sky_migration_service.dart';
import 'track_sky_reconciler.dart';

/// One calendar row owned by a joined Follow the Sky flow, as seen by the host.
///
/// Title / time / payload are taken as the user has them. The applicator never
/// invents content — it only decides which rows get a V2 ownership stamp.
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

/// Builds the non-destructive Cut 3 migration plan from live calendar rows.
///
/// Persistence is caller-owned: apply [FollowSkyMigrationPlan.stamps] by
/// writing `behavior_payload` only. Never rewrite title or time here.
class FollowSkyMigrationApplicator {
  FollowSkyMigrationApplicator({
    TrackSkyMigrationService? migration,
    FollowSkyMigrationPolicy? policy,
  })  : migration = migration ?? TrackSkyMigrationService(),
        policy = policy ?? const FollowSkyMigrationPolicy();

  final TrackSkyMigrationService migration;
  final FollowSkyMigrationPolicy policy;

  FollowSkyMigrationPlan plan({
    required SkyCatalog catalog,
    required DateTime nowUtc,
    required List<FollowSkyLegacyCalendarRow> rows,
    bool flowStillActive = true,
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

    return policy.reduce(plan: raw.plan, catalog: catalog);
  }
}
