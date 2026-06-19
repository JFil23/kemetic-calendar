import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    expect(startup, contains('final keepWarmStartVisible'));
    expect(startup, contains("source: 'startup:\$reason'"));
    expect(startup, contains("source: 'startup_backfill:\$reason'"));
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
      lessThan(startup.indexOf("source: 'startup:\$reason'")),
    );
    expect(
      startup.indexOf("source: 'startup:\$reason'"),
      lessThan(startup.indexOf("source: 'startup_backfill:\$reason'")),
    );
  });

  test('startup live load can paint flow events before standalone lane', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final load = _sourceBetween(
      source,
      'Future<void> _loadFromDisk({',
      '/// Allows other screens (e.g., Settings) to trigger a fresh sync',
    );

    expect(load, contains("commitVisibleCalendarState('flow_events')"));
    expect(load, contains("commitVisibleCalendarState('complete')"));
    expect(
      load.indexOf("commitVisibleCalendarState('flow_events')"),
      lessThan(load.indexOf('final standaloneResult = await standaloneFuture')),
    );
    expect(
      load.indexOf('final standaloneResult = await standaloneFuture'),
      lessThan(load.indexOf("commitVisibleCalendarState('complete')")),
    );
  });

  test('flow-only visible commit cannot replace painted standalone lane', () {
    expect(
      shouldCommitFlowOnlyVisibleCalendarState(
        flowAddedCount: 3,
        keepWarmStartSnapshotVisible: false,
        hasPaintedStandaloneLane: false,
      ),
      isTrue,
    );
    expect(
      shouldCommitFlowOnlyVisibleCalendarState(
        flowAddedCount: 3,
        keepWarmStartSnapshotVisible: true,
        hasPaintedStandaloneLane: false,
      ),
      isFalse,
    );
    expect(
      shouldCommitFlowOnlyVisibleCalendarState(
        flowAddedCount: 3,
        keepWarmStartSnapshotVisible: false,
        hasPaintedStandaloneLane: true,
      ),
      isFalse,
    );
    expect(
      shouldCommitFlowOnlyVisibleCalendarState(
        flowAddedCount: 0,
        keepWarmStartSnapshotVisible: false,
        hasPaintedStandaloneLane: false,
      ),
      isFalse,
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

  test('load from disk guards flow-only commit with painted standalone lane', () {
    final source = File(
      'lib/features/calendar/calendar_page.dart',
    ).readAsStringSync();
    final load = _sourceBetween(
      source,
      'Future<void> _loadFromDisk({',
      '/// Allows other screens (e.g., Settings) to trigger a fresh sync',
    );

    expect(load, contains('final hasPaintedStandaloneLaneAtLoadStart'));
    expect(load, contains('shouldCommitFlowOnlyVisibleCalendarState'));
    expect(
      load,
      contains('shouldPreservePaintedStandaloneLaneForHydrationCommit'),
    );
    expect(load, contains('_mergePaintedStandaloneLaneInto(newNotes)'));
    expect(load, contains('hasPaintedStandaloneLaneAtLoadStart'));
    expect(load, contains("commitVisibleCalendarState('flow_events')"));
    expect(load, contains("commitVisibleCalendarState('complete')"));
    expect(
      load.indexOf('final hasPaintedStandaloneLaneAtLoadStart'),
      lessThan(load.indexOf('shouldCommitFlowOnlyVisibleCalendarState')),
    );
    expect(
      load.indexOf('shouldCommitFlowOnlyVisibleCalendarState'),
      lessThan(load.indexOf("commitVisibleCalendarState('flow_events')")),
    );
    expect(
      load.indexOf('shouldPreservePaintedStandaloneLaneForHydrationCommit'),
      lessThan(load.indexOf("commitVisibleCalendarState('complete')")),
    );
    expect(
      load.indexOf("commitVisibleCalendarState('flow_events')"),
      lessThan(load.indexOf("commitVisibleCalendarState('complete')")),
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
