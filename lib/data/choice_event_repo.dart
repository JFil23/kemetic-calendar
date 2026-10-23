import 'package:supabase_flutter/supabase_flutter.dart';

import '../telemetry/telemetry_consent.dart';

abstract class ChoiceEventTracker {
  Future<void> trackChoiceEvent({
    required String eventType,
    String? nodeSlug,
    String? reflectionId,
    String? sourceSurface,
    String? deliveryId,
    Map<String, dynamic>? metadata,
  });
}

class SupabaseChoiceEventTracker implements ChoiceEventTracker {
  const SupabaseChoiceEventTracker(this._client);

  final SupabaseClient _client;

  static SupabaseChoiceEventTracker? tryCreate() {
    try {
      return SupabaseChoiceEventTracker(Supabase.instance.client);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> trackChoiceEvent({
    required String eventType,
    String? nodeSlug,
    String? reflectionId,
    String? sourceSurface,
    String? deliveryId,
    Map<String, dynamic>? metadata,
  }) async {
    await TelemetryConsent.runIfAllowed(_client, (userId) async {
      final cleanNodeSlug = nodeSlug?.trim();
      final cleanReflectionId = reflectionId?.trim();
      final cleanSourceSurface = sourceSurface?.trim();
      final cleanDeliveryId = deliveryId?.trim();

      final eventMetadata = <String, dynamic>{
        ...?metadata,
        'user_id': userId,
        if (cleanSourceSurface != null && cleanSourceSurface.isNotEmpty)
          'source_surface': cleanSourceSurface,
        if (cleanDeliveryId != null && cleanDeliveryId.isNotEmpty)
          'delivery_id': cleanDeliveryId,
        if (cleanReflectionId != null && cleanReflectionId.isNotEmpty)
          'reflection_id': cleanReflectionId,
        if (cleanNodeSlug != null && cleanNodeSlug.isNotEmpty) ...{
          'node_ref': cleanNodeSlug,
          'node_slug': cleanNodeSlug,
          'node_id': cleanNodeSlug,
        },
      };

      await _client.functions.invoke(
        'track_choice_event',
        body: <String, dynamic>{
          'event_type': eventType,
          if (cleanNodeSlug != null && cleanNodeSlug.isNotEmpty)
            'node_slug': cleanNodeSlug,
          if (cleanReflectionId != null && cleanReflectionId.isNotEmpty)
            'reflection_entry_id': cleanReflectionId,
          'metadata': eventMetadata,
        },
      );
    });
  }
}
