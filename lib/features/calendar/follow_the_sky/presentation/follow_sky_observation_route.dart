import '../domain/sky_catalog.dart';
import '../services/track_sky_materializer.dart';

/// Pure routing gate for the dedicated event-time observation experience.
class FollowSkyObservationRoute {
  const FollowSkyObservationRoute._();

  static bool matches({
    required String? clientEventId,
    required Map<String, dynamic>? behaviorPayload,
    required SkyCatalog? catalog,
  }) {
    if (clientEventId?.trim().isEmpty != false) return false;
    if (behaviorPayload?['kind'] != TrackSkyEventOwnership.behaviorKind) {
      return false;
    }
    if (behaviorPayload?['trackSkySchemaVersion'] !=
        TrackSkyEventOwnership.schemaVersion) {
      return false;
    }
    final skyEventId = TrackSkyEventOwnership.skyEventIdFromPayload(
      behaviorPayload,
    )?.trim();
    if (skyEventId == null || skyEventId.isEmpty || catalog == null) {
      return false;
    }
    final event = catalog.byId(skyEventId);
    return event != null && event.mergedIntoId == null;
  }
}
