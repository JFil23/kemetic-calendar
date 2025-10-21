// lib/data/user_events_repo.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kTable = 'user_events';

void _log(String msg) {
  if (kDebugMode) debugPrint('[user_events] $msg');
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

  const UserEvent({
    required this.id,
    this.clientEventId,
    required this.title,
    this.detail,
    this.location,
    required this.allDay,
    required this.startsAt,
    this.endsAt,
  });

  factory UserEvent.fromRow(Map<String, dynamic> row) {
    DateTime _parseTs(dynamic v) =>
        v == null ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) : DateTime.parse(v as String);

    return UserEvent(
      id: row['id'] as String,
      clientEventId: row['client_event_id'] as String?,
      title: row['title'] as String,
      detail: row['detail'] as String?,
      location: row['location'] as String?,
      allDay: (row['all_day'] as bool?) ?? false,
      startsAt: _parseTs(row['starts_at']).toUtc(),
      endsAt: row['ends_at'] == null ? null : DateTime.parse(row['ends_at'] as String).toUtc(),
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
    };
  }
}

class UserEventsRepo {
  UserEventsRepo(this._client);
  final SupabaseClient _client;

  /// Insert (new server id returned).
  Future<UserEvent> addEvent({
    required String title,
    required DateTime startsAtUtc,
    String? detail,
    String? location,
    bool allDay = false,
    String? clientEventId,
    DateTime? endsAtUtc,
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
    };

    _log('insert → $payload');
    try {
      final row = await _client.from(_kTable).insert(payload).select().single();
      _log('insert ✓ id=${row['id']}');
      return UserEvent.fromRow(row as Map<String, dynamic>);
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
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No user session. Please sign in.');

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
    };

    _log('upsert(client_event_id=$clientEventId) → $payload');
    try {
      final row = await _client
          .from(_kTable)
      // ⬇️ match the DB: unique(user_id, client_event_id)
          .upsert(payload, onConflict: 'user_id,client_event_id')
          .select()
          .single();
      _log('upsert ✓ id=${row['id']}');
      return UserEvent.fromRow(row as Map<String, dynamic>);
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
    String? title,
    String? detail,
    String? location,
    bool? allDay,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (detail != null) patch['detail'] = detail;
    if (location != null) patch['location'] = location;
    if (allDay != null) patch['all_day'] = allDay;
    if (startsAt != null) patch['starts_at'] = startsAt.toUtc().toIso8601String();
    if (endsAt != null) patch['ends_at'] = endsAt.toUtc().toIso8601String();
    if (patch.isEmpty) throw ArgumentError('Nothing to update.');

    _log('update($id) → $patch');
    try {
      final row = await _client.from(_kTable).update(patch).eq('id', id).select().single();
      _log('update ✓ id=$id');
      return UserEvent.fromRow(row as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      _log('update ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('update ✗ $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    _log('delete($id)');
    try {
      await _client.from(_kTable).delete().eq('id', id);
      _log('delete ✓');
    } on PostgrestException catch (e) {
      _log('delete ✗ ${e.code} ${e.message}');
      rethrow;
    }
  }

  Future<void> deleteByClientId(String clientEventId) async {
    _log('deleteByClientId($clientEventId)');
    try {
      await _client.from(_kTable).delete().eq('client_event_id', clientEventId);
      _log('deleteByClientId ✓');
    } on PostgrestException catch (e) {
      _log('deleteByClientId ✗ ${e.code} ${e.message}');
      rethrow;
    }
  }

  /// Delete Ma'at-generated events by flow id. Optionally from a given date forward.
  Future<void> deleteByFlowId(int flowId, {DateTime? fromDate}) async {
    _log('deleteByFlowId(flowId=$flowId, fromDate=$fromDate)');
    try {
      // 1) delete events explicitly tagged with flow_local_id
      var q1 = _client.from(_kTable).delete().eq('flow_local_id', flowId);
      if (fromDate != null) {
        q1 = q1.gte('starts_at', fromDate.toUtc().toIso8601String());
      }
      await q1;

      // 2) also delete Ma'at-generated events in the flow's date window (handles legacy rows with no flow_local_id)
      DateTime? startDate;
      DateTime? endDateInclusive; // end date as stored (date at 00:00)
      final rows = await _client
          .from('flows')
          .select('start_date,end_date')
          .eq('id', flowId)
          .limit(1);
      if (rows is List && rows.isNotEmpty) {
        final row = rows.first as Map<String, dynamic>;
        startDate = row['start_date'] == null ? null : DateTime.parse(row['start_date'] as String).toUtc();
        endDateInclusive = row['end_date'] == null ? null : DateTime.parse(row['end_date'] as String).toUtc();
      }

      // Build a half-open time window: [windowStart, windowEndExclusive)
      // so the entire last day is *included* even if your events are at 16:00 UTC.
      final windowStart = (fromDate ?? startDate)?.toUtc();
      final windowEndExclusive = endDateInclusive == null
          ? null
          : endDateInclusive.toUtc().add(const Duration(days: 1)); // next day at 00:00Z

      final user = _client.auth.currentUser;
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
      await _client.from(_kTable).upsert(rows, onConflict: 'user_id,client_event_id');
      if (kDebugMode) {
        debugPrint('[user_events] upsertManyDeterministic ✓ ${rows.length} rows');
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
  Future<List<({
  String? clientEventId,  // ✅ ADDED THIS LINE
  String title,
  String? detail,
  String? location,
  bool allDay,
  DateTime startsAtUtc,
  DateTime? endsAtUtc,
  int? flowLocalId,
  })>> getAllEvents({int limit = 500}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final rows = await _client
        .from(_kTable)
        .select('id,client_event_id,title,detail,location,all_day,starts_at,ends_at,flow_local_id,flows!left(id,active,end_date)')
        .eq('user_id', user.id)
        .order('starts_at', ascending: true)
        .limit(limit);

    final filtered = (rows as List).cast<Map<String, dynamic>>().where((row) {
      final int? fid = (row['flow_local_id'] as num?)?.toInt();
      if (fid == null) return true; // keep unassigned notes
      final Map<String, dynamic>? flow = row['flows'] as Map<String, dynamic>?;
      if (flow == null) return false; // hidden/missing flow
      final bool active = (flow['active'] as bool?) ?? false;
      final bool ended = flow['end_date'] != null;
      return active && !ended; // only active + not-ended flows
    }).map((row) => (
    clientEventId: row['client_event_id'] as String?,  // ✅ ADDED THIS LINE
    title: row['title'] as String,
    detail: row['detail'] as String?,
    location: row['location'] as String?,
    allDay: (row['all_day'] as bool?) ?? false,
    startsAtUtc: DateTime.parse(row['starts_at'] as String),
    endsAtUtc: row['ends_at'] == null ? null : DateTime.parse(row['ends_at'] as String),
    flowLocalId: (row['flow_local_id'] as num?)?.toInt(),
    )).toList();

    return filtered;
  }

  /// Minimal event telemetry to `app_events`.
  Future<void> track({
    required String event,
    Map<String, dynamic>? properties,
    String source = 'client',
  }) async {
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
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No user session');

    final payload = {
      'user_id': user.id,
      'name': name,
      'color': color,
      'active': active,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
      'rules': jsonDecode(rules),
    };

    if (id != null && id > 0) {
      payload['id'] = id;
    }

    _log('upsertFlow → $payload');
    final result = await _client.from('flows').upsert(payload).select().single();
    final savedId = (result['id'] as num).toInt();
    _log('upsertFlow ✓ id=$savedId');
    return savedId;
  }

  /// Fetch all flows for the signed-in user.
  Future<List<({
  int id,
  String name,
  int color,
  bool active,
  DateTime? startDate,
  DateTime? endDate,
  String? notes,
  String rules,
  String? shareId, // NEW: Include shareId
  })>> getAllFlows() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final res = await _client
        .from('flows')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (res as List).map((row) => (
    id: (row['id'] as num).toInt(),
    name: row['name'] as String,
    color: (row['color'] as num).toInt(),
    active: row['active'] as bool,
    startDate: row['start_date'] == null ? null : DateTime.parse(row['start_date'] as String),
    endDate: row['end_date'] == null ? null : DateTime.parse(row['end_date'] as String),
    notes: row['notes'] as String?,
    rules: jsonEncode(row['rules']),
    shareId: row['share_id'] as String?, // NEW: Include share_id
    )).toList();
  }

  /// Delete a single flow row.
  Future<void> deleteFlow(int flowId) async {
    _log('deleteFlow($flowId)');
    try {
      await _client.from('flows').delete().eq('id', flowId);
      _log('deleteFlow ✓');
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
        print('[UserEventsRepo] Updated flow $flowId with share_id: $shareId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[UserEventsRepo] Error updating flow share_id: $e');
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
        print('[UserEventsRepo] Error getting flow by share_id: $e');
      }
      return null;
    }
  }
}