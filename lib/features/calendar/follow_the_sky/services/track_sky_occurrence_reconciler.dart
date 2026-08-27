import 'package:flutter/foundation.dart';

import 'track_sky_materializer.dart';

@immutable
class PersistedTrackSkyChild {
  const PersistedTrackSkyChild({
    required this.clientEventId,
    required this.behaviorPayload,
  });

  final String? clientEventId;
  final Map<String, dynamic>? behaviorPayload;

  String? get validSkyEventId {
    final payload = behaviorPayload;
    if (payload?['kind'] != TrackSkyEventOwnership.behaviorKind ||
        payload?['trackSkySchemaVersion'] !=
            TrackSkyEventOwnership.schemaVersion) {
      return null;
    }
    final value = payload?['skyEventId'];
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }
}

@immutable
class TrackSkyOccurrenceReconciliationPlan {
  const TrackSkyOccurrenceReconciliationPlan({
    required this.expectedSkyEventIds,
    required this.existingSkyEventIds,
    required this.missingOccurrences,
    required this.duplicateSkyEventIds,
    required this.unexpectedSkyEventIds,
  });

  final Set<String> expectedSkyEventIds;
  final Set<String> existingSkyEventIds;
  final List<MaterializedSkyOccurrence> missingOccurrences;
  final Set<String> duplicateSkyEventIds;
  final Set<String> unexpectedSkyEventIds;

  bool get isComplete =>
      missingOccurrences.isEmpty && duplicateSkyEventIds.isEmpty;
}

/// Computes the idempotent write set for one concrete joined Follow Sky flow.
///
/// The caller supplies children for exactly one flow, so stable ownership is
/// `(flow identity, skyEventId)`. Existing rows are never rewritten; only
/// genuinely missing canonical occurrences are returned for creation.
class TrackSkyOccurrenceReconciler {
  const TrackSkyOccurrenceReconciler();

  TrackSkyOccurrenceReconciliationPlan plan({
    required Iterable<MaterializedSkyOccurrence> expectedOccurrences,
    required Iterable<PersistedTrackSkyChild> existingChildren,
  }) {
    final expected = <String, MaterializedSkyOccurrence>{};
    for (final occurrence in expectedOccurrences) {
      final previous = expected[occurrence.skyEventId];
      if (previous != null) {
        throw StateError(
          'Duplicate canonical Follow Sky occurrence: '
          '${occurrence.skyEventId}',
        );
      }
      expected[occurrence.skyEventId] = occurrence;
    }

    final existingIds = <String>{};
    final duplicates = <String>{};
    for (final child in existingChildren) {
      final skyEventId = child.validSkyEventId;
      if (skyEventId == null) continue;
      if (!existingIds.add(skyEventId)) duplicates.add(skyEventId);
    }

    final missing = <MaterializedSkyOccurrence>[
      for (final occurrence in expected.values)
        if (!existingIds.contains(occurrence.skyEventId)) occurrence,
    ]..sort((a, b) => a.startsAtUtc.compareTo(b.startsAtUtc));

    return TrackSkyOccurrenceReconciliationPlan(
      expectedSkyEventIds: Set<String>.unmodifiable(expected.keys),
      existingSkyEventIds: Set<String>.unmodifiable(existingIds),
      missingOccurrences: List<MaterializedSkyOccurrence>.unmodifiable(missing),
      duplicateSkyEventIds: Set<String>.unmodifiable(duplicates),
      unexpectedSkyEventIds: Set<String>.unmodifiable(
        existingIds.difference(expected.keys.toSet()),
      ),
    );
  }
}
