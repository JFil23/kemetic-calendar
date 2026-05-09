import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteRestorationSnapshot {
  const RemoteRestorationSnapshot({
    required this.snapshot,
    required this.source,
  });

  final Map<String, dynamic> snapshot;
  final String source;
}

class AppRestorationRepo {
  AppRestorationRepo(this._client);

  static const String tableName = 'user_app_restoration_snapshots';
  static const String windowScope = 'window';
  static const String latestScope = 'latest';

  final SupabaseClient _client;

  Future<RemoteRestorationSnapshot?> readWindowSnapshot({
    required String userId,
    required String deviceId,
    required String windowId,
  }) async {
    final row = await _client
        .from(tableName)
        .select('snapshot')
        .eq('user_id', userId)
        .eq('scope', windowScope)
        .eq('device_id', deviceId)
        .eq('window_id', windowId)
        .maybeSingle()
        .timeout(const Duration(seconds: 2));
    final snapshot = _coerceSnapshot(row);
    if (snapshot == null) {
      return null;
    }
    return RemoteRestorationSnapshot(
      snapshot: snapshot,
      source: 'remote_window',
    );
  }

  Future<RemoteRestorationSnapshot?> readLatestSnapshot({
    required String userId,
  }) async {
    final row = await _client
        .from(tableName)
        .select('snapshot')
        .eq('user_id', userId)
        .eq('scope', latestScope)
        .eq('device_id', '')
        .eq('window_id', '')
        .maybeSingle()
        .timeout(const Duration(seconds: 2));
    final snapshot = _coerceSnapshot(row);
    if (snapshot == null) {
      return null;
    }
    return RemoteRestorationSnapshot(
      snapshot: snapshot,
      source: 'remote_latest',
    );
  }

  Future<void> upsertSnapshots({
    required String userId,
    required String deviceId,
    required String windowId,
    required int schemaVersion,
    required int updatedAtMs,
    required Map<String, dynamic> snapshot,
  }) async {
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(
      updatedAtMs,
      isUtc: true,
    ).toIso8601String();
    final routeLocation = (snapshot['routeLocation'] as String?)?.trim();
    final canonicalSnapshot = Map<String, dynamic>.from(snapshot);

    await _client
        .from(tableName)
        .upsert(<Map<String, dynamic>>[
          <String, dynamic>{
            'user_id': userId,
            'scope': windowScope,
            'device_id': deviceId,
            'window_id': windowId,
            'snapshot': canonicalSnapshot,
            'schema_version': schemaVersion,
            'route_location': routeLocation,
            'updated_at': updatedAt,
          },
          <String, dynamic>{
            'user_id': userId,
            'scope': latestScope,
            'device_id': '',
            'window_id': '',
            'snapshot': canonicalSnapshot,
            'schema_version': schemaVersion,
            'route_location': routeLocation,
            'updated_at': updatedAt,
          },
        ], onConflict: 'user_id,scope,device_id,window_id')
        .timeout(const Duration(seconds: 3));
  }

  Map<String, dynamic>? _coerceSnapshot(Object? row) {
    if (row is! Map) {
      return null;
    }
    final snapshot = row['snapshot'];
    if (snapshot is Map<String, dynamic>) {
      return Map<String, dynamic>.from(snapshot);
    }
    if (snapshot is Map) {
      return snapshot.map<String, dynamic>(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }
}
