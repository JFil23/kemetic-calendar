import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DecanReflectionPromptState {
  const DecanReflectionPromptState(this._client);

  static const String seenPrefKey = 'calendar:seen_reflection_by_user';
  static const String dismissedPrefKey =
      'calendar:dismissed_reflection_by_user_v2';

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<bool> hasSeen(DateTime decanStart) =>
      _hasStoredDate(seenPrefKey, decanStart);

  Future<bool> hasDismissed(DateTime decanStart) =>
      _hasStoredDate(dismissedPrefKey, decanStart);

  Future<bool> hasInteracted(DateTime decanStart) async {
    return await hasDismissed(decanStart) || await hasSeen(decanStart);
  }

  Future<void> markSeen(DateTime decanStart) =>
      _storeDate(seenPrefKey, decanStart);

  Future<void> markDismissed(DateTime decanStart) =>
      _storeDate(dismissedPrefKey, decanStart);

  Future<void> markInteracted(DateTime decanStart) async {
    await markDismissed(decanStart);
    await markSeen(decanStart);
  }

  Future<bool> _hasStoredDate(String key, DateTime decanStart) async {
    final uid = _userId;
    if (uid == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return false;
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final stored = map[uid] as String?;
      return stored == _formatDateOnlyLocal(decanStart);
    } catch (_) {
      return false;
    }
  }

  Future<void> _storeDate(String key, DateTime decanStart) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      final map = raw == null || raw.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      map[uid] = _formatDateOnlyLocal(decanStart);
      await prefs.setString(key, jsonEncode(map));
    } catch (_) {
      // Non-critical local UI state.
    }
  }

  String _formatDateOnlyLocal(DateTime date) {
    final d = date.toLocal();
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}
