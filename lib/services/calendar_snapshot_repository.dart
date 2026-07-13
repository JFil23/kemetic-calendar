import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/calendar/calendar_warm_start_cache_identity.dart';

const String calendarSnapshotLaneFlows = 'flows';
const String calendarSnapshotLaneFlowEvents = 'flowEvents';
const String calendarSnapshotLaneStandaloneEvents = 'standaloneEvents';
const String calendarSnapshotLaneReminders = 'reminders';

const Set<String> calendarSnapshotRequiredLanes = <String>{
  calendarSnapshotLaneFlows,
  calendarSnapshotLaneFlowEvents,
  calendarSnapshotLaneStandaloneEvents,
  calendarSnapshotLaneReminders,
};

@immutable
class CalendarSnapshotIdentity {
  const CalendarSnapshotIdentity({
    required this.projectRef,
    required this.userId,
  });

  final String projectRef;
  final String userId;

  String get storageKey {
    final key = calendarWarmStartCacheKey(
      projectRef: projectRef,
      userId: userId,
    );
    if (key == null) {
      throw StateError('Calendar snapshot identity is incomplete.');
    }
    return key;
  }
}

@immutable
class CalendarSnapshotCoverage {
  const CalendarSnapshotCoverage({
    required this.startUtc,
    required this.endUtc,
  });

  final DateTime startUtc;
  final DateTime endUtc;

  bool get isValid => endUtc.toUtc().isAfter(startUtc.toUtc());

  bool contains(CalendarSnapshotCoverage other) {
    final start = startUtc.toUtc();
    final end = endUtc.toUtc();
    final otherStart = other.startUtc.toUtc();
    final otherEnd = other.endUtc.toUtc();
    return !start.isAfter(otherStart) && !end.isBefore(otherEnd);
  }
}

@immutable
class CalendarSnapshotCandidate {
  const CalendarSnapshotCandidate({
    required this.identity,
    required this.coverage,
    required this.completedLanes,
    required this.generation,
    required this.payload,
    required this.source,
    this.savedAt,
  });

  final CalendarSnapshotIdentity identity;
  final CalendarSnapshotCoverage coverage;
  final Set<String> completedLanes;
  final int generation;
  final Map<String, dynamic> payload;
  final String source;
  final DateTime? savedAt;
}

@immutable
class CalendarSnapshotDocument {
  const CalendarSnapshotDocument._(this.json);

  final Map<String, dynamic> json;

  String get projectRef => json['projectRef']! as String;
  String get userId => json['userId']! as String;
  int get generation => json['generation']! as int;
  int get eventCount => json['eventCount']! as int;
  int get flowCount => json['flowCount']! as int;
  String get digest => json['payloadDigest']! as String;

  CalendarSnapshotCoverage get coverage => CalendarSnapshotCoverage(
    startUtc: DateTime.parse(json['coverageStartUtc']! as String).toUtc(),
    endUtc: DateTime.parse(json['coverageEndUtc']! as String).toUtc(),
  );

  Set<String> get completedLanes =>
      (json['completedLanes']! as List).whereType<String>().toSet();

  bool covers(CalendarSnapshotCoverage requiredCoverage) =>
      coverage.contains(requiredCoverage);
}

abstract interface class CalendarSnapshotStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class HiveCalendarSnapshotStore implements CalendarSnapshotStore {
  static const String _boxName = 'calendar_snapshot.authority.v1';

  Future<Box<String>>? _openFlight;

  Future<Box<String>> _box() {
    final open = _openFlight;
    if (open != null) return open;
    final next = _openBox();
    _openFlight = next;
    return next;
  }

  Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }
    try {
      await Hive.initFlutter();
    } catch (_) {
      // Hive may already have been initialized by Supabase or calendar sync.
    }
    return Hive.openBox<String>(_boxName);
  }

  @override
  Future<String?> read(String key) async => (await _box()).get(key);

  @override
  Future<void> write(String key, String value) async {
    await (await _box()).put(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await (await _box()).delete(key);
  }
}

class MemoryCalendarSnapshotStore implements CalendarSnapshotStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class CalendarSnapshotRepository {
  CalendarSnapshotRepository({CalendarSnapshotStore? store})
    : _store = store ?? HiveCalendarSnapshotStore();

