import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_hydration_diagnostics.dart';
import 'package:mobile/features/calendar/calendar_visible_state_policy.dart';

void main() {
  test('startup restores warm calendar before live sync and hydration', () {
    final source = _calendarHydrationSource();
    final startup = _sourceBetween(
      source,
      'Future<void> _startHydrationEngine(String reason) async {',
      'String _horizonDiagnosticSource',
    );

    expect(
      startup,
      contains(
        "await _restoreWarmStartCacheIfAvailable(reason: 'startup_gate:\$reason')",
      ),
    );
    expect(startup, contains('_CalendarHydrationRequest.provisionalViewport'));
    expect(startup, contains('_CalendarHydrationRequest.catalogReconcile'));
    expect(startup, contains('unawaited('));
    expect(startup, contains('_runBackgroundHydration('));
    expect(
      startup.indexOf("await _restoreWarmStartCacheIfAvailable"),
      lessThan(
        startup.indexOf('_CalendarHydrationRequest.provisionalViewport'),
      ),
    );
    expect(
      startup.indexOf('_CalendarHydrationRequest.provisionalViewport'),
      lessThan(startup.indexOf('_CalendarHydrationRequest.catalogReconcile')),
    );
    expect(
      startup.indexOf('_CalendarHydrationRequest.catalogReconcile'),
      lessThan(startup.indexOf('_runBackgroundHydration(')),
      reason: 'background work begins only after visible authority',
    );
  });

  test('no-op invite import sync does not publish calendar invalidation', () {
    final source = _calendarHydrationSource();
    final sync = _sourceBetween(
      source,
      'Future<void> _syncAcceptedInviteCalendarImports(String reason) async {',
      'String? _canonicalDawnHouseRiteDetailForLoadedEvent',
    );

    expect(sync, contains('final changed = await ShareRepo'));
    expect(sync, contains('if (!changed) return;'));
    expect(
      sync.indexOf('if (!changed) return;'),
      lessThan(sync.indexOf('await _refreshCalendarStateFromServer()')),
    );
    expect(sync, contains('CalendarInvalidationReason.calendarImportSynced'));
  });

  test('warm snapshot remains visible when only flow events are ready', () {
    expect(
      shouldPublishVisibleCalendarHydration(
        phase: CalendarHydrationPublicationPhase.flowEvents,
        loadComplete: false,
      ),
      isFalse,
      reason: 'a partial server lane cannot replace the painted local state',
    );
  });

  test('cold startup does not expose a flow-only server snapshot', () {
    expect(
      shouldPublishVisibleCalendarHydration(
        phase: CalendarHydrationPublicationPhase.flowEvents,
        loadComplete: false,
      ),
      isFalse,
    );
  });

  test('complete flow and standalone hydration publishes atomically', () {
    expect(
      shouldPublishVisibleCalendarHydration(
        phase: CalendarHydrationPublicationPhase.complete,
        loadComplete: true,
      ),
      isTrue,
    );
  });

  test('database-heavy startup reads are sequenced', () {
    final hydration = File(
      'lib/features/calendar/hydration/calendar_hydration_engine.dart',
    ).readAsStringSync();

    expect(hydration, contains('.fetchWindow('));
    expect(
      hydration,
      contains('cancellationCheck: jobContext.throwIfCancelled'),
    );
    expect(hydration, isNot(contains('repo.getEventsForFlowIds(')));
    expect(
      hydration,
      isNot(contains('repo.getStandaloneEventsForDateRangeAll(')),
    );
    expect(hydration, isNot(contains('final flowEventsFuture =')));
    expect(hydration, isNot(contains('_clampHydrationWindowToFocus')));
    expect(hydration, contains('final focusWindow = ('));
    expect(hydration, contains('final standaloneWindow = focusWindow'));
    expect(
      hydration,
      contains('evaluatedResult: evaluatedCompleteness'),
      reason: 'bounded diagnostics cannot decide application completeness',
    );
    expect(
      RegExp(
        r'jobContext\.(?:isCurrent|throwIfCancelled)',
      ).allMatches(hydration).length,
      greaterThanOrEqualTo(3),
      reason:
          'backfill must check before flow, between lanes, and before merge',
    );
  });

  test('generic cache writes remain full-horizon only', () {
    final source = _calendarHydrationSource();
    final schedule = _sourceBetween(
      source,
      'void _scheduleWarmStartCacheSave() {',
      'Future<void> _flushPendingWarmStartCacheSave',
    );
    final flush = _sourceBetween(
      source,
      'Future<void> _flushPendingWarmStartCacheSave',
      'Future<void> _persistWarmStartCacheNow',
    );
    final persist = _sourceBetween(
      source,
      'Future<void> _persistWarmStartCacheNow',
      'Future<void> _restoreWarmStartCacheIfAvailable',
    );

    expect(schedule, contains('shouldPersistWarmStartCache'));
    expect(flush, contains('shouldPersistWarmStartCache'));
    expect(persist, contains('bool writeIsAuthorized()'));
    expect(
      RegExp(r'writeIsAuthorized\(\)').allMatches(persist).length,
      greaterThanOrEqualTo(3),
      reason: 'persistence is checked before and after the prefs await',
    );
    expect(source, contains('_warmStartCacheDebounceTimer?.cancel()'));
  });

  test('fresh viewport commit writes one fail-closed healing checkpoint', () {
    final source = _calendarHydrationSource();
    final engine = File(
      'lib/features/calendar/hydration/calendar_hydration_engine.dart',
    ).readAsStringSync();
    final persist = _sourceBetween(
      source,
      'Future<void> _persistWarmStartCacheNow',
      'Future<void> _restoreWarmStartCacheIfAvailable',
    );

    expect(
      engine,
      contains("debugReason: 'hydration_viewport_server_current'"),
    );
    expect(engine, contains('allowServerCurrentViewport: true'));
    expect(persist, contains('mayPersistServerCurrentViewport'));
    expect(
      RegExp(
        r'allowServerCurrentViewport: allowServerCurrentViewport',
      ).allMatches(persist).length,
      greaterThanOrEqualTo(3),
      reason: 'authority is revalidated before, during, and after persistence',
    );
  });

  test('background horizon is chunked and scheduler-owned', () {
    final source = _calendarHydrationSource();
    final backfill = _sourceBetween(
      source,
      'Future<bool> _hydrateFullHorizon({',
      'Future<void> _syncAcceptedInviteCalendarImports',
    );

    expect(backfill, contains('chunkDays: 75'));
    expect(backfill, contains('_CalendarHydrationRequest.background('));
    expect(backfill, contains('CalendarHydrationIntentKind.horizonChunk'));
    expect(
      backfill,
      contains('if (disposition == CalendarHydrationJobDisposition.cancelled)'),
    );
    expect(backfill, contains('index--;'));
  });

  test('an incomplete complete phase preserves warm visible state', () {
    expect(
      shouldPublishVisibleCalendarHydration(
        phase: CalendarHydrationPublicationPhase.complete,
        loadComplete: false,
      ),
      isFalse,
      reason: 'transient empty hydration must not erase visible events',
    );
  });

  test('calendar completeness requires all three calendar authorities', () {
    expect(
      calendarHydrationIsSemanticallyComplete(
        catalogComplete: true,
        flowEvents: HydrationFetchStatus.successNonempty,
        standalone: HydrationFetchStatus.successfulEmpty,
      ),
      isTrue,
    );

    for (final failedStatus in <HydrationFetchStatus>[
      HydrationFetchStatus.failed,
      HydrationFetchStatus.unauthenticated,
      HydrationFetchStatus.notRun,
    ]) {
      expect(
        calendarHydrationIsSemanticallyComplete(
          catalogComplete: true,
          flowEvents: failedStatus,
          standalone: HydrationFetchStatus.successfulEmpty,
        ),
        isFalse,
      );
      expect(
        calendarHydrationIsSemanticallyComplete(
          catalogComplete: true,
          flowEvents: HydrationFetchStatus.successfulEmpty,
          standalone: failedStatus,
        ),
        isFalse,
      );
    }

    expect(
      calendarHydrationIsSemanticallyComplete(
        catalogComplete: false,
        flowEvents: HydrationFetchStatus.successfulEmpty,
        standalone: HydrationFetchStatus.successfulEmpty,
      ),
      isFalse,
    );
  });

  test('warm-cache metadata separates save time from server authority', () {
    final source = _calendarHydrationSource();
    final snapshot = _sourceBetween(
      source,
      'Map<String, dynamic> _buildWarmStartSnapshot({',
      'void _scheduleWarmStartCacheSave()',
    );

    expect(snapshot, contains("'cacheSavedAt': cacheSavedAt"));
    expect(snapshot, contains("'lastAuthoritativeHydrationAt'"));
    expect(snapshot, contains("'lastAccountingAuthorityAt'"));
    expect(snapshot, contains("'accountingStale': _accountingStale"));
    expect(snapshot, contains("'catalogFingerprint'"));
    expect(snapshot, contains("'cacheAuthority'"));
    expect(snapshot, contains("'authoritativeViewportStartUtc'"));
    expect(snapshot, contains("'authoritativeViewportEndUtc'"));
    expect(source, contains('_hydrationController.validateCacheWrite('));
    expect(source, contains("debugReason: 'hydration_horizon_complete'"));
  });

  test('accounting failure only applies cached counts', () {
    expect(
      shouldApplyHydrationAccountingResult(
        status: HydrationFetchStatus.successfulEmpty,
        hasCachedCounts: false,
      ),
      isTrue,
    );
    expect(
      shouldApplyHydrationAccountingResult(
        status: HydrationFetchStatus.failed,
        hasCachedCounts: true,
      ),
      isTrue,
    );
    expect(
      shouldApplyHydrationAccountingResult(
        status: HydrationFetchStatus.failed,
        hasCachedCounts: false,
      ),
      isFalse,
    );
  });

  test('calendar hydration does not issue per-flow fallback requests', () {
    final hydration = File(
      'lib/features/calendar/hydration/calendar_hydration_engine.dart',
    ).readAsStringSync();

    expect(
      hydration,
      contains('CalendarHydrationRepository.fromUserEventsRepo'),
    );
    expect(hydration, isNot(contains('getEventsForFlow(')));
    expect(hydration, isNot(contains('flow_fallback_')));
  });

  test('import sync complete commit preserves painted standalone lane', () {
    expect(
      shouldPreservePaintedStandaloneLaneForHydrationCommit(
        source: 'invalidation:calendarImportSynced',
        commitPhase: 'complete',
        hasPaintedStandaloneLane: true,
      ),
      isTrue,
    );
    expect(
      shouldPreservePaintedStandaloneLaneForHydrationCommit(
        source: 'invalidation:calendarImportSynced',
        commitPhase: 'flow_events',
        hasPaintedStandaloneLane: true,
      ),
      isFalse,
    );
    expect(
      shouldPreservePaintedStandaloneLaneForHydrationCommit(
        source: 'startup_backfill:init',
        commitPhase: 'complete',
        hasPaintedStandaloneLane: true,
      ),
      isFalse,
    );
    expect(
      shouldPreservePaintedStandaloneLaneForHydrationCommit(
        source: 'invalidation:calendarImportSynced',
        commitPhase: 'complete',
        hasPaintedStandaloneLane: false,
      ),
      isFalse,
    );
  });
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing start marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing end marker: $end');
  return source.substring(startIndex, endIndex);
}

String _calendarHydrationSource() =>
    File('lib/features/calendar/calendar_page.dart').readAsStringSync() +
    File(
      'lib/features/calendar/hydration/calendar_hydration_engine.dart',
    ).readAsStringSync();
