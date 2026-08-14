import 'dart:async';
import 'dart:convert';

import 'calendar_snapshot_backend.dart';
import 'calendar_snapshot_models.dart';

/// Crash-recoverable, per-user calendar snapshot persistence.
///
/// Objects are immutable and content-addressed. Two alternating manifest slots
/// retain the current and previous complete generations; the head is published
/// only after every referenced object and the new manifest verify. A failed
/// write therefore leaves the prior generation readable.
final class CalendarSnapshotStore {
  CalendarSnapshotStore(this._backend);

  static const int schemaVersion = 1;
  static const String _rootPrefix = 'calendar_snapshot:v1';

  final CalendarSnapshotBackend _backend;
  Future<void>? _initialization;
  final StreamController<String> _invalidations = StreamController.broadcast();
  StreamSubscription<String>? _externalChangeSubscription;

  Stream<String> get invalidatedUserScopeDigests => _invalidations.stream;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _backend.initialize();
    _externalChangeSubscription = _backend.externalChanges.listen((key) {
      final match = RegExp(
        '^${RegExp.escape(_rootPrefix)}:([0-9a-f]{64}):head\$',
      ).firstMatch(key);
      if (match != null) _invalidations.add(match.group(1)!);
    });
  }

  Future<CalendarSnapshotCommitResult> commit(
    CalendarSnapshotCommit commit, {
    int? expectedGeneration,
    bool requireGenerationMatch = false,
  }) async {
    await initialize();
    final scope = commit.userScopeDigest;
    final prefix = _prefix(scope);
    return _backend.withExclusiveLock('$prefix:writer', () async {
      if (await _backend.read(_quarantineKey(prefix)) != null) {
        throw StateError(
          'Calendar snapshot scope is quarantined pending deletion',
        );
      }
      final before = await _readManifestCandidates(scope);
      final current = before.isEmpty ? null : before.first;
      final currentGeneration = current?.manifest.generation;
      if ((requireGenerationMatch || expectedGeneration != null) &&
          expectedGeneration != currentGeneration) {
        throw CalendarSnapshotConflict(
          expectedGeneration: expectedGeneration,
          actualGeneration: currentGeneration,
        );
      }

      final objects = _objectsFor(commit, prefix: prefix);
      var writtenObjectCount = 0;
      var reusedObjectCount = 0;
      for (final object in objects.values) {
        final existing = await _backend.read(object.key);
        if (existing != null &&
            calendarSnapshotDigest(existing) == object.checksum) {
          reusedObjectCount++;
          continue;
        }
        await _backend.write(object.key, object.encoded);
        final verified = await _backend.read(object.key);
        if (verified == null ||
            calendarSnapshotDigest(verified) != object.checksum) {
          throw CalendarSnapshotCorrupt(
            'object verification failed for ${object.logicalId}',
          );
        }
        writtenObjectCount++;
      }

      // CAS again after object writes. This rejects a non-cooperating writer
      // without risking the last complete manifest; orphan objects are safe.
      final afterObjects = await _readManifestCandidates(scope);
      final generationAfterObjects = afterObjects.isEmpty
          ? null
          : afterObjects.first.manifest.generation;
      if (generationAfterObjects != currentGeneration) {
        throw CalendarSnapshotConflict(
          expectedGeneration: currentGeneration,
          actualGeneration: generationAfterObjects,
        );
      }

      final generation = (currentGeneration ?? 0) + 1;
      final nextSlot = current?.slot == _ManifestSlot.a
          ? _ManifestSlot.b
          : _ManifestSlot.a;
      final manifest = _SnapshotManifest(
        schemaVersion: schemaVersion,
        userScopeDigest: scope,
        generation: generation,
        previousGeneration: currentGeneration,
        serverRevision: commit.serverRevision,
        overlayRevision: commit.overlayRevision,
        catalogFingerprint: commit.catalogFingerprint,
        origin: commit.origin,
        committedAtUtc: commit.committedAtUtc,
        lastSuccessfulRefreshAtUtc: commit.lastSuccessfulRefreshAtUtc,
        coverage: commit.coverage,
        canonicalDigest: commit.canonicalDigest,
        catalog: objects[_catalogLogicalId]!.reference,
        overlay: objects[_overlayLogicalId]!.reference,
        eventShards: <String, _SnapshotObjectReference>{
          for (final entry in objects.entries)
            if (entry.key.startsWith(_eventLogicalPrefix))
              entry.key.substring(_eventLogicalPrefix.length):
                  entry.value.reference,
        },
      );
      final encodedManifest = calendarCanonicalJson(manifest.toJson());
      final envelope = calendarCanonicalJson(<String, Object?>{
        'manifest': jsonDecode(encodedManifest),
        'checksum': calendarSnapshotDigest(encodedManifest),
      });
      final manifestKey = _manifestKey(prefix, nextSlot);
      await _backend.write(manifestKey, envelope);
      final verifiedManifest = await _readManifestSlot(scope, nextSlot);
      if (verifiedManifest == null ||
          verifiedManifest.manifest.generation != generation ||
          verifiedManifest.manifest.canonicalDigest != commit.canonicalDigest) {
        throw const CalendarSnapshotCorrupt(
          'manifest verification failed before publication',
        );
      }

      final head = calendarCanonicalJson(<String, Object?>{
        'schemaVersion': schemaVersion,
        'slot': nextSlot.name,
        'generation': generation,
        'manifestChecksum': calendarSnapshotDigest(encodedManifest),
      });
      await _backend.write(_headKey(prefix), head);
      final verifiedHead = await _readHead(scope);
      if (verifiedHead == null ||
          verifiedHead.slot != nextSlot ||
          verifiedHead.generation != generation) {
        throw const CalendarSnapshotCorrupt(
          'head verification failed after manifest publication',
        );
      }

      await _collectGarbage(scope);
      _invalidations.add(scope);
      return CalendarSnapshotCommitResult(
        generation: generation,
        previousGeneration: currentGeneration,
        canonicalDigest: commit.canonicalDigest,
        writtenObjectCount: writtenObjectCount,
        reusedObjectCount: reusedObjectCount,
      );
    });
  }

  /// Reads the newest complete generation, falling back to the retained
  /// previous generation if a manifest or any referenced object is corrupt.
  Future<CalendarSnapshotValue?> readLatest(
    String userScope, {
    Set<String>? eventShardIds,
  }) async {
    await initialize();
    final normalizedScope = userScope.trim();
    if (normalizedScope.isEmpty) return null;
    final scope = calendarSnapshotDigest(normalizedScope);
    if (await _backend.read(_quarantineKey(_prefix(scope))) != null) {
      return null;
    }
    final candidates = await _readManifestCandidates(scope);
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      try {
        return await _materialize(
          candidate.manifest,
          eventShardIds: eventShardIds,
          recoveredPreviousGeneration: index > 0,
        );
      } on CalendarSnapshotCorrupt {
        continue;
      }
    }
    return null;
  }

  Future<void> deleteUserScope(String userScope) async {
    await initialize();
    final normalizedScope = userScope.trim();
    if (normalizedScope.isEmpty) return;
    final scope = calendarSnapshotDigest(normalizedScope);
    final prefix = _prefix(scope);
    await _backend.withExclusiveLock('$prefix:writer', () async {
      // Quarantine is published before deletion. If any delete fails, callers
      // fail closed and can retry cleanup without exposing the old account.
      await _backend.write(
        _quarantineKey(prefix),
        DateTime.now().toUtc().toIso8601String(),
      );
      final keys = await _backend.keys(prefix: '$prefix:');
      for (final key in keys) {
        if (key == _quarantineKey(prefix)) continue;
        await _backend.delete(key);
      }
      final survivors = (await _backend.keys(prefix: '$prefix:'))
        ..remove(_quarantineKey(prefix));
      if (survivors.isNotEmpty) {
        throw StateError(
          'Calendar snapshot user-scope deletion left ${survivors.length} keys',
        );
      }
      await _backend.delete(_quarantineKey(prefix));
      _invalidations.add(scope);
    });
  }

  Future<void> dispose() async {
    await _externalChangeSubscription?.cancel();
    await _invalidations.close();
  }

  Future<CalendarSnapshotValue> _materialize(
    _SnapshotManifest manifest, {
    required Set<String>? eventShardIds,
    required bool recoveredPreviousGeneration,
  }) async {
    final catalogRaw = await _verifiedObject(manifest.catalog);
    final overlayRaw = await _verifiedObject(manifest.overlay);
    final catalogJson = jsonDecode(catalogRaw);
    final overlayJson = jsonDecode(overlayRaw);
    if (catalogJson is! Map || overlayJson is! Map) {
      throw const CalendarSnapshotCorrupt('catalog or overlay root is invalid');
    }
    final flowRows = (catalogJson['flows'] as List? ?? const <Object?>[])
        .whereType<Map>()
        .map((row) => Map<String, Object?>.from(row))
        .toList(growable: false);
    final calendarMetadataRaw = catalogJson['calendarMetadata'];
    if (calendarMetadataRaw is! Map) {
      throw const CalendarSnapshotCorrupt('calendar metadata is invalid');
    }
    final calendarMetadata = Map<String, Object?>.from(calendarMetadataRaw);
    final overlayRows = (overlayJson['records'] as List? ?? const <Object?>[])
        .whereType<Map>()
        .map((row) => Map<String, Object?>.from(row))
        .toList(growable: false);
    final eventsByDay = <String, List<Map<String, Object?>>>{};
    final selectedShards = manifest.eventShards.entries.where(
      (entry) => eventShardIds == null || eventShardIds.contains(entry.key),
    );
    final decodedShards = await Future.wait(
      selectedShards.map((entry) async {
        final raw = await _verifiedObject(entry.value);
        final decoded = jsonDecode(raw);
        if (decoded is! Map || decoded['days'] is! Map) {
          throw CalendarSnapshotCorrupt('event shard ${entry.key} is invalid');
        }
        return (id: entry.key, days: decoded['days'] as Map);
      }),
    );
    for (final shard in decodedShards) {
      final days = Map<Object?, Object?>.from(shard.days);
      for (final dayEntry in days.entries) {
        if (dayEntry.value is! List) {
          throw CalendarSnapshotCorrupt(
            'event shard ${shard.id} has invalid day ${dayEntry.key}',
          );
        }
        eventsByDay[dayEntry.key.toString()] = (dayEntry.value as List)
            .whereType<Map>()
            .map((row) => Map<String, Object?>.from(row))
            .toList(growable: false);
      }
    }

    if (eventShardIds == null) {
      final directDigest = calendarSnapshotDigest(
        calendarCanonicalJson(<String, Object?>{
          'userScopeDigest': manifest.userScopeDigest,
          'serverRevision': manifest.serverRevision,
          'overlayRevision': manifest.overlayRevision,
          'catalogFingerprint': manifest.catalogFingerprint,
          'coverage': manifest.coverage.map((value) => value.toJson()).toList(),
          'eventsByDay': eventsByDay,
          'flows': flowRows,
          'calendarMetadata': calendarMetadata,
          'overlayRecords': overlayRows,
        }),
      );
      if (directDigest != manifest.canonicalDigest) {
        throw const CalendarSnapshotCorrupt('canonical digest mismatch');
      }
    }

    return CalendarSnapshotValue(
      generation: manifest.generation,
      serverRevision: manifest.serverRevision,
      overlayRevision: manifest.overlayRevision,
      catalogFingerprint: manifest.catalogFingerprint,
      origin: manifest.origin,
      committedAtUtc: manifest.committedAtUtc,
      lastSuccessfulRefreshAtUtc: manifest.lastSuccessfulRefreshAtUtc,
      coverage: List<CalendarSnapshotCoverageInterval>.unmodifiable(
        manifest.coverage,
      ),
      eventsByDay: Map<String, List<Map<String, Object?>>>.unmodifiable(
        eventsByDay,
      ),
      flows: List<Map<String, Object?>>.unmodifiable(flowRows),
      calendarMetadata: Map<String, Object?>.unmodifiable(calendarMetadata),
      overlayRecords: List<Map<String, Object?>>.unmodifiable(overlayRows),
      canonicalDigest: manifest.canonicalDigest,
      recoveredPreviousGeneration: recoveredPreviousGeneration,
    );
  }

  Future<String> _verifiedObject(_SnapshotObjectReference reference) async {
    final raw = await _backend.read(reference.key);
    if (raw == null || calendarSnapshotDigest(raw) != reference.checksum) {
      throw CalendarSnapshotCorrupt(
        'missing or corrupt object ${reference.logicalId}',
      );
    }
    return raw;
  }

  Map<String, _SnapshotObject> _objectsFor(
    CalendarSnapshotCommit commit, {
    required String prefix,
  }) {
    final objects = <String, _SnapshotObject>{};
    void add(String logicalId, Object payload, int recordCount) {
      final encoded = calendarCanonicalJson(payload);
      final checksum = calendarSnapshotDigest(encoded);
      objects[logicalId] = _SnapshotObject(
        logicalId: logicalId,
        key: '$prefix:object:$checksum',
        checksum: checksum,
        encoded: encoded,
        recordCount: recordCount,
      );
    }

    add(_catalogLogicalId, <String, Object?>{
      'flows': commit.flows,
      'calendarMetadata': commit.calendarMetadata,
    }, commit.flows.length);
    add(_overlayLogicalId, <String, Object?>{
      'records': commit.overlayRecords,
    }, commit.overlayRecords.length);
    final shards = <String, Map<String, List<Map<String, Object?>>>>{};
    for (final entry in commit.eventsByDay.entries) {
      final shardId = _eventShardId(entry.key);
      shards.putIfAbsent(shardId, () => {})[entry.key] = entry.value;
    }
    for (final entry in shards.entries) {
      final count = entry.value.values.fold<int>(
        0,
        (sum, rows) => sum + rows.length,
      );
      add('$_eventLogicalPrefix${entry.key}', <String, Object?>{
        'days': entry.value,
      }, count);
    }
    return objects;
  }

  String _eventShardId(String dayKey) {
    final match = RegExp(r'^(-?\d+)-(\d+)-(\d+)$').firstMatch(dayKey);
    if (match == null) return 'unknown-${calendarSnapshotDigest(dayKey)}';
    return '${match.group(1)}-${match.group(2)}';
  }

  Future<List<_ManifestCandidate>> _readManifestCandidates(String scope) async {
    final head = await _readHead(scope);
    final slots = <_ManifestCandidate>[];
    for (final slot in _ManifestSlot.values) {
      final candidate = await _readManifestSlot(scope, slot);
      if (candidate != null) slots.add(candidate);
    }
    slots.sort((a, b) {
      if (head != null) {
        final aIsHead =
            a.slot == head.slot && a.manifest.generation == head.generation;
        final bIsHead =
            b.slot == head.slot && b.manifest.generation == head.generation;
        if (aIsHead && !bIsHead) return -1;
        if (bIsHead && !aIsHead) return 1;
      }
      return b.manifest.generation.compareTo(a.manifest.generation);
    });
    return slots;
  }

  Future<_SnapshotHead?> _readHead(String scope) async {
    final raw = await _backend.read(_headKey(_prefix(scope)));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return _SnapshotHead.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<_ManifestCandidate?> _readManifestSlot(
    String scope,
    _ManifestSlot slot,
  ) async {
    final raw = await _backend.read(_manifestKey(_prefix(scope), slot));
    if (raw == null) return null;
    try {
      final envelope = jsonDecode(raw);
      if (envelope is! Map || envelope['manifest'] is! Map) return null;
      final manifestRaw = Map<String, Object?>.from(
        envelope['manifest'] as Map,
      );
      final encodedManifest = calendarCanonicalJson(manifestRaw);
      if (envelope['checksum'] != calendarSnapshotDigest(encodedManifest)) {
        return null;
      }
      final manifest = _SnapshotManifest.fromJson(manifestRaw);
      if (manifest == null || manifest.userScopeDigest != scope) return null;
      return _ManifestCandidate(slot: slot, manifest: manifest);
    } catch (_) {
      return null;
    }
  }

  Future<void> _collectGarbage(String scope) async {
    final prefix = _prefix(scope);
    final manifests = await _readManifestCandidates(scope);
    final retained = <String>{};
    for (final candidate in manifests) {
      retained
        ..add(candidate.manifest.catalog.key)
        ..add(candidate.manifest.overlay.key)
        ..addAll(
          candidate.manifest.eventShards.values.map((value) => value.key),
        );
    }
    final objectKeys = await _backend.keys(prefix: '$prefix:object:');
    for (final key in objectKeys.difference(retained)) {
      await _backend.delete(key);
    }
  }

  String _prefix(String scope) => '$_rootPrefix:$scope';
  String _headKey(String prefix) => '$prefix:head';
  String _quarantineKey(String prefix) => '$prefix:quarantined';
  String _manifestKey(String prefix, _ManifestSlot slot) =>
      '$prefix:manifest:${slot.name}';

  static const String _catalogLogicalId = 'catalog';
  static const String _overlayLogicalId = 'overlay';
  static const String _eventLogicalPrefix = 'events:';
}

