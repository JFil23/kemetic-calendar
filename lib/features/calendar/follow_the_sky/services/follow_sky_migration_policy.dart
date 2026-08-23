import '../domain/sky_catalog.dart';
import '../domain/sky_event.dart';
import '../domain/sky_observing_night.dart';
import 'legacy_track_sky_migration_matcher.dart';
import 'track_sky_materializer.dart';
import 'track_sky_reconciler.dart';

/// Why a reconciler / additive action was not applied.
enum FollowSkyMigrationDeferralReason {
  /// `replace` would rewrite a row the user may have edited. Cut 3 never
  /// applies replace; the row is stamped in place instead.
  replaceCannotProveUntouched,

  /// An unmatched legacy future sits close enough in time that this night
  /// might already be that row. Prefer no duplicate over aggressive add.
  addWouldDuplicateUnmatchedLegacy,
}

class FollowSkyMigrationDeferral {
  const FollowSkyMigrationDeferral({
    required this.reason,
    this.clientEventId,
    this.skyEventId,
  });

  final FollowSkyMigrationDeferralReason reason;
  final String? clientEventId;
  final String? skyEventId;
}

/// One non-destructive write: attach V2 ownership to an existing row.
///
/// Touches `behavior_payload` only. Title, time, calendar and notifications are
/// left exactly as the user has them.
class FollowSkyMigrationStamp {
  const FollowSkyMigrationStamp({
    required this.clientEventId,
    required this.skyEventId,
    required this.behaviorPayload,
  });

  final String clientEventId;
  final String skyEventId;
  final Map<String, dynamic> behaviorPayload;
}

/// A demonstrably-absent V2 observing night to materialize as a new row.
class FollowSkyMigrationAdd {
  const FollowSkyMigrationAdd({
    required this.skyEventId,
    required this.occurrence,
  });

  final String skyEventId;
  final MaterializedSkyOccurrence occurrence;
}

/// Coverage numbers for an existing-user migration pass.
class FollowSkyMigrationCoverageReport {
  const FollowSkyMigrationCoverageReport({
    required this.canonicalNightsInWindow,
    required this.representedByLegacy,
    required this.newlyAdded,
    required this.deferredAmbiguous,
    required this.duplicatesCreated,
    required this.deferredSkyEventIds,
    required this.representedSkyEventIds,
    required this.addedSkyEventIds,
  });

  final int canonicalNightsInWindow;
  final int representedByLegacy;
  final int newlyAdded;
  final int deferredAmbiguous;

  /// Always 0 by construction — we never create a second row for a represented
  /// night, and we withhold adds that could collide with unmatched legacy.
  final int duplicatesCreated;

  final List<String> deferredSkyEventIds;
  final List<String> representedSkyEventIds;
  final List<String> addedSkyEventIds;

  String get auditLine =>
      'canonical=$canonicalNightsInWindow '
      'representedByLegacy=$representedByLegacy '
      'newlyAdded=$newlyAdded '
      'deferredAmbiguous=$deferredAmbiguous '
      'duplicatesCreated=$duplicatesCreated';
}

/// The subset of a reconcile plan that is safe to apply to live user data.
class FollowSkyMigrationPlan {
  const FollowSkyMigrationPlan({
    required this.stamps,
    required this.adds,
    required this.preservedClientEventIds,
    required this.deferrals,
    required this.coverage,
    required this.remainedJoined,
  });

  final List<FollowSkyMigrationStamp> stamps;
  final List<FollowSkyMigrationAdd> adds;
  final List<String> preservedClientEventIds;
  final List<FollowSkyMigrationDeferral> deferrals;
  final FollowSkyMigrationCoverageReport coverage;
  final bool remainedJoined;

  /// True when applying this plan would write nothing.
  bool get writesNothing => stamps.isEmpty && adds.isEmpty;

  int get deferredReplaceCount => deferrals
      .where(
        (d) =>
            d.reason ==
            FollowSkyMigrationDeferralReason.replaceCannotProveUntouched,
      )
      .length;

