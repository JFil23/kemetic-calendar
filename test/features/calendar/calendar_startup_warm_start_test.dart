import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_hydration_diagnostics.dart';
import 'package:mobile/features/calendar/calendar_visible_state_policy.dart';

void main() {
  test('startup restores warm calendar before live sync and hydration', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final startup = _sourceBetween(
      source,
      'Future<void> _runStartupPipeline(String reason) async {',
      'String? _canonicalDawnHouseRiteDetailForLoadedEvent',
    );

    expect(
      startup,
      contains(
        "await _restoreWarmStartCacheIfAvailable(reason: 'startup_gate:\$reason')",
      ),
    );
    expect(
      startup,
      contains('_syncAcceptedInviteCalendarImportsInBackground(reason)'),
    );
    expect(startup, contains("source: 'startup:\$reason'"));
    expect(startup, contains('_runProgressiveStartupBackfill('));
    expect(startup, isNot(contains('final keepWarmStartVisible')));
    expect(
      startup.indexOf("await _restoreWarmStartCacheIfAvailable"),
      lessThan(startup.indexOf("source: 'startup:\$reason'")),
    );
    expect(
      startup.indexOf("source: 'startup:\$reason'"),
      lessThan(startup.indexOf('_runProgressiveStartupBackfill(')),
    );
    expect(
      startup.indexOf('_runProgressiveStartupBackfill('),
      lessThan(
        startup.indexOf('_syncAcceptedInviteCalendarImportsInBackground'),
      ),
      reason: 'invite import must not contend with critical hydration',
    );
    expect(
      startup.indexOf('await _loadMyFlowsFilingSnapshot()'),
      lessThan(
        startup.indexOf('_syncAcceptedInviteCalendarImportsInBackground'),
      ),
      reason: 'invite import starts only after startup database reads finish',
    );
  });

  test('no-op invite import sync does not publish calendar invalidation', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final sync = _sourceBetween(
      source,
      'void _syncAcceptedInviteCalendarImportsInBackground(String reason) {',
      'String? _canonicalDawnHouseRiteDetailForLoadedEvent',
    );

    expect(sync, contains('final changed = await ShareRepo'));
    expect(sync, contains('if (!changed) return;'));
    expect(
      sync.indexOf('if (!changed) return;'),
      lessThan(sync.indexOf('await _loadCalendarState()')),
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
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final hydration = _sourceBetween(
      source,
      'Future<void> _loadFromDiskInner({',
      'if (source.startsWith(\'shared_calendar_event_tap\'))',
    );

    final flowHydration = hydration.indexOf(
      'final eventsByFlowId = await loadFlowEvents();',
    );
    final standaloneHydration = hydration.indexOf(
      'final standaloneFuture = repo.getStandaloneEventsForDateRangeAll(',
    );
    final standaloneCompletion = hydration.indexOf(
      'final standaloneFetchResult = await standaloneFuture;',
    );
    final flowAccounting = hydration.indexOf(
      'final flowEventCountsResult = await _flowsRepo',
    );

    expect(flowHydration, greaterThanOrEqualTo(0));
    expect(standaloneHydration, greaterThan(flowHydration));
    expect(standaloneCompletion, greaterThan(standaloneHydration));
    expect(flowAccounting, greaterThan(standaloneCompletion));
    expect(hydration, isNot(contains('final flowEventsFuture =')));
    expect(hydration, isNot(contains('_clampHydrationWindowToFocus')));
    expect(
      hydration,
      contains('includeSavedTimestamps: !fastStartupMode'),
      reason: 'exact saved-flow chronology cannot gate Phase A authority',
    );
    expect(
      hydration,
      contains('evaluatedResult: evaluatedCompleteness'),
      reason: 'bounded diagnostics cannot decide application completeness',
    );
    expect(
      hydration,
      contains(
        'flowWindow =\n'
        '            focusWindow ??\n'
        '            _computeFlowHydrationWindow',
      ),
    );
    expect(
      hydration,
      contains(
        'final standaloneWindow =\n'
        '          focusWindow ?? _computeStandaloneHydrationWindow(newFlows)',
      ),
    );
    expect(
      RegExp(
        r'_loadCoordinator\.hasQueuedRequest',
      ).allMatches(hydration).length,
      greaterThanOrEqualTo(3),
      reason:
          'backfill must check before flow, between lanes, and before merge',
    );
  });

  test('partial authority cannot reach any warm-cache write path', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
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
    expect(
      RegExp(r'shouldPersistWarmStartCache').allMatches(persist).length,
      greaterThanOrEqualTo(2),
      reason: 'persistence is checked before and after the prefs await',
    );
    expect(source, contains('_warmStartCacheDebounceTimer?.cancel()'));
  });

  test('Phase B is chunked and owns its coordinator cancellation', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final backfill = _sourceBetween(
      source,
      'Future<bool> _runProgressiveStartupBackfill({',
      'void _syncAcceptedInviteCalendarImportsInBackground',
    );

    expect(backfill, contains('chunkDays: 75'));
    expect(backfill, contains('_loadCoordinator.requestRevision'));
    expect(backfill, contains('_loadCoordinator.hasQueuedRequest'));
    expect(backfill, contains('await _loadFromDisk(source: source'));
    expect(backfill, contains("cancellationReason: 'newer_request'"));
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
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final snapshot = _sourceBetween(
      source,
      'Map<String, dynamic> _buildWarmStartSnapshot({',
      'void _scheduleWarmStartCacheSave()',
    );
    final startup = _sourceBetween(
      source,
      'Future<void> _runStartupPipeline(String reason) async {',
      'String? _canonicalDawnHouseRiteDetailForLoadedEvent',
    );

    expect(snapshot, contains("'cacheSavedAt': cacheSavedAt"));
    expect(snapshot, contains("'lastAuthoritativeHydrationAt'"));
    expect(snapshot, contains("'lastAccountingAuthorityAt'"));
    expect(snapshot, contains("'accountingStale': _accountingStale"));
    expect(startup, contains('CalendarHydrationAuthorityScope.visibleWindow'));
    expect(source, contains("debugReason: 'startup_backfill_complete'"));
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
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final loadFlowEvents = _sourceBetween(
      source,
      'Future<Map<int, List<FlowEventRow>>> loadFlowEvents() async {',
      'final standaloneWindow =',
    );

    expect(loadFlowEvents, contains('getEventsForFlowIds('));
    expect(loadFlowEvents, isNot(contains('getEventsForFlow(')));
    expect(loadFlowEvents, isNot(contains('flow_fallback_')));
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
