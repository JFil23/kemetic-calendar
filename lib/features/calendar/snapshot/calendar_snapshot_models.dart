import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Half-open server-authoritative coverage persisted with a calendar snapshot.
@immutable
final class CalendarSnapshotCoverageInterval {
  CalendarSnapshotCoverageInterval({
    required DateTime startUtc,
    required DateTime endUtc,
  }) : startUtc = startUtc.toUtc(),
       endUtc = endUtc.toUtc() {
    if (!this.endUtc.isAfter(this.startUtc)) {
      throw ArgumentError.value(
        (startUtc, endUtc),
        'interval',
        'Calendar snapshot coverage must be a non-empty half-open interval.',
      );
    }
  }

  final DateTime startUtc;
  final DateTime endUtc;

  Map<String, Object?> toJson() => <String, Object?>{
    'startUtc': startUtc.toIso8601String(),
    'endUtc': endUtc.toIso8601String(),
  };

  static CalendarSnapshotCoverageInterval? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, Object?>.from(raw);
    final start = DateTime.tryParse(json['startUtc']?.toString() ?? '');
    final end = DateTime.tryParse(json['endUtc']?.toString() ?? '');
    if (start == null || end == null || !end.isAfter(start)) return null;
    return CalendarSnapshotCoverageInterval(startUtc: start, endUtc: end);
  }
}

/// Canonical server + overlay value presented to the durable store.
///
/// The store owns persistence and generations; callers own conversion from
/// application models into JSON-safe records. Records are defensively copied
/// and normalized so shadow parity never depends on map insertion order.
@immutable
final class CalendarSnapshotCommit {
  CalendarSnapshotCommit({
    required String userScope,
    required String serverRevision,
    required String overlayRevision,
    required String catalogFingerprint,
    required String origin,
    required DateTime committedAtUtc,
    required DateTime lastSuccessfulRefreshAtUtc,
    required Iterable<CalendarSnapshotCoverageInterval> coverage,
    required Map<String, List<Map<String, Object?>>> eventsByDay,
    required Iterable<Map<String, Object?>> flows,
    Map<String, Object?> calendarMetadata = const <String, Object?>{},
    Iterable<Map<String, Object?>> overlayRecords = const [],
  }) : userScope = userScope.trim(),
       serverRevision = serverRevision.trim(),
       overlayRevision = overlayRevision.trim(),
       catalogFingerprint = catalogFingerprint.trim(),
       origin = origin.trim(),
       committedAtUtc = committedAtUtc.toUtc(),
       lastSuccessfulRefreshAtUtc = lastSuccessfulRefreshAtUtc.toUtc(),
       coverage = List<CalendarSnapshotCoverageInterval>.unmodifiable(
         _normalizedCoverage(coverage),
       ),
       eventsByDay = _normalizeEvents(eventsByDay),
       flows = List<Map<String, Object?>>.unmodifiable(_normalizeRows(flows)),
       calendarMetadata = _normalizeMap(calendarMetadata),
       overlayRecords = List<Map<String, Object?>>.unmodifiable(
         _normalizeRows(overlayRecords),
       ) {
    if (this.userScope.isEmpty) {
      throw ArgumentError.value(userScope, 'userScope', 'must not be empty');
    }
    if (this.serverRevision.isEmpty) {
      throw ArgumentError.value(
        serverRevision,
        'serverRevision',
        'must not be empty',
      );
    }
    if (this.overlayRevision.isEmpty) {
      throw ArgumentError.value(
        overlayRevision,
        'overlayRevision',
        'must not be empty',
      );
    }
    if (this.catalogFingerprint.isEmpty) {
      throw ArgumentError.value(
        catalogFingerprint,
        'catalogFingerprint',
        'must not be empty',
      );
    }
    if (this.origin.isEmpty) {
      throw ArgumentError.value(origin, 'origin', 'must not be empty');
    }
  }

  final String userScope;
  final String serverRevision;
  final String overlayRevision;
  final String catalogFingerprint;
  final String origin;
  final DateTime committedAtUtc;
  final DateTime lastSuccessfulRefreshAtUtc;
  final List<CalendarSnapshotCoverageInterval> coverage;
  final Map<String, List<Map<String, Object?>>> eventsByDay;
  final List<Map<String, Object?>> flows;
  final Map<String, Object?> calendarMetadata;
  final List<Map<String, Object?>> overlayRecords;

  String get userScopeDigest => calendarSnapshotDigest(userScope);

  String get canonicalDigest => calendarSnapshotDigest(
    calendarCanonicalJson(<String, Object?>{
      'userScopeDigest': userScopeDigest,
      'serverRevision': serverRevision,
      'overlayRevision': overlayRevision,
      'catalogFingerprint': catalogFingerprint,
      'coverage': coverage.map((value) => value.toJson()).toList(),
      'eventsByDay': eventsByDay,
      'flows': flows,
      'calendarMetadata': calendarMetadata,
      'overlayRecords': overlayRecords,
    }),
  );
}

