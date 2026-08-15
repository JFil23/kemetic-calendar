import 'calendar_hydration_diagnostics.dart';

enum CalendarHydrationPublicationPhase { flowEvents, complete }

/// Describes how much of the in-memory calendar has been confirmed by the
/// server in the current session.
///
/// A restored warm snapshot deliberately remains [none]. It is useful local
/// state, but it must never authorize overwriting the last full-horizon cache.
enum CalendarHydrationAuthorityScope { none, visibleWindow, fullHorizon }

typedef CalendarHydrationWindow = ({DateTime startUtc, DateTime endUtc});

/// One reason an item must not be published into the visible calendar.
///
/// Rules are evaluated in order and stop at the first match. Keeping the
/// bucket traversal here gives notes, reminders, flows, and future calendar
/// items one shared publication mechanism while their domain-specific rules
/// remain small predicates.
typedef CalendarItemSuppressionRule<T> = bool Function(String dayKey, T item);

typedef CalendarBucketReducer<T> =
    List<T> Function(String dayKey, List<T> items);

typedef CalendarPendingSourceConflictRule<T> =
    bool Function(
      String sourceDayKey,
      T sourceItem,
      String pendingDayKey,
      T pendingItem,
    );

/// Resolves an exact stable-identity match between a source row and a pending
/// row according to the authority represented by the source projection.
enum CalendarPendingIdentityConflictResolution {
  /// Live server hydration has observed the row, so the pending intent is
  /// confirmed and no longer needs to be overlaid.
  sourceConfirmsPending,

  /// A restored snapshot can be older than its separately durable overlay, so
  /// the pending row replaces every matching source row and remains pending.
  pendingReplacesSource,
}

final class CalendarPendingVisibleItem<T> {
  const CalendarPendingVisibleItem({required this.dayKey, required this.item});

  final String dayKey;
  final T item;
}

final class CalendarVisibleProjection<T> {
  CalendarVisibleProjection._({
    required this.buckets,
    required this.preservedPendingItems,
    required Iterable<String> confirmedPendingIdentities,
  }) : confirmedPendingIdentities = List<String>.unmodifiable(
         confirmedPendingIdentities,
       );

  final Map<String, List<T>> buckets;
  final int preservedPendingItems;
  final List<String> confirmedPendingIdentities;

  int get confirmedPendingItems => confirmedPendingIdentities.length;
}

/// Composes one visible projection from server-owned buckets and optimistic
/// creates, then runs the shared per-day reducer and final suppression rules.
///
/// By default, a stable identity observed anywhere in [source] confirms the
/// corresponding pending item. Snapshot restoration can instead declare its
/// separately durable pending overlay newer than the source. Nothing in the
/// source or pending collections is mutated.
CalendarVisibleProjection<T> deriveVisibleCalendarProjection<T>({
  required Map<String, List<T>> source,
  required Iterable<CalendarPendingVisibleItem<T>> pendingItems,
  required String? Function(T item) stableIdentityOf,
  required Iterable<CalendarItemSuppressionRule<T>> suppressionRules,
  CalendarPendingIdentityConflictResolution pendingIdentityConflictResolution =
      CalendarPendingIdentityConflictResolution.sourceConfirmsPending,
  CalendarPendingSourceConflictRule<T>? pendingSourceConflictRule,
  CalendarBucketReducer<T>? reduceBucket,
}) {
  final pending = pendingItems.toList(growable: false);
  final combined = <String, List<T>>{
    for (final entry in source.entries) entry.key: List<T>.of(entry.value),
  };
  final sourceIdentities = <String>{};
  if (pending.isNotEmpty) {
    for (final item in source.values.expand((items) => items)) {
      final identity = stableIdentityOf(item)?.trim();
      if (identity != null && identity.isNotEmpty) {
        sourceIdentities.add(identity);
      }
    }
  }
  final confirmedPendingIdentities = <String>[];
  var preservedPendingItems = 0;
  for (final pendingItem in pending) {
    final identity = stableIdentityOf(pendingItem.item)?.trim();
    if (identity != null &&
        identity.isNotEmpty &&
        sourceIdentities.contains(identity)) {
      if (pendingIdentityConflictResolution ==
          CalendarPendingIdentityConflictResolution.sourceConfirmsPending) {
        confirmedPendingIdentities.add(identity);
        continue;
      }
    }
    if (identity != null &&
        identity.isNotEmpty &&
        pendingIdentityConflictResolution ==
            CalendarPendingIdentityConflictResolution.pendingReplacesSource) {
      combined.removeWhere((_, items) {
        items.removeWhere((item) {
          final candidateIdentity = stableIdentityOf(item)?.trim();
          final exactIdentityMatch =
              candidateIdentity != null &&
              candidateIdentity.isNotEmpty &&
              candidateIdentity == identity;
          return exactIdentityMatch;
        });
        return items.isEmpty;
      });
      if (pendingSourceConflictRule != null) {
        combined.removeWhere((sourceDayKey, items) {
          items.removeWhere(
            (item) => pendingSourceConflictRule(
              sourceDayKey,
              item,
              pendingItem.dayKey,
              pendingItem.item,
            ),
          );
          return items.isEmpty;
        });
      }
    }
    combined.putIfAbsent(pendingItem.dayKey, () => <T>[]).add(pendingItem.item);
    preservedPendingItems++;
  }

  final rules = suppressionRules.toList(growable: false);
  final visible = <String, List<T>>{};
  for (final entry in combined.entries) {
    final reduced = reduceBucket == null
        ? entry.value
        : reduceBucket(entry.key, List<T>.of(entry.value));
    final retained = <T>[];
    for (final item in reduced) {
      var suppressed = false;
      for (final rule in rules) {
        if (!rule(entry.key, item)) continue;
        suppressed = true;
        break;
      }
      if (!suppressed) retained.add(item);
    }
    if (retained.isNotEmpty) visible[entry.key] = retained;
  }
  return CalendarVisibleProjection<T>._(
    buckets: visible,
    preservedPendingItems: preservedPendingItems,
    confirmedPendingIdentities: confirmedPendingIdentities,
  );
}