enum _ManifestSlot { a, b }

final class _SnapshotHead {
  const _SnapshotHead({required this.slot, required this.generation});

  final _ManifestSlot slot;
  final int generation;

  static _SnapshotHead? fromJson(Map raw) {
    final slot = switch (raw['slot']) {
      'a' => _ManifestSlot.a,
      'b' => _ManifestSlot.b,
      _ => null,
    };
    final generation = (raw['generation'] as num?)?.toInt();
    if (slot == null || generation == null || generation <= 0) return null;
    return _SnapshotHead(slot: slot, generation: generation);
  }
}

final class _ManifestCandidate {
  const _ManifestCandidate({required this.slot, required this.manifest});

  final _ManifestSlot slot;
  final _SnapshotManifest manifest;
}

final class _SnapshotObject {
  const _SnapshotObject({
    required this.logicalId,
    required this.key,
    required this.checksum,
    required this.encoded,
    required this.recordCount,
  });

  final String logicalId;
  final String key;
  final String checksum;
  final String encoded;
  final int recordCount;

  _SnapshotObjectReference get reference => _SnapshotObjectReference(
    logicalId: logicalId,
    key: key,
    checksum: checksum,
    recordCount: recordCount,
  );
}

final class _SnapshotObjectReference {
  const _SnapshotObjectReference({
    required this.logicalId,
    required this.key,
    required this.checksum,
    required this.recordCount,
  });

