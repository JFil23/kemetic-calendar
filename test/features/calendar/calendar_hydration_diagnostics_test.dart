import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_hydration_diagnostics.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('schema is bounded and strips forbidden identity fields', () async {
    final diagnostics = CalendarHydrationDiagnostics(capacity: 4);
    diagnostics.startColdProcess(
      userId: 'private-user-id',
      firstRoute: 'calendar',
    );
    diagnostics.recordPostProcessing(
      null,
      'privacy_probe',
      fields: const <String, Object?>{
        'title': 'SECRET_TITLE',
        'detail': 'SECRET_DETAIL',
        'user_id': 'SECRET_USER',
        'eventId': 'SECRET_EVENT',
        'flowId': 'SECRET_FLOW',
        'safe_count': 3,
      },
    );
    for (var index = 0; index < 12; index++) {
      diagnostics.recordCacheEvent('bounded', <String, Object?>{
        'index': index,
      });
    }

    await diagnostics.debugClose(HydrationTraceCloseReason.navigation);
    final payload = diagnostics.lastCompletedTrace!;
    final encoded = jsonEncode(payload);

    expect(payload['schema'], 1);
    expect(payload['closed_by'], 'navigation');
    expect(encoded, isNot(contains('private-user-id')));
    expect(encoded, isNot(contains('SECRET_TITLE')));
    expect(encoded, isNot(contains('SECRET_DETAIL')));
    expect(encoded, isNot(contains('SECRET_USER')));
    expect(encoded, isNot(contains('SECRET_EVENT')));
    expect(encoded, isNot(contains('SECRET_FLOW')));
    expect(_summary(payload)['dropped_event_count'], greaterThan(0));
  });

  test('completeness uses the final retrieval path and detects anomalies', () {
    final fallbackRecovered = evaluateHydrationCompleteness(
      HydrationCompletenessInput(
        catalogStatus: HydrationFetchStatus.successNonempty,
        hydrationFlowCount: 2,
        batchStatus: HydrationFetchStatus.failed,
        fallbackRequestCount: 2,
        fallbackFailedCount: 0,
        fallbackNonemptyCount: 2,
        standaloneStatus: HydrationFetchStatus.successfulEmpty,
        mapping: const HydrationBatchMappingStats(
          requestedFlowCount: 2,
          rawRowCount: 0,
          mappedRowCount: 0,
          mappedFlowCount: 0,
          nullFlowIdRowCount: 0,
          outsideRequestedSetRowCount: 0,
        ),
      ),
    );
    expect(fallbackRecovered.fetchComplete, isTrue);
    expect(fallbackRecovered.semanticComplete, isTrue);
    expect(fallbackRecovered.allAttemptsSucceeded, isFalse);

    final unauthenticatedCatalog = evaluateHydrationCompleteness(
      HydrationCompletenessInput(
        catalogStatus: HydrationFetchStatus.unauthenticated,
        hydrationFlowCount: 0,
        batchStatus: HydrationFetchStatus.notRun,
        fallbackRequestCount: 0,
        fallbackFailedCount: 0,
        fallbackNonemptyCount: 0,
        standaloneStatus: HydrationFetchStatus.successfulEmpty,
        mapping: null,
      ),
    );
    expect(unauthenticatedCatalog.fetchComplete, isFalse);

    final noFlows = evaluateHydrationCompleteness(
      HydrationCompletenessInput(
        catalogStatus: HydrationFetchStatus.successfulEmpty,
        hydrationFlowCount: 0,
        batchStatus: HydrationFetchStatus.notRun,
        fallbackRequestCount: 0,
        fallbackFailedCount: 0,
        fallbackNonemptyCount: 0,
        standaloneStatus: HydrationFetchStatus.successNonempty,
        mapping: null,
      ),
    );
    expect(noFlows.semanticComplete, isTrue);

    final emptyBatchDisagrees = evaluateHydrationCompleteness(
      HydrationCompletenessInput(
        catalogStatus: HydrationFetchStatus.successNonempty,
        hydrationFlowCount: 1,
        batchStatus: HydrationFetchStatus.successfulEmpty,
        fallbackRequestCount: 1,
        fallbackFailedCount: 0,
        fallbackNonemptyCount: 1,
        standaloneStatus: HydrationFetchStatus.successfulEmpty,
        mapping: const HydrationBatchMappingStats(
          requestedFlowCount: 1,
          rawRowCount: 0,
          mappedRowCount: 0,
          mappedFlowCount: 0,
          nullFlowIdRowCount: 0,
          outsideRequestedSetRowCount: 0,
        ),
      ),
    );
    expect(emptyBatchDisagrees.completenessAnomaly, isTrue);
    expect(emptyBatchDisagrees.mappingConsistent, isFalse);
    expect(emptyBatchDisagrees.semanticComplete, isFalse);
  });

  test('mapping stats reject nonempty-unmapped, null, and outside rows', () {
    const noneMapped = HydrationBatchMappingStats(
      requestedFlowCount: 2,
      rawRowCount: 3,
      mappedRowCount: 0,
      mappedFlowCount: 0,
      nullFlowIdRowCount: 1,
      outsideRequestedSetRowCount: 2,
    );
    expect(noneMapped.hasEmptyMapFromNonemptyRows, isTrue);
    expect(noneMapped.isConsistent, isFalse);

    const partiallyMappedWithImpossibleRow = HydrationBatchMappingStats(
      requestedFlowCount: 2,
      rawRowCount: 3,
      mappedRowCount: 2,
      mappedFlowCount: 1,
      nullFlowIdRowCount: 0,
      outsideRequestedSetRowCount: 1,
    );
    expect(partiallyMappedWithImpossibleRow.isConsistent, isFalse);
  });

  test('late work retains the immutable pass that started it', () async {
    final diagnostics = CalendarHydrationDiagnostics();
    diagnostics.startColdProcess(userId: 'user-a');
    final passA = diagnostics.beginPass(
      epoch: 1,
      requestedSource: 'startup:init',
      executedSource: 'startup:init',
    )!;
    final passB = diagnostics.beginPass(
      epoch: 2,
      requestedSource: 'invalidation:event_saved',
      executedSource: 'invalidation:event_saved',
    )!;

    diagnostics.recordRepositoryFetch(
      context: passB,
      operation: 'flow_batch',
      status: HydrationFetchStatus.successfulEmpty,
      durationMs: 7,
      requestCount: 1,
    );
    diagnostics.recordRepositoryFetch(
      context: passA,
      operation: 'flow_batch',
      status: HydrationFetchStatus.successNonempty,
      durationMs: 19,
      rowCount: 4,
      requestCount: 2,
      pageCount: 2,
    );
    diagnostics.endPass(passA, succeeded: true);
    diagnostics.endPass(passB, succeeded: true);
    diagnostics.recordCoordinatorIdle();
    await diagnostics.debugClose(HydrationTraceCloseReason.navigation);

    final passes = _maps(diagnostics.lastCompletedTrace!['passes']);
    final first = passes.singleWhere((pass) => pass['pass_epoch'] == 1);
    final second = passes.singleWhere((pass) => pass['pass_epoch'] == 2);
    expect(first['batch_outcome'], 'batch_nonempty');
    expect(first['network_request_count'], 2);
    expect(second['batch_outcome'], 'successful_empty');
    expect(second['network_request_count'], 1);
    expect(
      _summary(diagnostics.lastCompletedTrace!)['network_request_count'],
      3,
    );
    expect(diagnostics.lastCompletedTrace, isNot(contains('batch_outcome')));
  });

  test('local and server-complete frames remain distinct', () async {
    final diagnostics = CalendarHydrationDiagnostics();
    diagnostics.startColdProcess(userId: 'user-a');
    diagnostics.recordWarmCacheCommit(
      totalFlows: 1,
      totalEvents: 1,
      totalDayBuckets: 1,
      selectedDay: _snapshot(<String>{'a'}),
    );
    diagnostics.recordDayViewFrame(
      selectedDay: _snapshot(<String>{'a'}),
      dataVersion: 1,
      firstFrame: true,
    );

    final context = diagnostics.beginPass(
      epoch: 1,
      requestedSource: 'startup_backfill:init',
      executedSource: 'startup_backfill:init',
    )!;
    diagnostics.recordRepositoryFetch(
      context: context,
      operation: 'flow_catalog',
      status: HydrationFetchStatus.successNonempty,
      durationMs: 1,
    );
    diagnostics.recordRepositoryFetch(
      context: context,
      operation: 'flow_batch',
      status: HydrationFetchStatus.successNonempty,
      durationMs: 1,
      rowCount: 2,
    );
    diagnostics.recordRepositoryFetch(
      context: context,
      operation: 'standalone',
      status: HydrationFetchStatus.successfulEmpty,
      durationMs: 1,
    );
    diagnostics.recordBatchMapping(
      context: context,
      stats: const HydrationBatchMappingStats(
        requestedFlowCount: 1,
        rawRowCount: 2,
        mappedRowCount: 2,
        mappedFlowCount: 1,
        nullFlowIdRowCount: 0,
        outsideRequestedSetRowCount: 0,
      ),
    );
    final completeness = diagnostics.recordCompleteness(
      context: context,
      hydrationFlowCount: 1,
      claimedComplete: true,
    );
    diagnostics.recordVisibleCommit(
      context: context,
      phase: 'complete',
      originClass: 'server_complete',
      totalFlows: 1,
      totalEvents: 2,
      totalDayBuckets: 1,
      selectedDay: _snapshot(<String>{'a', 'b'}),
      claimedComplete: true,
      completeness: completeness,
    );
    diagnostics.recordDayViewFrame(
      selectedDay: _snapshot(<String>{'a', 'b'}),
      dataVersion: 2,
    );
    diagnostics.endPass(context, succeeded: true);
    diagnostics.recordCoordinatorIdle();
    await diagnostics.debugClose(HydrationTraceCloseReason.navigation);

    final summary = _summary(diagnostics.lastCompletedTrace!);
    expect(summary['time_to_first_local_snapshot_frame_ms'], isNotNull);
    expect(
      summary['time_to_first_server_confirmed_complete_frame_ms'],
      isNotNull,
    );
    expect(summary['warm_snapshot_selected_day_matches_final'], isFalse);
    expect(summary['warm_to_final_selected_day_added'], 1);
    expect(summary['warm_to_final_selected_day_removed'], 0);
    final frames = _maps(diagnostics.lastCompletedTrace!['frames']);
    expect(frames.first['acknowledged_commit_revisions'], <Object?>[1]);
    expect(frames.last['acknowledged_commit_revisions'], <Object?>[2]);
  });

  test(
    '500ms-equivalent quiet marker does not close before settlement',
    () async {
      final diagnostics = CalendarHydrationDiagnostics(
        quiescentDelay: const Duration(milliseconds: 10),
        settleDelay: const Duration(milliseconds: 70),
        hardTimeout: const Duration(seconds: 1),
      );
      diagnostics.startColdProcess(userId: 'user-a');

      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(diagnostics.hasActiveTrace, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(diagnostics.hasActiveTrace, isFalse);
      expect(diagnostics.lastCompletedTrace!['closed_by'], 'settled');
      expect(
        _summary(
          diagnostics.lastCompletedTrace!,
        )['time_to_first_quiescent_500ms'],
        isNotNull,
      );
    },
  );

  test('timeout and navigation close active traces', () async {
    final timed = CalendarHydrationDiagnostics(
      hardTimeout: const Duration(milliseconds: 25),
      settleDelay: const Duration(seconds: 1),
    );
    timed.startColdProcess(userId: 'user-a');
    timed.markAsyncWorkStarted(null, 'held_open');
    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(timed.lastCompletedTrace!['closed_by'], 'timeout');

    final navigated = CalendarHydrationDiagnostics();
    navigated.startWarmReturn(userId: 'user-a');
    await navigated.closeForNavigation();
    expect(navigated.lastCompletedTrace!['closed_by'], 'navigation');
  });

  test('last completed trace is isolated by account', () async {
    final diagnostics = CalendarHydrationDiagnostics();
    diagnostics.startColdProcess(userId: 'account-a');
    await diagnostics.closeForNavigation();
    expect(diagnostics.lastCompletedTrace, isNotNull);

    expect(await diagnostics.restoreLastCompletedForUser('account-b'), isNull);
    expect(diagnostics.lastCompletedTrace, isNull);
  });
}

HydrationSelectedDaySnapshot _snapshot(Set<String> identities) {
  return HydrationSelectedDaySnapshot(
    eventCount: identities.length,
    flowBackedCount: identities.length,
    reminderCount: 0,
    standaloneCount: 0,
    startMinuteSum: identities.length * 60,
    multisetChecksum: identities.length * 17,
  );
}

Map<String, Object?> _summary(Map<String, Object?> payload) {
  return Map<String, Object?>.from(payload['summary']! as Map);
}

List<Map<String, Object?>> _maps(Object? value) {
  return (value! as List)
      .map((item) => Map<String, Object?>.from(item as Map))
      .toList(growable: false);
}
