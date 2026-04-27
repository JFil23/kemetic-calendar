// lib/data/user_events_repo.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/calendar/notify.dart';
import '../telemetry/telemetry.dart';

const _kTable = 'user_events';

void _log(String msg) {
  if (kDebugMode) debugPrint('[user_events] $msg');
}

typedef FlowEventRow = ({
  String? id,
  String? clientEventId,
  String title,
  String? detail,
  String? location,
  bool allDay,
  DateTime startsAtUtc,
  DateTime? endsAtUtc,
  int? flowLocalId,
  String? category,
});

bool _isUuid(String? v) {
  if (v == null) return false;
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(v);
}

@immutable
class UserEvent {
  final String id;
  final String? clientEventId;
  final String title;
  final String? detail;
  final String? location;
  final bool allDay;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? flowLocalId;
  final String? category;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  const UserEvent({
    required this.id,
    this.clientEventId,
    required this.title,
    this.detail,
    this.location,
    required this.allDay,
    required this.startsAt,
    this.endsAt,
    this.flowLocalId,
    this.category,
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
      'title': title,
      'detail': detail,
      'location': location,
      'all_day': allDay,
      'starts_at': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'ends_at': endsAt!.toUtc().toIso8601String(),
      if (category != null) 'category': category,
    };
  }

  Map<String, dynamic> toPatch() {
    return {
      if (clientEventId != null) 'client_event_id': clientEventId,
      'title': title,
      'detail': detail,
      'location': location,
      'all_day': allDay,
      'starts_at': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'ends_at': endsAt!.toUtc().toIso8601String(),
      if (category != null) 'category': category,
    };
  }
}

class UserEventsRepo {
  UserEventsRepo(this._client);
  final SupabaseClient _client;
  static bool? _telemetryEnabled;

  bool get telemetryEnabled => _telemetryEnabled ?? true;

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
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No user session. Please sign in.');

    final payload = <String, dynamic>{
      'user_id': user.id,
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
      'title': title,
      'detail': detail,
      'location': location,
      'all_day': allDay,
      'starts_at': startsAtUtc.toIso8601String(),
      if (endsAtUtc != null) 'ends_at': endsAtUtc.toIso8601String(),
      if (flowLocalId != null) 'flow_local_id': flowLocalId,
      if (category != null) 'category': category,
    };

