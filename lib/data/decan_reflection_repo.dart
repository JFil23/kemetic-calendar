import 'package:flutter/foundation.dart';
import 'package:mobile/core/supabase_auth_retry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'decan_reflection_model.dart';

class DecanReflectionListResult {
  const DecanReflectionListResult({required this.data, this.errorMessage});

  final List<DecanReflection> data;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
}

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

  String _fmtStoredDate(DateTime date) =>
      date.toIso8601String().split('T').first;

  Future<DecanReflectionListResult> listMineResult() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return const DecanReflectionListResult(
        data: <DecanReflection>[],
        errorMessage: 'Sign in to view your decan reflections.',
      );
    }
    try {
      final res = await withSupabaseAuthRetry(
        _client,
        () => _client
            .from('decan_reflections')
            .select()
            .eq('user_id', uid)
            .order('decan_start', ascending: false),
      );
      final reflections = (res as List)
          .map((row) => DecanReflection.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
      return DecanReflectionListResult(data: reflections);
    } catch (e, st) {
      debugPrint('[DecanReflectionRepo] listMine error: $e');
      debugPrint('$st');
      return DecanReflectionListResult(
        data: const <DecanReflection>[],
        errorMessage: _friendlyReadError(e),
      );
    }
  }

  Future<List<DecanReflection>> listMine() async {
    final result = await listMineResult();
    return result.data;
  }

  Future<DecanReflection?> getById(String id) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await withSupabaseAuthRetry(
        _client,
        () => _client
            .from('decan_reflections')
            .select()
            .eq('id', id)
            .eq('user_id', uid)
            .maybeSingle(),
      );
      if (res == null) return null;
      return DecanReflection.fromJson(res);
    } catch (e) {
      debugPrint('[DecanReflectionRepo] getById error: $e');
      return null;
    }
  }

  Future<DecanReflection?> getLatest() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await withSupabaseAuthRetry(
        _client,
        () => _client
            .from('decan_reflections')
            .select()
            .eq('user_id', uid)
            .order('decan_start', ascending: false)
            .limit(1)
            .maybeSingle(),
      );
      if (res == null) return null;
      return DecanReflection.fromJson(res);
    } catch (e) {
      debugPrint('[DecanReflectionRepo] getLatest error: $e');
      return null;
    }
  }

  Future<DecanReflectionGraphHints?> getGraphHintsForReflection(
    DecanReflection reflection,
  ) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    try {
      final byReflectionId = await withSupabaseAuthRetry(
        _client,
        () => _client
            .from('reflection_generations')
            .select('anchor_nodes, metadata, source_snapshot, created_at')
            .eq('user_id', uid)
            .eq('period_type', 'decan')
            .filter(
              'source_snapshot->>decan_reflection_id',
              'eq',
              reflection.id,
            )
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle(),
      );
      if (byReflectionId != null) {
        return DecanReflectionGraphHints.fromGenerationJson(
          Map<String, dynamic>.from(byReflectionId as Map),
        );
      }
    } catch (e) {
      debugPrint('[DecanReflectionRepo] graph hints id lookup error: $e');
    }

    try {
      final start = _fmtStoredDate(reflection.decanStart);
      final end = _fmtStoredDate(reflection.decanEnd);
      final byWindow = await withSupabaseAuthRetry(
        _client,
        () => _client
            .from('reflection_generations')
            .select('anchor_nodes, metadata, source_snapshot, created_at')
            .eq('user_id', uid)
            .eq('period_type', 'decan')
            .like('period_key', '$start:$end:%')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle(),
      );
      if (byWindow == null) return null;
      return DecanReflectionGraphHints.fromGenerationJson(
        Map<String, dynamic>.from(byWindow as Map),
      );
    } catch (e) {
      debugPrint('[DecanReflectionRepo] graph hints window lookup error: $e');
      return null;
    }
  }

  Future<void> recordSuggestedNodeTap({
    required String reflectionId,
    required String nodeSlug,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    final slug = nodeSlug.trim();
    if (slug.isEmpty) return;

    try {
      final nodeRow = await withSupabaseAuthRetry(
        _client,
        () => _client.from('nodes').select('id').eq('slug', slug).maybeSingle(),
      );
      final nodeId = nodeRow == null ? null : nodeRow['id'] as String?;
      if (nodeId == null || nodeId.isEmpty) return;

      await withSupabaseAuthRetry(
        _client,
        () => _client.from('user_choice_events').insert({
          'user_id': uid,
          'event_type': 'reflection_linked_to_node',
          'node_id': nodeId,
          'reflection_entry_id': reflectionId,
          'metadata': {
            'source': 'decan_reflection_suggestion',
            'node_slug': slug,
          },
        }),
      );
    } catch (e) {
      debugPrint('[DecanReflectionRepo] recordSuggestedNodeTap error: $e');
    }
  }

  Future<DecanReflection?> findByWindow(
    DateTime decanStart,
    DateTime decanEnd,
  ) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await withSupabaseAuthRetry(
        _client,
        () => _client
            .from('decan_reflections')
            .select()
            .eq('user_id', uid)
            .eq('decan_start', _fmtDate(decanStart))
            .eq('decan_end', _fmtDate(decanEnd))
            .maybeSingle(),
      );
      if (res == null) return null;
      return DecanReflection.fromJson(res);
    } catch (e) {
      debugPrint('[DecanReflectionRepo] findByWindow error: $e');
      return null;
    }
  }

  Future<bool> hasPromptInteracted(DateTime decanStart) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final res = await withSupabaseAuthRetry(
        _client,
        () => _client
            .from('decan_reflection_prompt_interactions')
            .select('decan_start')
            .eq('user_id', uid)
            .eq('decan_start', _fmtDate(decanStart))
            .maybeSingle(),
      );
      return res != null;
    } catch (e) {
      debugPrint('[DecanReflectionRepo] hasPromptInteracted error: $e');
      return false;
    }
  }

  Future<void> markPromptInteracted({
    required DateTime decanStart,
    DateTime? decanEnd,
    String interactionKind = 'interacted',
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final payload = <String, dynamic>{
        'user_id': uid,
        'decan_start': _fmtDate(decanStart),
        if (decanEnd != null) 'decan_end': _fmtDate(decanEnd),
        'interaction_kind': interactionKind,
        'interacted_at': DateTime.now().toUtc().toIso8601String(),
      };
      await withSupabaseAuthRetry(
        _client,
        () => _client
            .from('decan_reflection_prompt_interactions')
            .upsert(payload, onConflict: 'user_id,decan_start'),
      );
    } catch (e) {
      debugPrint('[DecanReflectionRepo] markPromptInteracted error: $e');
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

      final res = await withSupabaseAuthRetry(
        _client,
        () => _client
            .from('decan_reflections')
            .insert(payload)
            .select()
            .maybeSingle(),
      );
      if (res == null) return null;
      return DecanReflection.fromJson(res);
    } catch (e, st) {
      debugPrint('[DecanReflectionRepo] saveReflection error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  String _friendlyReadError(Object error) {
    if (isExpiredSupabaseJwtError(error)) {
      return 'Your session expired. Sign in again, then reopen Decan Reflections.';
    }
    if (error is PostgrestException) {
      return 'Could not load decan reflections. Check your connection, then try again.';
    }
    return 'Could not load decan reflections. Try again in a moment.';
  }
}