  static final CalendarSnapshotRepository instance =
      CalendarSnapshotRepository();

  CalendarSnapshotStore _store;
  final Map<String, CalendarSnapshotDocument> _lastGoodByKey =
      <String, CalendarSnapshotDocument>{};
  final Map<String, Future<CalendarSnapshotDocument?>> _restoreFlights =
      <String, Future<CalendarSnapshotDocument?>>{};
  final Map<String, Future<CalendarSnapshotDocument>> _writeFlights =
      <String, Future<CalendarSnapshotDocument>>{};

  CalendarSnapshotDocument? peek(CalendarSnapshotIdentity identity) =>
      _lastGoodByKey[identity.storageKey];

  Future<CalendarSnapshotDocument?> restore(CalendarSnapshotIdentity identity) {
    final memory = peek(identity);
    if (memory != null) return SynchronousFuture(memory);
    final key = identity.storageKey;
    final inFlight = _restoreFlights[key];
    if (inFlight != null) return inFlight;
    final next = _restore(identity).whenComplete(() {
      _restoreFlights.remove(key);
    });
    _restoreFlights[key] = next;
    return next;
  }

  Future<CalendarSnapshotDocument?> _restore(
    CalendarSnapshotIdentity identity,
  ) async {
    final key = identity.storageKey;
    final raw = await _store.read(key);
    if (raw == null || raw.trim().isEmpty) return null;
    final document = decodeAndValidate(raw, expectedIdentity: identity);
    if (document == null) return null;
    final promotedWhileReading = _lastGoodByKey[key];
    if (promotedWhileReading != null) return promotedWhileReading;
    _lastGoodByKey[key] = document;
    return document;
  }

  Future<CalendarSnapshotDocument> promote(
    CalendarSnapshotCandidate candidate,
  ) {
    final key = candidate.identity.storageKey;
    final priorWrite = _writeFlights[key];
    final next = (() async {
      if (priorWrite != null) {
        try {
          await priorWrite;
        } catch (_) {
          // A failed prior candidate must not block a later valid promotion.
        }
      }
      return _promote(candidate);
    })();
    _writeFlights[key] = next;
    unawaited(
      next.then<void>(
        (_) => _clearWriteFlight(key, next),
        onError: (Object _, StackTrace stackTrace) =>
            _clearWriteFlight(key, next),
      ),
    );
    return next;
  }

  void _clearWriteFlight(String key, Future<CalendarSnapshotDocument> flight) {
    if (identical(_writeFlights[key], flight)) {
      _writeFlights.remove(key);
    }
  }

  Future<CalendarSnapshotDocument> _promote(
    CalendarSnapshotCandidate candidate,
  ) async {
    final encoded = encodeCandidate(candidate);
    final document = decodeAndValidate(
      encoded,
      expectedIdentity: candidate.identity,
    );
    if (document == null) {
      throw StateError('Refusing to promote an incomplete calendar snapshot.');
    }

    final key = candidate.identity.storageKey;
    var current = _lastGoodByKey[key];
    if (current == null) {
      final currentRaw = await _store.read(key);
      if (currentRaw != null) {
        current = decodeAndValidate(
          currentRaw,
          expectedIdentity: candidate.identity,
        );
      }
    }
    if (current != null && current.generation > candidate.generation) {
      throw StateError(
        'Refusing to replace a newer calendar snapshot generation.',
      );
    }

    await _store.write(key, encoded);
    final confirmedRaw = await _store.read(key);
    final confirmed = confirmedRaw == null
        ? null
        : decodeAndValidate(confirmedRaw, expectedIdentity: candidate.identity);
    if (confirmed == null || confirmed.digest != document.digest) {
      throw StateError('Calendar snapshot persistence was not confirmed.');
    }

    _lastGoodByKey[key] = confirmed;
    return confirmed;
  }

