import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'decan_reflection_model.dart';

class DecanReflectionRepo {
  final SupabaseClient _client;
  const DecanReflectionRepo(this._client);

  Future<List<DecanReflection>> listMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    try {
      final res = await _client
          .from('decan_reflections')
          .select()
          .eq('user_id', uid)
          .order('decan_start', ascending: false);
      return (res as List)
          .map((row) => DecanReflection.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DecanReflectionRepo] listMine error: $e');
      return [];
    }
  }

  Future<DecanReflection?> getById(String id) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _client
          .from('decan_reflections')
          .select()
          .eq('id', id)
          .eq('user_id', uid)
          .maybeSingle();
      if (res == null) return null;
      return DecanReflection.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[DecanReflectionRepo] getById error: $e');
      return null;
    }
  }
}
