import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/flow_visibility.dart';

const _kFlows = 'flows';

void _log(String msg) {
  if (kDebugMode) debugPrint('[flows] $msg');
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

DateTime? _savedAtFallbackForRow(Map<String, dynamic> row) {
  final isSaved = (row['is_saved'] as bool?) ?? false;
  if (!isSaved) return null;
  return _parseDateTime(row['updated_at']) ?? _parseDateTime(row['created_at']);
}

bool _isUuid(String? v) {
  if (v == null) return false;
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(v);
}

@immutable
class FlowRow {
  final int id;
  final String userId;
  final String? calendarId;
  final String name;
  final int color;
  final bool active;
  final bool isSaved;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final List<dynamic> rules; // store your _FlowRule list as JSON-serializable
  final Map<String, dynamic>? aiMetadata;
  final bool isHidden;
  final bool isReminder;
  final String? reminderUuid;
  final String? shareId;
  final DateTime? savedAt;
  final String? filingLifecycle;
  final bool visibleInActiveList;
  final bool visibleInSavedList;
  final int totalEventCount;
  final int remainingEventCount;
  final int remainingLiveEventCount;
  final bool isShared;
  final bool isPosted;
  final bool isSharedCalendarSource;
  final bool isFlowShareSource;

  const FlowRow({
    required this.id,
    required this.userId,
    this.calendarId,
    required this.name,
    required this.color,
    required this.active,
    required this.isSaved,
    required this.startDate,
    required this.endDate,
    required this.notes,
    required this.rules,
    this.aiMetadata,
    this.isHidden = false,
    this.isReminder = false,
    this.reminderUuid,
    this.shareId,
    this.savedAt,
    this.filingLifecycle,
    this.visibleInActiveList = false,
    this.visibleInSavedList = false,
    this.totalEventCount = 0,
    this.remainingEventCount = 0,
    this.remainingLiveEventCount = 0,
    this.isShared = false,
    this.isPosted = false,
    this.isSharedCalendarSource = false,
    this.isFlowShareSource = false,
  });

  factory FlowRow.fromRow(Map<String, dynamic> r) {
    dynamic rules = r['rules'];
    List<dynamic> rulesList;
    if (rules == null) {
      rulesList = const [];
    } else if (rules is List) {
      rulesList = rules;
    } else {
      // In case the column was accidentally stored as an object/string.
      rulesList = const [];
    }

    return FlowRow(
      id: (r['id'] as num).toInt(),
      userId: r['user_id'] as String,
      calendarId: r['calendar_id'] as String?,
      name: r['name'] as String,
      // Force 24-bit RGB and safe default matching the backend
      color: (((r['color'] as num?)?.toInt() ?? 0x4DD0E1) & 0x00FFFFFF),
      active: (r['active'] as bool?) ?? true,
      isSaved: (r['is_saved'] as bool?) ?? false,
      startDate: _parseDateTime(r['start_date']),
      endDate: _parseDateTime(r['end_date']),
      notes: r['notes'] as String?,
      rules: rulesList,
      isHidden: (r['is_hidden'] as bool?) ?? false,
      isReminder: (r['is_reminder'] as bool?) ?? false,
      reminderUuid: r['reminder_uuid'] as String?,
      shareId: r['share_id'] as String?,
      savedAt: _parseDateTime(r['saved_at']),
      filingLifecycle: r['lifecycle'] as String?,
      visibleInActiveList:
          (r['visible_in_active_list'] as bool?) ??
          ((r['lifecycle'] as String?) == 'active'),
      visibleInSavedList: (r['visible_in_saved_list'] as bool?) ?? false,
      totalEventCount: (r['total_event_count'] as num?)?.toInt() ?? 0,
      remainingEventCount: (r['remaining_event_count'] as num?)?.toInt() ?? 0,
      remainingLiveEventCount:
          (r['remaining_live_event_count'] as num?)?.toInt() ?? 0,
      isShared: (r['is_shared'] as bool?) ?? false,
      isPosted: (r['is_posted'] as bool?) ?? false,
      isSharedCalendarSource:
          (r['is_shared_calendar_source'] as bool?) ?? false,
      isFlowShareSource: (r['is_flow_share_source'] as bool?) ?? false,
      aiMetadata: r['ai_metadata'] != null
          ? Map<String, dynamic>.from(r['ai_metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toInsert({required String userId}) => {
    'user_id': userId,
    if (calendarId != null) 'calendar_id': calendarId,
    'name': name,
    'color': color,
    'active': active,
    'is_saved': isSaved,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'notes': notes,
    'rules': rules,
    'is_hidden': isHidden,
    'is_reminder': isReminder,
    'reminder_uuid': reminderUuid,
  };

  Map<String, dynamic> toUpdate() => {
    if (calendarId != null) 'calendar_id': calendarId,
    'name': name,
    'color': color,
    'active': active,
    'is_saved': isSaved,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'notes': notes,
    'rules': rules,
    'is_hidden': isHidden,
    'is_reminder': isReminder,
    'reminder_uuid': reminderUuid,
  };

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'user_id': userId,
    'calendar_id': calendarId,
    'name': name,
    'color': color,
    'active': active,
    'is_saved': isSaved,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'notes': notes,
    'rules': rules,
    'ai_metadata': aiMetadata,
    'is_hidden': isHidden,
    'is_reminder': isReminder,
    'reminder_uuid': reminderUuid,
    'share_id': shareId,
    'saved_at': savedAt?.toIso8601String(),
    'lifecycle': filingLifecycle,
    'visible_in_active_list': visibleInActiveList,
    'visible_in_saved_list': visibleInSavedList,
    'total_event_count': totalEventCount,
    'remaining_event_count': remainingEventCount,
    'remaining_live_event_count': remainingLiveEventCount,
    'is_shared': isShared,
    'is_posted': isPosted,
    'is_shared_calendar_source': isSharedCalendarSource,
    'is_flow_share_source': isFlowShareSource,
  };
}

class FlowFilingCounts {
  const FlowFilingCounts({required this.activeFlows, required this.flowEvents});

  final int activeFlows;
  final int flowEvents;

  static FlowFilingCounts fromRows(Iterable<FlowRow> rows) {
    var activeFlows = 0;
    var flowEvents = 0;
    for (final row in rows) {
      if (!row.visibleInActiveList) continue;
      activeFlows += 1;
      flowEvents += row.remainingLiveEventCount;
    }
    return FlowFilingCounts(activeFlows: activeFlows, flowEvents: flowEvents);
  }
}

class FlowsRepo {
  FlowsRepo(this._client);
  final SupabaseClient _client;

  static const _kFiledFlowsCacheKeyPrefix = 'flow_filing:client:v1';
  static final Map<String, List<FlowRow>> _filedFlowsMemoryCache = {};

  static String _filedFlowsCacheKey(String userId) =>
      '$_kFiledFlowsCacheKeyPrefix:$userId';

  String? get _currentUserId => _client.auth.currentUser?.id;

  List<FlowRow>? cachedMyFiledFlowsSync() {
    final userId = _currentUserId;
    if (userId == null) return null;
    final rows = _filedFlowsMemoryCache[userId];
    if (rows == null) return null;
    return List<FlowRow>.unmodifiable(rows);
  }

  Future<void> clearMyFiledFlowsCache() async {
    final userId = _currentUserId;
    if (userId == null) return;
    _filedFlowsMemoryCache.remove(userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_filedFlowsCacheKey(userId));
    } catch (e) {
      _log('clear filed flow cache failed: $e');
    }
  }

  FlowFilingCounts? cachedMyFlowFilingCountsSync() {
    final rows = cachedMyFiledFlowsSync();
    if (rows == null) return null;
    return FlowFilingCounts.fromRows(rows);
  }

  Future<List<FlowRow>?> restoreCachedFiledFlows() async {
    final userId = _currentUserId;
    if (userId == null) return null;
    final cachedRows = _filedFlowsMemoryCache[userId];
    if (cachedRows != null) return List<FlowRow>.unmodifiable(cachedRows);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_filedFlowsCacheKey(userId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final rows = decoded
          .whereType<Map>()
          .map((row) => FlowRow.fromRow(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      _filedFlowsMemoryCache[userId] = List<FlowRow>.unmodifiable(rows);
      return rows;
    } catch (e) {
      _log('restore filed flow cache failed: $e');
      return null;
    }
  }

  Future<FlowFilingCounts?> restoreCachedMyFlowFilingCounts() async {
    final rows = await restoreCachedFiledFlows();
    if (rows == null) return null;
    return FlowFilingCounts.fromRows(rows);
  }

  Future<void> _cacheFiledFlows({
    required String userId,
    required List<FlowRow> rows,
  }) async {
    final frozen = List<FlowRow>.unmodifiable(rows);
    _filedFlowsMemoryCache[userId] = frozen;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _filedFlowsCacheKey(userId),
        jsonEncode(frozen.map((row) => row.toCacheJson()).toList()),
      );
    } catch (e) {
      _log('persist filed flow cache failed: $e');
    }
  }

  Future<Map<int, DateTime>> _loadSavedTimestamps({
    required String userId,
    required Iterable<int> flowIds,
  }) async {
    final ids = flowIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};

    final rows =
        await _client
                .from('flow_saves')
                .select('flow_id, saved_at')
                .eq('user_id', userId)
                .inFilter('flow_id', ids)
            as List<dynamic>;

    final byFlowId = <int, DateTime>{};
    for (final raw in rows.cast<Map<String, dynamic>>()) {
      final flowId = (raw['flow_id'] as num?)?.toInt();
      final savedAt = _parseDateTime(raw['saved_at']);
      if (flowId == null || savedAt == null) continue;
      byFlowId[flowId] = savedAt;
    }
    return byFlowId;
  }

  Future<List<FlowRow>> _inflateFlowRows(
    List<Map<String, dynamic>> rows, {
    required String userId,
  }) async {
    final savedFlowIds = rows
        .where((row) => (row['is_saved'] as bool?) ?? false)
        .map((row) => (row['id'] as num).toInt())
        .toSet();
    final savedAtByFlowId = await _loadSavedTimestamps(
      userId: userId,
      flowIds: savedFlowIds,
    );

    return rows
        .map((row) {
          final flowId = (row['id'] as num).toInt();
          final enriched = Map<String, dynamic>.from(row);
          final savedAt =
              savedAtByFlowId[flowId] ?? _savedAtFallbackForRow(enriched);
          enriched['saved_at'] = savedAt?.toIso8601String();
          return FlowRow.fromRow(enriched);
        })
        .toList(growable: false);
  }

  FlowLedger<FlowRow> _buildLedger(
    Iterable<FlowRow> flows, {
    Map<int, int> totalEventCounts = const {},
    Map<int, int> remainingEventCounts = const {},
  }) {
    return buildFlowLedger<FlowRow>(
      flows: flows,
      idOf: (flow) => flow.id,
      activeOf: (flow) => flow.active,
      isSavedOf: (flow) => flow.isSaved,
      isHiddenOf: (flow) => flow.isHidden,
      isReminderOf: (flow) => flow.isReminder,
      endDateOf: (flow) => flow.endDate,
      notesOf: (flow) => flow.notes,
      useRemainingEventCount: true,
      totalEventCounts: totalEventCounts,
      remainingEventCounts: remainingEventCounts,
    );
  }

  Future<List<FlowRow>> _fetchMyRawFlows() => refreshMyFiledFlows();

  Future<List<FlowRow>> listMyFiledFlows({int? limit}) async {
    return refreshMyFiledFlows(limit: limit);
  }

  Future<List<FlowRow>> refreshMyFiledFlows({int? limit}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final query = _client
        .from('flow_filing_items_client')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    final rows =
        await (limit == null ? query : query.limit(limit)) as List<dynamic>;
    final inflated = await _inflateFlowRows(
      rows.cast<Map<String, dynamic>>(),
      userId: user.id,
    );
    unawaited(_cacheFiledFlows(userId: user.id, rows: inflated));
    return inflated;
  }

  Future<({Map<int, int> total, Map<int, int> remaining})> _loadMyEventCounts(
    List<int> flowIds,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null || flowIds.isEmpty) {
      return (total: <int, int>{}, remaining: <int, int>{});
    }
    final flowIdSet = flowIds.toSet();

    try {
      final rpcResponse = await _client.rpc('get_my_flow_activity');
      final rows = switch (rpcResponse) {
        List<dynamic>() => rpcResponse.cast<dynamic>(),
        Map() => [rpcResponse],
        _ => const <dynamic>[],
      };

      final totalCounts = <int, int>{};
      final remainingCounts = <int, int>{};
      for (final raw in rows.cast<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final flowId = (row['flow_id'] as num?)?.toInt();
        if (flowId == null || !flowIdSet.contains(flowId)) continue;
        totalCounts[flowId] = (row['total_event_count'] as num?)?.toInt() ?? 0;
        remainingCounts[flowId] =
            (row['remaining_event_count'] as num?)?.toInt() ?? 0;
      }
      return (total: totalCounts, remaining: remainingCounts);
    } catch (e) {
      _log('get_my_flow_activity unavailable, using local fallback: $e');
    }

    final eventRows =
        await _client
                .from('user_event_filing_items_client')
                .select('filed_flow_id, client_event_id')
                .eq('user_id', user.id)
                .inFilter('filed_flow_id', flowIds)
            as List<dynamic>;
    final completionRows =
        await _client
                .from('user_event_completions')
                .select('flow_id, client_event_id')
                .eq('user_id', user.id)
                .inFilter('flow_id', flowIds)
            as List<dynamic>;

    final completedClientIdsByFlow = <int, Set<String>>{};
    for (final raw in completionRows.cast<Map<String, dynamic>>()) {
      final flowId = (raw['flow_id'] as num?)?.toInt();
      final clientEventId = (raw['client_event_id'] as String?)?.trim();
      if (flowId == null || clientEventId == null || clientEventId.isEmpty) {
        continue;
      }
      completedClientIdsByFlow
          .putIfAbsent(flowId, () => <String>{})
          .add(clientEventId);
    }

    final totalCounts = <int, int>{};
    final remainingCounts = <int, int>{};
    for (final raw in eventRows.cast<Map<String, dynamic>>()) {
      final flowId = (raw['filed_flow_id'] as num?)?.toInt();
      if (flowId == null) continue;

      totalCounts[flowId] = (totalCounts[flowId] ?? 0) + 1;

      final clientEventId = (raw['client_event_id'] as String?)?.trim();
      final completed =
          clientEventId != null &&
          clientEventId.isNotEmpty &&
          (completedClientIdsByFlow[flowId]?.contains(clientEventId) ?? false);
      if (!completed) {
        remainingCounts[flowId] = (remainingCounts[flowId] ?? 0) + 1;
      }
    }

    return (total: totalCounts, remaining: remainingCounts);
  }

  Future<({Map<int, int> total, Map<int, int> remaining})>
  loadMyFlowEventCounts({required Iterable<int> flowIds}) async {
    return _loadMyEventCounts(flowIds.toList(growable: false));
  }

  Future<FlowLedger<FlowRow>> loadMyFlowLedger() async {
    final flows = await _fetchMyRawFlows();
    final flowIds = flows.map((flow) => flow.id).toList(growable: false);
    final eventCounts = await _loadMyEventCounts(flowIds);
    return _buildLedger(
      flows,
      totalEventCounts: eventCounts.total,
      remainingEventCounts: eventCounts.remaining,
    );
  }

  Stream<List<FlowRow>> streamMyFlows() {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _client
        .from('flows')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .order('start_date', ascending: true)
        .asyncMap((_) async => (await loadMyFlowLedger()).activeItems);
  }

  Future<FlowRow> upsert({
    int? id, // null → insert; non-null → update
    required String name,
    required int color,
    required bool active,
    String? calendarId,
    bool isSaved = false,
    bool isHidden = false,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    List<dynamic>? rulesJson,
    bool isReminder = false,
    String? reminderUuid,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No user session. Please sign in.');
    }

    final payload = <String, dynamic>{
      'user_id': user.id,
      if (calendarId != null) 'calendar_id': calendarId,
      'name': name,
      'color': color,
      'active': active,
      'is_saved': isSaved,
      'rules': rulesJson ?? <dynamic>[],
      'is_hidden': isHidden,
      'is_reminder': isReminder,
    };
    if (startDate != null) {
      payload['start_date'] = startDate.toUtc().toIso8601String();
    }
    payload['end_date'] = endDate?.toUtc().toIso8601String();
    if (notes != null) {
      payload['notes'] = notes;
    }
    if (reminderUuid != null) {
      payload['reminder_uuid'] = reminderUuid;
    }

    if (id == null) {
      final row = await _client.from(_kFlows).insert(payload).select().single();
      return FlowRow.fromRow(row);
    } else {
      final patch = Map<String, dynamic>.from(payload)..remove('user_id');
      final row = await _client
          .from(_kFlows)
          .update(patch)
          .eq('id', id)
          .select()
          .single();
      return FlowRow.fromRow(row);
    }
  }

  Future<int> insert({
    required String name,
    required int color,
    required bool active,
    String? calendarId,
    bool isSaved = false,
    bool isHidden = false,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    required List<dynamic> rulesJson,
    bool isReminder = false,
    String? reminderUuid,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No user session.');
    final payload = {
      'user_id': user.id,
      if (calendarId != null) 'calendar_id': calendarId,
      'name': name,
      'color': color,
      'active': active,
      'is_saved': isSaved,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
      'rules': rulesJson,
      'is_hidden': isHidden,
      'is_reminder': isReminder,
      'reminder_uuid': reminderUuid,
    };
    _log('insert → $payload');
    final row = await _client.from(_kFlows).insert(payload).select().single();
    final id = (row['id'] as num).toInt();
    _log('insert ✓ id=$id');
    return id;
  }

  Future<void> update({
    required int id,
    required String name,
    required int color,
    required bool active,
    String? calendarId,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    required List<dynamic> rulesJson,
    bool isReminder = false,
    String? reminderUuid,
  }) async {
    final patch = {
      if (calendarId != null) 'calendar_id': calendarId,
      'name': name,
      'color': color,
      'active': active,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
      'rules': rulesJson,
      'is_reminder': isReminder,
      'reminder_uuid': reminderUuid,
    };
    _log('update($id) → $patch');
    await _client.from(_kFlows).update(patch).eq('id', id);
    _log('update ✓');
  }

  Future<void> updateCalendar({
    required int id,
    required String calendarId,
  }) async {
    final trimmed = calendarId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(calendarId, 'calendarId', 'Must not be empty.');
    }
    final patch = <String, dynamic>{'calendar_id': trimmed};
    _log('updateCalendar($id) → $patch');
    await _client.from(_kFlows).update(patch).eq('id', id);
    _log('updateCalendar ✓');
  }

  Future<void> delete(int id) async {
    _log('delete($id)');
    await _client
        .from(_kFlows)
        .update({'is_hidden': true, 'active': false})
        .eq('id', id);
    _log('delete ✓ (soft)');
  }

  Future<List<FlowRow>> fetchAll() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No user session.');
    }

    _log('fetchAll');
    final ledger = await loadMyFlowLedger();
    _log('fetchAll ✓ ${ledger.entries.length} rows');
    return ledger.activeItems;
  }

  Future<List<FlowRow>> listMyFlows({int limit = 200}) async {
    final ledger = await loadMyFlowLedger();
    return ledger.activeItems.take(limit).toList(growable: false);
  }

  /// List flows for the current user without filtering by active/end dates.
  /// Useful for chooser UIs where inactive or saved flows should still appear.
  Future<List<FlowRow>> listMyFlowsUnfiltered({int limit = 500}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rows =
        await _client
                .from(_kFlows)
                .select()
                .eq('user_id', user.id)
                .order('created_at', ascending: false)
                .limit(limit)
            as List<dynamic>;
    return _inflateFlowRows(rows.cast<Map<String, dynamic>>(), userId: user.id);
  }

  /// Fetch a single flow by ID
  Future<FlowRow?> getFlowById(int id) async {
    final response = await _client
        .from(_kFlows)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return FlowRow.fromRow(response);
    }
    final flows = await _inflateFlowRows([
      Map<String, dynamic>.from(response as Map),
    ], userId: userId);
    return flows.isEmpty ? null : flows.first;
  }

  /// Fetch a flow id by reminder_uuid.
  Future<int?> getFlowIdByReminderUuid(String reminderUuid) async {
    if (!_isUuid(reminderUuid)) {
      return null;
    }
    try {
      final response = await _client
          .from(_kFlows)
          .select('id')
          .eq('reminder_uuid', reminderUuid)
          .maybeSingle();
      return response?['id'] as int?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[flows] getFlowIdByReminderUuid failed: $e');
      }
      return null;
    }
  }
}
