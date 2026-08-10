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

  test('RPC flow id parsing is strict and preserves release diagnostics', () {
    final matching = EndFlowRpcResponse.fromRow(<String, dynamic>{
      'flow_id': 919,
      'deleted_event_count': 30,
      'retired_notification_count': 4,
      'deleted_completion_count': 2,
    });
    expect(matching.identityStatusFor(919), EndFlowRpcIdentityStatus.matching);
    expect(matching.deletedEventCount, 30);

    expect(
      EndFlowRpcResponse.fromRow(const <String, dynamic>{
        'flow_id': 920,
      }).identityStatusFor(919),
      EndFlowRpcIdentityStatus.mismatching,
    );
    expect(
      EndFlowRpcResponse.fromRow(const <String, dynamic>{
        'flow_id': '919',
      }).identityStatusFor(919),
      EndFlowRpcIdentityStatus.malformed,
    );
    expect(
      EndFlowRpcResponse.fromRow(const <String, dynamic>{
        'flow_id': 919.5,
      }).identityStatusFor(919),
      EndFlowRpcIdentityStatus.malformed,
    );
    expect(
      EndFlowRpcResponse.fromRow(
        const <String, dynamic>{},
      ).identityStatusFor(919),
      EndFlowRpcIdentityStatus.missing,
    );
  });

  test('post-RPC verification matrix is table driven', () {
    final matching = EndFlowRpcResponse.matching(919);
    const mismatching = EndFlowRpcResponse(
      flowIdFieldPresent: true,
      rawFlowId: 920,
      parsedFlowId: 920,
    );
    const missing = EndFlowRpcResponse(
      flowIdFieldPresent: false,
      rawFlowId: null,
      parsedFlowId: null,
    );
    const malformed = EndFlowRpcResponse(
      flowIdFieldPresent: true,
      rawFlowId: 'bad-id',
      parsedFlowId: null,
    );
    const inactive = EndFlowVerificationResult.inactive();
    const active = EndFlowVerificationResult.active();
    const unavailable = EndFlowVerificationResult.unavailable(
      failureKind: EndFlowFailureKind.transport,
    );
    final cases =
        <
          ({
            String label,
            EndFlowRpcResponse? response,
            EndFlowVerificationResult verification,
            bool alreadyDeleted,
            EndFlowActionResult expected,
          })
        >[
          (
            label: 'matching + inactive',
            response: matching,
            verification: inactive,
            alreadyDeleted: false,
            expected: EndFlowActionResult.success,
          ),
          (
            label: 'matching + active',
            response: matching,
            verification: active,
            alreadyDeleted: false,
            expected: EndFlowActionResult.failed,
          ),
          (
            label: 'matching + unavailable',
            response: matching,
            verification: unavailable,
            alreadyDeleted: false,
            expected: EndFlowActionResult.success,
          ),
          for (final response in <EndFlowRpcResponse>[
            mismatching,
            missing,
            malformed,
          ]) ...[
            (
              label: 'anomaly + inactive',
              response: response,
              verification: inactive,
              alreadyDeleted: false,
              expected: EndFlowActionResult.success,
            ),
            (
              label: 'anomaly + active',
              response: response,
              verification: active,
              alreadyDeleted: false,
              expected: EndFlowActionResult.failed,
            ),
            (
              label: 'anomaly + unavailable',
              response: response,
              verification: unavailable,
              alreadyDeleted: false,
              expected: EndFlowActionResult.failed,
            ),
          ],
          (
            label: 'already deleted + inactive',
            response: null,
            verification: inactive,
            alreadyDeleted: true,
            expected: EndFlowActionResult.success,
          ),
          (
            label: 'already deleted + unavailable',
            response: null,
            verification: unavailable,
            alreadyDeleted: true,
            expected: EndFlowActionResult.success,
          ),
          (
            label: 'already deleted + active',
            response: null,
            verification: active,
            alreadyDeleted: true,
            expected: EndFlowActionResult.failed,
          ),
        ];

    for (final testCase in cases) {
      final outcome = resolveEndFlowPostRpc(
        requestedFlowId: 919,
        operationId: testCase.label,
        referenceCode: 'EF-MATRIX',
        rpcResponse: testCase.response,
        verification: testCase.verification,
        alreadyDeleted: testCase.alreadyDeleted,
      );
      expect(outcome.result, testCase.expected, reason: testCase.label);
      expect(
        outcome.verificationStatus,
        testCase.verification.status,
        reason: testCase.label,
      );
    }
  });

  test('terminal diagnostics retain protocol and verification evidence', () {
    final response = EndFlowRpcResponse.fromRow(<String, dynamic>{
      'flow_id': 920,
      'deleted_event_count': 30,
      'retired_notification_count': 4,
      'deleted_completion_count': 2,
    });
    final outcome = resolveEndFlowPostRpc(
      requestedFlowId: 919,
      operationId: 'protocol-evidence',
      referenceCode: 'EF-EVIDENCE',
      rpcResponse: response,
      verification: const EndFlowVerificationResult.unavailable(
        failureKind: EndFlowFailureKind.transport,
      ),
    );
    final record = EndFlowDiagnostics(capacity: 2).recordTerminal(
      flowId: 919,
      outcome: outcome,
      initiatorOwner: EndFlowOperationOwner.test,
    );

    expect(record.rpcIdentityStatus, EndFlowRpcIdentityStatus.mismatching);
    expect(record.rpcReturnedFlowId, 920);
    expect(record.rpcReturnedFlowIdRaw, '920');
    expect(record.deletedEventCount, 30);
    expect(record.verificationStatus, EndFlowVerificationStatus.unavailable);
    expect(record.verificationFailureKind, EndFlowFailureKind.transport);
    expect(record.referenceCode, 'EF-EVIDENCE');
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
