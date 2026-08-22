import '../domain/sky_catalog.dart';
import '../domain/sky_event.dart';
import 'track_sky_materializer.dart';

enum TrackSkyReconcileActionType {
  preserve,
  replace,
  stampOnly,
  add,
  cancelNotification,
}

class TrackSkyExistingOccurrence {
  const TrackSkyExistingOccurrence({
    required this.clientEventId,
    required this.title,
    required this.startsAtUtc,
    this.skyEventId,
    this.isPastOrCompleted = false,
    this.isUserEdited = false,
    this.hasScheduledNotification = false,
  });

  final String clientEventId;
  final String title;
  final DateTime startsAtUtc;
  final String? skyEventId;
  final bool isPastOrCompleted;
  final bool isUserEdited;
  final bool hasScheduledNotification;
}

class TrackSkyReconcileAction {
  const TrackSkyReconcileAction({
    required this.type,
    this.skyEventId,
    this.existingClientEventId,
    this.cancelNotificationForClientEventId,
  });

  final TrackSkyReconcileActionType type;
  final String? skyEventId;
  final String? existingClientEventId;
  final String? cancelNotificationForClientEventId;
}

class TrackSkyReconcilePlan {
  const TrackSkyReconcilePlan({required this.actions});

  final List<TrackSkyReconcileAction> actions;

  bool get isEmpty => actions.isEmpty;
}

/// Idempotent reconciler model (pure). Persistence/notifications applied by enrollment layer.
class TrackSkyReconciler {
  const TrackSkyReconciler();

  TrackSkyReconcilePlan plan({
    required SkyCatalog catalog,
    required DateTime nowUtc,
    required List<TrackSkyExistingOccurrence> existing,
    required Map<String, String?> legacySkyEventIds,
  }) {
    final actions = <TrackSkyReconcileAction>[];
    final represented = <String>{};

    for (final occ in existing) {
      if (occ.isPastOrCompleted) {
        actions.add(
          TrackSkyReconcileAction(
            type: TrackSkyReconcileActionType.preserve,
            existingClientEventId: occ.clientEventId,
            skyEventId: occ.skyEventId,
          ),
        );
        if (occ.skyEventId != null) represented.add(occ.skyEventId!);
        continue;
      }

      final matchedId = occ.skyEventId ?? legacySkyEventIds[occ.clientEventId];
      if (matchedId == null) {
        // Unmatched future — leave for matcher; do not invent.
        actions.add(
          TrackSkyReconcileAction(
            type: TrackSkyReconcileActionType.preserve,
            existingClientEventId: occ.clientEventId,
          ),
        );
        continue;
      }

      represented.add(matchedId);

      if (occ.isUserEdited) {
        if (occ.skyEventId == matchedId) {
          // Already stamped — second pass writes nothing for this row.
          continue;
        }
        actions.add(
          TrackSkyReconcileAction(
            type: TrackSkyReconcileActionType.stampOnly,
            skyEventId: matchedId,
            existingClientEventId: occ.clientEventId,
          ),
        );
        continue;
      }

      // Untouched system-generated future: replace + cancel old notification.
      actions.add(
        TrackSkyReconcileAction(
          type: TrackSkyReconcileActionType.replace,
          skyEventId: matchedId,
          existingClientEventId: occ.clientEventId,
          cancelNotificationForClientEventId:
              occ.hasScheduledNotification ? occ.clientEventId : null,
        ),
      );
    }

    for (final event in catalog.upcoming(nowUtc: nowUtc)) {
      if (represented.contains(event.id)) continue;
      actions.add(
        TrackSkyReconcileAction(
          type: TrackSkyReconcileActionType.add,
          skyEventId: event.id,
        ),
      );
    }

    return TrackSkyReconcilePlan(actions: actions);
  }

  /// Second-pass plan when everything is already V2-owned and complete → empty writes.
  bool isIdempotentNoop(TrackSkyReconcilePlan plan) {
    return plan.actions.every(
      (a) =>
          a.type == TrackSkyReconcileActionType.preserve ||
          (a.type == TrackSkyReconcileActionType.stampOnly &&
              a.skyEventId == null),
    );
  }
}

extension TrackSkyReconcilerMaterialize on TrackSkyReconcilePlan {
  List<SkyEvent> eventsToAdd(SkyCatalog catalog) {
    final ids = actions
        .where((a) => a.type == TrackSkyReconcileActionType.add)
        .map((a) => a.skyEventId)
        .whereType<String>();
    return [
      for (final id in ids)
        if (catalog.byId(id) != null) catalog.byId(id)!,
    ];
  }
}

/// Helper to stamp ownership after replace.
Map<String, dynamic> ownershipAfterReconcile({
  required String skyEventId,
  required bool legacyPreserved,
}) {
  return TrackSkyEventOwnership.behaviorPayload(
    skyEventId: skyEventId,
    legacyPreserved: legacyPreserved,
  );
}
