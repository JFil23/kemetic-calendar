import '../domain/sky_catalog.dart';
import 'legacy_track_sky_migration_matcher.dart';
import 'track_sky_materializer.dart';
import 'track_sky_reconciler.dart';

class TrackSkyMigrationResult {
  const TrackSkyMigrationResult({
    required this.plan,
    required this.legacyMatches,
    required this.remainedJoined,
  });

  final TrackSkyReconcilePlan plan;
  final Map<String, String> legacyMatches;
  final bool remainedJoined;
}

/// Cut 3 in-place upgrade. Never requires re-enrollment.
class TrackSkyMigrationService {
  TrackSkyMigrationService({
    LegacyTrackSkyMigrationMatcher? matcher,
    TrackSkyReconciler? reconciler,
  })  : matcher = matcher ?? const LegacyTrackSkyMigrationMatcher(),
        reconciler = reconciler ?? const TrackSkyReconciler();

  final LegacyTrackSkyMigrationMatcher matcher;
  final TrackSkyReconciler reconciler;

  TrackSkyMigrationResult migrateExistingJoinedFlow({
    required SkyCatalog catalog,
    required DateTime nowUtc,
    required List<TrackSkyExistingOccurrence> existing,
    required List<LegacyTrackSkyCandidate> legacyCandidates,
    bool flowStillActive = true,
  }) {
    final matches = matcher.matchAll(
      legacyEvents: legacyCandidates,
      catalog: catalog,
    );

    // Merge already-stamped skyEventIds into match map.
    final legacySkyEventIds = <String, String?>{
      for (final occ in existing)
        if (occ.skyEventId != null) occ.clientEventId: occ.skyEventId,
      ...matches,
    };

    final plan = reconciler.plan(
      catalog: catalog,
      nowUtc: nowUtc,
      existing: existing,
      legacySkyEventIds: legacySkyEventIds,
    );

    return TrackSkyMigrationResult(
      plan: plan,
      legacyMatches: matches,
      remainedJoined: flowStillActive,
    );
  }

  /// Apply plan to mutable lists (test/helper). Real persistence is caller-owned.
  List<String> notificationClientIdsToCancel(TrackSkyReconcilePlan plan) {
    return [
      for (final a in plan.actions)
        if (a.cancelNotificationForClientEventId != null)
          a.cancelNotificationForClientEventId!,
    ];
  }

  Set<String> representedSkyEventIds(TrackSkyReconcilePlan plan) {
    return {
      for (final a in plan.actions)
        if (a.skyEventId != null &&
            (a.type == TrackSkyReconcileActionType.stampOnly ||
                a.type == TrackSkyReconcileActionType.replace ||
                a.type == TrackSkyReconcileActionType.preserve))
          a.skyEventId!,
    };
  }

  Map<String, dynamic> stampPayload(String skyEventId, {required bool edited}) {
    return TrackSkyEventOwnership.behaviorPayload(
      skyEventId: skyEventId,
      legacyPreserved: edited,
    );
  }
}
