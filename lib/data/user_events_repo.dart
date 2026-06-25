// lib/data/user_events_repo.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'birthday_calendar.dart';
import '../features/calendar/notify.dart';
import '../telemetry/telemetry.dart';
import '../utils/flow_filter_engine.dart';

const _kTable = 'user_events';
const _kReadableEventsTable = 'user_event_filing_items_client';

void _log(String msg) {
  if (kDebugMode) debugPrint('[user_events] $msg');
}

typedef FlowEventRow = ({
  String? id,
  String? clientEventId,
  String? calendarId,
  String? calendarName,
  int? calendarColor,
  bool calendarIsPersonal,
  String title,
  String? detail,
  String? location,
  bool allDay,
  DateTime startsAtUtc,
  DateTime? endsAtUtc,
  int? flowLocalId,
  String? category,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
});

typedef StandaloneEventRow = ({
  String? id,
  String? clientEventId,
  String? calendarId,
  String? calendarName,
  int? calendarColor,
  bool calendarIsPersonal,
  String title,
  String? detail,
  String? location,
  bool allDay,
  DateTime startsAtUtc,
  DateTime? endsAtUtc,
  int? flowLocalId,
  String? category,
  bool isReminder,
});

bool _isUuid(String? v) {
  if (v == null) return false;
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(v);
}

Iterable<List<T>> _chunkList<T>(List<T> items, int size) sync* {
  if (items.isEmpty || size <= 0) return;
  for (var i = 0; i < items.length; i += size) {
    final end = (i + size < items.length) ? i + size : items.length;
    yield items.sublist(i, end);
  }
}

DateTime? _parseOptionalDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

String? _normalizedFilingItemKind(Map<String, dynamic> row) {
  final raw = row['item_kind']?.toString().trim().toLowerCase();
  return raw == null || raw.isEmpty ? null : raw;
}

int? _positiveInt(dynamic value) {
  final parsed = (value as num?)?.toInt();
  return parsed != null && parsed > 0 ? parsed : null;
}

@visibleForTesting
int? canonicalFiledFlowIdForEventRow(Map<String, dynamic> row) {
  return _positiveInt(row['filed_flow_id']) ??
      _positiveInt(row['flow_local_id']);
}

@visibleForTesting
bool filingRowIsFlowCalendarEvent(Map<String, dynamic> row) {
  final kind = _normalizedFilingItemKind(row);
  if (kind == 'flow') return true;
  if (kind == 'note' || kind == 'reminder') return false;
  return canonicalFiledFlowIdForEventRow(row) != null;
}

@visibleForTesting
bool filingRowIsStandaloneCalendarEvent(Map<String, dynamic> row) {
  final kind = _normalizedFilingItemKind(row);
  if (kind == 'note' || kind == 'reminder') return true;
  if (kind == 'flow') return false;
  return canonicalFiledFlowIdForEventRow(row) == null;
}

