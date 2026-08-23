import '../domain/sky_catalog.dart';
import 'track_sky_materializer.dart';
import 'track_sky_reconciler.dart';

/// Why a reconciler action was not applied.
enum FollowSkyMigrationDeferralReason {
  /// `replace` rewrites a row the user may have edited. V1 never recorded the
  /// as-generated title/time, so "untouched" cannot be proven from the row
  /// alone, and `isUserEdited` defaults to false — every legacy future would
  /// be rewritten. Needs a product decision before it can run.
  replaceCannotProveUntouched,

  /// `add` is only safe once every legacy future is matched. While unmatched
  /// legacy futures remain, adding the catalog event they stand for would put
  /// a duplicate V2 row beside the user's existing one.
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

/// The subset of a reconcile plan that is safe to apply to live user data.
class FollowSkyMigrationPlan {
  const FollowSkyMigrationPlan({
    required this.stamps,
    required this.preservedClientEventIds,
    required this.deferrals,
  });

  final List<FollowSkyMigrationStamp> stamps;
  final List<String> preservedClientEventIds;
  final List<FollowSkyMigrationDeferral> deferrals;

  /// True when applying this plan would write nothing. A second pass over an
  /// already-migrated flow must be a no-op.
  bool get writesNothing => stamps.isEmpty;

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
      'stamps=${stamps.length} preserved=${preservedClientEventIds.length} '
      'deferredReplace=$deferredReplaceCount deferredAdd=$deferredAddCount';
}

/// Cut 3 migration policy: reduces a [TrackSkyReconcilePlan] to the actions
/// that cannot lose user data.
///
/// The reconciler is free to plan `replace` and `add`; this policy decides what
/// actually reaches the database. Only ownership stamping is applied, so a
/// legacy Follow the Sky flow becomes V2-owned in place: the user stays joined,
/// their rows keep their own titles and times, past events are untouched, and
/// no second copy of an event is created.
class FollowSkyMigrationPolicy {
  const FollowSkyMigrationPolicy();

  FollowSkyMigrationPlan reduce({
    required TrackSkyReconcilePlan plan,
    SkyCatalog? catalog,
  }) {
    final stamps = <FollowSkyMigrationStamp>[];
    final preserved = <String>[];
    final deferrals = <FollowSkyMigrationDeferral>[];
    final stamped = <String>{};

    for (final action in plan.actions) {
      switch (action.type) {
        case TrackSkyReconcileActionType.preserve:
          final id = action.existingClientEventId;
          if (id != null) preserved.add(id);
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
          break;

        case TrackSkyReconcileActionType.add:
          deferrals.add(
            FollowSkyMigrationDeferral(
              reason: FollowSkyMigrationDeferralReason
                  .addWouldDuplicateUnmatchedLegacy,
              skyEventId: action.skyEventId,
            ),
          );
          break;

        case TrackSkyReconcileActionType.cancelNotification:
          // Only ever paired with replace, which never runs here.
          break;
      }
    }

    return FollowSkyMigrationPlan(
      stamps: stamps,
      preservedClientEventIds: preserved,
      deferrals: deferrals,
    );
  }

  /// True when [occurrence] already carries V2 ownership, so it needs no write.
  bool alreadyOwned(Map<String, dynamic>? behaviorPayload) {
    return TrackSkyEventOwnership.skyEventIdFromPayload(behaviorPayload) != null;
  }
}