    final callerTag = caller == null || caller.isEmpty ? 'unspecified' : caller;
    _log('upsert(client_event_id=$clientEventId caller=$callerTag) → $payload');
    try {
      final row = await _client
          .from(_kTable)
          // ⬇️ match the DB: unique(user_id, client_event_id)
          .upsert(payload, onConflict: 'user_id,client_event_id')
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
    String? title,
    String? detail,
    String? location,
    bool? allDay,
    DateTime? startsAt,
    DateTime? endsAt,
    String? category,
  }) async {
    final patch = <String, dynamic>{};
    if (clientEventId != null) patch['client_event_id'] = clientEventId;
    if (title != null) patch['title'] = title;
    if (detail != null) patch['detail'] = detail;
    if (location != null) patch['location'] = location;
    if (allDay != null) patch['all_day'] = allDay;
    if (startsAt != null) {
      patch['starts_at'] = startsAt.toUtc().toIso8601String();
    }
    if (endsAt != null) patch['ends_at'] = endsAt.toUtc().toIso8601String();
    if (category != null) patch['category'] = category;
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
          .from(_kTable)
          .select()
          .eq('user_id', user.id)
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
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final row = await _client
            .from(_kTable)
            .select('client_event_id')
            .eq('user_id', user.id)
            .eq('id', id)
            .maybeSingle();
        cidForLog = (row?['client_event_id'] as String?);
      }
    } catch (_) {}
    _log('delete($id) cid=${cidForLog ?? 'unknown'}');
    try {
      final deleted = await _client
          .from(_kTable)
          .delete()
          .eq('id', id)
          .select('flow_local_id')
          .maybeSingle();

      _log('delete ✓');

      final flowId = (deleted?['flow_local_id'] as num?)?.toInt();
      if (flowId != null && flowId > 0) {
        unawaited(
          track(
            event: 'event_deleted',
            properties: {
              'flow_id': flowId,
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

  Future<void> deleteByClientId(String clientEventId) async {
    _log('deleteByClientId($clientEventId)');
    try {
      await Notify.cancelNotificationsForClientEventIds([clientEventId]);

      final deletedRows = await _client
          .from(_kTable)
          .delete()
          .eq('client_event_id', clientEventId)
          .select('id, flow_local_id');

      final rows = deletedRows.cast<Map<String, dynamic>>();
      if (rows.isEmpty) {
        _log('deleteByClientId ⚠️ no rows for cid=$clientEventId');
        return;
      }

      final deletedId = rows.first['id'] as String?;
      final flowId = (rows.first['flow_local_id'] as num?)?.toInt();
      _log(
        'deleteByClientId ✓ id=${deletedId ?? 'unknown'} cid=$clientEventId',
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
        return;
      }
      _log('deleteByClientId ✗ ${e.code} ${e.message}');
      rethrow;
    }
  }

  /// Delete events by client_event_id prefix (e.g., 'nutrition:item-id:').
  /// Useful for bulk deletion of related events.
  Future<void> deleteByClientIdPrefix(
    String prefix, {
    DateTime? fromUtc,
  }) async {
    _log('deleteByClientIdPrefix($prefix, fromUtc=$fromUtc)');
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

      var query = _client
          .from(_kTable)
          .delete()
          .eq('user_id', user.id)
          .like('client_event_id', '$prefix%');
      if (fromUtc != null) {
        query = query.gte('starts_at', fromUtc.toUtc().toIso8601String());
      }

      await query;

      _log('deleteByClientIdPrefix ✓');
    } on PostgrestException catch (e) {
      _log('deleteByClientIdPrefix ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('deleteByClientIdPrefix ✗ $e');
      rethrow;
    }
  }

  /// Delete events by a list of row ids (scoped to current user).
  Future<void> deleteByIds(List<String> ids) async {
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
      await _client
          .from(_kTable)
          .delete()
          .eq('user_id', user.id)
          .inFilter('id', ids);
      _log('deleteByIds ✓');
    } on PostgrestException catch (e) {
      _log('deleteByIds ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('deleteByIds ✗ $e');
      rethrow;
    }
  }

  /// Delete Ma'at-generated events by flow id. Optionally from a given date forward.
  Future<void> deleteByFlowId(int flowId, {DateTime? fromDate}) async {
    _log('deleteByFlowId(flowId=$flowId, fromDate=$fromDate)');
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
      var q1 = _client.from(_kTable).delete().eq('flow_local_id', flowId);
      if (fromDate != null) {
        q1 = q1.gte('starts_at', fromDate.toUtc().toIso8601String());
      }
      await q1;

      // 2) also delete Ma'at-generated events in the flow's date window (handles legacy rows with no flow_local_id)
      if (user != null && (windowStart != null || windowEndExclusive != null)) {
        var q2 = _client
            .from(_kTable)
            .delete()
            .eq('user_id', user.id)
            .like('client_event_id', 'maat:%');
        if (windowStart != null) {
          q2 = q2.gte('starts_at', windowStart.toIso8601String());
        }
        if (windowEndExclusive != null) {
          q2 = q2.lt('starts_at', windowEndExclusive.toIso8601String());
        }
        await q2;
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
        .from(_kTable)
        .select(
          'id,client_event_id,title,detail,location,all_day,starts_at,ends_at,flow_local_id,category,flows!left(id,active,end_date)',
        )
        .eq('user_id', user.id)
        .order('starts_at', ascending: true)
        .limit(limit);

    final filtered = (rows as List)
        .cast<Map<String, dynamic>>()
        .where((row) {
          final int? fid = (row['flow_local_id'] as num?)?.toInt();

          // Standalone events (no flow) are fine
          if (fid == null) return true;

          // 🚫 Orphaned event: has flow_local_id but no flow row (flow was deleted)
          final Map<String, dynamic>? flow =
              row['flows'] as Map<String, dynamic>?;
          if (flow == null) {
            // Orphaned event - skip it
            return false;
          }

          // If there's a flow, it must be active
          final bool active = (flow['active'] as bool?) ?? false;
          if (!active) {
            // Flow exists but is inactive - skip it
            return false;
          }

          // Treat flows as "ended" ONLY if their end_date is in the past.
          // If end_date is in the future (or today), we still want to see them on the calendar.
          final String? endDateStr = flow['end_date'] as String?;
          bool expired = false;
          if (endDateStr != null) {
            final endDate = DateTime.parse(endDateStr).toUtc();
            final now = DateTime.now().toUtc();
            expired = endDate.isBefore(now);
          }

          return !expired; // Only return true if flow is active AND not expired
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
            flowLocalId: (row['flow_local_id'] as num?)?.toInt(),
            category: row['category'] as String?,
          ),
        )
        .toList();

    return filtered;
  }

  /// Fetch standalone (non-flow) events within a UTC window.
  /// endUtc is treated as an exclusive upper bound.
  Future<
    List<
      ({
        String? id,
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
  getStandaloneEventsForDateRange({
    required DateTime startUtc,
    required DateTime endUtc,
    int limit = 10000,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      var query = _client
          .from(_kTable)
          .select(
            'id,client_event_id,title,detail,location,all_day,starts_at,ends_at,flow_local_id,category',
          )
          .eq('user_id', user.id)
          .isFilter('flow_local_id', null)
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

      return rows.cast<Map<String, dynamic>>().map((row) {
        return (
          id: row['id'] as String?,
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
      List<
        ({
          String? id,
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
      events,
      int pageCount,
      int rawCount,
    })
  >
  getStandaloneEventsForDateRangeAll({
    required DateTime startUtc,
    required DateTime endUtc,
    int pageSize = 1000,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return (
        events:
            <
              ({
                String? id,
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
            >[],
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
            .from(_kTable)
            .select(
              'id,client_event_id,title,detail,location,all_day,starts_at,ends_at,flow_local_id,category',
            )
            .eq('user_id', user.id)
            .isFilter('flow_local_id', null)
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
        events:
            <
              ({
                String? id,
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
            >[],
        pageCount: pageCount,
        rawCount: pages.length,
      );
    } catch (e) {
      _log('getStandaloneEventsForDateRangeAll ✗ $e');
      return (
        events:
            <
              ({
                String? id,
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
            >[],
        pageCount: pageCount,
        rawCount: pages.length,
      );
    }

    final seenIds = <String>{};
    final seenCids = <String>{};
    final List<
      ({
        String? id,
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
    events = [];

    for (final row in pages) {
      final id = row['id'] as String?;
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
      ));
    }

    if (kDebugMode) {
      _log(
        'getStandaloneEventsForDateRangeAll ✓ pages=$pageCount raw=${pages.length} merged=${events.length}',
      );
    }

    return (events: events, pageCount: pageCount, rawCount: pages.length);
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

  /// Fetch reminder occurrences by prefix and from-date (includes id + detail for override detection).
  Future<
    List<
      ({String id, String? clientEventId, String? detail, DateTime startsAtUtc})
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
          .select('id,client_event_id,detail,starts_at')
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
          detail: row['detail'] as String?,
          startsAtUtc: DateTime.parse(row['starts_at'] as String),
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
        .from(_kTable)
        .select(
          'id,client_event_id,title,detail,location,all_day,starts_at,ends_at,flow_local_id,category,updated_at,created_at',
        )
        .eq('user_id', user.id)
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
  }) async {
    try {
      var query = _client
          .from('user_events')
          .select('''
            id,
            client_event_id,
            title,
            detail,
            location,
            all_day,
            starts_at,
            ends_at,
            flow_local_id,
            category
          ''')
          .eq('flow_local_id', flowId);

      if (startUtc != null) {
        query = query.gte('starts_at', startUtc.toUtc().toIso8601String());
      }
      if (endUtc != null) {
        query = query.lt('starts_at', endUtc.toUtc().toIso8601String());
      }

      final rows = await query.order('starts_at', ascending: true);

      return (rows as List).map<FlowEventRow>((row) {
        return (
          id: row['id'] as String?,
          clientEventId: row['client_event_id'] as String?,
          title: (row['title'] as String?) ?? '',
          detail: row['detail'] as String?,
          location: row['location'] as String?,
          allDay: (row['all_day'] as bool?) ?? false,
          startsAtUtc: DateTime.parse(row['starts_at'] as String).toUtc(),
          endsAtUtc: row['ends_at'] != null
              ? DateTime.parse(row['ends_at'] as String).toUtc()
              : null,
          flowLocalId: (row['flow_local_id'] as num?)?.toInt(),
          category: row['category'] as String?,
        );
      }).toList();
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
            .from('user_events')
            .select(
              'id,client_event_id,title,detail,location,all_day,starts_at,ends_at,flow_local_id,category',
            )
            .eq('user_id', user.id)
            .inFilter('flow_local_id', ids);

        if (startUtc != null) {
          query = query.gte('starts_at', startUtc.toUtc().toIso8601String());
        }
        if (endUtc != null) {
          query = query.lt('starts_at', endUtc.toUtc().toIso8601String());
        }

        final rows = await query
            .order('flow_local_id', ascending: true)
            .order('starts_at', ascending: true)
            .range(offset, offset + pageSize - 1);
        final page = (rows as List).map<FlowEventRow>((row) {
          return (
            id: row['id'] as String?,
            clientEventId: row['client_event_id'] as String?,
            title: (row['title'] as String?) ?? '',
            detail: row['detail'] as String?,
            location: row['location'] as String?,
            allDay: (row['all_day'] as bool?) ?? false,
            startsAtUtc: DateTime.parse(row['starts_at'] as String).toUtc(),
            endsAtUtc: row['ends_at'] != null
                ? DateTime.parse(row['ends_at'] as String).toUtc()
                : null,
            flowLocalId: (row['flow_local_id'] as num?)?.toInt(),
            category: row['category'] as String?,
          );
        }).toList();

        events.addAll(page);
        pageCount++;

        if (page.length < pageSize) {
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
  }

  /// Upsert a flow (jsonb rules). Returns server id.
  Future<int> upsertFlow({
    int? id,
    required String name,
    required int color,
    required bool active,
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
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No user session');
    }

    final payload = <String, dynamic>{
      'user_id': user.id,
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
        String name,
        int color,
        bool active,
        bool isSaved,
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
        .from('flows')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (res as List)
        .map(
          (row) => (
            id: (row['id'] as num).toInt(),
            name: row['name'] as String,
            color: (row['color'] as num).toInt(),
            active: row['active'] as bool,
            isSaved: (row['is_saved'] as bool?) ?? false,
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
          ),
        )
        .toList();
  }

  /// Delete a single flow row.
  Future<void> deleteFlow(int flowId) async {
    _log('deleteFlow($flowId)');
    try {
      try {
        final events = await getEventsForFlow(flowId);
        final cidsToCancel = events
            .map((event) => event.clientEventId)
            .whereType<String>()
            .where((cid) => cid.trim().isNotEmpty)
            .toSet();
        if (cidsToCancel.isNotEmpty) {
          await Notify.cancelNotificationsForClientEventIds(cidsToCancel);
        }
      } catch (_) {
        // Flow delete should still proceed if notification cleanup misses.
      }

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
    try {
      final updated = await _client
          .from('flows')
          .update({'is_saved': isSaved})
          .eq('id', flowId)
          .select('id, is_saved, active, updated_at')
          .single();
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

  /// Get flow by share_id
  Future<int?> getFlowIdByShareId(String shareId) async {
    try {
      final response = await _client
          .from('flows')
          .select('id')
          .eq('share_id', shareId)
          .maybeSingle();

      return response?['id'] as int?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UserEventsRepo] Error getting flow by share_id: $e');
      }
      return null;
    }
  }
}
