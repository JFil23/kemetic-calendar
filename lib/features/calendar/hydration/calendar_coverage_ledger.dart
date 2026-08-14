import 'package:flutter/foundation.dart';

import 'calendar_hydration_models.dart';

/// Immutable, normalized server coverage keyed to exactly one catalog
/// fingerprint. Entries are added only after both hydration lanes commit.
@immutable
class CalendarCoverageLedger {
  CalendarCoverageLedger._({
    required this.catalogFingerprint,
    required List<CalendarHydrationInterval> intervals,
  }) : intervals = List<CalendarHydrationInterval>.unmodifiable(intervals);

  factory CalendarCoverageLedger.empty(String catalogFingerprint) =>
      CalendarCoverageLedger._(
        catalogFingerprint: catalogFingerprint,
        intervals: const <CalendarHydrationInterval>[],
      );

  factory CalendarCoverageLedger.fromIntervals({
    required String catalogFingerprint,
    required Iterable<CalendarHydrationInterval> intervals,
  }) {
    var ledger = CalendarCoverageLedger.empty(catalogFingerprint);
    for (final interval in intervals) {
      ledger = ledger.add(fingerprint: catalogFingerprint, interval: interval);
    }
    return ledger;
  }

  final String catalogFingerprint;
  final List<CalendarHydrationInterval> intervals;

  CalendarCoverageLedger add({
    required String fingerprint,
    required CalendarHydrationInterval interval,
  }) {
    if (fingerprint != catalogFingerprint) {
      return CalendarCoverageLedger.empty(
        fingerprint,
      ).add(fingerprint: fingerprint, interval: interval);
    }
    final sorted = <CalendarHydrationInterval>[...intervals, interval]
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    final normalized = <CalendarHydrationInterval>[];
    for (final candidate in sorted) {
      if (normalized.isEmpty) {
        normalized.add(candidate);
        continue;
      }
      final previous = normalized.last;
      if (!previous.overlaps(candidate) && !previous.touches(candidate)) {
        normalized.add(candidate);
        continue;
      }
      final end = previous.endUtc.isAfter(candidate.endUtc)
          ? previous.endUtc
          : candidate.endUtc;
      normalized[normalized.length - 1] = CalendarHydrationInterval(
        startUtc: previous.startUtc,
        endUtc: end,
      );
    }
    return CalendarCoverageLedger._(
      catalogFingerprint: catalogFingerprint,
      intervals: normalized,
    );
  }

  bool covers(CalendarHydrationInterval interval) =>
      intervals.any((covered) => covered.containsInterval(interval));

  List<CalendarHydrationInterval> gapsWithin(
    CalendarHydrationInterval horizon,
  ) {
    final gaps = <CalendarHydrationInterval>[];
    var cursor = horizon.startUtc;
    for (final covered in intervals) {
      if (!covered.endUtc.isAfter(horizon.startUtc) ||
          !covered.startUtc.isBefore(horizon.endUtc)) {
        continue;
      }
      final coveredStart = covered.startUtc.isBefore(horizon.startUtc)
          ? horizon.startUtc
          : covered.startUtc;
      final coveredEnd = covered.endUtc.isAfter(horizon.endUtc)
          ? horizon.endUtc
          : covered.endUtc;
      if (coveredStart.isAfter(cursor)) {
        gaps.add(
          CalendarHydrationInterval(startUtc: cursor, endUtc: coveredStart),
        );
      }
      if (coveredEnd.isAfter(cursor)) cursor = coveredEnd;
      if (!cursor.isBefore(horizon.endUtc)) break;
    }
    if (cursor.isBefore(horizon.endUtc)) {
      gaps.add(
        CalendarHydrationInterval(startUtc: cursor, endUtc: horizon.endUtc),
      );
    }
    return List<CalendarHydrationInterval>.unmodifiable(gaps);
  }
}
