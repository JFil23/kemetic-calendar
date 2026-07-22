import 'dart:convert';

import 'restoration_durable_store_stub.dart'
    if (dart.library.html) 'restoration_durable_store_web.dart'
    as platform;

enum DurableSnapshotWriteStatus { committed, superseded }

class DurableSnapshotStoreException implements Exception {
  const DurableSnapshotStoreException(this.message);

  final String message;

  @override
  String toString() => 'DurableSnapshotStoreException: $message';
}

abstract interface class RestorationDurableStore {
  bool get isSupported;

  Future<String?> readWindowEnvelope(String userId, String windowId);

  Future<String?> readLatestEnvelope(String userId);

  Future<String?> readLastActiveUserId();

  Future<DurableSnapshotWriteStatus> writeEnvelope(
    DurableRestorationEnvelope envelope,
  );

  Future<void> clearWindow(String userId, String windowId);

  Future<void> clearLastActiveUser();
}

class PlatformRestorationDurableStore implements RestorationDurableStore {
  const PlatformRestorationDurableStore();

  @override
  bool get isSupported => platform.supportsAcknowledgedDurableSnapshotStore;

  @override
  Future<String?> readWindowEnvelope(String userId, String windowId) =>
      platform.readWindowEnvelope(userId, windowId);

  @override
  Future<String?> readLatestEnvelope(String userId) =>
      platform.readLatestEnvelope(userId);

  @override
  Future<String?> readLastActiveUserId() => platform.readLastActiveUserId();

  @override
  Future<DurableSnapshotWriteStatus> writeEnvelope(
    DurableRestorationEnvelope envelope,
  ) async {
    final result = await platform.writeEnvelope(
      userId: envelope.userId,
      windowId: envelope.windowId,
      generation: envelope.generation,
      encodedEnvelope: envelope.encode(),
    );
    return switch (result) {
      'committed' => DurableSnapshotWriteStatus.committed,
      'superseded' => DurableSnapshotWriteStatus.superseded,
      _ => throw DurableSnapshotStoreException(
        'unexpected platform write result: $result',
      ),
    };
  }

  @override
  Future<void> clearWindow(String userId, String windowId) =>
      platform.clearWindow(userId, windowId);

  @override
  Future<void> clearLastActiveUser() => platform.clearLastActiveUser();
}

class DurableRestorationEnvelope {
  const DurableRestorationEnvelope._({
    required this.authoritySchemaVersion,
    required this.snapshotSchemaVersion,
    required this.userId,
    required this.windowId,
    required this.generation,
    required this.snapshotJson,
    required this.integrity,
  });

  static const int currentAuthoritySchemaVersion = 1;

  final int authoritySchemaVersion;
  final int snapshotSchemaVersion;
  final String userId;
  final String windowId;
  final int generation;
  final String snapshotJson;
  final String integrity;

  factory DurableRestorationEnvelope.create({
    required int snapshotSchemaVersion,
    required String userId,
    required String windowId,
    required int generation,
    required String snapshotJson,
  }) {
    final normalizedUserId = userId.trim();
    final normalizedWindowId = windowId.trim();
    if (normalizedUserId.isEmpty ||
        normalizedWindowId.isEmpty ||
        generation < 0 ||
        snapshotSchemaVersion < 1 ||
        snapshotJson.trim().isEmpty) {
      throw const DurableSnapshotStoreException(
        'invalid durable restoration envelope input',
      );
    }
    final integrity = _integrityFor(
      authoritySchemaVersion: currentAuthoritySchemaVersion,
      snapshotSchemaVersion: snapshotSchemaVersion,
      userId: normalizedUserId,
      windowId: normalizedWindowId,
      generation: generation,
      snapshotJson: snapshotJson,
    );
    return DurableRestorationEnvelope._(
      authoritySchemaVersion: currentAuthoritySchemaVersion,
      snapshotSchemaVersion: snapshotSchemaVersion,
      userId: normalizedUserId,
      windowId: normalizedWindowId,
      generation: generation,
      snapshotJson: snapshotJson,
      integrity: integrity,
    );
  }

  static DurableRestorationEnvelope? tryDecode(
    String? encoded, {
    String? expectedUserId,
    String? expectedWindowId,
  }) {
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      final raw = decoded.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final authoritySchemaVersion = _asInt(raw['authoritySchemaVersion']);
      final snapshotSchemaVersion = _asInt(raw['snapshotSchemaVersion']);
      final userId = (raw['userId'] as String?)?.trim();
      final windowId = (raw['windowId'] as String?)?.trim();
      final generation = _asInt(raw['generation']);
      final snapshotJson = raw['snapshotJson'] as String?;
      final integrity = raw['integrity'] as String?;
      if (authoritySchemaVersion == null ||
          authoritySchemaVersion != currentAuthoritySchemaVersion ||
          snapshotSchemaVersion == null ||
          snapshotSchemaVersion < 1 ||
          userId == null ||
          userId.isEmpty ||
          windowId == null ||
          windowId.isEmpty ||
          generation == null ||
          generation < 0 ||
          snapshotJson == null ||
          snapshotJson.trim().isEmpty ||
          integrity == null ||
          integrity.isEmpty ||
          (expectedUserId != null && userId != expectedUserId.trim()) ||
          (expectedWindowId != null && windowId != expectedWindowId.trim())) {
        return null;
      }
      final expectedIntegrity = _integrityFor(
        authoritySchemaVersion: authoritySchemaVersion,
        snapshotSchemaVersion: snapshotSchemaVersion,
        userId: userId,
        windowId: windowId,
        generation: generation,
        snapshotJson: snapshotJson,
      );
      if (integrity != expectedIntegrity) return null;
      return DurableRestorationEnvelope._(
        authoritySchemaVersion: authoritySchemaVersion,
        snapshotSchemaVersion: snapshotSchemaVersion,
        userId: userId,
        windowId: windowId,
        generation: generation,
        snapshotJson: snapshotJson,
        integrity: integrity,
      );
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(<String, Object>{
    'authoritySchemaVersion': authoritySchemaVersion,
    'snapshotSchemaVersion': snapshotSchemaVersion,
    'userId': userId,
    'windowId': windowId,
    'generation': generation,
    'snapshotJson': snapshotJson,
    'integrity': integrity,
  });

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _integrityFor({
    required int authoritySchemaVersion,
    required int snapshotSchemaVersion,
    required String userId,
    required String windowId,
    required int generation,
    required String snapshotJson,
  }) {
    final payload = jsonEncode(<String, Object>{
      'authoritySchemaVersion': authoritySchemaVersion,
      'snapshotSchemaVersion': snapshotSchemaVersion,
      'userId': userId,
      'windowId': windowId,
      'generation': generation,
      'snapshotJson': snapshotJson,
    });
    var hash = 0x811c9dc5;
    for (final codeUnit in payload.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'fnv1a32:${hash.toRadixString(16).padLeft(8, '0')}';
  }
}
