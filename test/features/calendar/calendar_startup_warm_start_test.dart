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
    expect(startup, contains("source: 'startup_cold_authoritative:\$reason'"));
    expect(startup, contains("source: 'startup_backfill:\$reason'"));
    expect(startup, contains('if (keepWarmStartVisible) {'));
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
        startup.indexOf("source: 'startup_cold_authoritative:\$reason'"),
      ),
    );
    expect(
      startup.indexOf("source: 'startup_cold_authoritative:\$reason'"),
      lessThan(startup.indexOf("source: 'startup_backfill:\$reason'")),
    );
    expect(
      startup,
      isNot(contains("await _loadFromDisk(source: 'startup:\$reason')")),
    );
  });

  test('event hydration may stage flow data internally before standalone', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final load = _sourceBetween(
      source,
      'Future<void> _loadFromDisk({',
      '/// Allows other screens (e.g., Settings) to trigger a fresh sync',
    );

    expect(load, contains("commitVisibleCalendarState('flow_events')"));
    expect(load, contains(completeCommitMarker));
    expect(
      load.indexOf("commitVisibleCalendarState('flow_events')"),
      lessThan(load.indexOf('final standaloneResult = await standaloneFuture')),
    );
    expect(
      load.indexOf('final standaloneResult = await standaloneFuture'),
      lessThan(load.indexOf(completeCommitMarker)),
    );
    expect(load, isNot(contains('fastStartupMode')));
    expect(load, isNot(contains('focusWindow')));
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

  test('flow-only visible commit cannot replace painted event snapshot', () {
    expect(
      shouldCommitFlowOnlyVisibleCalendarState(
        flowAddedCount: 3,
        keepWarmStartSnapshotVisible: false,
        hasPaintedEventSnapshot: false,
      ),
      isTrue,
    );
    expect(
      shouldCommitFlowOnlyVisibleCalendarState(
        flowAddedCount: 3,
        keepWarmStartSnapshotVisible: true,
        hasPaintedEventSnapshot: false,
      ),
      isFalse,
    );
    expect(
      shouldCommitFlowOnlyVisibleCalendarState(
        flowAddedCount: 3,
        keepWarmStartSnapshotVisible: false,
        hasPaintedEventSnapshot: true,
      ),
      isFalse,
    );
    expect(
      shouldCommitFlowOnlyVisibleCalendarState(
        flowAddedCount: 0,
        keepWarmStartSnapshotVisible: false,
        hasPaintedEventSnapshot: false,
      ),
      isFalse,
    );
  });

  test('completed visible snapshot policy preserves last-good events', () {
    expect(
      shouldPublishCompletedVisibleCalendarSnapshot(
        loadComplete: false,
        hasIncomingEventSnapshot: false,
        hasPaintedEventSnapshot: true,
      ),
      isFalse,
      reason: 'transient empty hydration must not erase visible events',
    );
    expect(
      shouldPublishCompletedVisibleCalendarSnapshot(
        loadComplete: false,
        hasIncomingEventSnapshot: true,
        hasPaintedEventSnapshot: true,
      ),
      isFalse,
      reason: 'partial newer data must wait until the snapshot is complete',
    );
    expect(
      shouldPublishCompletedVisibleCalendarSnapshot(
        loadComplete: true,
        hasIncomingEventSnapshot: false,
        hasPaintedEventSnapshot: true,
      ),
      isTrue,
      reason: 'a completed refresh may confirm the true empty state',
    );
    expect(
      shouldPublishCompletedVisibleCalendarSnapshot(
        loadComplete: true,
        hasIncomingEventSnapshot: true,
        hasPaintedEventSnapshot: true,
      ),
      isTrue,
      reason: 'a complete newer snapshot may replace stale event blocks',
    );
    expect(
      shouldPublishCompletedVisibleCalendarSnapshot(
        loadComplete: false,
        hasIncomingEventSnapshot: true,
        hasPaintedEventSnapshot: false,
      ),
      isTrue,
      reason:
          'first paint may use useful incoming events when no prior state exists',
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

  test(
    'load from disk guards flow-only commit with painted standalone lane',
    () {
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
      expect(load, contains('shouldCommitFlowOnlyVisibleCalendarState'));
      expect(load, contains('shouldPublishCompletedVisibleCalendarSnapshot'));
      expect(
        load,
        contains('shouldPreservePaintedStandaloneLaneForHydrationCommit'),
      );
      expect(load, contains('_mergePaintedStandaloneLaneInto(newNotes)'));
      expect(load, contains('hasPaintedStandaloneLaneAtLoadStart'));
      expect(load, contains("commitVisibleCalendarState('flow_events')"));
      expect(load, contains(completeCommitMarker));
      expect(
        load.indexOf('final hasPaintedStandaloneLaneAtLoadStart'),
        lessThan(load.indexOf('shouldCommitFlowOnlyVisibleCalendarState')),
      );
      expect(
        load.indexOf('final hasPaintedEventSnapshotAtLoadStart'),
        lessThan(load.indexOf('shouldPublishCompletedVisibleCalendarSnapshot')),
      );
      expect(
        load.indexOf('shouldCommitFlowOnlyVisibleCalendarState'),
        lessThan(load.indexOf("commitVisibleCalendarState('flow_events')")),
      );
      expect(
        load.indexOf('shouldPreservePaintedStandaloneLaneForHydrationCommit'),
        lessThan(load.indexOf(completeCommitMarker)),
      );
      expect(
        load.indexOf("commitVisibleCalendarState('flow_events')"),
        lessThan(load.indexOf(completeCommitMarker)),
      );
    },
  );

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
