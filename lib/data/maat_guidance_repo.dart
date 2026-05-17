import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'maat_guidance_model.dart';

abstract interface class MaatGuidanceDataSource {
  Future<MaatGuidanceDelivery?> fetchPending();
  Future<MaatGuidanceDelivery?> getById(String id);
  Future<void> ack({
    required String deliveryId,
    required String action,
    Map<String, dynamic>? metadata,
  });
  Future<void> evaluate({String? timezone});
}

class MaatGuidanceRepo implements MaatGuidanceDataSource {
  const MaatGuidanceRepo(this._client);

  final SupabaseClient _client;

  @override
  Future<MaatGuidanceDelivery?> fetchPending() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _client.functions.invoke(
        'fetch_maat_guidance_pending',
        body: const <String, dynamic>{},
      );
      final data = _asMap(res.data);
      final delivery = _asMap(data?['delivery']);
      if (delivery == null) return null;
      return MaatGuidanceDelivery.fromJson(delivery);
    } catch (error) {
      debugPrint('[MaatGuidanceRepo] fetchPending skipped: $error');
      return null;
    }
  }

  @override
  Future<MaatGuidanceDelivery?> getById(String id) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || id.trim().isEmpty) return null;
    try {
      final res = await _client.functions.invoke(
        'fetch_maat_guidance_pending',
        body: <String, dynamic>{'delivery_id': id.trim()},
      );
      final data = _asMap(res.data);
      final delivery = _asMap(data?['delivery']);
      if (delivery == null) return null;
      return MaatGuidanceDelivery.fromJson(delivery);
    } catch (error) {
      debugPrint('[MaatGuidanceRepo] getById skipped: $error');
      return null;
    }
  }

  @override
  Future<void> ack({
    required String deliveryId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || deliveryId.trim().isEmpty) return;
    try {
      await _client.functions.invoke(
        'ack_maat_guidance',
        body: <String, dynamic>{
          'delivery_id': deliveryId.trim(),
          'action': action,
          if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
        },
      );
    } catch (error) {
      debugPrint('[MaatGuidanceRepo] ack $action skipped: $error');
    }
  }

  @override
  Future<void> evaluate({String? timezone}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client.functions.invoke(
        'evaluate_maat_guidance',
        body: <String, dynamic>{
          if (timezone != null && timezone.trim().isNotEmpty)
            'timezone': timezone.trim(),
        },
      );
    } catch (error) {
      debugPrint('[MaatGuidanceRepo] evaluate skipped: $error');
    }
  }
}

Map<String, dynamic>? _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}