String _formatDateOnlyLocal(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

StandaloneEventRow _standaloneRowFromBirthdayOccurrence(
  BirthdayOccurrence occurrence,
) {
  final row = occurrence.toStandaloneEventRow();
  return (
    id: row['id'] as String?,
    clientEventId: row['client_event_id'] as String?,
    calendarId: row['calendar_id'] as String?,
    calendarName: row['calendar_name'] as String?,
    calendarColor: (row['calendar_color'] as num?)?.toInt(),
    calendarIsPersonal: (row['calendar_is_personal'] as bool?) ?? false,
    title: (row['title'] as String?) ?? '',
    detail: row['detail'] as String?,
    location: row['location'] as String?,
    allDay: (row['all_day'] as bool?) ?? true,
    startsAtUtc: DateTime.parse(row['starts_at'] as String),
    endsAtUtc: row['ends_at'] == null
        ? null
        : DateTime.parse(row['ends_at'] as String),
    flowLocalId: (row['flow_local_id'] as num?)?.toInt(),
    category: row['category'] as String?,
    isReminder: false,
  );
}

@immutable
class UserEvent {
  final String id;
  final String? clientEventId;
  final String? calendarId;
  final String? calendarName;
  final int? calendarColor;
  final bool calendarIsPersonal;
  final String title;
  final String? detail;
  final String? location;
  final bool allDay;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? flowLocalId;
  final String? category;
  final String? actionId;
  final Map<String, dynamic>? behaviorPayload;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  const UserEvent({
    required this.id,
    this.clientEventId,
    this.calendarId,
    this.calendarName,
    this.calendarColor,
    this.calendarIsPersonal = true,
    required this.title,
    this.detail,
    this.location,
    required this.allDay,
    required this.startsAt,
    this.endsAt,
    this.flowLocalId,
    this.category,
    this.actionId,
    this.behaviorPayload,
    this.updatedAt,
    this.createdAt,
  });

  factory UserEvent.fromRow(Map<String, dynamic> row) {
    DateTime parseTs(dynamic v) => v == null
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.parse(v as String);

    return UserEvent(
      id: row['id'] as String,
      clientEventId: row['client_event_id'] as String?,
      calendarId: row['calendar_id'] as String?,
      calendarName: row['calendar_name'] as String?,
      calendarColor: (row['calendar_color'] as num?)?.toInt(),
      calendarIsPersonal: (row['calendar_is_personal'] as bool?) ?? true,
      title: row['title'] as String,
      detail: row['detail'] as String?,
      location: row['location'] as String?,
      allDay: (row['all_day'] as bool?) ?? false,
      startsAt: parseTs(row['starts_at']).toUtc(),
      endsAt: row['ends_at'] == null
          ? null
          : DateTime.parse(row['ends_at'] as String).toUtc(),
      flowLocalId: row['flow_local_id'] != null
          ? (row['flow_local_id'] as num).toInt()
          : null,
      category: row['category'] as String?,
      actionId: (row['action_id'] as String?)?.trim(),
      behaviorPayload: row['behavior_payload'] is Map
          ? Map<String, dynamic>.from(row['behavior_payload'] as Map)
          : null,
      updatedAt: row['updated_at'] == null
          ? null
          : DateTime.parse(row['updated_at'] as String).toUtc(),
      createdAt: row['created_at'] == null
          ? null
          : DateTime.parse(row['created_at'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toInsert({required String userId}) {
    return {
      'user_id': userId,
      'client_event_id': clientEventId,
      if (calendarId != null) 'calendar_id': calendarId,
      'title': title,
      'detail': detail,
      'location': location,
      'all_day': allDay,
      'starts_at': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'ends_at': endsAt!.toUtc().toIso8601String(),
      if (category != null) 'category': category,
      if (actionId != null) 'action_id': actionId,
      if (behaviorPayload != null) 'behavior_payload': behaviorPayload,
    };
  }

  Map<String, dynamic> toPatch() {
    return {
      if (clientEventId != null) 'client_event_id': clientEventId,
      if (calendarId != null) 'calendar_id': calendarId,
      'title': title,
      'detail': detail,
      'location': location,
      'all_day': allDay,
      'starts_at': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'ends_at': endsAt!.toUtc().toIso8601String(),
      if (category != null) 'category': category,
      if (actionId != null) 'action_id': actionId,
      if (behaviorPayload != null) 'behavior_payload': behaviorPayload,
    };
  }
}

class UserEventsRepo {
  UserEventsRepo(this._client);
  final SupabaseClient _client;
  static final Set<String> _graphRefreshInFlightUsers = <String>{};
  static final Set<String> _graphRefreshPendingUsers = <String>{};

  int _rpcCount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> _semanticDeleteParams({
    required String semantic,
    required bool suppressesClient,
    required String sourceFeature,
    required String deleteScope,
  }) {
    return {
      'p_delete_semantic': semantic,
      'p_suppresses_client': suppressesClient,
      'p_source_feature': sourceFeature,
      'p_delete_scope': deleteScope,
    };
  }

  Future<int> _deleteUserEventIdsSemantic(
    List<String> ids, {
    required String semantic,
    required bool suppressesClient,
    required String sourceFeature,
    required String deleteScope,
  }) async {
    var deleted = 0;
    final trimmedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    for (final chunk in _chunkList(trimmedIds, 200)) {
      final result = await _client.rpc(
        'delete_user_events_by_ids_semantic',
        params: {
          'p_ids': chunk,
          ..._semanticDeleteParams(
            semantic: semantic,
            suppressesClient: suppressesClient,
            sourceFeature: sourceFeature,
            deleteScope: deleteScope,
          ),
        },
      );
      deleted += _rpcCount(result);
    }
    return deleted;
  }

  Future<int> _deleteUserEventsByClientIdSemantic(
    String clientEventId, {
    required String semantic,
    required bool suppressesClient,
    required String sourceFeature,
    required String deleteScope,
  }) async {
    final trimmed = clientEventId.trim();
    if (trimmed.isEmpty) return 0;
    final result = await _client.rpc(
      'delete_user_events_by_client_id_semantic',
      params: {
        'p_client_event_id': trimmed,
        ..._semanticDeleteParams(
          semantic: semantic,
          suppressesClient: suppressesClient,
          sourceFeature: sourceFeature,
          deleteScope: deleteScope,
        ),
      },
    );
    return _rpcCount(result);
  }

  Future<int> _deleteUserEventsByClientIdPrefixSemantic(
    String prefix, {
    DateTime? fromUtc,
    DateTime? untilUtc,
    required String semantic,
    required bool suppressesClient,
    required String sourceFeature,
    required String deleteScope,
  }) async {
    final trimmed = prefix.trim();
    if (trimmed.isEmpty) return 0;
    final result = await _client.rpc(
      'delete_user_events_by_client_id_prefix_semantic',
      params: {
        'p_client_event_id_prefix': trimmed,
        if (fromUtc != null) 'p_from_utc': fromUtc.toUtc().toIso8601String(),
        if (untilUtc != null) 'p_until_utc': untilUtc.toUtc().toIso8601String(),
        ..._semanticDeleteParams(
          semantic: semantic,
          suppressesClient: suppressesClient,
          sourceFeature: sourceFeature,
          deleteScope: deleteScope,
        ),
      },
    );
    return _rpcCount(result);
  }

  Future<int> _deleteUserEventsByFlowSemantic(
    int flowId, {
    DateTime? fromUtc,
    DateTime? untilUtc,
    required String semantic,
    required bool suppressesClient,
    required String sourceFeature,
    required String deleteScope,
  }) async {
    if (flowId <= 0) return 0;
    final result = await _client.rpc(
      'delete_user_events_by_flow_semantic',
      params: {
        'p_flow_id': flowId,
        if (fromUtc != null) 'p_from_utc': fromUtc.toUtc().toIso8601String(),
        if (untilUtc != null) 'p_until_utc': untilUtc.toUtc().toIso8601String(),
        ..._semanticDeleteParams(
          semantic: semantic,
          suppressesClient: suppressesClient,
          sourceFeature: sourceFeature,
          deleteScope: deleteScope,
        ),
      },
    );
    return _rpcCount(result);
  }

  Future<int> _deleteUserEventsByCategorySemantic(
    String category, {
    required String semantic,
    required bool suppressesClient,
    required String sourceFeature,
    required String deleteScope,
  }) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return 0;
    final result = await _client.rpc(
      'delete_user_events_by_category_semantic',
      params: {
        'p_category': trimmed,
        ..._semanticDeleteParams(
          semantic: semantic,
          suppressesClient: suppressesClient,
          sourceFeature: sourceFeature,
          deleteScope: deleteScope,
        ),
      },
    );
    return _rpcCount(result);
  }

  Future<List<Map<String, dynamic>>> _loadStandaloneGhostRowsForFlow({
    required String userId,
    required int flowId,
    DateTime? startUtc,
    DateTime? endUtc,
    int pageSize = 1000,
  }) async {
    final rowsForDelete = <Map<String, dynamic>>[];
    var offset = 0;

    while (true) {
      var query = _client
          .from(_kTable)
          .select('id,client_event_id,detail,flow_local_id,starts_at')
          .eq('user_id', userId)
          .isFilter('flow_local_id', null);

      if (startUtc != null) {
        query = query.gte('starts_at', startUtc.toUtc().toIso8601String());
      }
      if (endUtc != null) {
        query = query.lt('starts_at', endUtc.toUtc().toIso8601String());
      }

      final rawPage = await query
          .order('starts_at', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      final page = (rawPage as List).cast<Map<String, dynamic>>().toList(
        growable: false,
      );
      for (final row in page) {
        if (!eventReferencesFlow(
          flowId: flowId,
          flowLocalId: (row['flow_local_id'] as num?)?.toInt(),
          clientEventId: row['client_event_id'] as String?,
          detail: row['detail'] as String?,
        )) {
          continue;
        }
        rowsForDelete.add(row);
      }

      if (page.length < pageSize) break;
      offset += pageSize;
    }

    return rowsForDelete;
  }

  static bool? _telemetryEnabled;
  static const String _readSelect =
      'id,calendar_id,calendar_name,calendar_color,calendar_is_personal,client_event_id,title,detail,location,all_day,starts_at,ends_at,flow_local_id,category,action_id,behavior_payload,updated_at,created_at';
  static const String _filingReadSelect =
      'id,calendar_id,calendar_name,calendar_color,calendar_is_personal,client_event_id,title,detail,location,all_day,starts_at,ends_at,flow_local_id,filed_flow_id,item_kind,category,action_id,behavior_payload,updated_at,created_at';
  static const String _flowEventReadSelect =
      'id,calendar_id,calendar_name,calendar_color,calendar_is_personal,client_event_id,title,detail,location,all_day,starts_at,ends_at,flow_local_id,filed_flow_id,item_kind,category,action_id,behavior_payload';

  bool get telemetryEnabled => _telemetryEnabled ?? true;

  FlowEventRow _flowEventRowFromFilingRow(
    Map<String, dynamic> row, {
    int? flowLocalIdOverride,
  }) {
    return (
      id: row['id'] as String?,
      clientEventId: row['client_event_id'] as String?,
      calendarId: row['calendar_id'] as String?,
      calendarName: row['calendar_name'] as String?,
      calendarColor: (row['calendar_color'] as num?)?.toInt(),
      calendarIsPersonal: (row['calendar_is_personal'] as bool?) ?? true,
      title: (row['title'] as String?) ?? '',
      detail: row['detail'] as String?,
      location: row['location'] as String?,
      allDay: (row['all_day'] as bool?) ?? false,
      startsAtUtc: DateTime.parse(row['starts_at'] as String).toUtc(),
      endsAtUtc: row['ends_at'] != null
          ? DateTime.parse(row['ends_at'] as String).toUtc()
          : null,
      flowLocalId: flowLocalIdOverride ?? canonicalFiledFlowIdForEventRow(row),
      category: row['category'] as String?,
      actionId: (row['action_id'] as String?)?.trim(),
      behaviorPayload: row['behavior_payload'] is Map
          ? Map<String, dynamic>.from(row['behavior_payload'] as Map)
          : null,
    );
  }

  /// Refresh telemetry/personalization flags from the profile helper RPC.
  static Future<void> refreshTelemetrySettings(SupabaseClient client) async {
    try {
      final resp = await client.rpc('get_my_telemetry_and_personalization');
      Map<String, dynamic>? row;
      if (resp is List && resp.isNotEmpty && resp.first is Map) {
        row = Map<String, dynamic>.from(resp.first as Map);
      } else if (resp is Map) {
        row = Map<String, dynamic>.from(resp);
      }
      final tEnabled = row?['telemetry_enabled'];
      if (tEnabled is bool) {
        _telemetryEnabled = tEnabled;
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[UserEventsRepo] refreshTelemetrySettings error: $e');
        debugPrint('$st');
      }
    }
  }

  static void setTelemetryEnabledForTesting(bool? enabled) {
    _telemetryEnabled = enabled;
  }

  static const _allowedFeedbackTags = <String>{
    'wrong_time',
    'too_much',
    'too_easy',
    'irrelevant',
    'great_fit',
  };

  /// Insert (new server id returned).
  Future<UserEvent> addEvent({
    required String title,
    required DateTime startsAtUtc,
    String? detail,
    String? location,
    bool allDay = false,
    String? clientEventId,
    DateTime? endsAtUtc,
    String? category,
    String? calendarId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No user session. Please sign in.');

    final payload = <String, dynamic>{
      'user_id': user.id,
      if (calendarId != null) 'calendar_id': calendarId,
      'title': title,
      'detail': detail,
      'location': location,
      'all_day': allDay,
      'starts_at': startsAtUtc.toIso8601String(),
      if (endsAtUtc != null) 'ends_at': endsAtUtc.toIso8601String(),
      if (clientEventId != null) 'client_event_id': clientEventId,
      if (category != null) 'category': category,
    };

    _log('insert → $payload');
    try {
      final row = await _client.from(_kTable).insert(payload).select().single();
      _log('insert ✓ id=${row['id']}');
      return UserEvent.fromRow(row);
    } on PostgrestException catch (e) {
      _log('insert ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('insert ✗ $e');
      rethrow;
    }
  }

  /// Create or update by client_event_id (idempotent).
  /// IMPORTANT: we now conflict on `(user_id, client_event_id)` to match the DB unique index.
  Future<UserEvent> upsertByClientId({
    required String clientEventId,
    required String title,
    required DateTime startsAtUtc,
    String? detail,
    String? location,
    bool allDay = false,
    DateTime? endsAtUtc,
    int? flowLocalId,
    String? category,
    String? actionId,
    Map<String, dynamic>? behaviorPayload,
    String? calendarId,
    String? caller,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No user session. Please sign in.');

    try {
      final existing = await _client
          .from(_kTable)
          .select()
          .eq('client_event_id', clientEventId)
          .maybeSingle();
      if (existing != null &&
          (existing['category'] as String?) == 'tombstone') {
        final callerTag = caller == null || caller.isEmpty
            ? 'unspecified'
            : caller;
        _log(
          'upsert blocked by tombstone client_event_id=$clientEventId caller=$callerTag',
        );
        return UserEvent.fromRow(existing);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[user_events] tombstone check failed for cid=$clientEventId: $e',
        );
      }
    }

    final payload = {
      'user_id': user.id,
      'client_event_id': clientEventId,
      if (calendarId != null) 'calendar_id': calendarId,
      'title': title,
      'detail': detail,
      'location': location,
      'all_day': allDay,
      'starts_at': startsAtUtc.toIso8601String(),
      if (endsAtUtc != null) 'ends_at': endsAtUtc.toIso8601String(),
      if (flowLocalId != null) 'flow_local_id': flowLocalId,
      if (category != null) 'category': category,
      if (actionId != null) 'action_id': actionId,
      if (behaviorPayload != null) 'behavior_payload': behaviorPayload,
    };

    final callerTag = caller == null || caller.isEmpty ? 'unspecified' : caller;
    _log('upsert(client_event_id=$clientEventId caller=$callerTag) → $payload');
    try {
      final row = await _client
          .from(_kTable)
          .upsert(payload, onConflict: 'client_event_id')
          .select()
          .single();
      _log('upsert ✓ id=${row['id']} caller=$callerTag');
      return UserEvent.fromRow(row);
    } on PostgrestException catch (e) {
      _log('upsert ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('upsert ✗ $e');
      rethrow;
    }
  }

  /// Update by row id (owner-scoped by RLS).
  Future<UserEvent> update({
    required String id,
    String? clientEventId,
    String? calendarId,
    String? title,
    String? detail,
    String? location,
    bool? allDay,
    DateTime? startsAt,
    DateTime? endsAt,
    String? category,
    String? actionId,
    Map<String, dynamic>? behaviorPayload,
  }) async {
    final patch = <String, dynamic>{};
    if (clientEventId != null) patch['client_event_id'] = clientEventId;
    if (calendarId != null) patch['calendar_id'] = calendarId;
    if (title != null) patch['title'] = title;
    if (detail != null) patch['detail'] = detail;
    if (location != null) patch['location'] = location;
    if (allDay != null) patch['all_day'] = allDay;
    if (startsAt != null) {
      patch['starts_at'] = startsAt.toUtc().toIso8601String();
    }
    if (endsAt != null) patch['ends_at'] = endsAt.toUtc().toIso8601String();
    if (category != null) patch['category'] = category;
    if (actionId != null) patch['action_id'] = actionId;
    if (behaviorPayload != null) patch['behavior_payload'] = behaviorPayload;
    if (patch.isEmpty) throw ArgumentError('Nothing to update.');

    _log('update($id) → $patch');
    try {
      final row = await _client
          .from(_kTable)
          .update(patch)
          .eq('id', id)
          .select()
          .single();
      _log('update ✓ id=$id');
      final updated = UserEvent.fromRow(row);
      if (updated.flowLocalId != null && updated.flowLocalId! > 0) {
        unawaited(
          track(
            event: 'event_updated',
            properties: {
              'flow_id': updated.flowLocalId,
              'event_id': id,
              'v': kAppEventsSchemaVersion,
            },
          ),
        );
      }
      return updated;
    } on PostgrestException catch (e) {
      _log('update ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('update ✗ $e');
      rethrow;
    }
  }

  Future<UserEvent?> getEventByClientEventId(String clientEventId) async {
    final user = _client.auth.currentUser;
    final trimmed = clientEventId.trim();
    if (user == null || trimmed.isEmpty) return null;

    try {
      final row = await _client
          .from(_kReadableEventsTable)
          .select(_readSelect)
          .eq('client_event_id', trimmed)
          .maybeSingle();
      if (row == null) return null;
      return UserEvent.fromRow((row as Map).cast<String, dynamic>());
    } on PostgrestException catch (e) {
      _log('getEventByClientEventId ✗ ${e.code} ${e.message}');
      return null;
    } catch (e) {
      _log('getEventByClientEventId ✗ $e');
      return null;
    }
  }

  /// Replace the editable event fields for an existing row.
  /// Unlike [update], nullable fields are written through and can be cleared.
  Future<UserEvent> replace({
    required String id,
    required String clientEventId,
    String? calendarId,
    required String title,
    String? detail,
    String? location,
    required bool allDay,
    required DateTime startsAt,
    DateTime? endsAt,
    String? category,
  }) async {
    final patch = <String, dynamic>{
      'client_event_id': clientEventId,
      if (calendarId != null) 'calendar_id': calendarId,
      'title': title,
      'detail': detail,
      'location': location,
      'all_day': allDay,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'category': category,
    };

    _log('replace($id) → $patch');
    try {
      final row = await _client
          .from(_kTable)
          .update(patch)
          .eq('id', id)
          .select()
          .single();
      _log('replace ✓ id=$id');
      return UserEvent.fromRow(row);
    } on PostgrestException catch (e) {
      _log('replace ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('replace ✗ $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    String? cidForLog;
    int? flowIdForLog;
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final row = await _client
            .from(_kTable)
            .select('client_event_id,flow_local_id')
            .eq('user_id', user.id)
            .eq('id', id)
            .maybeSingle();
        cidForLog = (row?['client_event_id'] as String?);
        flowIdForLog = (row?['flow_local_id'] as num?)?.toInt();
      }
    } catch (_) {}
    _log('delete($id) cid=${cidForLog ?? 'unknown'}');
    try {
      final deletedCount = await _deleteUserEventIdsSemantic(
        [id],
        semantic: 'user_delete',
        suppressesClient: true,
        sourceFeature: 'UserEventsRepo.delete',
        deleteScope: 'exact_occurrence',
      );

      if (deletedCount <= 0) {
        _log('delete ⚠️ no rows for id=$id');
        return;
      }

      _log('delete ✓ deleted=$deletedCount');

      if (flowIdForLog != null && flowIdForLog > 0) {
        unawaited(
          track(
            event: 'event_deleted',
            properties: {
              'flow_id': flowIdForLog,
              'event_id': id,
              'v': kAppEventsSchemaVersion,
            },
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116' ||
          e.message.contains('Results contain 0 rows')) {
        _log('delete ⚠️ no rows for id=$id');
        return;
      }
      _log('delete ✗ ${e.code} ${e.message}');
      rethrow;
    }
  }

  Future<void> updateCalendarForFlowEvents({
    required int flowId,
    required String calendarId,
  }) async {
    final trimmed = calendarId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(calendarId, 'calendarId', 'Must not be empty.');
    }
    final patch = <String, dynamic>{'calendar_id': trimmed};
    _log('updateCalendarForFlowEvents($flowId) → $patch');
    try {
      await _client.from(_kTable).update(patch).eq('flow_local_id', flowId);
      _log('updateCalendarForFlowEvents ✓ flow=$flowId');
    } on PostgrestException catch (e) {
      _log('updateCalendarForFlowEvents ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('updateCalendarForFlowEvents ✗ $e');
      rethrow;
    }
  }

  Future<void> deleteByClientId(
    String clientEventId, {
    String semantic = 'user_delete',
    bool suppressesClient = true,
    String sourceFeature = 'UserEventsRepo.deleteByClientId',
    String deleteScope = 'exact_occurrence',
  }) async {
    _log('deleteByClientId($clientEventId)');
    try {
      await Notify.cancelNotificationsForClientEventIds([clientEventId]);

      final existingRows = await _client
          .from(_kTable)
          .select('id, flow_local_id')
          .eq('client_event_id', clientEventId);

      final rows = existingRows.cast<Map<String, dynamic>>();
      if (rows.isEmpty) {
        _log('deleteByClientId ⚠️ no rows for cid=$clientEventId');
        if (suppressesClient) {
          await recordDeletionTombstone(
            clientEventId: clientEventId,
            reason: 'delete_by_client_id_missing_row',
          );
        }
        return;
      }

      final deletedCount = await _deleteUserEventsByClientIdSemantic(
        clientEventId,
        semantic: semantic,
        suppressesClient: suppressesClient,
        sourceFeature: sourceFeature,
        deleteScope: deleteScope,
      );
      if (deletedCount <= 0) {
        _log('deleteByClientId ⚠️ no rows for cid=$clientEventId');
        if (suppressesClient) {
          await recordDeletionTombstone(
            clientEventId: clientEventId,
            reason: 'delete_by_client_id_missing_row',
          );
        }
        return;
      }

      final deletedId = rows.first['id'] as String?;
      final flowId = (rows.first['flow_local_id'] as num?)?.toInt();
      _log(
        'deleteByClientId ✓ id=${deletedId ?? 'unknown'} cid=$clientEventId deleted=$deletedCount semantic=$semantic suppresses=$suppressesClient',
      );

      if (flowId != null && flowId > 0 && deletedId != null) {
        unawaited(
          track(
            event: 'event_deleted',
            properties: {
              'flow_id': flowId,
              'event_id': deletedId,
              'v': kAppEventsSchemaVersion,
            },
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116' ||
          e.message.contains('Results contain 0 rows')) {
        _log('deleteByClientId ⚠️ no rows for cid=$clientEventId');
        if (suppressesClient) {
          await recordDeletionTombstone(
            clientEventId: clientEventId,
            reason: 'delete_by_client_id_missing_row',
          );
        }
        return;
      }
      _log('deleteByClientId ✗ ${e.code} ${e.message}');
      rethrow;
    }
  }

  Future<void> recordDeletionTombstone({
    required String clientEventId,
    String? calendarId,
    String reason = 'client_delete',
  }) async {
    final trimmed = clientEventId.trim();
    if (trimmed.isEmpty) return;

    try {
      await _client.rpc(
        'record_user_event_tombstone',
        params: {
          'p_client_event_id': trimmed,
          if (calendarId != null && calendarId.trim().isNotEmpty)
            'p_calendar_id': calendarId.trim(),
          'p_reason': reason,
        },
      );
      _log('recordDeletionTombstone ✓ cid=$trimmed');
    } on PostgrestException catch (e) {
      _log('recordDeletionTombstone ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('recordDeletionTombstone ✗ $e');
      rethrow;
    }
  }

  /// Delete events by client_event_id prefix (e.g., 'nutrition:item-id:').
  /// Useful for bulk deletion of related events.
  Future<void> deleteByClientIdPrefix(
    String prefix, {
    DateTime? fromUtc,
    DateTime? untilUtc,
    String semantic = 'user_delete',
    bool suppressesClient = true,
    String sourceFeature = 'UserEventsRepo.deleteByClientIdPrefix',
    String deleteScope = 'client_id_prefix',
  }) async {
    _log(
      'deleteByClientIdPrefix($prefix, fromUtc=$fromUtc, untilUtc=$untilUtc, semantic=$semantic, suppresses=$suppressesClient)',
    );
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      var selectQuery = _client
          .from(_kTable)
          .select('client_event_id')
          .eq('user_id', user.id)
          .like('client_event_id', '$prefix%');
      if (fromUtc != null) {
        selectQuery = selectQuery.gte(
          'starts_at',
          fromUtc.toUtc().toIso8601String(),
        );
      }
      if (untilUtc != null) {
        selectQuery = selectQuery.lt(
          'starts_at',
          untilUtc.toUtc().toIso8601String(),
        );
      }
      final rowsToCancel = await selectQuery;
      final cidsToCancel = (rowsToCancel as List)
          .cast<Map<String, dynamic>>()
          .map((row) => row['client_event_id'] as String?)
          .whereType<String>()
          .where((cid) => cid.trim().isNotEmpty)
          .toSet();
      if (cidsToCancel.isNotEmpty) {
        await Notify.cancelNotificationsForClientEventIds(cidsToCancel);
      }

      final deletedCount = await _deleteUserEventsByClientIdPrefixSemantic(
        prefix,
        fromUtc: fromUtc,
        untilUtc: untilUtc,
        semantic: semantic,
        suppressesClient: suppressesClient,
        sourceFeature: sourceFeature,
        deleteScope: deleteScope,
      );

      _log('deleteByClientIdPrefix ✓ deleted=$deletedCount');
    } on PostgrestException catch (e) {
      _log('deleteByClientIdPrefix ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('deleteByClientIdPrefix ✗ $e');
      rethrow;
    }
  }

  /// Delete events by category through the semantic delete path.
  Future<void> deleteByCategory(
    String category, {
    String semantic = 'user_delete',
    bool suppressesClient = true,
    String sourceFeature = 'UserEventsRepo.deleteByCategory',
    String deleteScope = 'category',
  }) async {
    _log(
      'deleteByCategory($category, semantic=$semantic, suppresses=$suppressesClient)',
    );
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final rowsToCancel = await _client
          .from(_kTable)
          .select('client_event_id')
          .eq('user_id', user.id)
          .eq('category', category);
      final cidsToCancel = (rowsToCancel as List)
          .cast<Map<String, dynamic>>()
          .map((row) => row['client_event_id'] as String?)
          .whereType<String>()
          .where((cid) => cid.trim().isNotEmpty)
          .toSet();
      if (cidsToCancel.isNotEmpty) {
        await Notify.cancelNotificationsForClientEventIds(cidsToCancel);
      }

      final deletedCount = await _deleteUserEventsByCategorySemantic(
        category,
        semantic: semantic,
        suppressesClient: suppressesClient,
        sourceFeature: sourceFeature,
        deleteScope: deleteScope,
      );
      _log('deleteByCategory ✓ deleted=$deletedCount');
    } on PostgrestException catch (e) {
      _log('deleteByCategory ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('deleteByCategory ✗ $e');
      rethrow;
    }
  }

  /// Delete events by a list of row ids (scoped to current user).
  Future<void> deleteByIds(
    List<String> ids, {
    String semantic = 'user_delete',
    bool suppressesClient = true,
    String sourceFeature = 'UserEventsRepo.deleteByIds',
    String deleteScope = 'exact_occurrence',
  }) async {
    if (ids.isEmpty) return;
    List<({String id, String? clientEventId})> rowsForLog = const [];
    try {
      rowsForLog = await getClientEventIdsByIds(ids);
    } catch (_) {}
    if (rowsForLog.isNotEmpty) {
      final cidLog = rowsForLog
          .map((r) => '${r.id}:${r.clientEventId ?? 'null'}')
          .join(',');
      _log('deleteByIds(count=${ids.length}) idsWithCid=[$cidLog]');
    } else {
      _log('deleteByIds(count=${ids.length}) ids=${ids.join(",")}');
    }
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;
      final cidsToCancel = rowsForLog
          .map((row) => row.clientEventId)
          .whereType<String>()
          .where((cid) => cid.trim().isNotEmpty)
          .toSet();
      if (cidsToCancel.isNotEmpty) {
        await Notify.cancelNotificationsForClientEventIds(cidsToCancel);
      }
      final deletedCount = await _deleteUserEventIdsSemantic(
        ids,
        semantic: semantic,
        suppressesClient: suppressesClient,
        sourceFeature: sourceFeature,
        deleteScope: deleteScope,
      );
      _log(
        'deleteByIds ✓ deleted=$deletedCount semantic=$semantic suppresses=$suppressesClient',
      );
    } on PostgrestException catch (e) {
      _log('deleteByIds ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('deleteByIds ✗ $e');
      rethrow;
    }
  }

  /// Delete Ma'at-generated events by flow id. Optionally from a given date forward.
  Future<void> deleteByFlowId(
    int flowId, {
    DateTime? fromDate,
    String semantic = 'user_delete',
    bool suppressesClient = true,
    String sourceFeature = 'UserEventsRepo.deleteByFlowId',
    String deleteScope = 'flow',
  }) async {
    _log(
      'deleteByFlowId(flowId=$flowId, fromDate=$fromDate, semantic=$semantic, suppresses=$suppressesClient)',
    );
    try {
      DateTime? startDate;
      DateTime? endDateInclusive; // end date as stored (date at 00:00)
      final rows = await _client
          .from('flows')
          .select('start_date,end_date')
          .eq('id', flowId)
          .limit(1);
      if (rows.isNotEmpty) {
        final row = rows.first;
        startDate = row['start_date'] == null
            ? null
            : DateTime.parse(row['start_date'] as String).toUtc();
        endDateInclusive = row['end_date'] == null
            ? null
            : DateTime.parse(row['end_date'] as String).toUtc();
      }

      // Build a half-open time window: [windowStart, windowEndExclusive)
      // so the entire last day is *included* even if your events are at 16:00 UTC.
      final windowStart = (fromDate ?? startDate)?.toUtc();
      final windowEndExclusive = endDateInclusive?.toUtc().add(
        const Duration(days: 1),
      ); // next day at 00:00Z

      final user = _client.auth.currentUser;
      final cidsToCancel = <String>{};
      List<Map<String, dynamic>> orphanRows = const [];

      try {
        final taggedEvents = await getEventsForFlow(
          flowId,
          startUtc: fromDate?.toUtc(),
        );
        for (final event in taggedEvents) {
          final cid = event.clientEventId?.trim();
          if (cid != null && cid.isNotEmpty) {
            cidsToCancel.add(cid);
          }
        }
      } catch (_) {
        // Best effort only; deletion should still proceed.
      }

      if (user != null) {
        orphanRows = await _loadStandaloneGhostRowsForFlow(
          userId: user.id,
          flowId: flowId,
          startUtc: windowStart,
          endUtc: windowEndExclusive,
        );
        for (final row in orphanRows) {
          final cid = (row['client_event_id'] as String?)?.trim();
          if (cid != null && cid.isNotEmpty) {
            cidsToCancel.add(cid);
          }
        }
      }

      if (user != null && (windowStart != null || windowEndExclusive != null)) {
        var legacySelect = _client
            .from(_kTable)
            .select('client_event_id')
            .eq('user_id', user.id)
            .like('client_event_id', 'maat:%');
        if (windowStart != null) {
          legacySelect = legacySelect.gte(
            'starts_at',
            windowStart.toIso8601String(),
          );
        }
        if (windowEndExclusive != null) {
          legacySelect = legacySelect.lt(
            'starts_at',
            windowEndExclusive.toIso8601String(),
          );
        }
        final legacyRows = await legacySelect;
        for (final row in (legacyRows as List).cast<Map<String, dynamic>>()) {
          final cid = (row['client_event_id'] as String?)?.trim();
          if (cid != null && cid.isNotEmpty) {
            cidsToCancel.add(cid);
          }
        }
      }

      if (cidsToCancel.isNotEmpty) {
        await Notify.cancelNotificationsForClientEventIds(cidsToCancel);
      }

      // 1) delete events explicitly tagged with flow_local_id
      await _deleteUserEventsByFlowSemantic(
        flowId,
        fromUtc: fromDate?.toUtc(),
        semantic: semantic,
        suppressesClient: suppressesClient,
        sourceFeature: sourceFeature,
        deleteScope: deleteScope,
      );

      // 2) also delete Ma'at-generated events in the flow's date window (handles legacy rows with no flow_local_id)
      if (user != null && (windowStart != null || windowEndExclusive != null)) {
        await _deleteUserEventsByClientIdPrefixSemantic(
          'maat:',
          fromUtc: windowStart,
          untilUtc: windowEndExclusive,
          semantic: semantic,
          suppressesClient: suppressesClient,
          sourceFeature: sourceFeature,
          deleteScope: 'legacy_maat_flow_window',
        );
      }

      if (user != null && orphanRows.isNotEmpty) {
        final orphanIds = orphanRows
            .map((row) => row['id'] as String?)
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toList(growable: false);
        for (final chunk in _chunkList(orphanIds, 200)) {
          await _deleteUserEventIdsSemantic(
            chunk,
            semantic: semantic,
            suppressesClient: suppressesClient,
            sourceFeature: sourceFeature,
            deleteScope: 'orphan_flow_cleanup',
          );
        }
      }

      _log('deleteByFlowId ✓');
    } on PostgrestException catch (e) {
      _log('deleteByFlowId ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('deleteByFlowId ✗ $e');
      rethrow;
    }
  }

  /// Bulk idempotent upsert for Ma'at note batches (deterministic client_event_id).
  Future<void> upsertManyDeterministic(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await _client
          .from(_kTable)
          .upsert(rows, onConflict: 'user_id,client_event_id');
      if (kDebugMode) {
        debugPrint(
          '[user_events] upsertManyDeterministic ✓ ${rows.length} rows',
        );
      }
    } on PostgrestException catch (e) {
      _log('upsertManyDeterministic ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('upsertManyDeterministic ✗ $e');
      rethrow;
    }
  }

  /// Stream only the signed-in user's rows (RLS still enforces ownership).
  Stream<List<Map<String, dynamic>>> streamMyEvents() {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.value(const []);
    _log('streamMyEvents(user=${user.id})');
    return _client
        .from(_kTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('starts_at')
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  /// Typed list for a quick sanity read.
  /// ✅ FIXED: Added clientEventId to return type
  Future<
    List<
      ({
        String? id,
        String? clientEventId, // ✅ ADDED THIS LINE
        String title,
        String? detail,
        String? location,
        bool allDay,
        DateTime startsAtUtc,
        DateTime? endsAtUtc,
        int? flowLocalId,
        String? category,
      })
    >
  >
  getAllEvents({int limit = 500}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final rows = await _client
        .from(_kReadableEventsTable)
        .select(_filingReadSelect)
        .order('starts_at', ascending: true)
        .limit(limit);

    final filtered = (rows as List)
        .cast<Map<String, dynamic>>()
        .where((row) {
          final category = (row['category'] as String?)?.trim().toLowerCase();
          if (category == 'tombstone') return false;
          return filingRowIsStandaloneCalendarEvent(row) ||
              filingRowIsFlowCalendarEvent(row);
        })
        .map(
          (row) => (
            id: row['id'] as String?,
            clientEventId:
                row['client_event_id'] as String?, // ✅ ADDED THIS LINE
            title: row['title'] as String,
            detail: row['detail'] as String?,
            location: row['location'] as String?,
            allDay: (row['all_day'] as bool?) ?? false,
            startsAtUtc: DateTime.parse(row['starts_at'] as String),
            endsAtUtc: row['ends_at'] == null
                ? null
                : DateTime.parse(row['ends_at'] as String),
            flowLocalId: canonicalFiledFlowIdForEventRow(row),
            category: row['category'] as String?,
          ),
        )
        .toList();

    return filtered;
  }

  /// Fetch standalone (non-flow) events within a UTC window.
  /// endUtc is treated as an exclusive upper bound.
  Future<List<StandaloneEventRow>> getStandaloneEventsForDateRange({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 10000,
    Map<int, FlowRecordSnapshot> flowOwnersById = const {},
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      var query = _client
          .from(_kReadableEventsTable)
          .select(_flowEventReadSelect)
          .inFilter('item_kind', const ['note', 'reminder'])
          .gte('starts_at', startUtc.toUtc().toIso8601String())
          .lt('starts_at', endUtc.toUtc().toIso8601String())
          .order('starts_at', ascending: true);

      if (limit > 0) {
        query = query.limit(limit);
      }

      final rows = await query;
      _log(
        'getStandaloneEventsForDateRange ✓ ${rows.length} rows '
        '(${startUtc.toUtc().toIso8601String()} → ${endUtc.toUtc().toIso8601String()})',
      );

      final events = rows
          .cast<Map<String, dynamic>>()
          .map((row) {
            if (!filingRowIsStandaloneCalendarEvent(row)) {
              final decision = classifyFlowEvent(
                event: FlowEventSnapshot(
                  flowLocalId: (row['flow_local_id'] as num?)?.toInt(),
                  clientEventId: row['client_event_id'] as String?,
                  detail: row['detail'] as String?,
                  category: row['category'] as String?,
                ),
                flowOwnersById: flowOwnersById,
              );
              if (!decision.isStandaloneVisible) {
                return null;
              }
            }
            return (
              id: row['id'] as String?,
              clientEventId: row['client_event_id'] as String?,
              calendarId: row['calendar_id'] as String?,
              calendarName: row['calendar_name'] as String?,
              calendarColor: (row['calendar_color'] as num?)?.toInt(),
              calendarIsPersonal:
                  (row['calendar_is_personal'] as bool?) ?? true,
              title: (row['title'] as String?) ?? '',
              detail: row['detail'] as String?,
              location: row['location'] as String?,
              allDay: (row['all_day'] as bool?) ?? false,
              startsAtUtc: DateTime.parse(row['starts_at'] as String),
              endsAtUtc: row['ends_at'] == null
                  ? null
                  : DateTime.parse(row['ends_at'] as String),
              flowLocalId: canonicalFiledFlowIdForEventRow(row),
              category: row['category'] as String?,
              isReminder: _normalizedFilingItemKind(row) == 'reminder',
            );
          })
          .whereType<StandaloneEventRow>()
          .toList();

      final birthdayOccurrences = await BirthdayCalendarRepo(
        _client,
      ).getOccurrencesForRange(startUtc: startUtc, endUtc: endUtc);
      events.addAll(
        birthdayOccurrences.map(_standaloneRowFromBirthdayOccurrence),
      );
      events.sort((a, b) {
        final byStart = a.startsAtUtc.compareTo(b.startsAtUtc);
        if (byStart != 0) return byStart;
        return (a.clientEventId ?? a.id ?? '').compareTo(
          b.clientEventId ?? b.id ?? '',
        );
      });
      return events;
    } on PostgrestException catch (e) {
      _log(
        'getStandaloneEventsForDateRange ✗ code=${e.code} message=${e.message} hint=${e.hint} details=${e.details} '
        '(${startUtc.toUtc().toIso8601String()} → ${endUtc.toUtc().toIso8601String()})',
      );
      return const [];
    } catch (e) {
      _log('getStandaloneEventsForDateRange ✗ $e');
      return const [];
    }
  }

  /// Fetch standalone events in a window, paging until exhausted to avoid server caps.
  /// Returns merged unique rows (by id then client_event_id) plus debug counts.
  Future<
    ({
      List<StandaloneEventRow> events,
      List<String> ghostEventIds,
      int pageCount,
      int rawCount,
    })
  >
  getStandaloneEventsForDateRangeAll({
    required DateTime startUtc,
    required DateTime endUtc,
    int pageSize = 1000,
    Map<int, FlowRecordSnapshot> flowOwnersById = const {},
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return (
        events: const <StandaloneEventRow>[],
        ghostEventIds: const <String>[],
        pageCount: 0,
        rawCount: 0,
      );
    }

    final List<Map<String, dynamic>> pages = [];
    int pageCount = 0;
    int offset = 0;

    try {
      while (true) {
        var query = _client
            .from(_kReadableEventsTable)
            .select(_flowEventReadSelect)
            .inFilter('item_kind', const ['note', 'reminder'])
            .gte('starts_at', startUtc.toUtc().toIso8601String())
            .lt('starts_at', endUtc.toUtc().toIso8601String())
            .order('starts_at', ascending: true)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1);

        final rows = await query;
        final pageRows = (rows as List).cast<Map<String, dynamic>>().toList(
          growable: false,
        );
        pageCount++;
        pages.addAll(pageRows);

        if (kDebugMode) {
          _log(
            'getStandaloneEventsForDateRangeAll page=$pageCount rows=${pageRows.length} offset=$offset',
          );
        }

        if (pageRows.length < pageSize) {
          break;
        }
        offset += pageSize;
      }
    } on PostgrestException catch (e) {
      _log(
        'getStandaloneEventsForDateRangeAll ✗ code=${e.code} ${e.message} hint=${e.hint} details=${e.details} '
        '(${startUtc.toUtc().toIso8601String()} → ${endUtc.toUtc().toIso8601String()})',
      );
      return (
        events: const <StandaloneEventRow>[],
        ghostEventIds: const <String>[],
        pageCount: pageCount,
        rawCount: pages.length,
      );
    } catch (e) {
      _log('getStandaloneEventsForDateRangeAll ✗ $e');
      return (
        events: const <StandaloneEventRow>[],
        ghostEventIds: const <String>[],
        pageCount: pageCount,
        rawCount: pages.length,
      );
    }

    final seenIds = <String>{};
    final seenCids = <String>{};
    final List<StandaloneEventRow> events = [];
    final ghostEventIds = <String>[];

    for (final row in pages) {
      final id = row['id'] as String?;
      if (!filingRowIsStandaloneCalendarEvent(row)) {
        final decision = classifyFlowEvent(
          event: FlowEventSnapshot(
            flowLocalId: (row['flow_local_id'] as num?)?.toInt(),
            clientEventId: row['client_event_id'] as String?,
            detail: row['detail'] as String?,
            category: row['category'] as String?,
          ),
          flowOwnersById: flowOwnersById,
        );
        if (decision.shouldPurgeGhostRow && id != null && id.isNotEmpty) {
          ghostEventIds.add(id);
        }
        continue;
      }

      final cid = row['client_event_id'] as String?;

      if (id != null && id.isNotEmpty) {
        if (seenIds.contains(id)) continue;
        seenIds.add(id);
      } else if (cid != null && cid.isNotEmpty) {
        if (seenCids.contains(cid)) continue;
        seenCids.add(cid);
      }

      events.add((
        id: row['id'] as String?,
        clientEventId: row['client_event_id'] as String?,
        calendarId: row['calendar_id'] as String?,
        calendarName: row['calendar_name'] as String?,
        calendarColor: (row['calendar_color'] as num?)?.toInt(),
        calendarIsPersonal: (row['calendar_is_personal'] as bool?) ?? true,
        title: (row['title'] as String?) ?? '',
        detail: row['detail'] as String?,
        location: row['location'] as String?,
        allDay: (row['all_day'] as bool?) ?? false,
        startsAtUtc: DateTime.parse(row['starts_at'] as String),
        endsAtUtc: row['ends_at'] == null
            ? null
            : DateTime.parse(row['ends_at'] as String),
        flowLocalId: canonicalFiledFlowIdForEventRow(row),
        category: row['category'] as String?,
        isReminder: _normalizedFilingItemKind(row) == 'reminder',
      ));
    }

    final birthdayOccurrences = await BirthdayCalendarRepo(
      _client,
    ).getOccurrencesForRange(startUtc: startUtc, endUtc: endUtc);
    for (final occurrence in birthdayOccurrences) {
      final row = _standaloneRowFromBirthdayOccurrence(occurrence);
      final id = row.id;
      final cid = row.clientEventId;
      if (id != null && id.isNotEmpty) {
        if (seenIds.contains(id)) continue;
        seenIds.add(id);
      } else if (cid != null && cid.isNotEmpty) {
        if (seenCids.contains(cid)) continue;
        seenCids.add(cid);
      }
      events.add(row);
    }

    if (birthdayOccurrences.isNotEmpty) {
      events.sort((a, b) {
        final byStart = a.startsAtUtc.compareTo(b.startsAtUtc);
        if (byStart != 0) return byStart;
        return (a.clientEventId ?? a.id ?? '').compareTo(
          b.clientEventId ?? b.id ?? '',
        );
      });
    }

    if (kDebugMode) {
      _log(
        'getStandaloneEventsForDateRangeAll ✓ pages=$pageCount raw=${pages.length} merged=${events.length} ghosts=${ghostEventIds.length}',
      );
    }

    return (
      events: events,
      ghostEventIds: ghostEventIds,
      pageCount: pageCount,
      rawCount: pages.length,
    );
  }

  /// Fetch reminder events by client_event_id prefix. Reminders-only.
  Future<
    List<
      ({
        String? clientEventId,
        String title,
        String? detail,
        String? location,
        bool allDay,
        DateTime startsAtUtc,
        DateTime? endsAtUtc,
        int? flowLocalId,
        String? category,
      })
    >
  >
  getReminderEvents({int limit = 5000}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    var query = _client
        .from(_kTable)
        .select(
          'id,client_event_id,title,detail,location,all_day,starts_at,ends_at,flow_local_id,category',
        )
        .eq('user_id', user.id)
        .like('client_event_id', 'reminder:%')
        .order('starts_at', ascending: true);
    if (limit > 0) {
      query = query.limit(limit);
    }

    final rows = await query;
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      return (
        clientEventId: row['client_event_id'] as String?,
        title: (row['title'] as String?) ?? '',
        detail: row['detail'] as String?,
        location: row['location'] as String?,
        allDay: (row['all_day'] as bool?) ?? false,
        startsAtUtc: DateTime.parse(row['starts_at'] as String),
        endsAtUtc: row['ends_at'] == null
            ? null
            : DateTime.parse(row['ends_at'] as String),
        flowLocalId: (row['flow_local_id'] as num?)?.toInt(),
        category: row['category'] as String?,
      );
    }).toList();
  }

  /// Fetch reminder tombstones (client_event_id starts with reminder:tombstone:).
  Future<Set<String>> getReminderTombstoneIds({int limit = 1000}) async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    var query = _client
        .from(_kTable)
        .select('client_event_id')
        .eq('user_id', user.id)
        .like('client_event_id', 'reminder:tombstone:%')
        .order('starts_at', ascending: true);
    if (limit > 0) {
      query = query.limit(limit);
    }

    final rows = await query;
    final ids = <String>{};
    for (final row in (rows as List)) {
      final cid = (row as Map<String, dynamic>)['client_event_id'] as String?;
      if (cid != null && cid.startsWith('reminder:tombstone:')) {
        final parts = cid.split(':');
        if (parts.length >= 3 && parts[2].isNotEmpty) {
          ids.add(parts[2]);
        }
      }
    }
    return ids;
  }

  /// Fetch events by client_event_id prefix.
  Future<
    List<
      ({
        String? clientEventId,
        String title,
        String? detail,
        String? location,
        bool allDay,
        DateTime startsAtUtc,
        DateTime? endsAtUtc,
        int? flowLocalId,
        String? category,
      })
    >
  >
  getEventsByPrefix(String prefix, {int limit = 2000}) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    var query = _client
        .from(_kTable)
        .select(
          'client_event_id,title,detail,location,all_day,starts_at,ends_at,flow_local_id,category',
        )
        .eq('user_id', user.id)
        .like('client_event_id', '$prefix%')
        .order('starts_at', ascending: true);
    if (limit > 0) {
      query = query.limit(limit);
    }

    final rows = await query;
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      return (
        clientEventId: row['client_event_id'] as String?,
        title: (row['title'] as String?) ?? '',
        detail: row['detail'] as String?,
        location: row['location'] as String?,
        allDay: (row['all_day'] as bool?) ?? false,
        startsAtUtc: DateTime.parse(row['starts_at'] as String),
        endsAtUtc: row['ends_at'] == null
            ? null
            : DateTime.parse(row['ends_at'] as String),
        flowLocalId: (row['flow_local_id'] as num?)?.toInt(),
        category: row['category'] as String?,
      );
    }).toList();
  }

  /// Fetch reminder occurrences by prefix and from-date.
  Future<
    List<
      ({
        String id,
        String? clientEventId,
        String title,
        String? detail,
        String? location,
        bool allDay,
        DateTime startsAtUtc,
        DateTime? endsAtUtc,
        String? calendarId,
        int? flowLocalId,
        String? category,
      })
    >
  >
  getReminderOccurrenceRows(
    String prefix, {
    required DateTime fromUtc,
    int limit = 2000,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      var query = _client
          .from(_kTable)
          .select(
            'id,client_event_id,title,detail,location,all_day,starts_at,ends_at,calendar_id,flow_local_id,category',
          )
          .eq('user_id', user.id)
          .like('client_event_id', '$prefix%')
          .gte('starts_at', fromUtc.toUtc().toIso8601String())
          .order('starts_at', ascending: true);
      if (limit > 0) {
        query = query.limit(limit);
      }
      final rows = await query;
      return (rows as List).cast<Map<String, dynamic>>().map((row) {
        return (
          id: row['id'] as String,
          clientEventId: row['client_event_id'] as String?,
          title: (row['title'] as String?) ?? '',
          detail: row['detail'] as String?,
          location: row['location'] as String?,
          allDay: (row['all_day'] as bool?) ?? false,
          startsAtUtc: DateTime.parse(row['starts_at'] as String),
          endsAtUtc: row['ends_at'] == null
              ? null
              : DateTime.parse(row['ends_at'] as String),
          calendarId: row['calendar_id'] as String?,
          flowLocalId: (row['flow_local_id'] as num?)?.toInt(),
          category: row['category'] as String?,
        );
      }).toList();
    } on PostgrestException catch (e) {
      _log('getReminderOccurrenceRows ✗ ${e.code} ${e.message}');
      return const [];
    } catch (e) {
      _log('getReminderOccurrenceRows ✗ $e');
      return const [];
    }
  }

  /// Fetch events within a start/end window with metadata (updated_at).
  Future<List<UserEvent>> getEventsForWindow({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 1000,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    var query = _client
        .from(_kReadableEventsTable)
        .select(_readSelect)
        .gte('starts_at', startUtc.toUtc().toIso8601String())
        .lte('starts_at', endUtc.toUtc().toIso8601String())
        .order('starts_at', ascending: true);

    if (limit > 0) {
      query = query.limit(limit);
    }

    final rows = await query;
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(UserEvent.fromRow)
        .toList();
  }

  Future<List<FlowEventRow>> getEventsForFlow(
    int flowId, {
    DateTime? startUtc,
    DateTime? endUtc,
    bool flowEventsOnly = false,
  }) async {
    try {
      var query = _client
          .from(_kReadableEventsTable)
          .select(_flowEventReadSelect)
          .eq('filed_flow_id', flowId);

      if (flowEventsOnly) {
        query = query.eq('item_kind', 'flow');
      }

      if (startUtc != null) {
        query = query.gte('starts_at', startUtc.toUtc().toIso8601String());
      }
      if (endUtc != null) {
        query = query.lt('starts_at', endUtc.toUtc().toIso8601String());
      }

      final rows = await query.order('starts_at', ascending: true);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .where(
            (row) =>
                canonicalFiledFlowIdForEventRow(row) == flowId &&
                (!flowEventsOnly || filingRowIsFlowCalendarEvent(row)),
          )
          .map<FlowEventRow>(_flowEventRowFromFilingRow)
          .toList();
    } catch (e, st) {
      if (kDebugMode) {
        // keep this so we can see if anything explodes
        // but don't crash hydration if it fails
        // (this was part of why October 29 felt "bulletproof")
        debugPrint('[UserEventsRepo] getEventsForFlow($flowId) error: $e');
        debugPrint('$st');
      }
      return [];
    }
  }

  Future<List<FlowEventRow>> getEventsForFlowIds(
    Set<int> flowIds, {
    int pageSize = 1000,
    DateTime? startUtc,
    DateTime? endUtc,
  }) async {
    if (flowIds.isEmpty) return const [];
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final ids = flowIds.toList()..sort();
    final events = <FlowEventRow>[];
    int offset = 0;
    int pageCount = 0;

    try {
      while (true) {
        var query = _client
            .from(_kReadableEventsTable)
            .select(_flowEventReadSelect)
            .inFilter('filed_flow_id', ids)
            .eq('item_kind', 'flow');

        if (startUtc != null) {
          query = query.gte('starts_at', startUtc.toUtc().toIso8601String());
        }
        if (endUtc != null) {
          query = query.lt('starts_at', endUtc.toUtc().toIso8601String());
        }

        final rows = await query
            .order('filed_flow_id', ascending: true)
            .order('starts_at', ascending: true)
            .range(offset, offset + pageSize - 1);
        final typedRows = (rows as List).cast<Map<String, dynamic>>();
        final page = typedRows
            .where(filingRowIsFlowCalendarEvent)
            .map<FlowEventRow>(_flowEventRowFromFilingRow)
            .toList();

        events.addAll(page);
        pageCount++;

        if (typedRows.length < pageSize) {
          break;
        }
        offset += pageSize;
      }

      if (kDebugMode) {
        _log(
          'getEventsForFlowIds ✓ flows=${ids.length} events=${events.length} pages=$pageCount',
        );
      }
    } on PostgrestException catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[UserEventsRepo] getEventsForFlowIds error: ${e.code} ${e.message}',
        );
        debugPrint('$st');
      }
      return const [];
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[UserEventsRepo] getEventsForFlowIds error: $e');
        debugPrint('$st');
      }
      return const [];
    }

    return events;
  }

  /// Fetch client_event_id for given row ids (debug/logging helpers).
  Future<List<({String id, String? clientEventId})>> getClientEventIdsByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from(_kTable)
          .select('id,client_event_id')
          .eq('user_id', user.id)
          .inFilter('id', ids);
      return (rows as List).cast<Map<String, dynamic>>().map((row) {
        return (
          id: row['id'] as String,
          clientEventId: row['client_event_id'] as String?,
        );
      }).toList();
    } catch (e, st) {
      _log('getClientEventIdsByIds ✗ $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      return const [];
    }
  }

  /// Minimal event telemetry to `app_events`.
  Future<void> track({
    required String event,
    Map<String, dynamic>? properties,
    String source = 'client',
  }) async {
    if (!telemetryEnabled) return;
    final user = _client.auth.currentUser;
    _log('track("$event")');
    try {
      await _client.from('app_events').insert({
        'user_id': user?.id,
        'email': user?.email,
        'event': event,
        'properties': properties ?? const <String, dynamic>{},
        'source': source,
      });
    } catch (e) {
      _log('track ✗ $e');
      // swallow—telemetry should not block UX
    }
  }

  Future<void> trackShareViewed({
    required String shareId,
    String? source,
  }) async {
    if (shareId.isEmpty) return;
    await track(
      event: 'share_viewed',
      source: 'client',
      properties: {
        'v': kAppEventsSchemaVersion,
        'share_id': shareId,
        if (source != null && source.trim().isNotEmpty) 'source': source.trim(),
      },
    );
  }

  Future<void> trackFlowFeedback({
    required int flowId,
    required List<String> tags,
    int? rating,
    String? shareId,
  }) async {
    if (flowId <= 0) return;
    final filteredTags = tags
        .where(_allowedFeedbackTags.contains)
        .toSet()
        .toList();
    if (filteredTags.isEmpty) return;
    final int? safeRating = rating != null && rating >= 1 && rating <= 5
        ? rating
        : null;

    await track(
      event: 'flow_feedback',
      source: 'client',
      properties: {
        'v': kAppEventsSchemaVersion,
        'flow_id': flowId,
        'tags': filteredTags,
        if (safeRating != null) 'rating': safeRating,
        if (shareId != null && shareId.isNotEmpty) 'share_id': shareId,
      },
    );
  }

  Future<void> trackFlowImported({
    required int flowId,
    required String shareId,
    String? originType,
    int? originFlowId,
    String? scheduledStartIso,
  }) async {
    if (flowId <= 0 || shareId.isEmpty) return;
    await track(
      event: 'flow_imported',
      source: 'client',
      properties: {
        'v': kAppEventsSchemaVersion,
        'flow_id': flowId,
        'share_id': shareId,
        if (originType != null && originType.trim().isNotEmpty)
          'origin_type': originType.trim(),
        if (originFlowId != null && originFlowId > 0)
          'origin_flow_id': originFlowId,
        if (scheduledStartIso != null && scheduledStartIso.isNotEmpty)
          'scheduled_start': scheduledStartIso,
      },
    );
  }

  Future<void> trackFlowImportFailed({
    String? shareId,
    required String error,
  }) async {
    final safeError = error.length > 500 ? error.substring(0, 500) : error;
    await track(
      event: 'flow_import_failed',
      source: 'client',
      properties: {
        'v': kAppEventsSchemaVersion,
        if (shareId != null && shareId.isNotEmpty) 'share_id': shareId,
        'error': safeError,
      },
    );
  }

  /// Record a completion for a flow-backed event via RPC.
  /// completedOnDate should be the local date the event belongs to.
  Future<void> recordEventCompletion({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    String source = 'day_view',
    Map<String, dynamic>? metadata,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final dateStr =
        '${completedOnDate.year}-${completedOnDate.month.toString().padLeft(2, '0')}-${completedOnDate.day.toString().padLeft(2, '0')}';
    await _client.rpc(
      'record_event_completion',
      params: {
        'p_client_event_id': clientEventId,
        'p_flow_id': flowId,
        'p_completed_on': dateStr,
        'p_source': source,
      },
    );
    if (metadata != null && metadata.isNotEmpty) {
      await _client
          .from('user_event_completions')
          .update({'metadata': metadata})
          .eq('user_id', user.id)
          .eq('client_event_id', clientEventId);
      if (_isMaatFlowCompletionMetadata(metadata)) {
        unawaited(_maybeRefreshKnowledgeGraph(user.id));
      }
    }
  }

  /// Undo completion by deleting the row for this client_event_id.
  Future<void> unrecordEventCompletion(String clientEventId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('user_event_completions')
        .delete()
        .eq('user_id', user.id)
        .eq('client_event_id', clientEventId);
    unawaited(_maybeRefreshKnowledgeGraph(user.id));
  }

  bool _isMaatFlowCompletionMetadata(Map<String, dynamic> metadata) {
    final flowKey = metadata['flow_key']?.toString().trim().toLowerCase();
    if (flowKey == 'dawn-house-rite' ||
        flowKey == 'evening-threshold-rite' ||
        flowKey == 'track-the-sky' ||
        flowKey == 'the-weighing' ||
        flowKey == 'the-offering-table' ||
        flowKey == 'the-tending' ||
        flowKey == 'the-kept-word' ||
        flowKey == 'the-course' ||
        flowKey == 'the-moon-return' ||
        flowKey == 'the-wag' ||
        flowKey == 'the-decan-watch' ||
        flowKey == 'the-days-outside-the-year' ||
        flowKey == 'the-open-hand' ||
        flowKey == 'the-djed') {
      return true;
    }
    final graph = metadata['knowledge_graph'];
    if (graph is Map) {
      return graph['version']?.toString() == 'maat_flow_completion_v1';
    }
    return false;
  }

  Future<void> _maybeRefreshKnowledgeGraph(String userId) async {
    if (userId.isEmpty) return;
    if (_graphRefreshInFlightUsers.contains(userId)) {
      _graphRefreshPendingUsers.add(userId);
      return;
    }

    _graphRefreshInFlightUsers.add(userId);
    try {
      do {
        _graphRefreshPendingUsers.remove(userId);
        await _client.functions.invoke(
          'rebuild_personal_graph',
          body: <String, dynamic>{'date_window_days': 90},
        );
      } while (_graphRefreshPendingUsers.contains(userId));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[user_events] graph refresh skipped: $e');
      }
    } finally {
      _graphRefreshPendingUsers.remove(userId);
      _graphRefreshInFlightUsers.remove(userId);
    }
  }

  /// Canonical end-flow path.
  ///
  /// When [deleteAllMaterialized] is false, the RPC prunes the selected
  /// occurrence and every future materialized row while keeping earlier
  /// history intact. When true, it removes every matched materialized row from
  /// the current flow calendar while leaving previously shared, posted, or
  /// saved copies in their own records unchanged.
  Future<
    ({
      int flowId,
      DateTime endedAtUtc,
      String endedOn,
      int deletedEventCount,
      int retiredNotificationCount,
      int deletedCompletionCount,
    })
  >
  endFlow({
    required int flowId,
    required DateTime endedAtLocal,
    bool deleteAllMaterialized = false,
  }) async {
    final response = await _client.rpc(
      'end_flow',
      params: {
        'p_flow_id': flowId,
        'p_ended_at': endedAtLocal.toUtc().toIso8601String(),
        'p_ended_on': _formatDateOnlyLocal(endedAtLocal),
        'p_delete_all_materialized': deleteAllMaterialized,
      },
    );

    Map<String, dynamic>? row;
    if (response is List && response.isNotEmpty && response.first is Map) {
      row = Map<String, dynamic>.from(response.first as Map);
    } else if (response is Map) {
      row = Map<String, dynamic>.from(response);
    }
    if (row == null) {
      throw StateError('end_flow returned no result for flowId=$flowId');
    }

    try {
      await Notify.syncLocalDeliveryMode();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[UserEventsRepo] endFlow notify sync failed: $e');
        debugPrint('$st');
      }
    }

    return (
      flowId: (row['flow_id'] as num?)?.toInt() ?? flowId,
      endedAtUtc:
          DateTime.tryParse(row['ended_at'] as String? ?? '')?.toUtc() ??
          endedAtLocal.toUtc(),
      endedOn: (row['ended_on'] as String?)?.trim().isNotEmpty == true
          ? (row['ended_on'] as String).trim()
          : _formatDateOnlyLocal(endedAtLocal),
      deletedEventCount: (row['deleted_event_count'] as num?)?.toInt() ?? 0,
      retiredNotificationCount:
          (row['retired_notification_count'] as num?)?.toInt() ?? 0,
      deletedCompletionCount:
          (row['deleted_completion_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Upsert a flow (jsonb rules). Returns server id.
  Future<int> upsertFlow({
    int? id,
    required String name,
    required int color,
    required bool active,
    String? calendarId,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    required String rules,
    bool isHidden = false,
    bool? isSaved,
    String? shareId,
    bool? isReminder,
    String? reminderUuid,
    String? originType,
    int? originFlowId,
    String? originShareId,
    String? originGenerationId,
    int? rootFlowId,
    Map<String, dynamic>? aiMetadata,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No user session');
    }

    final payload = <String, dynamic>{
      'user_id': user.id,
      if (calendarId != null) 'calendar_id': calendarId,
      'name': name,
      'color': (color & 0x00FFFFFF), // 24-bit guard
      'active': active,
      'rules': jsonDecode(rules),
      'is_hidden': isHidden,
    };
    if (startDate != null) payload['start_date'] = startDate.toIso8601String();
    if (endDate != null) payload['end_date'] = endDate.toIso8601String();
    if (notes != null) payload['notes'] = notes;
    if (isSaved != null) payload['is_saved'] = isSaved;
    if (_isUuid(shareId)) payload['share_id'] = shareId;
    if (isReminder != null) payload['is_reminder'] = isReminder;
    if (_isUuid(reminderUuid)) payload['reminder_uuid'] = reminderUuid;
    const allowedOriginTypes = {
      'manual',
      'ai',
      'share_import',
      'profile_import',
      'saved_import',
      'fork',
      'template',
    };
    if (originType != null && allowedOriginTypes.contains(originType.trim())) {
      payload['origin_type'] = originType.trim();
    }
    if (originFlowId != null && originFlowId > 0) {
      payload['origin_flow_id'] = originFlowId;
    }
    if (_isUuid(originShareId)) {
      payload['origin_share_id'] = originShareId;
    }
    if (_isUuid(originGenerationId)) {
      payload['origin_generation_id'] = originGenerationId;
    }
    if (rootFlowId != null && rootFlowId > 0) {
      payload['root_flow_id'] = rootFlowId;
    }
    if (aiMetadata != null) {
      payload['ai_metadata'] = aiMetadata;
    }

    try {
      if (id == null || id <= 0) {
        final inserted = await _client
            .from('flows')
            .insert(payload)
            .select('id')
            .single();
        return (inserted['id'] as num).toInt();
      } else {
        final patch = Map<String, dynamic>.from(payload)..remove('user_id');
        final updated = await _client
            .from('flows')
            .update(patch)
            .eq('id', id)
            .select('id')
            .single();
        return (updated['id'] as num).toInt();
      }
    } on PostgrestException catch (e, st) {
      _log('upsertFlow ✗ ${e.code} ${e.message}');
      _log('$st');
      rethrow;
    } catch (e, st) {
      _log('upsertFlow ✗ $e');
      _log('$st');
      rethrow;
    }
  }

  Future<void> flowCommit({
    required String generationId,
    required int flowId,
  }) async {
    if (!_isUuid(generationId)) {
      return;
    }
    try {
      await _client.rpc(
        'flow_commit',
        params: {'p_generation_id': generationId, 'p_flow_id': flowId},
      );
      _log('flow_commit ✓ gen=$generationId flow=$flowId');
    } on PostgrestException catch (e, st) {
      _log('flow_commit ✗ ${e.code} ${e.message}');
      _log('$st');
      rethrow;
    } catch (e, st) {
      _log('flow_commit ✗ $e');
      _log('$st');
      rethrow;
    }
  }

  /// Fetch all flows for the signed-in user.
  Future<
    List<
      ({
        int id,
        String? userId,
        String? calendarId,
        String name,
        int color,
        bool active,
        bool isSaved,
        DateTime? savedAt,
        DateTime? startDate,
        DateTime? endDate,
        String? notes,
        String rules,
        String? shareId, // NEW: Include shareId
        bool isHidden,
        bool isReminder,
        String? reminderUuid,
      })
    >
  >
  getAllFlows() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final res = await _client
        .from('flows_with_calendars')
        .select()
        .order('created_at', ascending: false);

    final rows = (res as List).cast<Map<String, dynamic>>();
    final savedAtByFlowId = await getSavedFlowTimestamps(
      flowIds: rows
          .where((row) => (row['is_saved'] as bool?) ?? false)
          .map((row) => (row['id'] as num).toInt()),
    );

    return rows.map((row) {
      final flowId = (row['id'] as num).toInt();
      final isSaved = (row['is_saved'] as bool?) ?? false;
      final savedAt =
          savedAtByFlowId[flowId] ??
          (isSaved
              ? (_parseOptionalDateTime(row['updated_at']) ??
                    _parseOptionalDateTime(row['created_at']))
              : null);
      return (
        id: flowId,
        userId: row['user_id'] as String?,
        calendarId: row['calendar_id'] as String?,
        name: row['name'] as String,
        color: (row['color'] as num).toInt(),
        active: row['active'] as bool,
        isSaved: isSaved,
        savedAt: savedAt,
        startDate: row['start_date'] == null
            ? null
            : DateTime.parse(row['start_date'] as String),
        endDate: row['end_date'] == null
            ? null
            : DateTime.parse(row['end_date'] as String),
        notes: row['notes'] as String?,
        rules: jsonEncode(row['rules']),
        shareId: row['share_id'] as String?, // NEW: Include share_id
        isHidden: (row['is_hidden'] as bool?) ?? false,
        isReminder: (row['is_reminder'] as bool?) ?? false,
        reminderUuid: row['reminder_uuid'] as String?,
      );
    }).toList();
  }

  Future<Map<int, DateTime>> getSavedFlowTimestamps({
    required Iterable<int> flowIds,
  }) async {
    final user = _client.auth.currentUser;
    final ids = flowIds.toSet().toList(growable: false);
    if (user == null || ids.isEmpty) return const {};

    final rows =
        await _client
                .from('flow_saves')
                .select('flow_id, saved_at')
                .eq('user_id', user.id)
                .inFilter('flow_id', ids)
            as List<dynamic>;

    final byFlowId = <int, DateTime>{};
    for (final raw in rows.cast<Map<String, dynamic>>()) {
      final flowId = (raw['flow_id'] as num?)?.toInt();
      final savedAt = _parseOptionalDateTime(raw['saved_at']);
      if (flowId == null || savedAt == null) continue;
      byFlowId[flowId] = savedAt;
    }
    return byFlowId;
  }

  /// Delete a single flow row.
  Future<void> deleteFlow(int flowId) async {
    _log('deleteFlow($flowId)');
    try {
      // Canonical delete path: purge linked event rows before the flow is
      // soft-deleted so local notification cleanup does not rely solely on the
      // backend trigger.
      await deleteByFlowId(flowId);

      final row = await _client
          .from('flows')
          .select('id, is_saved')
          .eq('id', flowId)
          .maybeSingle();
      final isSaved = (row?['is_saved'] as bool?) ?? false;

      // Soft delete: hide and deactivate even for saved flows so they disappear from UI.
      // Saved flows intentionally keep their row; the UI uses is_hidden/active to filter.
      await _client
          .from('flows')
          .update({'is_hidden': true, 'active': false})
          .eq('id', flowId);
      _log('deleteFlow ✓ (soft${isSaved ? ', saved flow' : ''})');
    } on PostgrestException catch (e) {
      _log('deleteFlow ✗ ${e.code} ${e.message}');
      rethrow;
    }
  }

  /// Update flow with share_id reference (for re-import tracking)
  Future<void> updateFlowShareId({
    required int flowId,
    required String shareId,
  }) async {
    try {
      await _client
          .from('flows')
          .update({'share_id': shareId})
          .eq('id', flowId);

      if (kDebugMode) {
        debugPrint(
          '[UserEventsRepo] Updated flow $flowId with share_id: $shareId',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UserEventsRepo] Error updating flow share_id: $e');
      }
      rethrow;
    }
  }

  /// Toggle saved flag for a flow.
  Future<void> setFlowSaved({
    required int flowId,
    required bool isSaved,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No user session. Please sign in.');
    }

    try {
      final updated = await _client
          .from('flows')
          .update({'is_saved': isSaved})
          .eq('id', flowId)
          .select('id, is_saved, active, updated_at')
          .single();

      if (isSaved) {
        await _client.from('flow_saves').upsert({
          'user_id': user.id,
          'flow_id': flowId,
          'saved_from': 'self',
          'saved_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,flow_id');
      } else {
        await _client
            .from('flow_saves')
            .delete()
            .eq('user_id', user.id)
            .eq('flow_id', flowId);
      }

      if (kDebugMode) {
        debugPrint('[UserEventsRepo] setFlowSaved DB row: $updated');
      }
    } on PostgrestException catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[UserEventsRepo] setFlowSaved FAILED: ${e.code} ${e.message} ${e.details}',
        );
        debugPrint('$st');
      }
      rethrow;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[UserEventsRepo] setFlowSaved FAILED: $e');
        debugPrint('$st');
      }
      rethrow;
    }
  }

  /// Get an imported flow for a share.
  ///
  /// Older Inbox imports linked `flows.share_id`. Route-backed Flow Studio
  /// imports preserve lineage with `flows.origin_share_id`, so both columns are
  /// valid import-status markers for a share.
  Future<int?> getFlowIdByShareId(String shareId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null || !_isUuid(shareId)) return null;
      final response = await _client
          .from('flows')
          .select('id, active, is_saved, created_at')
          .eq('user_id', user.id)
          .or('share_id.eq.$shareId,origin_share_id.eq.$shareId')
          .order('active', ascending: false)
          .order('is_saved', ascending: false)
          .order('created_at', ascending: false)
          .limit(1);

      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return null;
      return (rows.first['id'] as num?)?.toInt();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UserEventsRepo] Error getting flow by share_id: $e');
      }
      return null;
    }
  }
}