  int get deferredAddCount => deferrals
      .where(
        (d) =>
            d.reason ==
            FollowSkyMigrationDeferralReason
                .addWouldDuplicateUnmatchedLegacy,
      )
      .length;

  String get auditLine =>
      'stamps=${stamps.length} adds=${adds.length} '
      'preserved=${preservedClientEventIds.length} '
      'deferredReplace=$deferredReplaceCount deferredAdd=$deferredAddCount '
      '| ${coverage.auditLine}';
}

/// Cut 3 / 3.1 migration policy.
///
/// Preservation baseline (never abandoned):
/// - `replace` is never applied — stamp ownership instead.
/// - existing title / time / notifications are never rewritten or cancelled
///   merely to normalize.
///
/// Additive completion (Cut 3.1):
/// - matched / stamped legacy futures count as represented observing nights;
/// - missing V2 nights are added only when absence is unambiguous;
/// - nights beyond the V1 catalog horizon are always safe additive candidates;
/// - within the overlap, unmatched legacy rows within the matcher window defer
///   nearby adds (prefer no duplicate).
class FollowSkyMigrationPolicy {
  FollowSkyMigrationPolicy({
    DateTime? v1CatalogHorizonEndUtc,
    this.ambiguityWindow = const Duration(hours: 36),
  }) : v1CatalogHorizonEndUtc =
            v1CatalogHorizonEndUtc ?? defaultV1HorizonEnd;

  /// Last exclusive end of known V1 Track Sky markdown coverage.
  /// Instant at or after this could not have been V1-materialized.
  static final DateTime defaultV1HorizonEnd = DateTime.utc(2027, 3, 1);

  final DateTime v1CatalogHorizonEndUtc;
  final Duration ambiguityWindow;

