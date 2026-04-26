import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'insight_link_model.dart';
import 'insight_link_utils.dart';

typedef _JsonMap = Map<String, dynamic>;

/// Persists insight links and node user content locally, and syncs to
/// Supabase when an authenticated session is available.
class InsightLinkRepo {
  InsightLinkRepo([SupabaseClient? client]) : _client = client;

  static const _linksKey = 'insight_links';
  static const _nodeTextKey = 'node_user_content';
  static const _linkSyncDebounce = Duration(milliseconds: 800);
  static const _graphRefreshCooldown = Duration(seconds: 20);
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[1-5][0-9a-fA-F]{3}-'
    r'[89abAB][0-9a-fA-F]{3}-'
    r'[0-9a-fA-F]{12}$',
  );
  static final Map<String, Timer> _pendingLinkSyncTimers = <String, Timer>{};
  static final Map<String, List<InsightLink>> _pendingLinkSnapshots =
      <String, List<InsightLink>>{};
  static final Map<String, DateTime> _lastGraphRefreshAtByUser =
      <String, DateTime>{};
  static final Set<String> _graphRefreshInFlightUsers = <String>{};

  final SupabaseClient? _client;

  SupabaseClient? _safeClient() {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient? _remoteClientForUser(String userId) {
    if (userId.isEmpty || userId == 'local') return null;
    final client = _safeClient();
    final currentUserId = client?.auth.currentUser?.id;
    if (client == null || currentUserId == null || currentUserId != userId) {
      return null;
    }
    return client;
  }

  bool _looksLikeUuid(String value) => _uuidPattern.hasMatch(value);

  String _userScoped(String base, String userId) => '$base:$userId';

  String _nodeSourceId(String slug) => 'node-$slug';

  String? _slugFromNodeSourceId(String sourceId) {
    if (sourceId.startsWith('node-') && sourceId.length > 5) {
      return sourceId.substring(5);
    }
    return null;
  }

  String? _journalDateKeyFromSourceId(String sourceId) {
    if (!sourceId.startsWith('journal-') || sourceId.length != 18) {
      return null;
    }
    return sourceId.substring(8);
  }

  String _linkKey(InsightLink link) {
    return [
      link.sourceType.name,
      link.sourceId,
      link.start,
      link.end,
      link.targetType.name,
      link.targetId,
    ].join('|');
  }

  DateTime _parseDateTime(dynamic raw) {
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  InsightSourceType? _sourceTypeFromDb(String? raw) {
    switch (raw) {
      case 'node_user_text':
        return InsightSourceType.nodeUserText;
      case 'journal_entry':
        return InsightSourceType.journalEntry;
      case 'reflection_entry':
        return InsightSourceType.reflectionEntry;
      default:
        return null;
    }
  }

  InsightTargetType? _targetTypeFromDb(String? raw) {
    switch (raw) {
      case 'node':
        return InsightTargetType.node;
      case 'journal_entry':
        return InsightTargetType.journalEntry;
      case 'reflection_entry':
        return InsightTargetType.reflectionEntry;
      default:
        return null;
    }
  }

  String _sourceTypeToDb(InsightSourceType type) {
    switch (type) {
      case InsightSourceType.nodeUserText:
        return 'node_user_text';
      case InsightSourceType.journalEntry:
        return 'journal_entry';
      case InsightSourceType.reflectionEntry:
        return 'reflection_entry';
    }
  }

  String _targetTypeToDb(InsightTargetType type) {
    switch (type) {
      case InsightTargetType.node:
        return 'node';
      case InsightTargetType.journalEntry:
        return 'journal_entry';
      case InsightTargetType.reflectionEntry:
        return 'reflection_entry';
    }
  }

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<InsightLink>> _fetchLocalLinks(String userId) async {
    final prefs = await _prefs();
    final raw = prefs.getString(_userScoped(_linksKey, userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => InsightLink.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InsightLinkRepo] failed to decode local links: $e');
      }
      return [];
    }
  }

  Future<void> _saveLocalLinks(
    String userId,
    List<InsightLink> links,
  ) async {
    final prefs = await _prefs();
    final jsonStr = jsonEncode(links.map((e) => e.toJson()).toList());
    await prefs.setString(_userScoped(_linksKey, userId), jsonStr);
  }

  Future<List<NodeUserContent>> _fetchLocalNodeContent(String userId) async {
    final prefs = await _prefs();
    final raw = prefs.getString(_userScoped(_nodeTextKey, userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => NodeUserContent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[InsightLinkRepo] failed to decode local node user content: $e',
        );
      }
      return [];
    }
  }

  Future<void> _saveLocalNodeContent(
    String userId,
    List<NodeUserContent> content,
  ) async {
    final prefs = await _prefs();
    final jsonStr = jsonEncode(content.map((e) => e.toJson()).toList());
    await prefs.setString(_userScoped(_nodeTextKey, userId), jsonStr);
  }

  InsightLink _mergeLinkPair(InsightLink a, InsightLink b) {
    final newer = a.updatedAt.isAfter(b.updatedAt) ? a : b;
    final older = identical(newer, a) ? b : a;
    final preferredId = _looksLikeUuid(a.id)
        ? a.id
        : _looksLikeUuid(b.id)
        ? b.id
        : newer.id;
    final createdAt = a.createdAt.isBefore(b.createdAt) ? a.createdAt : b.createdAt;
    final updatedAt = a.updatedAt.isAfter(b.updatedAt) ? a.updatedAt : b.updatedAt;

    return InsightLink(
      id: preferredId,
      userId: newer.userId,
      sourceType: newer.sourceType,
      sourceId: newer.sourceId,
      start: newer.start,
      end: newer.end,
      selectedText: newer.selectedText.isNotEmpty
          ? newer.selectedText
          : older.selectedText,
      targetType: newer.targetType,
      targetId: newer.targetId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  List<InsightLink> _mergeLinks(
    List<InsightLink> local,
    List<InsightLink> remote,
  ) {
    final byKey = <String, InsightLink>{};

    for (final link in remote) {
      byKey[_linkKey(link)] = link;
    }
    for (final link in local) {
      final key = _linkKey(link);
      final existing = byKey[key];
      byKey[key] = existing == null ? link : _mergeLinkPair(existing, link);
    }

    final merged = byKey.values.toList()
      ..sort((a, b) {
        final sourceCompare = a.sourceId.compareTo(b.sourceId);
        if (sourceCompare != 0) return sourceCompare;
        final startCompare = a.start.compareTo(b.start);
        if (startCompare != 0) return startCompare;
        return a.targetId.compareTo(b.targetId);
      });
    return merged;
  }

  NodeUserContent _mergeNodeContentPair(
    NodeUserContent a,
    NodeUserContent b,
  ) {
    final newer = a.updatedAt.isAfter(b.updatedAt) ? a : b;
    final older = identical(newer, a) ? b : a;
    final createdAt = a.createdAt.isBefore(b.createdAt) ? a.createdAt : b.createdAt;
    final updatedAt = a.updatedAt.isAfter(b.updatedAt) ? a.updatedAt : b.updatedAt;

    return NodeUserContent(
      id: _nodeSourceId(newer.nodeId),
      userId: newer.userId,
      nodeId: newer.nodeId,
      text: newer.text.isNotEmpty ? newer.text : older.text,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  List<NodeUserContent> _mergeNodeContent(
    List<NodeUserContent> local,
    List<NodeUserContent> remote,
  ) {
    final byNodeId = <String, NodeUserContent>{};

    for (final entry in remote) {
      byNodeId[entry.nodeId] = entry;
    }
    for (final entry in local) {
      final existing = byNodeId[entry.nodeId];
      byNodeId[entry.nodeId] = existing == null
          ? entry
          : _mergeNodeContentPair(existing, entry);
    }

    final merged = byNodeId.values.toList()
      ..sort((a, b) => a.nodeId.compareTo(b.nodeId));
    return merged;
  }

  bool _linksEquivalent(List<InsightLink> a, List<InsightLink> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (_linkKey(left) != _linkKey(right)) return false;
      if (left.selectedText != right.selectedText) return false;
      if (left.userId != right.userId) return false;
    }
    return true;
  }

  bool _nodeContentEquivalent(
    List<NodeUserContent> a,
    List<NodeUserContent> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].nodeId != b[i].nodeId) return false;
      if (a[i].text != b[i].text) return false;
    }
    return true;
  }

  Future<Map<String, String>> _fetchNodeIdMapBySlug(
    SupabaseClient client,
    Iterable<String> slugs,
  ) async {
    final uniqueSlugs = slugs.map((slug) => slug.trim()).where((slug) => slug.isNotEmpty).toSet();
    if (uniqueSlugs.isEmpty) return const <String, String>{};

    final rows = await client
        .from('nodes')
        .select('id,slug')
        .inFilter('slug', uniqueSlugs.toList());

    final map = <String, String>{};
    for (final row in rows as List) {
      final data = row as _JsonMap;
      final id = data['id'] as String?;
      final slug = data['slug'] as String?;
      if (id == null || slug == null) continue;
      map[slug] = id;
    }
    return map;
  }

  Future<Map<String, String>> _fetchNodeSlugMapById(
    SupabaseClient client,
    Iterable<String> ids,
  ) async {
    final uniqueIds = ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (uniqueIds.isEmpty) return const <String, String>{};

    final rows = await client
        .from('nodes')
        .select('id,slug')
        .inFilter('id', uniqueIds.toList());

    final map = <String, String>{};
    for (final row in rows as List) {
      final data = row as _JsonMap;
      final id = data['id'] as String?;
      final slug = data['slug'] as String?;
      if (id == null || slug == null) continue;
      map[id] = slug;
    }
    return map;
  }

  Future<Map<String, String>> _fetchJournalIdMapByDate(
    SupabaseClient client,
    String userId,
    Iterable<String> dateKeys,
  ) async {
    final uniqueDates =
        dateKeys.map((date) => date.trim()).where((date) => date.isNotEmpty).toSet();
    if (uniqueDates.isEmpty) return const <String, String>{};

    final rows = await client
        .from('journal_entries')
        .select('id,greg_date')
        .eq('user_id', userId)
        .inFilter('greg_date', uniqueDates.toList());

    final map = <String, String>{};
    for (final row in rows as List) {
      final data = row as _JsonMap;
      final id = data['id'] as String?;
      final gregDate = data['greg_date'] as String?;
      if (id == null || gregDate == null) continue;
      map[gregDate] = id;
    }
    return map;
  }

  Future<Map<String, String>> _fetchJournalDateMapById(
    SupabaseClient client,
    Iterable<String> ids,
  ) async {
    final uniqueIds = ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (uniqueIds.isEmpty) return const <String, String>{};

    final rows = await client
        .from('journal_entries')
        .select('id,greg_date')
        .inFilter('id', uniqueIds.toList());

    final map = <String, String>{};
    for (final row in rows as List) {
      final data = row as _JsonMap;
      final id = data['id'] as String?;
      final gregDate = data['greg_date'] as String?;
      if (id == null || gregDate == null) continue;
      map[id] = gregDate;
    }
    return map;
  }

  Future<Map<String, String>> _ensureNodeContentIds(
    SupabaseClient client,
    String userId,
    Map<String, String> nodeIdBySlug,
  ) async {
    final nodeUuids = nodeIdBySlug.values.toSet().toList();
    if (nodeUuids.isEmpty) return const <String, String>{};

    final existingRows = await client
        .from('node_user_content')
        .select('id,node_id')
        .eq('user_id', userId)
        .inFilter('node_id', nodeUuids);

    final contentIdByNodeUuid = <String, String>{};
    for (final row in existingRows as List) {
      final data = row as _JsonMap;
      final id = data['id'] as String?;
      final nodeId = data['node_id'] as String?;
      if (id == null || nodeId == null) continue;
      contentIdByNodeUuid[nodeId] = id;
    }

    final missingNodeUuids = nodeUuids
        .where((nodeUuid) => !contentIdByNodeUuid.containsKey(nodeUuid))
        .toList();
    if (missingNodeUuids.isNotEmpty) {
      final payload = missingNodeUuids
          .map(
            (nodeUuid) => <String, dynamic>{
              'user_id': userId,
              'node_id': nodeUuid,
              'plain_text': '',
            },
          )
          .toList();
      final inserted = await client
          .from('node_user_content')
          .insert(payload)
          .select('id,node_id');
      for (final row in inserted as List) {
        final data = row as _JsonMap;
        final id = data['id'] as String?;
        final nodeId = data['node_id'] as String?;
        if (id == null || nodeId == null) continue;
        contentIdByNodeUuid[nodeId] = id;
      }
    }

    final contentIdBySlug = <String, String>{};
    nodeIdBySlug.forEach((slug, nodeUuid) {
      final contentId = contentIdByNodeUuid[nodeUuid];
      if (contentId != null) {
        contentIdBySlug[slug] = contentId;
      }
    });
    return contentIdBySlug;
  }

  Future<List<NodeUserContent>?> _fetchRemoteNodeContent(String userId) async {
    final client = _remoteClientForUser(userId);
    if (client == null) return null;

    try {
      final rows = ((await client
          .from('node_user_content')
          .select('id,user_id,node_id,plain_text,created_at,updated_at')
          .eq('user_id', userId)) as List)
          .cast<_JsonMap>();

      final nodeUuidToSlug = await _fetchNodeSlugMapById(
        client,
        rows.map((row) => row['node_id'] as String?).whereType<String>(),
      );

      final content = <NodeUserContent>[];
      for (final row in rows) {
        final nodeUuid = row['node_id'] as String?;
        final slug = nodeUuid == null ? null : nodeUuidToSlug[nodeUuid];
        if (slug == null) continue;

        content.add(
          NodeUserContent(
            id: _nodeSourceId(slug),
            userId: row['user_id'] as String? ?? userId,
            nodeId: slug,
            text: (row['plain_text'] as String?) ?? '',
            createdAt: _parseDateTime(row['created_at']),
            updatedAt: _parseDateTime(row['updated_at']),
          ),
        );
      }

      return content;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InsightLinkRepo] remote node content fetch failed: $e');
      }
      return null;
    }
  }

  Future<List<InsightLink>?> _fetchRemoteLinks(String userId) async {
    final client = _remoteClientForUser(userId);
    if (client == null) return null;

    try {
      final rows = await client
          .from('insight_links')
          .select(
            'id,user_id,source_type,source_id,source_range_start,source_range_end,source_selected_text,target_type,target_id,created_at,updated_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final rawRows = (rows as List).cast<_JsonMap>();
      final nodeTargetIds = <String>{};
      final nodeSourceContentIds = <String>{};
      final journalSourceIds = <String>{};

      for (final row in rawRows) {
        if (row['target_type'] == 'node') {
          final targetId = row['target_id'] as String?;
          if (targetId != null) nodeTargetIds.add(targetId);
        }
        if (row['source_type'] == 'node_user_text') {
          final sourceId = row['source_id'] as String?;
          if (sourceId != null) nodeSourceContentIds.add(sourceId);
        }
        if (row['source_type'] == 'journal_entry') {
          final sourceId = row['source_id'] as String?;
          if (sourceId != null) journalSourceIds.add(sourceId);
        }
      }

      final nodeEntryRows = nodeSourceContentIds.isEmpty
          ? const <_JsonMap>[]
          : ((await client
                  .from('node_insight_entries')
                  .select('id,node_id')
                  .inFilter('id', nodeSourceContentIds.toList())) as List)
              .cast<_JsonMap>();

      final nodeEntryIds = nodeEntryRows
          .map((row) => row['id'] as String?)
          .whereType<String>()
          .toSet();

      final legacyNodeContentRows = nodeSourceContentIds.isEmpty
          ? const <_JsonMap>[]
          : ((await client
                  .from('node_user_content')
                  .select('id,node_id')
                  .inFilter(
                    'id',
                    nodeSourceContentIds
                        .where((id) => !nodeEntryIds.contains(id))
                        .toList(),
                  )) as List)
              .cast<_JsonMap>();

      final nodeIdsForSlugLookup = <String>{...nodeTargetIds};
      for (final row in nodeEntryRows) {
        final nodeId = row['node_id'] as String?;
        if (nodeId != null) nodeIdsForSlugLookup.add(nodeId);
      }
      for (final row in legacyNodeContentRows) {
        final nodeId = row['node_id'] as String?;
        if (nodeId != null) nodeIdsForSlugLookup.add(nodeId);
      }

      final nodeUuidToSlug = await _fetchNodeSlugMapById(
        client,
        nodeIdsForSlugLookup,
      );
      final journalIdToDate = await _fetchJournalDateMapById(
        client,
        journalSourceIds,
      );

      final entrySourceIdToSlug = <String, String>{};
      for (final row in nodeEntryRows) {
        final contentId = row['id'] as String?;
        final nodeId = row['node_id'] as String?;
        final slug = nodeId == null ? null : nodeUuidToSlug[nodeId];
        if (contentId == null || slug == null) continue;
        entrySourceIdToSlug[contentId] = slug;
      }

      final legacyNodeSourceIdToSlug = <String, String>{};
      for (final row in legacyNodeContentRows) {
        final contentId = row['id'] as String?;
        final nodeId = row['node_id'] as String?;
        final slug = nodeId == null ? null : nodeUuidToSlug[nodeId];
        if (contentId == null || slug == null) continue;
        legacyNodeSourceIdToSlug[contentId] = slug;
      }

      final links = <InsightLink>[];
      for (final row in rawRows) {
        final sourceType = _sourceTypeFromDb(row['source_type'] as String?);
        final targetType = _targetTypeFromDb(row['target_type'] as String?);
        if (sourceType == null || targetType == null) continue;

        final rawSourceId = row['source_id'] as String? ?? '';
        final rawTargetId = row['target_id'] as String? ?? '';

        String? localSourceId;
        switch (sourceType) {
          case InsightSourceType.nodeUserText:
            if (entrySourceIdToSlug.containsKey(rawSourceId)) {
              localSourceId = rawSourceId;
            } else {
              final slug = legacyNodeSourceIdToSlug[rawSourceId];
              if (slug != null) localSourceId = _nodeSourceId(slug);
            }
            break;
          case InsightSourceType.journalEntry:
            final gregDate = journalIdToDate[rawSourceId];
            if (gregDate != null) {
              localSourceId = journalInsightSourceId(DateTime.parse(gregDate));
            }
            break;
          case InsightSourceType.reflectionEntry:
            localSourceId = rawSourceId;
            break;
        }

        String? localTargetId;
        switch (targetType) {
          case InsightTargetType.node:
            localTargetId = nodeUuidToSlug[rawTargetId];
            break;
          case InsightTargetType.journalEntry:
          case InsightTargetType.reflectionEntry:
            localTargetId = rawTargetId;
            break;
        }

        if (localSourceId == null || localTargetId == null) {
          if (kDebugMode) {
            debugPrint(
              '[InsightLinkRepo] skipped unresolved remote link ${row['id']}',
            );
          }
          continue;
        }

        links.add(
          InsightLink(
            id: row['id'] as String? ?? '',
            userId: row['user_id'] as String? ?? userId,
            sourceType: sourceType,
            sourceId: localSourceId,
            start: (row['source_range_start'] as num?)?.toInt() ?? 0,
            end: (row['source_range_end'] as num?)?.toInt() ?? 0,
            selectedText: (row['source_selected_text'] as String?) ?? '',
            targetType: targetType,
            targetId: localTargetId,
            createdAt: _parseDateTime(row['created_at']),
            updatedAt: _parseDateTime(row['updated_at']),
          ),
        );
      }

      return links;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InsightLinkRepo] remote link fetch failed: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _resolveLinkPayload(
    SupabaseClient client,
    String userId,
    InsightLink link,
  ) async {
    String? remoteSourceId;
    switch (link.sourceType) {
      case InsightSourceType.nodeUserText:
        if (_looksLikeUuid(link.sourceId)) {
          remoteSourceId = link.sourceId;
        } else {
          final slug = _slugFromNodeSourceId(link.sourceId);
          if (slug == null) return null;
          final nodeIds = await _fetchNodeIdMapBySlug(client, <String>[slug]);
          final contentIds = await _ensureNodeContentIds(client, userId, nodeIds);
          remoteSourceId = contentIds[slug];
        }
        break;
      case InsightSourceType.journalEntry:
        if (_looksLikeUuid(link.sourceId)) {
          remoteSourceId = link.sourceId;
        } else {
          final dateKey = _journalDateKeyFromSourceId(link.sourceId);
          if (dateKey == null) return null;
          final journalIds = await _fetchJournalIdMapByDate(
            client,
            userId,
            <String>[dateKey],
          );
          remoteSourceId = journalIds[dateKey];
        }
        break;
      case InsightSourceType.reflectionEntry:
        remoteSourceId = _looksLikeUuid(link.sourceId) ? link.sourceId : null;
        break;
    }

    String? remoteTargetId;
    switch (link.targetType) {
      case InsightTargetType.node:
        final nodeIds = await _fetchNodeIdMapBySlug(
          client,
          <String>[link.targetId],
        );
        remoteTargetId = nodeIds[link.targetId];
        break;
      case InsightTargetType.journalEntry:
      case InsightTargetType.reflectionEntry:
        remoteTargetId = _looksLikeUuid(link.targetId) ? link.targetId : null;
        break;
    }

    if (remoteSourceId == null || remoteTargetId == null) {
      return null;
    }

    return <String, dynamic>{
      'user_id': userId,
      'source_type': _sourceTypeToDb(link.sourceType),
      'source_id': remoteSourceId,
      'source_range_start': link.start,
      'source_range_end': link.end,
      'source_selected_text': link.selectedText,
      'target_type': _targetTypeToDb(link.targetType),
      'target_id': remoteTargetId,
    };
  }

  Future<void> _syncRemoteLinks(
    String userId,
    List<InsightLink> desiredLinks,
  ) async {
    final client = _remoteClientForUser(userId);
    if (client == null) return;

    final remoteExisting = await _fetchRemoteLinks(userId) ?? const <InsightLink>[];
    final existingById = <String, InsightLink>{
      for (final link in remoteExisting) link.id: link,
    };
    final existingByKey = <String, InsightLink>{
      for (final link in remoteExisting) _linkKey(link): link,
    };

    final upserts = <Map<String, dynamic>>[];
    final inserts = <Map<String, dynamic>>[];
    final desiredIds = <String>{};

    for (final link in desiredLinks) {
      final payload = await _resolveLinkPayload(client, userId, link);
      if (payload == null) {
        if (kDebugMode) {
          debugPrint(
            '[InsightLinkRepo] deferred unresolved link sync for ${link.sourceId}',
          );
        }
        continue;
      }

      final existing = (_looksLikeUuid(link.id) ? existingById[link.id] : null) ??
          existingByKey[_linkKey(link)];
      final targetId = existing?.id;
      if (targetId != null) {
        desiredIds.add(targetId);
        upserts.add(<String, dynamic>{...payload, 'id': targetId});
      } else if (_looksLikeUuid(link.id)) {
        desiredIds.add(link.id);
        upserts.add(<String, dynamic>{...payload, 'id': link.id});
      } else {
        inserts.add(payload);
      }
    }

    try {
      if (upserts.isNotEmpty) {
        await client.from('insight_links').upsert(upserts);
      }

      if (inserts.isNotEmpty) {
        final inserted = await client
            .from('insight_links')
            .insert(inserts)
            .select('id');
        for (final row in inserted as List) {
          final id = (row as _JsonMap)['id'] as String?;
          if (id != null) desiredIds.add(id);
        }
      }

      final idsToDelete = remoteExisting
          .map((link) => link.id)
          .where((id) => !desiredIds.contains(id))
          .toList();
      if (idsToDelete.isNotEmpty) {
        await client.from('insight_links').delete().inFilter('id', idsToDelete);
      }

      unawaited(_maybeRefreshKnowledgeGraph(userId, client));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InsightLinkRepo] remote link sync failed: $e');
      }
    }
  }

  Future<void> _syncRemoteNodeContent(
    String userId,
    List<NodeUserContent> content,
  ) async {
    final client = _remoteClientForUser(userId);
    if (client == null) return;

    try {
      final nodeIdBySlug = await _fetchNodeIdMapBySlug(
        client,
        content.map((entry) => entry.nodeId),
      );

      final upserts = <Map<String, dynamic>>[];
      final deleteNodeIds = <String>[];

      for (final entry in content) {
        final nodeUuid = nodeIdBySlug[entry.nodeId];
        if (nodeUuid == null) continue;
        final trimmedText = entry.text.trim();
        if (trimmedText.isEmpty) {
          deleteNodeIds.add(nodeUuid);
          continue;
        }
        upserts.add(
          <String, dynamic>{
            'user_id': userId,
            'node_id': nodeUuid,
            'plain_text': trimmedText,
          },
        );
      }

      if (deleteNodeIds.isNotEmpty) {
        await client
            .from('node_user_content')
            .delete()
            .eq('user_id', userId)
            .inFilter('node_id', deleteNodeIds);
      }

      if (upserts.isNotEmpty) {
        await client
            .from('node_user_content')
            .upsert(upserts, onConflict: 'user_id,node_id');
      }

      unawaited(_maybeRefreshKnowledgeGraph(userId, client));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InsightLinkRepo] remote node content sync failed: $e');
      }
    }
  }

  Future<void> _maybeRefreshKnowledgeGraph(
    String userId,
    SupabaseClient client,
  ) async {
    if (_graphRefreshInFlightUsers.contains(userId)) return;
    final now = DateTime.now();
    final lastRefreshAt = _lastGraphRefreshAtByUser[userId];
    if (lastRefreshAt != null &&
        now.difference(lastRefreshAt) < _graphRefreshCooldown) {
      return;
    }

    _graphRefreshInFlightUsers.add(userId);
    _lastGraphRefreshAtByUser[userId] = now;
    try {
      await client.functions.invoke(
        'rebuild_personal_graph',
        body: <String, dynamic>{'date_window_days': 90},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[InsightLinkRepo] graph refresh skipped: $e');
      }
    } finally {
      _graphRefreshInFlightUsers.remove(userId);
    }
  }

  Future<List<InsightLink>> fetchLinks(String userId) async {
    final localLinks = await _fetchLocalLinks(userId);
    final remoteLinks = await _fetchRemoteLinks(userId);
    if (remoteLinks == null) {
      return localLinks;
    }

    final mergedLinks = _mergeLinks(localLinks, remoteLinks);
    if (!_linksEquivalent(mergedLinks, localLinks)) {
      await _saveLocalLinks(userId, mergedLinks);
    }
    if (!_linksEquivalent(mergedLinks, remoteLinks)) {
      _pendingLinkSyncTimers[userId]?.cancel();
      _pendingLinkSnapshots[userId] = List<InsightLink>.from(mergedLinks);
      _pendingLinkSyncTimers[userId] = Timer(_linkSyncDebounce, () {
        final snapshot = _pendingLinkSnapshots.remove(userId);
        _pendingLinkSyncTimers.remove(userId);
        if (snapshot == null) return;
        unawaited(_syncRemoteLinks(userId, snapshot));
      });
    }
    return mergedLinks;
  }

  Future<void> saveLinks(String userId, List<InsightLink> links) async {
    await _saveLocalLinks(userId, links);

    final client = _remoteClientForUser(userId);
    if (client == null) return;

    _pendingLinkSnapshots[userId] = List<InsightLink>.from(links);
    _pendingLinkSyncTimers[userId]?.cancel();
    _pendingLinkSyncTimers[userId] = Timer(_linkSyncDebounce, () {
      final snapshot = _pendingLinkSnapshots.remove(userId);
      _pendingLinkSyncTimers.remove(userId);
      if (snapshot == null) return;
      unawaited(_syncRemoteLinks(userId, snapshot));
    });
  }

  Future<List<NodeUserContent>> fetchNodeContent(String userId) async {
    final localContent = await _fetchLocalNodeContent(userId);
    final remoteContent = await _fetchRemoteNodeContent(userId);
    if (remoteContent == null) {
      return localContent;
    }

    final mergedContent = _mergeNodeContent(localContent, remoteContent);
    if (!_nodeContentEquivalent(mergedContent, localContent)) {
      await _saveLocalNodeContent(userId, mergedContent);
    }
    if (!_nodeContentEquivalent(mergedContent, remoteContent)) {
      await _syncRemoteNodeContent(userId, mergedContent);
    }
    return mergedContent;
  }

  Future<void> saveNodeContent(
    String userId,
    List<NodeUserContent> content,
  ) async {
    await _saveLocalNodeContent(userId, content);
    final client = _remoteClientForUser(userId);
    if (client == null) return;
    await _syncRemoteNodeContent(userId, content);
  }
}
