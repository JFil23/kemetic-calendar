import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'decan_reflection_model.dart';

class DecanReflectionRepo {
  final SupabaseClient _client;
  const DecanReflectionRepo(this._client);

  String _fmtDate(DateTime date) {
    final d = date.toUtc();
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

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

  Future<DecanReflection?> getLatest() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _client
          .from('decan_reflections')
          .select()
          .eq('user_id', uid)
          .order('decan_start', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return DecanReflection.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[DecanReflectionRepo] getLatest error: $e');
      return null;
    }
  }

  Future<DecanReflection?> findByWindow(
    DateTime decanStart,
    DateTime decanEnd,
  ) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _client
          .from('decan_reflections')
          .select()
          .eq('user_id', uid)
          .eq('decan_start', _fmtDate(decanStart))
          .eq('decan_end', _fmtDate(decanEnd))
          .maybeSingle();
      if (res == null) return null;
      return DecanReflection.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[DecanReflectionRepo] findByWindow error: $e');
      return null;
    }
  }

  Future<DecanReflection?> saveReflection({
    required String decanName,
    String? decanTheme,
    required DateTime decanStart,
    required DateTime decanEnd,
    required int badgeCount,
    required String reflectionText,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final existing = await findByWindow(decanStart, decanEnd);
      if (existing != null) return existing;

      final payload = <String, dynamic>{
        'user_id': uid,
        'decan_name': decanName,
        'decan_start': _fmtDate(decanStart),
        'decan_end': _fmtDate(decanEnd),
        'badge_count': badgeCount,
        'reflection_text': reflectionText,
      };

      if (decanTheme != null && decanTheme.trim().isNotEmpty) {
        payload['decan_theme'] = decanTheme;
      }

      final res = await _client.from('decan_reflections').insert(payload).select().maybeSingle();
      if (res == null) return null;
      return DecanReflection.fromJson(res as Map<String, dynamic>);
    } catch (e, st) {
      debugPrint('[DecanReflectionRepo] saveReflection error: $e');
      debugPrint('$st');
      rethrow;
    }
  }
}