  FollowSkyMigrationPlan reduce({
    required TrackSkyReconcilePlan plan,
    required SkyCatalog catalog,
    required DateTime nowUtc,
    required List<TrackSkyExistingOccurrence> existing,
    required Map<String, String> legacyMatches,
    required List<LegacyTrackSkyCandidate> unmatchedLegacy,
    required TrackSkyMaterializer materializer,
    required String ianaTimeZone,
    String? Function(SkyEvent event)? visibilityNoteFor,
    bool flowStillActive = true,
  }) {
    final stamps = <FollowSkyMigrationStamp>[];
    final preserved = <String>[];
    final deferrals = <FollowSkyMigrationDeferral>[];
    final stamped = <String>{};
    final represented = <String>{};

    void markRepresented(String? skyEventId) {
      if (skyEventId == null || skyEventId.isEmpty) return;
      represented.add(skyEventId);
      final event = catalog.byId(skyEventId);
      if (event == null || event.mergedIntoId != null) return;
      final night = catalog.observingNight(event);
      represented.add(night.skyEventId);
      final companion = night.companion;
      if (companion != null) represented.add(companion.id);
    }

    for (final occ in existing) {
      markRepresented(occ.skyEventId);
      markRepresented(legacyMatches[occ.clientEventId]);
    }

    for (final action in plan.actions) {
      switch (action.type) {
        case TrackSkyReconcileActionType.preserve:
          final id = action.existingClientEventId;
          if (id != null) preserved.add(id);
          markRepresented(action.skyEventId);
          break;

        case TrackSkyReconcileActionType.stampOnly:
          final id = action.existingClientEventId;
          final skyEventId = action.skyEventId;
          if (id == null || skyEventId == null) break;
          if (!stamped.add(id)) break;
          stamps.add(
            FollowSkyMigrationStamp(
              clientEventId: id,
              skyEventId: skyEventId,
              behaviorPayload: ownershipAfterReconcile(
                skyEventId: skyEventId,
                legacyPreserved: true,
                catalog: catalog,
              ),
            ),
          );
          markRepresented(skyEventId);
          break;

        case TrackSkyReconcileActionType.replace:
          // Downgrade to a stamp: claim the row for V2 without rewriting it.
          final id = action.existingClientEventId;
          final skyEventId = action.skyEventId;
          deferrals.add(
            FollowSkyMigrationDeferral(
              reason: FollowSkyMigrationDeferralReason
                  .replaceCannotProveUntouched,
              clientEventId: id,
              skyEventId: skyEventId,
            ),
          );
          if (id == null || skyEventId == null) break;
          if (!stamped.add(id)) break;
          stamps.add(
            FollowSkyMigrationStamp(
              clientEventId: id,
              skyEventId: skyEventId,
              behaviorPayload: ownershipAfterReconcile(
                skyEventId: skyEventId,
                legacyPreserved: true,
                catalog: catalog,
              ),
            ),
          );
          markRepresented(skyEventId);
          break;

        case TrackSkyReconcileActionType.add:
          // Additive decisions are made below from observing nights, not from
          // the reconciler's raw add list (which is unaware of ambiguity).
          break;

        case TrackSkyReconcileActionType.cancelNotification:
          // Never cancel merely to normalize a preserved legacy row.
          break;
      }
    }

    final nights = catalog.upcomingNights(nowUtc: nowUtc);
    final adds = <FollowSkyMigrationAdd>[];
    final deferredAddIds = <String>[];
    final representedBeforeAdds = Set<String>.from(represented);

    for (final night in nights) {
      final id = night.skyEventId;
      if (represented.contains(id)) continue;

      final ambiguousLegacy = _ambiguousLegacyFor(
        night: night,
        unmatchedLegacy: unmatchedLegacy,
      );
      if (ambiguousLegacy != null) {
        deferrals.add(
          FollowSkyMigrationDeferral(
            reason: FollowSkyMigrationDeferralReason
                .addWouldDuplicateUnmatchedLegacy,
            clientEventId: ambiguousLegacy.clientEventId,
            skyEventId: id,
          ),
        );
        deferredAddIds.add(id);
        continue;
      }

      // Beyond V1 horizon → always safe. Within overlap → unambiguous absence.
      final beyondV1 =
          !night.primaryInstantUtc.isBefore(v1CatalogHorizonEndUtc);
      if (!beyondV1) {
        // Still safe: no unmatched legacy could claim this night, and it is
        // not already represented by a matched/stamped row.
      }

      final occurrence = materializer.materialize(
        event: night.anchor,
        night: night,
        ianaTimeZone: ianaTimeZone,
        visibilityNote: visibilityNoteFor?.call(night.windowSource),
      );
      adds.add(
        FollowSkyMigrationAdd(skyEventId: id, occurrence: occurrence),
      );
      markRepresented(id);
    }

    final coverage = FollowSkyMigrationCoverageReport(
      canonicalNightsInWindow: nights.length,
      representedByLegacy: nights
          .where((n) => representedBeforeAdds.contains(n.skyEventId))
          .length,
      newlyAdded: adds.length,
      deferredAmbiguous: deferredAddIds.length,
      duplicatesCreated: 0,
      deferredSkyEventIds: List<String>.unmodifiable(deferredAddIds),
      representedSkyEventIds: List<String>.unmodifiable(
        nights
            .where((n) => representedBeforeAdds.contains(n.skyEventId))
            .map((n) => n.skyEventId)
            .toList(growable: false),
      ),
      addedSkyEventIds: List<String>.unmodifiable(
        adds.map((a) => a.skyEventId).toList(growable: false),
      ),
    );

    return FollowSkyMigrationPlan(
      stamps: stamps,
      adds: adds,
      preservedClientEventIds: preserved,
      deferrals: deferrals,
      coverage: coverage,
      remainedJoined: flowStillActive,
    );
  }

  /// True when [behaviorPayload] already carries V2 ownership.
  bool alreadyOwned(Map<String, dynamic>? behaviorPayload) {
    return TrackSkyEventOwnership.skyEventIdFromPayload(behaviorPayload) != null;
  }

  LegacyTrackSkyCandidate? _ambiguousLegacyFor({
    required SkyObservingNight night,
    required List<LegacyTrackSkyCandidate> unmatchedLegacy,
  }) {
    for (final legacy in unmatchedLegacy) {
      final delta =
          night.primaryInstantUtc.difference(legacy.startsAtUtc).abs();
      if (delta <= ambiguityWindow) return legacy;
    }
    return null;
  }
}
