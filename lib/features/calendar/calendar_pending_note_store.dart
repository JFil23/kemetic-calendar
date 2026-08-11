import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The small, user-scoped recovery record for an event whose successful write
/// has not yet been observed by an authoritative hydration pass.
class PendingCalendarNoteRecord {
  const PendingCalendarNoteRecord({
    required this.clientEventId,
    required this.dayKey,
    required this.createdAt,
    required this.notePayload,
  });

  static const int schemaVersion = 1;

  final String clientEventId;
  final String dayKey;
  final DateTime createdAt;
  final Map<String, dynamic> notePayload;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': schemaVersion,
    'clientEventId': clientEventId,
    'dayKey': dayKey,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'note': notePayload,
  };

  static PendingCalendarNoteRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final json = Map<String, dynamic>.from(raw);
      if ((json['version'] as num?)?.toInt() != schemaVersion) return null;
      final clientEventId = (json['clientEventId'] as String?)?.trim();
      final dayKey = (json['dayKey'] as String?)?.trim();
      final createdAt = DateTime.tryParse(
        (json['createdAt'] as String?)?.trim() ?? '',
      );
      final note = json['note'];
      if (clientEventId == null ||
          clientEventId.isEmpty ||
          dayKey == null ||
          dayKey.isEmpty ||
          createdAt == null ||
          note is! Map) {
        return null;
      }
      return PendingCalendarNoteRecord(
        clientEventId: clientEventId,
        dayKey: dayKey,
        createdAt: createdAt.toUtc(),
        notePayload: Map<String, dynamic>.from(note),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Stores one record per CID so concurrent adds cannot overwrite each other.
/// The key is user-scoped and both components are encoded before being used as
/// SharedPreferences key material.
class PendingCalendarNoteStore {
  PendingCalendarNoteStore({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  static const String _keyPrefix = 'calendar:pending_note:v1';

  final Future<SharedPreferences> Function() _preferences;

  String _encodeKeyPart(String value) => base64Url.encode(utf8.encode(value));

  String _userPrefix(String userId) =>
      '$_keyPrefix:${_encodeKeyPart(userId.trim())}:';

  String _recordKey(String userId, String clientEventId) =>
      '${_userPrefix(userId)}${_encodeKeyPart(clientEventId.trim())}';

  Future<void> write({
    required String userId,
    required PendingCalendarNoteRecord record,
  }) async {
    final normalizedUserId = userId.trim();
    final cid = record.clientEventId.trim();
    if (normalizedUserId.isEmpty || cid.isEmpty) {
      throw ArgumentError('Pending calendar note requires user and CID');
    }
    final prefs = await _preferences();
    final saved = await prefs.setString(
      _recordKey(normalizedUserId, cid),
      jsonEncode(record.toJson()),
    );
    if (!saved) {
      throw StateError('Pending calendar note persistence was rejected');
    }
  }

  Future<List<PendingCalendarNoteRecord>> readForUser(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return const <PendingCalendarNoteRecord>[];
    final prefs = await _preferences();
    final prefix = _userPrefix(normalizedUserId);
    final records = <PendingCalendarNoteRecord>[];
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final record = PendingCalendarNoteRecord.fromJson(jsonDecode(raw));
        if (record != null) records.add(record);
      } catch (_) {
        // Leave malformed records isolated; they cannot safely reconstruct a
        // visible event and must not prevent other records from restoring.
      }
    }
    records.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return records;
  }

  Future<void> remove({
    required String userId,
    required String clientEventId,
  }) async {
    final normalizedUserId = userId.trim();
    final cid = clientEventId.trim();
    if (normalizedUserId.isEmpty || cid.isEmpty) return;
    final prefs = await _preferences();
    await prefs.remove(_recordKey(normalizedUserId, cid));
  }

  Future<void> removeMany({
    required String userId,
    required Iterable<String> clientEventIds,
  }) async {
    for (final cid in clientEventIds.map((value) => value.trim()).toSet()) {
      if (cid.isEmpty) continue;
      await remove(userId: userId, clientEventId: cid);
    }
  }

  Future<void> clearForUser(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    final prefs = await _preferences();
    final prefix = _userPrefix(normalizedUserId);
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      await prefs.remove(key);
    }
  }
}
