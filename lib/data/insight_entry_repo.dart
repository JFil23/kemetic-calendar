import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'insight_entry_model.dart';

class InsightEntryRepo {
  final SupabaseClient _client;

  InsightEntryRepo(this._client);

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[InsightEntryRepo] $message');
    }
  }

  String _formatDate(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, String>> _fetchNodeIdMapBySlug(
    Iterable<String> slugs,
  ) async {
    final uniqueSlugs = slugs
        .map((slug) => slug.trim())
        .where((slug) => slug.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueSlugs.isEmpty) return const <String, String>{};

    final rows = await _client
        .from('nodes')
        .select('id,slug')
        .inFilter('slug', uniqueSlugs);

    final map = <String, String>{};
    for (final row in rows as List) {
      final json = row as Map<String, dynamic>;
      final id = json['id'] as String?;
      final slug = json['slug'] as String?;
      if (id == null || slug == null) continue;
      map[slug] = id;
    }
    return map;
  }

  Future<Map<String, String>> _fetchNodeSlugMapById(
    Iterable<String> ids,
  ) async {
    final uniqueIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) return const <String, String>{};

    final rows = await _client
        .from('nodes')
        .select('id,slug')
        .inFilter('id', uniqueIds);

    final map = <String, String>{};
    for (final row in rows as List) {
      final json = row as Map<String, dynamic>;
      final id = json['id'] as String?;
      final slug = json['slug'] as String?;
      if (id == null || slug == null) continue;
      map[id] = slug;
    }
    return map;
  }

  Future<void> _syncLegacyNodeUserContent({
    required String userId,
    required String nodeUuid,
  }) async {
    final rows = await _client
        .from('node_insight_entries')
        .select('body_text, entry_date, created_at')
        .eq('user_id', userId)
        .eq('node_id', nodeUuid)
        .order('entry_date', ascending: true)
        .order('created_at', ascending: true);

    final entries = (rows as List<dynamic>?) ?? const [];
    final mergedText = entries
        .map(
          (raw) => (raw as Map<String, dynamic>)['body_text'] as String? ?? '',
        )
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n');

    if (mergedText.isEmpty) {
      await _client
          .from('node_user_content')
          .delete()
          .eq('user_id', userId)
          .eq('node_id', nodeUuid);
      return;
    }

    await _client.from('node_user_content').upsert({
      'user_id': userId,
      'node_id': nodeUuid,
      'plain_text': mergedText,
    }, onConflict: 'user_id,node_id');
  }

  Future<List<InsightEntry>> fetchEntriesForNode(String nodeSlug) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return const [];

      final nodeIds = await _fetchNodeIdMapBySlug(<String>[nodeSlug]);
      final nodeUuid = nodeIds[nodeSlug];
      if (nodeUuid == null) {
        _log('fetchEntriesForNode failed: missing node slug "$nodeSlug"');
        return const [];
      }

      final rows = await _client
          .from('node_insight_entries')
          .select(
            'id, user_id, node_id, body_text, entry_date, created_at, updated_at, nodes(slug, title, glyph)',
          )
          .eq('user_id', userId)
          .eq('node_id', nodeUuid)
          .order('entry_date', ascending: true)
          .order('created_at', ascending: true);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(InsightEntry.fromJson)
          .toList();
    } catch (e) {
      _log('fetchEntriesForNode failed: $e');
      return const [];
    }
  }

  Future<List<InsightEntry>> fetchMyEntries({int limit = 300}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return const [];

      final rows = await _client
          .from('node_insight_entries')
          .select(
            'id, user_id, node_id, body_text, entry_date, created_at, updated_at, nodes(slug, title, glyph)',
          )
          .eq('user_id', userId)
          .order('entry_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(InsightEntry.fromJson)
          .toList();
    } catch (e) {
      _log('fetchMyEntries failed: $e');
      return const [];
    }
  }

  Future<InsightEntry?> saveEntry({
    String? entryId,
    required String nodeSlug,
    required String bodyText,
    required DateTime entryDate,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final trimmed = bodyText.trim();
      if (trimmed.isEmpty) return null;

      final nodeIds = await _fetchNodeIdMapBySlug(<String>[nodeSlug]);
      final nodeUuid = nodeIds[nodeSlug];
      if (nodeUuid == null) {
        _log('saveEntry failed: missing node slug "$nodeSlug"');
        return null;
      }

      final payload = <String, dynamic>{
        'user_id': userId,
        'node_id': nodeUuid,
        'body_text': trimmed,
        'entry_date': _formatDate(entryDate),
      };

      final selected =
          'id, user_id, node_id, body_text, entry_date, created_at, updated_at, nodes(slug, title, glyph)';

      final row = entryId == null
          ? await _client
                .from('node_insight_entries')
                .insert(payload)
                .select(selected)
                .single()
          : await _client
                .from('node_insight_entries')
                .update(payload)
                .eq('id', entryId)
                .eq('user_id', userId)
                .select(selected)
                .single();

      final savedJson = Map<String, dynamic>.from(row as Map);
      final savedId = savedJson['id'] as String?;
      if (savedId != null) {
        await _client
            .from('insight_posts')
            .update({
              'node_id': nodeUuid,
              'body_text': trimmed,
              'entry_date': _formatDate(entryDate),
            })
            .eq('user_id', userId)
            .eq('insight_entry_id', savedId);
      }

      await _syncLegacyNodeUserContent(userId: userId, nodeUuid: nodeUuid);
      return InsightEntry.fromJson(savedJson);
    } catch (e) {
      _log('saveEntry failed: $e');
      return null;
    }
  }

  Future<bool> deleteEntry(InsightEntry entry) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final nodeIds = await _fetchNodeIdMapBySlug(<String>[entry.nodeId]);
      final nodeUuid = nodeIds[entry.nodeId];

      await _client
          .from('node_insight_entries')
          .delete()
          .eq('id', entry.id)
          .eq('user_id', userId);

      if (nodeUuid != null) {
        await _syncLegacyNodeUserContent(userId: userId, nodeUuid: nodeUuid);
      }
      return true;
    } catch (e) {
      _log('deleteEntry failed: $e');
      return false;
    }
  }

  Future<Map<String, String>> fetchNodeSlugsByEntryIds(
    Iterable<String> entryIds,
  ) async {
    try {
      final uniqueIds = entryIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (uniqueIds.isEmpty) return const <String, String>{};

      final rows = await _client
          .from('node_insight_entries')
          .select('id, node_id')
          .inFilter('id', uniqueIds);

      final nodeUuids = (rows as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['node_id'] as String?)
          .whereType<String>()
          .toSet();
      final slugByUuid = await _fetchNodeSlugMapById(nodeUuids);

      final result = <String, String>{};
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw as Map);
        final entryId = row['id'] as String?;
        final nodeUuid = row['node_id'] as String?;
        final slug = nodeUuid == null ? null : slugByUuid[nodeUuid];
        if (entryId == null || slug == null) continue;
        result[entryId] = slug;
      }
      return result;
    } catch (e) {
      _log('fetchNodeSlugsByEntryIds failed: $e');
      return const <String, String>{};
    }
  }
}