  final String logicalId;
  final String key;
  final String checksum;
  final int recordCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'logicalId': logicalId,
    'key': key,
    'checksum': checksum,
    'recordCount': recordCount,
  };

  static _SnapshotObjectReference? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final logicalId = raw['logicalId']?.toString();
    final key = raw['key']?.toString();
    final checksum = raw['checksum']?.toString();
    final count = (raw['recordCount'] as num?)?.toInt();
    if (logicalId == null ||
        logicalId.isEmpty ||
        key == null ||
        key.isEmpty ||
        checksum == null ||
        checksum.isEmpty ||
        count == null ||
        count < 0) {
      return null;
    }
    return _SnapshotObjectReference(
      logicalId: logicalId,
      key: key,
      checksum: checksum,
      recordCount: count,
    );
  }
}

final class _SnapshotManifest {
  const _SnapshotManifest({
    required this.schemaVersion,
    required this.userScopeDigest,
    required this.generation,
    required this.previousGeneration,
    required this.serverRevision,
    required this.overlayRevision,
    required this.catalogFingerprint,
    required this.origin,
    required this.committedAtUtc,
    required this.lastSuccessfulRefreshAtUtc,
    required this.coverage,
    required this.canonicalDigest,
    required this.catalog,
    required this.overlay,
    required this.eventShards,
  });

