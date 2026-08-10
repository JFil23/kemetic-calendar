import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/calendar/calendar_invalidation.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CalendarPage.debugResetEndFlowCoordinatorForTesting();
    CalendarPage.debugFlowEndUserScopeForTesting = 'end-flow-test-user';
    EndFlowAuthReadiness.instance.debugSetReadyForTesting(true);
    CalendarPage.debugClearFlowEndCacheForTesting = () async {};
    CalendarPage.debugTrackFlowEndClassificationForTesting = (_) async {};
  });

  tearDown(CalendarPage.debugResetEndFlowCoordinatorForTesting);

  test(
    'same-flow callers share one outcome and publish only after commit',
    () async {
      final rpc = Completer<EndFlowActionResult>();
      final published = <CalendarInvalidated>[];
      var rpcCalls = 0;
      CalendarPage.debugEndFlowRpcForTesting = (flowId, endedAtLocal) {
        rpcCalls += 1;
        return rpc.future;
      };
      CalendarPage.debugPublishFlowEndForTesting = published.add;

      final first = CalendarPage.debugRunEndFlowForTesting(41);
      final joined = CalendarPage.debugRunEndFlowForTesting(41);

      expect(identical(first, joined), isTrue);
      expect(rpcCalls, 1);
      expect(CalendarPage.debugIsFlowEndPendingForTesting(41), isTrue);
      expect(published, isEmpty);

      rpc.complete(EndFlowActionResult.success);

      final firstOutcome = await first;
      final joinedOutcome = await joined;
      expect(identical(firstOutcome, joinedOutcome), isTrue);
      expect(firstOutcome.result, EndFlowActionResult.success);
      expect(firstOutcome.terminalStage, EndFlowTerminalStage.postCommit);
      expect(firstOutcome.rpcAttempted, isTrue);
      expect(CalendarPage.debugIsFlowEndPendingForTesting(41), isFalse);
      expect(
        EndFlowVisibilityStore.instance.stateFor(41),
        EndFlowVisibilityState.committed,
      );
      expect(published, hasLength(1));
      expect(
        published.single.reason,
        CalendarInvalidationReason.flowEndedCommitted,
      );
      expect(published.single.flowId, 41);

      final terminal = CalendarPage.debugEndFlowDiagnosticRecordsForTesting
          .where(
            (record) =>
                record.recordKind ==
                EndFlowDiagnosticRecordKind.canonicalTerminal,
          )
          .toList();
      expect(terminal, hasLength(1));
      expect(terminal.single.operationId, firstOutcome.operationId);
    },
  );

  test('simultaneous ends retain isolated outcomes and records', () async {
    final rpcs = <int, Completer<EndFlowActionResult>>{
      51: Completer<EndFlowActionResult>(),
      52: Completer<EndFlowActionResult>(),
    };
    final publishedFlowIds = <int>[];
    CalendarPage.debugEndFlowRpcForTesting = (flowId, endedAtLocal) =>
        rpcs[flowId]!.future;
    CalendarPage.debugPublishFlowEndForTesting = (invalidation) {
      publishedFlowIds.add(invalidation.flowId!);
    };

    final first = CalendarPage.debugRunEndFlowForTesting(51);
    final second = CalendarPage.debugRunEndFlowForTesting(52);

    expect(CalendarPage.debugIsFlowEndPendingForTesting(51), isTrue);
    expect(CalendarPage.debugIsFlowEndPendingForTesting(52), isTrue);

    rpcs[51]!.complete(EndFlowActionResult.success);
    final firstOutcome = await first;
    expect(firstOutcome.result, EndFlowActionResult.success);
    expect(publishedFlowIds, <int>[51]);
    expect(CalendarPage.debugIsFlowEndPendingForTesting(51), isFalse);
    expect(CalendarPage.debugIsFlowEndPendingForTesting(52), isTrue);

    rpcs[52]!.complete(EndFlowActionResult.success);
    final secondOutcome = await second;
    expect(secondOutcome.result, EndFlowActionResult.success);
    expect(firstOutcome.operationId, isNot(secondOutcome.operationId));
    expect(publishedFlowIds, <int>[51, 52]);
    expect(CalendarPage.debugIsFlowEndPendingForTesting(52), isFalse);

    final terminal = CalendarPage.debugEndFlowDiagnosticRecordsForTesting
        .where(
          (record) =>
              record.recordKind ==
              EndFlowDiagnosticRecordKind.canonicalTerminal,
        )
        .toList();
    expect(terminal, hasLength(2));
    expect(terminal.map((record) => record.flowId).toSet(), <int>{51, 52});
  });

  test('auth loss before invocation is a classified pre-RPC guard', () async {
    var rpcCalls = 0;
    CalendarPage.debugEndFlowRpcForTesting = (flowId, endedAtLocal) async {
      rpcCalls += 1;
      return EndFlowActionResult.success;
    };
    EndFlowAuthReadiness.instance.debugSetReadyForTesting(false);

    final outcome = await CalendarPage.debugRunEndFlowForTesting(61);

    expect(rpcCalls, 0);
    expect(outcome.result, EndFlowActionResult.failed);
    expect(outcome.failureKind, EndFlowFailureKind.sessionNotReady);
    expect(outcome.terminalStage, EndFlowTerminalStage.preRpcGuard);
    expect(outcome.rpcAttempted, isFalse);
    expect(EndFlowVisibilityStore.instance.stateFor(61), isNull);
    expect(
      endFlowFailureMessage(outcome.failureKind),
      'Your session isn’t ready. Try again in a moment.',
    );
    final terminal =
        CalendarPage.debugEndFlowDiagnosticRecordsForTesting.single;
    expect(terminal.recordKind, EndFlowDiagnosticRecordKind.canonicalTerminal);
    expect(terminal.operationId, outcome.operationId);
  });

  test(
    'transport exception maps to rpc-no-response without raw error',
    () async {
      CalendarPage.debugEndFlowRpcForTesting = (flowId, endedAtLocal) async {
        throw http.ClientException(
          'Bearer secret-token https://private.example.test/user@example.com',
        );
      };

      final outcome = await CalendarPage.debugRunEndFlowForTesting(62);

      expect(outcome.failureKind, EndFlowFailureKind.transport);
      expect(outcome.terminalStage, EndFlowTerminalStage.rpcNoResponse);
      expect(outcome.rpcAttempted, isTrue);
      expect(EndFlowVisibilityStore.instance.stateFor(62), isNull);
      final payload = EndFlowDiagnostics.instance.copyPayloadForOperation(
        outcome.operationId,
      );
      expect(payload, isNotNull);
      expect(payload, isNot(contains('secret-token')));
      expect(payload, isNot(contains('private.example.test')));
      expect(payload, isNot(contains('user@example.com')));
    },
  );

  test('post-commit side-effect failures cannot flip success', () async {
    CalendarPage.debugEndFlowRpcForTesting = (flowId, endedAtLocal) async =>
        EndFlowActionResult.success;
    CalendarPage.debugClearFlowEndCacheForTesting = () async {
      throw StateError('cache detail must not escape');
    };
    CalendarPage.debugPublishFlowEndForTesting = (_) {
      throw StateError('publish detail must not escape');
    };

    final outcome = await CalendarPage.debugRunEndFlowForTesting(63);

    expect(outcome.result, EndFlowActionResult.success);
    expect(outcome.terminalStage, EndFlowTerminalStage.postCommit);
    final records = CalendarPage.debugEndFlowDiagnosticRecordsForTesting;
    expect(
      records.where(
        (record) =>
            record.recordKind == EndFlowDiagnosticRecordKind.canonicalTerminal,
      ),
      hasLength(1),
    );
    expect(
      records
          .where(
            (record) =>
                record.recordKind == EndFlowDiagnosticRecordKind.sideEffect,
          )
          .map((record) => record.sideEffectKind)
          .toSet(),
      <EndFlowSideEffectKind>{
        EndFlowSideEffectKind.filingCacheClear,
        EndFlowSideEffectKind.invalidationPublish,
      },
    );
  });

  test('classification telemetry is fire-and-forget on success', () async {
    final telemetry = Completer<void>();
    CalendarPage.debugEndFlowRpcForTesting = (flowId, endedAtLocal) async =>
        EndFlowActionResult.success;
    CalendarPage.debugTrackFlowEndClassificationForTesting = (_) =>
        telemetry.future;

    final outcome = await CalendarPage.debugRunEndFlowForTesting(
      64,
    ).timeout(const Duration(seconds: 1));

    expect(outcome.result, EndFlowActionResult.success);
    expect(telemetry.isCompleted, isFalse);
    telemetry.complete();
  });
}
