import 'calendar_hydration_diagnostics.dart';

enum CalendarHydrationPublicationPhase { flowEvents, complete }

/// Describes how much of the in-memory calendar has been confirmed by the
/// server in the current session.
///
/// A restored warm snapshot deliberately remains [none]. It is useful local
/// state, but it must never authorize overwriting the last full-horizon cache.
enum CalendarHydrationAuthorityScope { none, visibleWindow, fullHorizon }

typedef CalendarHydrationWindow = ({DateTime startUtc, DateTime endUtc});

bool shouldPersistWarmStartCache(CalendarHydrationAuthorityScope scope) =>
    scope == CalendarHydrationAuthorityScope.fullHorizon;

bool shouldSetFullServerHydrationSentinel(
  CalendarHydrationAuthorityScope scope,
) => scope == CalendarHydrationAuthorityScope.fullHorizon;

bool shouldClearWarmStartSnapshotVisible(
  CalendarHydrationAuthorityScope scope,
) => scope == CalendarHydrationAuthorityScope.fullHorizon;

bool shouldScheduleCacheSaveOnDataBump(CalendarHydrationAuthorityScope scope) =>
    scope == CalendarHydrationAuthorityScope.fullHorizon;

/// Replaces only the half-open server window while preserving every cached
/// bucket outside it. Unparseable existing keys are retained fail-safe, while
/// incoming buckets outside the authoritative window are ignored.
Map<String, List<T>> mergeHydrationWindowIntoNotes<T>({
  required Map<String, List<T>> existing,
  required Map<String, List<T>> incoming,
  required DateTime windowStartInclusive,
  required DateTime windowEndExclusive,
  required DateTime? Function(String key) parseKeyToDay,
}) {
  assert(windowEndExclusive.isAfter(windowStartInclusive));
  final merged = <String, List<T>>{};
  existing.forEach((key, values) {
    final day = parseKeyToDay(key);
    final insideWindow =
        day != null &&
        !day.isBefore(windowStartInclusive) &&
        day.isBefore(windowEndExclusive);
    if (!insideWindow) merged[key] = List<T>.of(values);
  });
  incoming.forEach((key, values) {
    final day = parseKeyToDay(key);
    final insideWindow =
        day != null &&
        !day.isBefore(windowStartInclusive) &&
        day.isBefore(windowEndExclusive);
    if (insideWindow && values.isNotEmpty) {
      merged[key] = List<T>.of(values);
    }
  });
  return merged;
}

/// Keeps only parseable buckets inside the authoritative horizon. Invalid
/// legacy keys are retained because silently discarding an unparseable bucket
/// would be destructive.
Map<String, List<T>> retainNotesWithinHydrationWindow<T>({
  required Map<String, List<T>> notes,
  required DateTime windowStartInclusive,
  required DateTime windowEndExclusive,
  required DateTime? Function(String key) parseKeyToDay,
}) {
  final retained = <String, List<T>>{};
  notes.forEach((key, values) {
    final day = parseKeyToDay(key);
    final insideWindow =
        day == null ||
        (!day.isBefore(windowStartInclusive) &&
            day.isBefore(windowEndExclusive));
    if (insideWindow && values.isNotEmpty) retained[key] = List<T>.of(values);
  });
  return retained;
}

/// Produces gap-free, non-overlapping chunks for `union - excludeWindow`.
/// All boundaries are half-open and preserve the input instants exactly.
List<CalendarHydrationWindow> buildBackfillChunks({
  required DateTime unionStart,
  required DateTime unionEnd,
  required CalendarHydrationWindow excludeWindow,
  int chunkDays = 75,
}) {
  if (!unionEnd.isAfter(unionStart)) return const [];
  if (chunkDays <= 0) {
    throw ArgumentError.value(chunkDays, 'chunkDays', 'must be positive');
  }

  final excludedStart = excludeWindow.startUtc.isAfter(unionStart)
      ? excludeWindow.startUtc
      : unionStart;
  final excludedEnd = excludeWindow.endUtc.isBefore(unionEnd)
      ? excludeWindow.endUtc
      : unionEnd;
  final hasExcludedIntersection = excludedEnd.isAfter(excludedStart);
  final remaining = <CalendarHydrationWindow>[];
  if (!hasExcludedIntersection) {
    remaining.add((startUtc: unionStart, endUtc: unionEnd));
  } else {
    if (excludedStart.isAfter(unionStart)) {
      remaining.add((startUtc: unionStart, endUtc: excludedStart));
    }
    if (unionEnd.isAfter(excludedEnd)) {
      remaining.add((startUtc: excludedEnd, endUtc: unionEnd));
    }
  }

  final chunks = <CalendarHydrationWindow>[];
  final chunkSpan = Duration(days: chunkDays);
  for (final interval in remaining) {
    var cursor = interval.startUtc;
    while (cursor.isBefore(interval.endUtc)) {
      final candidateEnd = cursor.add(chunkSpan);
      final chunkEnd = candidateEnd.isBefore(interval.endUtc)
          ? candidateEnd
          : interval.endUtc;
      chunks.add((startUtc: cursor, endUtc: chunkEnd));
      cursor = chunkEnd;
    }
  }
  return List<CalendarHydrationWindow>.unmodifiable(chunks);
}

bool hydrationFetchSucceeded(HydrationFetchStatus status) =>
    status == HydrationFetchStatus.successNonempty ||
    status == HydrationFetchStatus.successfulEmpty;

bool calendarHydrationIsSemanticallyComplete({
  required bool catalogComplete,
  required HydrationFetchStatus flowEvents,
  required HydrationFetchStatus standalone,
}) =>
    catalogComplete &&
    hydrationFetchSucceeded(flowEvents) &&
    hydrationFetchSucceeded(standalone);

bool shouldApplyHydrationAccountingResult({
  required HydrationFetchStatus status,
  required bool hasCachedCounts,
}) => hydrationFetchSucceeded(status) || hasCachedCounts;

bool shouldPublishVisibleCalendarHydration({
  required CalendarHydrationPublicationPhase phase,
  required bool loadComplete,
}) {
  // Neither hydration lane owns a visible server snapshot by itself. Local
  // state remains authoritative until both required lanes have produced the
  // complete result for this pass.
  return phase == CalendarHydrationPublicationPhase.complete && loadComplete;
}

bool shouldPreservePaintedStandaloneLaneForHydrationCommit({
  required String source,
  required String commitPhase,
  required bool hasPaintedStandaloneLane,
}) {
  return hasPaintedStandaloneLane &&
      source == 'invalidation:calendarImportSynced' &&
      commitPhase == 'complete';
}