  final int schemaVersion;
  final String userScopeDigest;
  final int generation;
  final int? previousGeneration;
  final String serverRevision;
  final String overlayRevision;
  final String catalogFingerprint;
  final String origin;
  final DateTime committedAtUtc;
  final DateTime lastSuccessfulRefreshAtUtc;
  final List<CalendarSnapshotCoverageInterval> coverage;
  final String canonicalDigest;
  final _SnapshotObjectReference catalog;
  final _SnapshotObjectReference overlay;
  final Map<String, _SnapshotObjectReference> eventShards;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'userScopeDigest': userScopeDigest,
    'generation': generation,
    'previousGeneration': previousGeneration,
    'serverRevision': serverRevision,
    'overlayRevision': overlayRevision,
    'catalogFingerprint': catalogFingerprint,
    'origin': origin,
    'committedAtUtc': committedAtUtc.toIso8601String(),
    'lastSuccessfulRefreshAtUtc': lastSuccessfulRefreshAtUtc.toIso8601String(),
    'coverage': coverage.map((value) => value.toJson()).toList(),
    'canonicalDigest': canonicalDigest,
    'catalog': catalog.toJson(),
    'overlay': overlay.toJson(),
    'eventShards': <String, Object?>{
      for (final entry in eventShards.entries) entry.key: entry.value.toJson(),
    },
  };

  static _SnapshotManifest? fromJson(Map raw) {
    final schemaVersion = (raw['schemaVersion'] as num?)?.toInt();
    final userScopeDigest = raw['userScopeDigest']?.toString();
    final generation = (raw['generation'] as num?)?.toInt();
    final previousGeneration = (raw['previousGeneration'] as num?)?.toInt();
    final serverRevision = raw['serverRevision']?.toString();
    final overlayRevision = raw['overlayRevision']?.toString();
    final catalogFingerprint = raw['catalogFingerprint']?.toString();
    final origin = raw['origin']?.toString();
    final committedAtUtc = DateTime.tryParse(
      raw['committedAtUtc']?.toString() ?? '',
    );
    final refreshedAtUtc = DateTime.tryParse(
      raw['lastSuccessfulRefreshAtUtc']?.toString() ?? '',
    );
    final canonicalDigest = raw['canonicalDigest']?.toString();
    final catalog = _SnapshotObjectReference.fromJson(raw['catalog']);
    final overlay = _SnapshotObjectReference.fromJson(raw['overlay']);
    if (schemaVersion != CalendarSnapshotStore.schemaVersion ||
        userScopeDigest == null ||
        userScopeDigest.length != 64 ||
        generation == null ||
        generation <= 0 ||
        serverRevision == null ||
        serverRevision.isEmpty ||
        overlayRevision == null ||
        overlayRevision.isEmpty ||
        catalogFingerprint == null ||
        catalogFingerprint.isEmpty ||
        origin == null ||
        origin.isEmpty ||
        committedAtUtc == null ||
        refreshedAtUtc == null ||
        canonicalDigest == null ||
        canonicalDigest.length != 64 ||
        catalog == null ||
        overlay == null) {
      return null;
    }
    final rawCoverage = raw['coverage'];
    if (rawCoverage is! List) return null;
    final coverage = <CalendarSnapshotCoverageInterval>[];
    for (final value in rawCoverage) {
      final interval = CalendarSnapshotCoverageInterval.fromJson(value);
      if (interval == null) return null;
      coverage.add(interval);
    }
    final eventShards = <String, _SnapshotObjectReference>{};
    final rawShards = raw['eventShards'];
    if (rawShards is! Map) return null;
    for (final entry in rawShards.entries) {
      final reference = _SnapshotObjectReference.fromJson(entry.value);
      if (reference == null) return null;
      eventShards[entry.key.toString()] = reference;
    }
    return _SnapshotManifest(
      schemaVersion: schemaVersion!,
      userScopeDigest: userScopeDigest,
      generation: generation,
      previousGeneration: previousGeneration,
      serverRevision: serverRevision,
      overlayRevision: overlayRevision,
      catalogFingerprint: catalogFingerprint,
      origin: origin,
      committedAtUtc: committedAtUtc.toUtc(),
      lastSuccessfulRefreshAtUtc: refreshedAtUtc.toUtc(),
      coverage: coverage,
      canonicalDigest: canonicalDigest,
      catalog: catalog,
      overlay: overlay,
      eventShards: eventShards,
    );
  }
}
