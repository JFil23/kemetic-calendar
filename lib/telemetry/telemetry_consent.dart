import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/account_operation_fence.dart';

/// Consent belongs to the current account, never to a process-wide cached flag.
/// Reads fail closed; optional analytics have no durable queue or warm cache.
class TelemetryConsent {
  TelemetryConsent._();

  // Written only by the repository's existing test hook. True never grants consent.
  static bool? overrideForTesting;

  static Future<void> runIfAllowed(
    SupabaseClient client,
    Future<void> Function(String userId) write,
  ) async {
    final fence = AccountOperationFence(client);
    try {
      if (fence.userId == null || overrideForTesting == false) return;
      final response = await client.rpc('get_my_telemetry_and_personalization');
      final row = response is List && response.isNotEmpty
          ? response.first
          : response;
      if (row is! Map || row['telemetry_enabled'] != true || !fence.isCurrent) {
        return;
      }
      await write(fence.userId!);
    } catch (error) {
      // Preference/network failures cannot grant consent or block the product.
      if (kDebugMode)
        debugPrint('[telemetry] consent/write failed: ${error.runtimeType}');
    } finally {
      fence.dispose();
    }
  }
}
