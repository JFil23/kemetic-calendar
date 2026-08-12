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

  test(
    'backfill summary persists chunk, accounting, and cache proof',
    () async {
      const userId = 'user-a';
      final diagnostics = CalendarHydrationDiagnostics();
      diagnostics.setBuildLabel('staging-current');
      diagnostics.startColdProcess(userId: userId);
      final chunks = <({DateTime startUtc, DateTime endUtc})>[
        (startUtc: DateTime.utc(2026, 1, 1), endUtc: DateTime.utc(2026, 2, 1)),
      ];
      await diagnostics.startBackfillSummary(
        userId: userId,
        focusStartUtc: DateTime.utc(2026, 2, 1),
        focusEndUtc: DateTime.utc(2026, 3, 1),
        unionStartUtc: DateTime.utc(2026, 1, 1),
        unionEndUtc: DateTime.utc(2026, 3, 1),
        chunks: chunks,
      );
      await diagnostics.recordBackfillChunk(
        userId: userId,
        index: 0,
        flowStatus: HydrationFetchStatus.successNonempty,
        flowDurationMs: 321,
        flowStartedAtUtc: DateTime.utc(2026, 4, 1, 12),
        flowEndedAtUtc: DateTime.utc(2026, 4, 1, 12, 0, 1),
        standaloneStatus: HydrationFetchStatus.successfulEmpty,
        standaloneDurationMs: 87,
        standaloneStartedAtUtc: DateTime.utc(2026, 4, 1, 12, 0, 1),
        standaloneEndedAtUtc: DateTime.utc(2026, 4, 1, 12, 0, 2),
        merged: true,
      );
      await diagnostics.finishBackfillSummary(
        userId: userId,
        fullHorizonComplete: true,
        accountingStatus: HydrationFetchStatus.successNonempty,
        accountingDurationMs: 456,
        accountingStartedAtUtc: DateTime.utc(2026, 4, 1, 12, 0, 2),
        accountingEndedAtUtc: DateTime.utc(2026, 4, 1, 12, 0, 3),
        cacheSaveEnded: true,
        cacheSaveOutcome: 'saved',
      );

      final summary = diagnostics.lastBackfillSummary!;
      expect(summary['trace_id'], isNotNull);
      expect(summary['full_horizon_complete'], isTrue);
      expect(summary['accounting_status'], 'success_nonempty');
      expect(summary['accounting_duration_ms'], 456);
      expect(summary['accounting_started_at_utc'], '2026-04-01T12:00:02.000Z');
      expect(summary['accounting_ended_at_utc'], '2026-04-01T12:00:03.000Z');
      expect(summary['accounting_overlap_detected'], isFalse);
      expect(summary['cache_save_ended'], isTrue);
      expect(summary['cache_save_outcome'], 'saved');
      final chunk = Map<String, Object?>.from(
        (summary['chunks']! as List).single as Map,
      );
      expect(chunk['flow_duration_ms'], 321);
      expect(chunk['standalone_duration_ms'], 87);
      expect(chunk['lane_overlap_detected'], isFalse);
      expect(chunk['merged'], isTrue);
      await diagnostics.debugClose(HydrationTraceCloseReason.navigation);

      final restored = CalendarHydrationDiagnostics();
      await restored.restoreLastCompletedForUser(userId);
      expect(restored.lastBackfillSummary, summary);
    },
  );

  test(
    'completed exports preserve trace and backfill build identity',
    () async {
      const userId = 'user-a';
      final diagnostics = CalendarHydrationDiagnostics();
      diagnostics.setBuildLabel('staging-old');
      diagnostics.startColdProcess(userId: userId);
      await diagnostics.startBackfillSummary(
        userId: userId,
        focusStartUtc: DateTime.utc(2026, 1, 1),
        focusEndUtc: DateTime.utc(2026, 2, 1),
        unionStartUtc: DateTime.utc(2026, 1, 1),
        unionEndUtc: DateTime.utc(2026, 2, 1),
        chunks: const <({DateTime startUtc, DateTime endUtc})>[],
      );
      final backfillTraceId = diagnostics.lastBackfillSummary!['trace_id'];
      await diagnostics.debugClose(HydrationTraceCloseReason.navigation);

      final completedTraceId = diagnostics.lastCompletedTrace!['trace_id'];
      expect(completedTraceId, backfillTraceId);
      diagnostics.setBuildLabel('staging-new');
      final payload = diagnostics.buildLastCompletedExport(
        exportedByBuild: 'staging-new',
      )!;

      expect(payload['build'], 'staging-old');
      expect(payload['exported_by_build'], 'staging-new');
      final backfill = Map<String, Object?>.from(
        payload['backfill_summary']! as Map,
      );
      expect(backfill['build'], 'staging-old');
      expect(backfill['trace_id'], completedTraceId);
    },
  );

  test('export excludes a backfill summary from another trace', () async {
    const userId = 'user-a';
    final diagnostics = CalendarHydrationDiagnostics();
    diagnostics.setBuildLabel('staging-current');
    diagnostics.startColdProcess(userId: userId);
    await diagnostics.startBackfillSummary(
      userId: userId,
      focusStartUtc: DateTime.utc(2026, 1, 1),
      focusEndUtc: DateTime.utc(2026, 2, 1),
      unionStartUtc: DateTime.utc(2026, 1, 1),
      unionEndUtc: DateTime.utc(2026, 2, 1),
      chunks: const <({DateTime startUtc, DateTime endUtc})>[],
    );
    await diagnostics.debugClose(HydrationTraceCloseReason.navigation);

    diagnostics.startWarmReturn(userId: userId);
    await diagnostics.debugClose(HydrationTraceCloseReason.navigation);
    final payload = diagnostics.buildLastCompletedExport(
      exportedByBuild: 'staging-current',
    )!;

    expect(payload, isNot(contains('backfill_summary')));
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

  test('frame acknowledgement requires the same day and membership', () async {
    final diagnostics = CalendarHydrationDiagnostics();
    diagnostics.startColdProcess(userId: 'user-a');
    final context = diagnostics.beginPass(
      epoch: 1,
      requestedSource: 'test',
      executedSource: 'test',
    )!;
    diagnostics.recordVisibleCommit(
      context: context,
      phase: 'complete',
      originClass: 'server_complete',
      totalFlows: 1,
      totalEvents: 1,
      totalDayBuckets: 1,
      selectedDay: _snapshot(<String>{'a'}, dayKey: '2026-1-1'),
      claimedComplete: true,
      completeness: const HydrationCompletenessResult(
        fetchComplete: true,
        mappingConsistent: true,
        semanticComplete: true,
        allAttemptsSucceeded: true,
        completenessAnomaly: false,
        reasons: <String>[],
      ),
    );

    for (var index = 0; index < 2; index++) {
      diagnostics.recordDayViewFrame(
        selectedDay: _snapshot(<String>{'a'}, dayKey: '2026-1-2'),
        dataVersion: index + 1,
      );
    }
    diagnostics.recordDayViewFrame(
      selectedDay: _snapshot(<String>{'a'}, dayKey: '2026-1-1'),
      dataVersion: 3,
    );
    await diagnostics.debugClose(HydrationTraceCloseReason.navigation);

    final payload = diagnostics.lastCompletedTrace!;
    final frames = _maps(payload['frames']);
    expect(frames[0]['acknowledged_commit_revisions'], isEmpty);
    expect(frames[1]['acknowledged_commit_revisions'], isEmpty);
    expect(frames[2]['acknowledged_commit_revisions'], <Object?>[1]);
    final mismatches = _maps(payload['events'])
        .where((event) => event['marker'] == 'frame_commit_day_mismatch')
        .toList(growable: false);
    expect(mismatches, hasLength(1));
    expect(_summary(payload)['final_committed_selected_day_key'], '2026-1-1');
    expect(_summary(payload)['final_rendered_selected_day_key'], '2026-1-1');
  });

  test(
    'trace closure cannot invalidate independently evaluated completeness',
    () async {
      final diagnostics = CalendarHydrationDiagnostics();
      diagnostics.startColdProcess(userId: 'user-a');
      final context = diagnostics.beginPass(
        epoch: 1,
        requestedSource: 'startup_backfill:test:4',
        executedSource: 'startup_backfill:test:4',
      )!;
      const evaluated = HydrationCompletenessResult(
        fetchComplete: true,
        mappingConsistent: true,
        semanticComplete: true,
        allAttemptsSucceeded: true,
        completenessAnomaly: false,
        reasons: <String>[],
      );

      await diagnostics.debugClose(HydrationTraceCloseReason.timeout);
      final afterClose = diagnostics.recordCompleteness(
        context: context,
        hydrationFlowCount: 71,
        claimedComplete: true,
        evaluatedResult: evaluated,
      );

      expect(afterClose.semanticComplete, isTrue);
      expect(afterClose.allAttemptsSucceeded, isTrue);
    },
  );

  test('same-day stale checksum stays pending without a false stamp', () async {
    final diagnostics = CalendarHydrationDiagnostics();
    diagnostics.startColdProcess(userId: 'user-a');
    final context = diagnostics.beginPass(
      epoch: 1,
      requestedSource: 'test',
      executedSource: 'test',
    )!;
    diagnostics.recordVisibleCommit(
      context: context,
      phase: 'complete',
      originClass: 'server_complete',
      totalFlows: 1,
      totalEvents: 2,
      totalDayBuckets: 1,
      selectedDay: _snapshot(<String>{'a', 'b'}),
      claimedComplete: true,
      completeness: const HydrationCompletenessResult(
        fetchComplete: true,
        mappingConsistent: true,
        semanticComplete: true,
        allAttemptsSucceeded: true,
        completenessAnomaly: false,
        reasons: <String>[],
      ),
    );
    for (var index = 0; index < 2; index++) {
      diagnostics.recordDayViewFrame(
        selectedDay: _snapshot(<String>{'a'}),
        dataVersion: index + 1,
      );
    }
    await diagnostics.debugClose(HydrationTraceCloseReason.navigation);

    final payload = diagnostics.lastCompletedTrace!;
    expect(
      _summary(payload)['time_to_first_server_confirmed_complete_frame_ms'],
      isNull,
    );
    final frames = _maps(payload['frames']);
    expect(
      frames,
      everyElement(containsPair('acknowledged_commit_revisions', isEmpty)),
    );
    final mismatches = _maps(payload['events'])
        .where((event) => event['marker'] == 'frame_commit_checksum_mismatch')
        .toList(growable: false);
    expect(mismatches, hasLength(1));
    final summary = _summary(payload);
    expect(
      summary['final_committed_selected_day_multiset_checksum'],
      isNot(summary['final_rendered_selected_day_multiset_checksum']),
    );
  });

  test('different-day frame cannot create a server-confirmed stamp', () async {
    final diagnostics = CalendarHydrationDiagnostics();
    diagnostics.startColdProcess(userId: 'user-a');
    final context = diagnostics.beginPass(
      epoch: 1,
      requestedSource: 'test',
      executedSource: 'test',
    )!;
    diagnostics.recordVisibleCommit(
      context: context,
      phase: 'complete',
      originClass: 'server_complete',
      totalFlows: 1,
      totalEvents: 1,
      totalDayBuckets: 1,
      selectedDay: _snapshot(<String>{'a'}, dayKey: '2026-1-1'),
      claimedComplete: true,
      completeness: const HydrationCompletenessResult(
        fetchComplete: true,
        mappingConsistent: true,
        semanticComplete: true,
        allAttemptsSucceeded: true,
        completenessAnomaly: false,
        reasons: <String>[],
      ),
    );
    diagnostics.recordDayViewFrame(
      selectedDay: _snapshot(<String>{'a'}, dayKey: '2026-1-2'),
      dataVersion: 1,
    );
    await diagnostics.debugClose(HydrationTraceCloseReason.navigation);

    expect(
      _summary(
        diagnostics.lastCompletedTrace!,
      )['time_to_first_server_confirmed_complete_frame_ms'],
      isNull,
    );
  });

  test('open Day View controls the diagnostic day sample', () {
    expect(
      selectHydrationDiagnosticDay(
        fallbackKYear: 2026,
        fallbackKMonth: 1,
        fallbackKDay: 1,
        activeDayViewOpen: true,
        activeKYear: 2026,
        activeKMonth: 2,
        activeKDay: 3,
      ),
      (kYear: 2026, kMonth: 2, kDay: 3),
    );
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

HydrationSelectedDaySnapshot _snapshot(
  Set<String> identities, {
  String dayKey = '2026-1-1',
}) {
  return HydrationSelectedDaySnapshot(
    dayKey: dayKey,
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
