// lib/data/user_events_repo.dart
import 'dart:async';
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
    // Supabase returns ISO strings for timestamptz in Flutter
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
      'user_id': userId, // RLS guard + explicit ownership
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

  /// Create or update by client_event_id (safe to call repeatedly).
  Future<UserEvent> upsertByClientId({
    required String clientEventId,
    required String title,
    required DateTime startsAtUtc,
    String? detail,
    String? location,
    bool allDay = false,
    DateTime? endsAtUtc,
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
    };

    // Uses the unique constraint on client_event_id
    _log('upsert(client_event_id=$clientEventId) → $payload');
    try {
      final row = await _client
          .from(_kTable)
          .upsert(payload, onConflict: 'client_event_id') // idempotent
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

  Future<void> deleteByFlowId(int flowId) async {
    _log('deleteByFlowId(flowId=$flowId)');
    try {
      await _client.from(_kTable).delete().like('client_event_id', 'maat:%:$flowId:%');
      _log('deleteByFlowId ✓');
    } on PostgrestException catch (e) {
      _log('deleteByFlowId ✗ ${e.code} ${e.message}');
      rethrow;
    }
  }
  Future<void> insertMany(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await _client.from(_kTable).insert(rows);
      if (kDebugMode) {
        debugPrint('[user_events] insertMany ✓ ${rows.length} rows');
      }
    } on PostgrestException catch (e) {
      _log('insertMany ✗ ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      _log('insertMany ✗ $e');
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
  Future<List<UserEvent>> listTyped({int limit = 200}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No user session. Please sign in.');
    final rows = await _client
        .from(_kTable)
        .select()
        .eq('user_id', user.id)
        .order('starts_at')
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map(UserEvent.fromRow).toList();
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
        'user_id': user?.id, // trigger will backfill from JWT if omitted
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
}
