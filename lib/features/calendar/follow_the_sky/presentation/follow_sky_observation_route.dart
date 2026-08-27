import '../services/track_sky_materializer.dart';

/// Pure routing gate for the dedicated event-time observation experience.
class FollowSkyObservationRoute {
  const FollowSkyObservationRoute._();

  static bool matches({
    required String? flowName,
    required String? clientEventId,
    required Map<String, dynamic>? behaviorPayload,
  }) {
    final normalizedFlow = flowName?.trim().toLowerCase();
    if (normalizedFlow != 'follow the sky' &&
        normalizedFlow != 'track the sky') {
      return false;
    }
    if (clientEventId?.trim().isEmpty != false) return false;
    if (behaviorPayload?['trackSkySchemaVersion'] !=
        TrackSkyEventOwnership.schemaVersion) {
      return false;
    }
    return TrackSkyEventOwnership.skyEventIdFromPayload(
          behaviorPayload,
        )?.trim().isNotEmpty ==
        true;
  }
}