/// Derives the mutable day buckets that may be painted from an immutable or
/// mutable source projection.
///
/// The source is never mutated or aliased. Empty buckets are omitted because
/// they carry no visible state. Given side-effect-free [suppressionRules], this
/// function is a pure reducer over the source projection.
Map<String, List<T>> deriveVisibleCalendarBuckets<T>({
  required Map<String, List<T>> source,
  required Iterable<CalendarItemSuppressionRule<T>> suppressionRules,
}) => deriveVisibleCalendarProjection<T>(
  source: source,
  pendingItems: <CalendarPendingVisibleItem<T>>[],
  stableIdentityOf: (_) => null,
  suppressionRules: suppressionRules,
).buckets;

/// Merges catalog items by stable identity while preserving source order.
///
/// Duplicate source identities collapse in place, incoming rows replace the
/// matching position, and new incoming identities append in input order.
List<T> mergeCalendarCatalogByIdentity<T, I extends Object>({
  required Iterable<T> source,
  required Iterable<T> incoming,
  required I? Function(T item) identityOf,
}) {
  final merged = <T>[];
  final indexByIdentity = <I, int>{};

  void merge(T item, {required bool retainWithoutIdentity}) {
    final identity = identityOf(item);
    if (identity == null) {
      if (retainWithoutIdentity) merged.add(item);
      return;
    }
    final existingIndex = indexByIdentity[identity];
    if (existingIndex == null) {
      indexByIdentity[identity] = merged.length;
      merged.add(item);
      return;
    }
    merged[existingIndex] = item;
  }

  for (final item in source) {
    merge(item, retainWithoutIdentity: true);
  }
  for (final item in incoming) {
    merge(item, retainWithoutIdentity: false);
  }
  return merged;
}

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

/// Replaces only the serialized viewport buckets in an existing warm cache.
/// Every outside bucket, including unparseable legacy keys, is retained from
/// [previous] without reserialization through the live event model.
Map<String, dynamic>? mergeSerializedWarmCacheViewport({
  required Map<String, dynamic> previous,
  required Map<String, dynamic> fresh,
  required String userId,
  required DateTime viewportStartInclusive,
  required DateTime viewportEndExclusive,
  required DateTime? Function(String key) parseKeyToDay,
}) {
  final previousUserId = (previous['userId'] as String?)?.trim();
  if (previousUserId != null &&
      previousUserId.isNotEmpty &&
      previousUserId != userId) {
    return null;
  }
  final mergedNotes = <String, dynamic>{};
  void copyNotes(Object? raw, {required bool inside}) {
    if (raw is! Map) return;
    raw.forEach((key, value) {
      final stringKey = key.toString();
      final day = parseKeyToDay(stringKey);
      final isInside =
          day != null &&
          !day.isBefore(viewportStartInclusive) &&
          day.isBefore(viewportEndExclusive);
      if (isInside == inside) mergedNotes[stringKey] = value;
    });
  }

  copyNotes(previous['notes'], inside: false);
  copyNotes(fresh['notes'], inside: true);
  return <String, dynamic>{
    ...previous,
    ...fresh,
    'compactionLevel':
        'viewport_checkpoint:${previous['compactionLevel'] ?? 'legacy'}',
    'cacheCenterDay': previous['cacheCenterDay'] ?? fresh['cacheCenterDay'],
    'cachePastDays': previous['cachePastDays'],
    'cacheFutureDays': previous['cacheFutureDays'],
    'notes': mergedNotes,
  };
}

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