  String encodeCandidate(CalendarSnapshotCandidate candidate) {
    if (!candidate.coverage.isValid) {
      throw StateError('Calendar snapshot coverage is invalid.');
    }
    if (!candidate.completedLanes.containsAll(calendarSnapshotRequiredLanes)) {
      throw StateError('Calendar snapshot is missing required lanes.');
    }
    if (candidate.generation < 1) {
      throw StateError('Calendar snapshot generation must be positive.');
    }

    final flows = candidate.payload['flows'];
    final notes = candidate.payload['notes'];
    if (flows is! List || notes is! Map) {
      throw StateError('Calendar snapshot payload is malformed.');
    }
    final eventCount = _serializedEventCount(notes);
    final lanes = candidate.completedLanes.toList()..sort();
    final document = <String, dynamic>{
      ...candidate.payload,
      'schemaVersion': calendarWarmStartCacheSchemaVersion,
      'projectRef': candidate.identity.projectRef,
      'userId': candidate.identity.userId,
      'savedAt': (candidate.savedAt ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
      'loadCompleted': true,
      'coverageStartUtc': candidate.coverage.startUtc.toUtc().toIso8601String(),
      'coverageEndUtc': candidate.coverage.endUtc.toUtc().toIso8601String(),
      'completedLanes': lanes,
      'eventCount': eventCount,
      'flowCount': flows.length,
      'generation': candidate.generation,
      'source': candidate.source,
    };
    document['payloadDigest'] = _stableDocumentDigest(document);
    return jsonEncode(document);
  }

  CalendarSnapshotDocument? decodeAndValidate(
    String raw, {
    required CalendarSnapshotIdentity expectedIdentity,
  }) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final json = Map<String, dynamic>.from(decoded);
      if ((json['schemaVersion'] as num?)?.toInt() !=
          calendarWarmStartCacheSchemaVersion) {
        return null;
      }
      if (json['loadCompleted'] != true) return null;
      if ((json['projectRef'] as String?)?.trim() !=
          expectedIdentity.projectRef) {
        return null;
      }
      if ((json['userId'] as String?)?.trim() != expectedIdentity.userId) {
        return null;
      }

      final start = DateTime.tryParse(
        (json['coverageStartUtc'] as String?) ?? '',
      );
      final end = DateTime.tryParse((json['coverageEndUtc'] as String?) ?? '');
      if (start == null || end == null || !end.isAfter(start)) return null;

      final lanes = (json['completedLanes'] as List?)
          ?.whereType<String>()
          .toSet();
      if (lanes == null || !lanes.containsAll(calendarSnapshotRequiredLanes)) {
        return null;
      }

      final flows = json['flows'];
      final notes = json['notes'];
      if (flows is! List || notes is! Map) return null;
      if ((json['flowCount'] as num?)?.toInt() != flows.length) return null;
      if ((json['eventCount'] as num?)?.toInt() !=
          _serializedEventCount(notes)) {
        return null;
      }
      if (((json['generation'] as num?)?.toInt() ?? 0) < 1) return null;

      final digest = (json['payloadDigest'] as String?)?.trim();
      if (digest == null || digest.isEmpty) return null;
      final withoutDigest = Map<String, dynamic>.from(json)
        ..remove('payloadDigest');
      if (_stableDocumentDigest(withoutDigest) != digest) return null;
      return CalendarSnapshotDocument._(json);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  Future<String?> debugReadRaw(CalendarSnapshotIdentity identity) =>
      _store.read(identity.storageKey);

  @visibleForTesting
  Future<void> debugWriteRaw(
    CalendarSnapshotIdentity identity,
    String raw,
  ) async {
    await _store.write(identity.storageKey, raw);
    _lastGoodByKey.remove(identity.storageKey);
  }

  @visibleForTesting
  void debugReplaceStore(CalendarSnapshotStore store) {
    _store = store;
    _lastGoodByKey.clear();
    _restoreFlights.clear();
    _writeFlights.clear();
  }

  void clearRetainedSnapshotMemory() {
    _lastGoodByKey.clear();
    _restoreFlights.clear();
  }
}

int _serializedEventCount(Map<dynamic, dynamic> notes) {
  var count = 0;
  for (final value in notes.values) {
    if (value is List) count += value.length;
  }
  return count;
}

String _stableDocumentDigest(Map<String, dynamic> document) {
  final bytes = utf8.encode(jsonEncode(document));
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash = (((hash ^ byte) << 5) - (hash ^ byte)) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
