import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/data/user_events_repo.dart';
import 'package:mobile/telemetry/telemetry.dart';

/// Analytics + [user_choice_events] (via `track_choice_event`) for rhythm flows.
class RhythmTelemetry {
  RhythmTelemetry._();

  static Future<void> trackScreen(SupabaseClient client, String screen) async {
    await UserEventsRepo(client).track(
      event: 'rhythm_screen_viewed',
      properties: {
        'v': kAppEventsSchemaVersion,
        'screen': screen,
      },
    );
  }

  /// Logs to `app_events` and posts `cycle_field_saved` to the edge function (best-effort).
  static Future<void> recordCycleFieldSaved({
    required SupabaseClient client,
    required String fieldId,
    required String category,
    required bool isTimed,
    required bool remindersEnabled,
    required int patternCount,
  }) async {
    if (fieldId.isEmpty) return;

    await UserEventsRepo(client).track(
      event: 'rhythm_item_saved',
      properties: {
        'v': kAppEventsSchemaVersion,
        'field_id': fieldId,
        'category': category,
        'is_timed': isTimed,
        'reminders_enabled': remindersEnabled,
        'pattern_count': patternCount,
      },
    );

    try {
      await client.functions.invoke(
        'track_choice_event',
        body: <String, dynamic>{
          'event_type': 'cycle_field_saved',
          'metadata': <String, dynamic>{
            'field_id': fieldId,
            'category': category,
            'reminder_enabled': remindersEnabled,
            'is_timed': isTimed,
            'pattern_count': patternCount,
          },
        },
      );
    } catch (_) {
      // Best-effort only; do not surface to user.
    }
  }
}
