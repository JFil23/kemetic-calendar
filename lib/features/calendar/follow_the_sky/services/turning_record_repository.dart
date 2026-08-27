import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/turning_record.dart';

class TurningRecordSaveResult {
  const TurningRecordSaveResult({
    required this.record,
    required this.cloudSynced,
  });

  final TurningRecord record;
  final bool cloudSynced;
}

class TurningRecordRepository {
  TurningRecordRepository(this._client, {SharedPreferences? preferences})
    : _preferences = preferences;

  static const String table = 'follow_sky_turning_records';
  static const String _localPrefix = 'follow_sky:turning_record:v1:';
  static const String _pendingPrefix = 'follow_sky:turning_pending:v1:';
  final SupabaseClient _client;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  String _localKey(String clientEventId) =>
      '$_localPrefix${Uri.encodeComponent(clientEventId)}';

  String _pendingKey(String clientEventId) =>
      '$_pendingPrefix${Uri.encodeComponent(clientEventId)}';

  Future<TurningRecord?> load(String clientEventId) async {
    final local = await _loadLocal(clientEventId);
    final user = _client.auth.currentUser;
    if (user == null) return local;
    if (local != null && await isPendingSync(clientEventId)) {
      final retried = await _saveWithStatus(local, user.id);
      if (retried.cloudSynced) return retried.record;
      return local;
    }
    try {
      final row = await _client
          .from(table)
          .select()
          .eq('user_id', user.id)
          .eq('client_event_id', clientEventId)
          .maybeSingle();
      if (row == null && local != null) {
        await _setPending(clientEventId, true);
        return (await _saveWithStatus(local, user.id)).record;
      }
      if (row == null) return null;
      final decodedRemote = TurningRecord.fromJson(row);
      final remote = _withoutLeakedRcVerificationProse(decodedRemote);
      if (remote.reflectionText != decodedRemote.reflectionText) {
        return (await _saveWithStatus(remote, user.id)).record;
      }
      await _saveLocal(remote);
      await _setPending(clientEventId, false);
      return remote;
    } on Object {
      return local;
    }
  }

  Future<TurningRecord> loadOrCreate({
    required String clientEventId,
    required String skyEventId,
    required String? intentionSnapshot,
    required DateTime scheduledTimeSnapshot,
  }) async {
    final existing = await load(clientEventId);
    if (existing != null) return existing;
    final now = DateTime.now().toUtc();
    final created = TurningRecord(
      id: const Uuid().v4(),
      clientEventId: clientEventId,
      skyEventId: skyEventId,
      intentionSnapshot: intentionSnapshot,
      reflectionText: '',
      startedAt: now,
      lastEditedAt: now,
      scheduledTimeSnapshot: scheduledTimeSnapshot.toUtc(),
    );
    return save(created);
  }

  Future<TurningRecord> save(TurningRecord record) async {
    return (await saveWithStatus(record)).record;
  }

  Future<TurningRecordSaveResult> saveWithStatus(TurningRecord record) async {
    record = _withoutLeakedRcVerificationProse(record);
    await _saveLocal(record);
    await _setPending(record.clientEventId, true);
    final user = _client.auth.currentUser;
    if (user == null) {
      return TurningRecordSaveResult(record: record, cloudSynced: false);
    }
    return _saveWithStatus(record, user.id);
  }

  Future<TurningRecordSaveResult> _saveWithStatus(
    TurningRecord record,
    String userId,
  ) async {
    try {
      final payload = <String, dynamic>{...record.toJson(), 'user_id': userId}
        ..remove('id');
      final row = await _client
          .from(table)
          .upsert(payload, onConflict: 'user_id,client_event_id')
          .select()
          .single();
      final persisted = TurningRecord.fromJson(row);
      await _saveLocal(persisted);
      await _setPending(record.clientEventId, false);
      return TurningRecordSaveResult(record: persisted, cloudSynced: true);
    } on Object {
      // The pending flag survives process restarts. A later load retries even
      // when the person never edits this record again.
      await _setPending(record.clientEventId, true);
      return TurningRecordSaveResult(record: record, cloudSynced: false);
    }
  }

  Future<bool> isPendingSync(String clientEventId) async =>
      (await _prefs).getBool(_pendingKey(clientEventId)) ?? false;

  Future<TurningRecord?> _loadLocal(String clientEventId) async {
    final raw = (await _prefs).getString(_localKey(clientEventId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final record = TurningRecord.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      final safeRecord = _withoutLeakedRcVerificationProse(record);
      if (safeRecord.reflectionText != record.reflectionText) {
        await _saveLocal(safeRecord);
      }
      return safeRecord;
    } on Object {
      return null;
    }
  }

  TurningRecord _withoutLeakedRcVerificationProse(TurningRecord record) {
    const leakedRcVerificationProse =
        'RC wiring check: '
        'the approved sky view held.';
    if (record.reflectionText.trim() != leakedRcVerificationProse) {
      return record;
    }
    return record.copyWith(
      reflectionText: '',
      lastEditedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _saveLocal(TurningRecord record) async {
    await (await _prefs).setString(
      _localKey(record.clientEventId),
      jsonEncode(record.toJson()),
    );
  }

  Future<void> _setPending(String clientEventId, bool pending) async {
    final preferences = await _prefs;
    if (pending) {
      await preferences.setBool(_pendingKey(clientEventId), true);
    } else {
      await preferences.remove(_pendingKey(clientEventId));
    }
  }
}
