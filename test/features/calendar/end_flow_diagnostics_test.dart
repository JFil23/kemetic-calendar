import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/end_flow_diagnostics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('ring buffer is bounded and ordered newest first', () {
    final diagnostics = EndFlowDiagnostics(capacity: 2);
    diagnostics.record(_terminalRecord(flowId: 1, operationId: 'op-one'));
    diagnostics.record(_terminalRecord(flowId: 2, operationId: 'op-two'));
    diagnostics.record(_terminalRecord(flowId: 3, operationId: 'op-three'));

    expect(diagnostics.records, hasLength(2));
    expect(diagnostics.records.map((record) => record.operationId), <String>[
      'op-three',
      'op-two',
    ]);
    expect(diagnostics.terminalRecordFor('op-one'), isNull);
  });

  test('copy payload is the sanitized canonical terminal record', () async {
    final diagnostics = EndFlowDiagnostics(capacity: 4);
    final outcome = EndFlowOutcome.failure(
      operationId: '12345678-1234-1234-1234-123456789012',
      failureKind: EndFlowFailureKind.authorization,
      postgrestCode: '42501',
      httpStatus: 403,
    );
    diagnostics.recordRpcAttempted(
      flowId: 919,
      operationId: outcome.operationId,
      referenceCode: outcome.referenceCode,
      initiatorOwner: EndFlowOperationOwner.calendar,
    );
    diagnostics.recordTerminal(
      flowId: 919,
      outcome: outcome,
      initiatorOwner: EndFlowOperationOwner.calendar,
    );

    MethodCall? clipboardCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          clipboardCall = call;
          return null;
        });

    expect(
      await diagnostics.copyTerminalDiagnostics(outcome.operationId),
      isTrue,
    );
    expect(clipboardCall?.method, 'Clipboard.setData');
    final arguments = clipboardCall?.arguments as Map<Object?, Object?>;
    final copied = arguments['text'] as String;
    expect(copied, contains('"record_kind": "canonical_terminal"'));
    expect(copied, contains('"reference_code": "EF-12345678"'));
    expect(copied, contains('"postgrest_code": "42501"'));
    expect(copied, isNot(contains('"record_kind": "rpc_attempted"')));
    expect(copied, isNot(contains('Bearer ')));
    expect(copied, isNot(contains('https://')));
    expect(copied, isNot(contains('@')));
  });

  test(
    'failure classifier separates response, transport, and auth failures',
    () {
      final transport = classifyEndFlowFailure(
        TimeoutException('private timeout detail'),
      );
      expect(transport.failureKind, EndFlowFailureKind.transport);
      expect(transport.terminalStage, EndFlowTerminalStage.rpcNoResponse);

      final authorization = classifyEndFlowFailure(
        const PostgrestException(message: 'private', code: '42501'),
      );
      expect(authorization.failureKind, EndFlowFailureKind.authorization);
      expect(
        authorization.terminalStage,
        EndFlowTerminalStage.rpcErrorReturned,
      );
      expect(authorization.postgrestCode, '42501');

      final server = classifyEndFlowFailure(
        const PostgrestException(message: 'private', code: 'P0001'),
      );
      expect(server.failureKind, EndFlowFailureKind.server);
      expect(server.terminalStage, EndFlowTerminalStage.rpcErrorReturned);

      final auth = classifyEndFlowFailure(
        const AuthException('private', statusCode: '403', code: 'forbidden'),
      );
      expect(auth.failureKind, EndFlowFailureKind.authorization);
      expect(auth.httpStatus, 403);
      expect(auth.postgrestCode, 'forbidden');

      final hostileCode = classifyEndFlowFailure(
        const PostgrestException(
          message: 'private',
          code: 'https://private.example/user@example.com Bearer secret',
        ),
      );
      expect(hostileCode.postgrestCode, 'redacted');
    },
  );

  test('failure mapper provides the locked session and distinct copies', () {
    expect(
      endFlowFailureMessage(EndFlowFailureKind.sessionNotReady),
      'Your session isn’t ready. Try again in a moment.',
    );
    expect(
      endFlowFailureMessage(EndFlowFailureKind.transport),
      contains('Check your connection'),
    );
    expect(
      endFlowFailureMessage(EndFlowFailureKind.authorization),
      contains('permission'),
    );
    expect(
      endFlowFailureMessage(EndFlowFailureKind.server),
      contains('server'),
    );
    expect(
      <EndFlowFailureKind>{
        EndFlowFailureKind.sessionNotReady,
        EndFlowFailureKind.transport,
        EndFlowFailureKind.authorization,
        EndFlowFailureKind.server,
      }.map(endFlowFailureMessage).toSet(),
      hasLength(4),
    );
  });
}

EndFlowDiagnosticRecord _terminalRecord({
  required int flowId,
  required String operationId,
}) => EndFlowDiagnosticRecord(
  recordKind: EndFlowDiagnosticRecordKind.canonicalTerminal,
  recordedAtUtc: DateTime.utc(2026, 8, 9),
  flowId: flowId,
  operationId: operationId,
  referenceCode: endFlowReferenceCode(operationId),
  initiatorOwner: EndFlowOperationOwner.test,
  result: EndFlowActionResult.failed,
  failureKind: EndFlowFailureKind.unknown,
  terminalStage: EndFlowTerminalStage.rpcNoResponse,
  rpcAttempted: true,
);
