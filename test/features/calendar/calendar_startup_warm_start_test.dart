import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_visible_state_policy.dart';

void main() {
  const completeCommitMarker =
      "commitVisibleCalendarState(\n        'complete'";

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
    expect(startup, contains('await _initialPersistedViewStateLoad;'));
    expect(
      startup,
      contains('_syncAcceptedInviteCalendarImportsInBackground(reason)'),
    );
    expect(startup, contains('final keepWarmStartVisible'));
    expect(
      startup,
      contains("source: 'startup_focused_authoritative:\$reason'"),
    );
    expect(startup, contains("source: 'startup_backfill:\$reason'"));
    expect(
      startup,
      contains('await _awaitInitialViewportSettlementForFirstPaint();'),
    );
    expect(startup, contains('if (!keepWarmStartVisible) {'));
    expect(
      startup.indexOf('await _initialPersistedViewStateLoad;'),
      lessThan(startup.indexOf("await _restoreWarmStartCacheIfAvailable")),
    );
    expect(
      startup.indexOf("await _restoreWarmStartCacheIfAvailable"),
      lessThan(
        startup.indexOf('_syncAcceptedInviteCalendarImportsInBackground'),
      ),
    );
    expect(
      startup.indexOf('_syncAcceptedInviteCalendarImportsInBackground'),
      lessThan(startup.indexOf('final keepWarmStartVisible')),
    );
    expect(
      startup.indexOf('final keepWarmStartVisible'),
      lessThan(
        startup.indexOf("source: 'startup_focused_authoritative:\$reason'"),
      ),
    );
    expect(
      startup.indexOf("source: 'startup_focused_authoritative:\$reason'"),
      lessThan(
        startup.indexOf(
          'await _awaitInitialViewportSettlementForFirstPaint();',
        ),
      ),
    );
    expect(
      startup.indexOf('await _awaitInitialViewportSettlementForFirstPaint();'),
      lessThan(startup.indexOf("source: 'startup_backfill:\$reason'")),
    );
    expect(startup, isNot(contains('startup_cold_authoritative')));
    expect(
      startup,
      isNot(contains("await _loadFromDisk(source: 'startup:\$reason')")),
    );
  });

  test('event hydration publishes only after standalone lane completes', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final load = _sourceBetween(
      source,
      'Future<void> _loadFromDisk({',
      '/// Allows other screens (e.g., Settings) to trigger a fresh sync',
    );

    expect(load, isNot(contains("commitVisibleCalendarState('flow_events')")));
    expect(load, contains(completeCommitMarker));
    expect(
      load.indexOf('final standaloneResult = await standaloneFuture'),
      lessThan(load.indexOf(completeCommitMarker)),
    );
    expect(load, isNot(contains('fastStartupMode')));
    expect(load, contains('final focusWindow = focusedStartupMode'));
    expect(load, contains('_computeStartupVisibleHydrationWindow()'));
    expect(load, contains('_clampHydrationWindowToFocus'));
    expect(load, contains('_expandHydrationWindowToInclude'));
  });

  test('portrait calendar centers its lazy year range on restored state', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final scroll = _sourceBetween(
      source,
      'Widget _buildCalendarScrollView() {',
      'Map<int, FlowData> _buildCalendarFlowChromeIndex()',
    );

    expect(
      scroll,
      contains(
        'final baseYear = _calendarScrollBaseYear ?? _lastViewKy ?? kToday.kYear;',
      ),
    );
    expect(scroll, contains('final kYear = baseYear - (i + 1);'));
    expect(scroll, contains('kYear: baseYear,'));
    expect(scroll, contains('final kYear = baseYear + (i + 1);'));
    expect(scroll, isNot(contains('final kYear = kToday.kYear - (i + 1);')));
    expect(scroll, isNot(contains('final kYear = kToday.kYear + (i + 1);')));
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

  test('visible snapshot policy requires every event lane to complete', () {
    expect(
      shouldPublishCompletedVisibleCalendarSnapshot(loadComplete: false),
      isFalse,
      reason: 'transient empty hydration must not erase visible events',
    );
    expect(
      shouldPublishCompletedVisibleCalendarSnapshot(loadComplete: true),
      isTrue,
      reason: 'a completed refresh may confirm the true empty state',
    );
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
      reason:
          'An authoritative standalone result may still remove stale painted '
          'events; only partial-authority startup backfill preserves them.',
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

  test('startup backfill complete commit preserves painted standalone lane', () {
    expect(
      shouldPreservePaintedStandaloneLaneForHydrationCommit(
        source: 'startup_backfill:init',
        commitPhase: 'complete',
        hasPaintedStandaloneLane: true,
        standaloneLaneAuthoritative: false,
      ),
      isTrue,
      reason:
          'Startup backfill is a partial-authority refresh while warm state is '
          'painted; it cannot delete standalone/reminder events unless that '
          'lane was loaded authoritatively.',
    );
  });

  test(
    'warm startup reminder sync may update local cache without prompting',
    () {
      final source = File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsStringSync();
      final startup = _sourceBetween(
        source,
        'Future<void> _runStartupPipeline(String reason) async {',
        'String? _canonicalDawnHouseRiteDetailForLoadedEvent',
      );
      final postProcessing = _sourceBetween(
        source,
        'Future<void> finishNonCriticalPostProcessing() async {',
        'await finishNonCriticalPostProcessing();',
      );

      expect(
        startup,
        isNot(contains('updateLocalCache: !keepWarmStartVisible')),
        reason:
            'Warm startup may avoid destructive reloads, but authorized '
            'reminder occurrences still need to materialize locally.',
      );
      expect(
        postProcessing,
        isNot(contains('skipped reminder regen after warm-start backfill')),
        reason:
            'Warm-start backfill must not globally suppress local reminder lane '
            'materialization.',
      );
    },
  );

  test('load from disk never publishes a flow-only event candidate', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final load = _sourceBetween(
      source,
      'Future<void> _loadFromDisk({',
      '/// Allows other screens (e.g., Settings) to trigger a fresh sync',
    );

    expect(load, contains('final hasPaintedStandaloneLaneAtLoadStart'));
    expect(load, contains('final hasPaintedEventSnapshotAtLoadStart'));
    expect(load, contains('shouldPublishCompletedVisibleCalendarSnapshot'));
    expect(
      load,
      contains('shouldPreservePaintedStandaloneLaneForHydrationCommit'),
    );
    expect(load, contains('_mergePaintedStandaloneLaneInto(newNotes)'));
    expect(load, contains('hasPaintedStandaloneLaneAtLoadStart'));
    expect(load, isNot(contains("commitVisibleCalendarState('flow_events')")));
    expect(load, contains(completeCommitMarker));
    expect(
      load.indexOf('final hasPaintedEventSnapshotAtLoadStart'),
      lessThan(load.indexOf('shouldPublishCompletedVisibleCalendarSnapshot')),
    );
    expect(
      load.indexOf('shouldPreservePaintedStandaloneLaneForHydrationCommit'),
      lessThan(load.indexOf(completeCommitMarker)),
    );
  });

  test('deferred startup idle gate is bounded', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final wait = _sourceBetween(
      source,
      'Future<void> _waitForFirstRasterizedFrameForDeferredStartup() async {',
      'void _restoreMyFlowsFilingSnapshotCacheAfterFirstFrame({',
    );

    expect(wait, contains('waitUntilFirstFrameRasterized.timeout'));
    expect(wait, contains('binding.endOfFrame.timeout'));
    expect(wait, contains('SchedulerBinding.instance'));
    expect(wait, contains('.scheduleTask<void>('));
    expect(
      wait,
      contains('.timeout(const Duration(milliseconds: 250))'),
      reason:
          'A browser that never reaches an idle slot must not strand calendar '
          'hydration behind the first-frame deferral gate.',
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