@immutable
final class CalendarSnapshotValue {
  const CalendarSnapshotValue({
    required this.generation,
    required this.serverRevision,
    required this.overlayRevision,
    required this.catalogFingerprint,
    required this.origin,
    required this.committedAtUtc,
    required this.lastSuccessfulRefreshAtUtc,
    required this.coverage,
    required this.eventsByDay,
    required this.flows,
    required this.calendarMetadata,
    required this.overlayRecords,
    required this.canonicalDigest,
    required this.recoveredPreviousGeneration,
  });

  final int generation;
  final String serverRevision;
  final String overlayRevision;
  final String catalogFingerprint;
  final String origin;
  final DateTime committedAtUtc;
  final DateTime lastSuccessfulRefreshAtUtc;
  final List<CalendarSnapshotCoverageInterval> coverage;
  final Map<String, List<Map<String, Object?>>> eventsByDay;
  final List<Map<String, Object?>> flows;
  final Map<String, Object?> calendarMetadata;
  final List<Map<String, Object?>> overlayRecords;
  final String canonicalDigest;
  final bool recoveredPreviousGeneration;

  String get viewRevision => '$serverRevision:$overlayRevision';
}

@immutable
final class CalendarSnapshotCommitResult {
  const CalendarSnapshotCommitResult({
    required this.generation,
    required this.previousGeneration,
    required this.canonicalDigest,
    required this.writtenObjectCount,
    required this.reusedObjectCount,
  });

  final int generation;
  final int? previousGeneration;
  final String canonicalDigest;
  final int writtenObjectCount;
  final int reusedObjectCount;
}

final class CalendarSnapshotConflict implements Exception {
  const CalendarSnapshotConflict({
    required this.expectedGeneration,
    required this.actualGeneration,
  });

  final int? expectedGeneration;
  final int? actualGeneration;

  @override
  String toString() =>
      'CalendarSnapshotConflict(expected=$expectedGeneration, '
      'actual=$actualGeneration)';
}

final class CalendarSnapshotCorrupt implements Exception {
  const CalendarSnapshotCorrupt(this.reason);

  final String reason;

  @override
  String toString() => 'CalendarSnapshotCorrupt($reason)';
}

Map<String, List<Map<String, Object?>>> _normalizeEvents(
  Map<String, List<Map<String, Object?>>> source,
) {
  final result = SplayTreeMap<String, List<Map<String, Object?>>>();
  for (final entry in source.entries) {
    final dayKey = entry.key.trim();
    if (dayKey.isEmpty) continue;
    result[dayKey] = List<Map<String, Object?>>.unmodifiable(
      _normalizeRows(entry.value),
    );
  }
  return Map<String, List<Map<String, Object?>>>.unmodifiable(result);
}

List<Map<String, Object?>> _normalizeRows(
  Iterable<Map<String, Object?>> source,
) {
  final encoded = <({String canonical, Map<String, Object?> value})>[];
  for (final row in source) {
    final value = _normalizeMap(row);
    encoded.add((canonical: calendarCanonicalJson(value), value: value));
  }
  encoded.sort((a, b) => a.canonical.compareTo(b.canonical));
  return encoded.map((entry) => entry.value).toList(growable: false);
}

Map<String, Object?> _normalizeMap(Map source) {
  final sorted = SplayTreeMap<String, Object?>();
  source.forEach((key, value) {
    sorted[key.toString()] = _normalizeJsonValue(value);
  });
  return Map<String, Object?>.unmodifiable(sorted);
}

Object? _normalizeJsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) return _normalizeMap(value);
  if (value is Iterable) {
    return List<Object?>.unmodifiable(value.map(_normalizeJsonValue));
  }
  throw ArgumentError.value(
    value,
    'value',
    'Calendar snapshot records must contain JSON-safe values.',
  );
}

List<CalendarSnapshotCoverageInterval> _normalizedCoverage(
  Iterable<CalendarSnapshotCoverageInterval> source,
) {
  final sorted = source.toList(growable: false)
    ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  final result = <CalendarSnapshotCoverageInterval>[];
  for (final candidate in sorted) {
    if (result.isEmpty) {
      result.add(candidate);
      continue;
    }
    final previous = result.last;
    if (candidate.startUtc.isAfter(previous.endUtc)) {
      result.add(candidate);
      continue;
    }
    result[result.length - 1] = CalendarSnapshotCoverageInterval(
      startUtc: previous.startUtc,
      endUtc: candidate.endUtc.isAfter(previous.endUtc)
          ? candidate.endUtc
          : previous.endUtc,
    );
  }
  return result;
}

String calendarCanonicalJson(Object? value) =>
    jsonEncode(_normalizeJsonValue(value));

String calendarSnapshotDigest(String value) =>
    sha256.convert(utf8.encode(value)).toString();
