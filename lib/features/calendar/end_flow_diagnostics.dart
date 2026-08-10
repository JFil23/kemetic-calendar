import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../telemetry/telemetry.dart';

enum EndFlowActionResult { success, failed, notHandled }

enum EndFlowFailureKind {
  sessionNotReady,
  transport,
  authorization,
  server,
  unknown,
}

enum EndFlowTerminalStage {
  preRpcGuard,
  rpcErrorReturned,
  rpcNoResponse,
  postRpcVerification,
  postCommit,
}

enum EndFlowRpcIdentityStatus { matching, mismatching, missing, malformed }

enum EndFlowVerificationStatus { inactive, active, unavailable }

enum EndFlowOperationOwner { calendar, detachedMyFlows, test }

enum EndFlowDiagnosticRecordKind {
  rpcAttempted,
  canonicalTerminal,
  callerSurface,
  sideEffect,
}

enum EndFlowSideEffectKind { telemetry, filingCacheClear, invalidationPublish }

extension on EndFlowActionResult {
  String get diagnosticValue => switch (this) {
    EndFlowActionResult.success => 'success',
    EndFlowActionResult.failed => 'failed',
    EndFlowActionResult.notHandled => 'not_handled',
  };
}

extension on EndFlowFailureKind {
  String get diagnosticValue => switch (this) {
    EndFlowFailureKind.sessionNotReady => 'session_not_ready',
    EndFlowFailureKind.transport => 'transport',
    EndFlowFailureKind.authorization => 'authorization',
    EndFlowFailureKind.server => 'server',
    EndFlowFailureKind.unknown => 'unknown',
  };
}

extension on EndFlowTerminalStage {
  String get diagnosticValue => switch (this) {
    EndFlowTerminalStage.preRpcGuard => 'pre_rpc_guard',
    EndFlowTerminalStage.rpcErrorReturned => 'rpc_error_returned',
    EndFlowTerminalStage.rpcNoResponse => 'rpc_no_response',
    EndFlowTerminalStage.postRpcVerification => 'post_rpc_verification',
    EndFlowTerminalStage.postCommit => 'post_commit',
  };
}

extension on EndFlowRpcIdentityStatus {
  String get diagnosticValue => switch (this) {
    EndFlowRpcIdentityStatus.matching => 'matching',
    EndFlowRpcIdentityStatus.mismatching => 'mismatching',
    EndFlowRpcIdentityStatus.missing => 'missing',
    EndFlowRpcIdentityStatus.malformed => 'malformed',
  };
}

extension on EndFlowVerificationStatus {
  String get diagnosticValue => switch (this) {
    EndFlowVerificationStatus.inactive => 'inactive',
    EndFlowVerificationStatus.active => 'active',
    EndFlowVerificationStatus.unavailable => 'unavailable',
  };
}

extension on EndFlowOperationOwner {
  String get diagnosticValue => switch (this) {
    EndFlowOperationOwner.calendar => 'calendar',
    EndFlowOperationOwner.detachedMyFlows => 'detached_my_flows',
    EndFlowOperationOwner.test => 'test',
  };
}

extension on EndFlowDiagnosticRecordKind {
  String get diagnosticValue => switch (this) {
    EndFlowDiagnosticRecordKind.rpcAttempted => 'rpc_attempted',
    EndFlowDiagnosticRecordKind.canonicalTerminal => 'canonical_terminal',
    EndFlowDiagnosticRecordKind.callerSurface => 'caller_surface',
    EndFlowDiagnosticRecordKind.sideEffect => 'side_effect',
  };
}

extension on EndFlowSideEffectKind {
  String get diagnosticValue => switch (this) {
    EndFlowSideEffectKind.telemetry => 'telemetry',
    EndFlowSideEffectKind.filingCacheClear => 'filing_cache_clear',
    EndFlowSideEffectKind.invalidationPublish => 'invalidation_publish',
  };
}

@immutable
class EndFlowOutcome {
  const EndFlowOutcome({
    required this.result,
    required this.failureKind,
    required this.terminalStage,
    required this.operationId,
    required this.rpcAttempted,
    required this.postgrestCode,
    required this.httpStatus,
    required this.referenceCode,
    this.rpcIdentityStatus,
    this.rpcReturnedFlowId,
    this.rpcReturnedFlowIdRaw,
    this.deletedEventCount,
    this.retiredNotificationCount,
    this.deletedCompletionCount,
    this.verificationStatus,
    this.verificationFailureKind,
    this.verificationPostgrestCode,
    this.verificationHttpStatus,
    this.alreadyDeleted = false,
  });

  factory EndFlowOutcome.success({required String operationId}) =>
      EndFlowOutcome(
        result: EndFlowActionResult.success,
        failureKind: null,
        terminalStage: EndFlowTerminalStage.postCommit,
        operationId: operationId,
        rpcAttempted: true,
        postgrestCode: null,
        httpStatus: null,
        referenceCode: endFlowReferenceCode(operationId),
      );

  factory EndFlowOutcome.notHandled({required String operationId}) =>
      EndFlowOutcome(
        result: EndFlowActionResult.notHandled,
        failureKind: EndFlowFailureKind.unknown,
        terminalStage: EndFlowTerminalStage.preRpcGuard,
        operationId: operationId,
        rpcAttempted: false,
        postgrestCode: null,
        httpStatus: null,
        referenceCode: endFlowReferenceCode(operationId),
      );

  factory EndFlowOutcome.failure({
    required String operationId,
    required EndFlowFailureKind failureKind,
    EndFlowTerminalStage terminalStage = EndFlowTerminalStage.rpcErrorReturned,
    bool rpcAttempted = true,
    String? postgrestCode,
    int? httpStatus,
  }) => EndFlowOutcome(
    result: EndFlowActionResult.failed,
    failureKind: failureKind,
    terminalStage: terminalStage,
    operationId: operationId,
    rpcAttempted: rpcAttempted,
    postgrestCode: postgrestCode,
    httpStatus: httpStatus,
    referenceCode: endFlowReferenceCode(operationId),
  );

  final EndFlowActionResult result;
  final EndFlowFailureKind? failureKind;
  final EndFlowTerminalStage terminalStage;
  final String operationId;
  final bool rpcAttempted;
  final String? postgrestCode;
  final int? httpStatus;
  final String referenceCode;
  final EndFlowRpcIdentityStatus? rpcIdentityStatus;
  final int? rpcReturnedFlowId;
  final String? rpcReturnedFlowIdRaw;
  final int? deletedEventCount;
  final int? retiredNotificationCount;
  final int? deletedCompletionCount;
  final EndFlowVerificationStatus? verificationStatus;
  final EndFlowFailureKind? verificationFailureKind;
  final String? verificationPostgrestCode;
  final int? verificationHttpStatus;
  final bool alreadyDeleted;

  bool get isSuccess => result == EndFlowActionResult.success;

  Map<String, Object?> toDiagnosticFields() => <String, Object?>{
    'result': result.diagnosticValue,
    'failure_kind': failureKind?.diagnosticValue,
    'terminal_stage': terminalStage.diagnosticValue,
    'operation_id': operationId,
    'rpc_attempted': rpcAttempted,
    'postgrest_code': postgrestCode,
    'http_status': httpStatus,
    'reference_code': referenceCode,
    'rpc_identity_status': rpcIdentityStatus?.diagnosticValue,
    'rpc_returned_flow_id': rpcReturnedFlowId,
    'rpc_returned_flow_id_raw': rpcReturnedFlowIdRaw,
    'deleted_event_count': deletedEventCount,
    'retired_notification_count': retiredNotificationCount,
    'deleted_completion_count': deletedCompletionCount,
    'verification_status': verificationStatus?.diagnosticValue,
    'verification_failure_kind': verificationFailureKind?.diagnosticValue,
    'verification_postgrest_code': verificationPostgrestCode,
    'verification_http_status': verificationHttpStatus,
    'already_deleted': alreadyDeleted,
  };
}

@immutable
class EndFlowRpcResponse {
  const EndFlowRpcResponse({
    required this.flowIdFieldPresent,
    required this.rawFlowId,
    required this.parsedFlowId,
    this.deletedEventCount,
    this.retiredNotificationCount,
    this.deletedCompletionCount,
  });

  factory EndFlowRpcResponse.fromRow(Map<String, dynamic>? row) {
    final present = row?.containsKey('flow_id') ?? false;
    final rawFlowId = present ? row!['flow_id'] : null;
    return EndFlowRpcResponse(
      flowIdFieldPresent: present,
      rawFlowId: rawFlowId,
      parsedFlowId: _strictDiagnosticInteger(rawFlowId),
      deletedEventCount: _strictDiagnosticInteger(row?['deleted_event_count']),
      retiredNotificationCount: _strictDiagnosticInteger(
        row?['retired_notification_count'],
      ),
      deletedCompletionCount: _strictDiagnosticInteger(
        row?['deleted_completion_count'],
      ),
    );
  }

  factory EndFlowRpcResponse.matching(
    int flowId, {
    int deletedEventCount = 0,
    int retiredNotificationCount = 0,
    int deletedCompletionCount = 0,
  }) => EndFlowRpcResponse(
    flowIdFieldPresent: true,
    rawFlowId: flowId,
    parsedFlowId: flowId,
    deletedEventCount: deletedEventCount,
    retiredNotificationCount: retiredNotificationCount,
    deletedCompletionCount: deletedCompletionCount,
  );

  final bool flowIdFieldPresent;
  final Object? rawFlowId;
  final int? parsedFlowId;
  final int? deletedEventCount;
  final int? retiredNotificationCount;
  final int? deletedCompletionCount;

  EndFlowRpcIdentityStatus identityStatusFor(int requestedFlowId) {
    if (!flowIdFieldPresent || rawFlowId == null) {
      return EndFlowRpcIdentityStatus.missing;
    }
    final parsed = parsedFlowId;
    if (parsed == null) return EndFlowRpcIdentityStatus.malformed;
    return parsed == requestedFlowId
        ? EndFlowRpcIdentityStatus.matching
        : EndFlowRpcIdentityStatus.mismatching;
  }

  String get rawFlowIdDiagnosticValue {
    if (!flowIdFieldPresent) return '<missing>';
    final raw = rawFlowId;
    if (raw == null) return '<null>';
    if (raw is num || raw is bool || raw is String) {
      final safe = redactLogText(raw.toString());
      return safe.length <= 80 ? safe : '${safe.substring(0, 80)}…';
    }
    return '<${raw.runtimeType}>';
  }
}

int? _strictDiagnosticInteger(Object? raw) {
  if (raw is int) return raw;
  if (raw is num && raw.isFinite && raw == raw.truncateToDouble()) {
    return raw.toInt();
  }
  return null;
}

@immutable
class EndFlowVerificationResult {
  const EndFlowVerificationResult._({
    required this.status,
    this.failureKind,
    this.postgrestCode,
    this.httpStatus,
  });

  const EndFlowVerificationResult.inactive()
    : this._(status: EndFlowVerificationStatus.inactive);

  const EndFlowVerificationResult.active()
    : this._(status: EndFlowVerificationStatus.active);

  const EndFlowVerificationResult.unavailable({
    EndFlowFailureKind? failureKind,
    String? postgrestCode,
    int? httpStatus,
  }) : this._(
         status: EndFlowVerificationStatus.unavailable,
         failureKind: failureKind,
         postgrestCode: postgrestCode,
         httpStatus: httpStatus,
       );

  final EndFlowVerificationStatus status;
  final EndFlowFailureKind? failureKind;
  final String? postgrestCode;
  final int? httpStatus;
}

EndFlowOutcome resolveEndFlowPostRpc({
  required int requestedFlowId,
  required String operationId,
  required String referenceCode,
  required EndFlowRpcResponse? rpcResponse,
  required EndFlowVerificationResult verification,
  bool alreadyDeleted = false,
}) {
  assert(alreadyDeleted || rpcResponse != null);
  final identity = rpcResponse?.identityStatusFor(requestedFlowId);
  final commits = alreadyDeleted
      ? verification.status != EndFlowVerificationStatus.active
      : identity == EndFlowRpcIdentityStatus.matching
      ? verification.status != EndFlowVerificationStatus.active
      : verification.status == EndFlowVerificationStatus.inactive;
  final failureKind = commits
      ? null
      : verification.status == EndFlowVerificationStatus.unavailable
      ? verification.failureKind ?? EndFlowFailureKind.server
      : EndFlowFailureKind.server;

  return EndFlowOutcome(
    result: commits ? EndFlowActionResult.success : EndFlowActionResult.failed,
    failureKind: failureKind,
    terminalStage: commits
        ? EndFlowTerminalStage.postCommit
        : EndFlowTerminalStage.postRpcVerification,
    operationId: operationId,
    rpcAttempted: true,
    postgrestCode: commits ? null : verification.postgrestCode,
    httpStatus: commits ? null : verification.httpStatus,
    referenceCode: referenceCode,
    rpcIdentityStatus: identity,
    rpcReturnedFlowId: rpcResponse?.parsedFlowId,
    rpcReturnedFlowIdRaw: rpcResponse?.rawFlowIdDiagnosticValue,
    deletedEventCount: rpcResponse?.deletedEventCount,
    retiredNotificationCount: rpcResponse?.retiredNotificationCount,
    deletedCompletionCount: rpcResponse?.deletedCompletionCount,
    verificationStatus: verification.status,
    verificationFailureKind: verification.failureKind,
    verificationPostgrestCode: verification.postgrestCode,
    verificationHttpStatus: verification.httpStatus,
    alreadyDeleted: alreadyDeleted,
  );
}

@immutable
class EndFlowFailureClassification {
  const EndFlowFailureClassification({
    required this.failureKind,
    required this.terminalStage,
    this.postgrestCode,
    this.httpStatus,
  });

  final EndFlowFailureKind failureKind;
  final EndFlowTerminalStage terminalStage;
  final String? postgrestCode;
  final int? httpStatus;
}

@immutable
class EndFlowDiagnosticRecord {
  const EndFlowDiagnosticRecord({
    required this.recordKind,
    required this.recordedAtUtc,
    required this.flowId,
    required this.operationId,
    required this.referenceCode,
    required this.initiatorOwner,
    required this.rpcAttempted,
    this.callerOwner,
    this.result,
    this.failureKind,
    this.terminalStage,
    this.postgrestCode,
    this.httpStatus,
    this.sideEffectKind,
    this.rpcIdentityStatus,
    this.rpcReturnedFlowId,
    this.rpcReturnedFlowIdRaw,
    this.deletedEventCount,
    this.retiredNotificationCount,
    this.deletedCompletionCount,
    this.verificationStatus,
    this.verificationFailureKind,
    this.verificationPostgrestCode,
    this.verificationHttpStatus,
    this.alreadyDeleted = false,
  });

  final EndFlowDiagnosticRecordKind recordKind;
  final DateTime recordedAtUtc;
  final int flowId;
  final String operationId;
  final String referenceCode;
  final EndFlowOperationOwner initiatorOwner;
  final EndFlowOperationOwner? callerOwner;
  final EndFlowActionResult? result;
  final EndFlowFailureKind? failureKind;
  final EndFlowTerminalStage? terminalStage;
  final bool rpcAttempted;
  final String? postgrestCode;
  final int? httpStatus;
  final EndFlowSideEffectKind? sideEffectKind;
  final EndFlowRpcIdentityStatus? rpcIdentityStatus;
  final int? rpcReturnedFlowId;
  final String? rpcReturnedFlowIdRaw;
  final int? deletedEventCount;
  final int? retiredNotificationCount;
  final int? deletedCompletionCount;
  final EndFlowVerificationStatus? verificationStatus;
  final EndFlowFailureKind? verificationFailureKind;
  final String? verificationPostgrestCode;
  final int? verificationHttpStatus;
  final bool alreadyDeleted;

  Map<String, Object?> toJson() => <String, Object?>{
    'record_kind': recordKind.diagnosticValue,
    'recorded_at_utc': recordedAtUtc.toUtc().toIso8601String(),
    'flow_id': flowId,
    'operation_id': operationId,
    'reference_code': referenceCode,
    'initiator_owner': initiatorOwner.diagnosticValue,
    'caller_owner': callerOwner?.diagnosticValue,
    'result': result?.diagnosticValue,
    'failure_kind': failureKind?.diagnosticValue,
    'terminal_stage': terminalStage?.diagnosticValue,
    'rpc_attempted': rpcAttempted,
    'postgrest_code': postgrestCode,
    'http_status': httpStatus,
    'side_effect_kind': sideEffectKind?.diagnosticValue,
    'rpc_identity_status': rpcIdentityStatus?.diagnosticValue,
    'rpc_returned_flow_id': rpcReturnedFlowId,
    'rpc_returned_flow_id_raw': rpcReturnedFlowIdRaw,
    'deleted_event_count': deletedEventCount,
    'retired_notification_count': retiredNotificationCount,
    'deleted_completion_count': deletedCompletionCount,
    'verification_status': verificationStatus?.diagnosticValue,
    'verification_failure_kind': verificationFailureKind?.diagnosticValue,
    'verification_postgrest_code': verificationPostgrestCode,
    'verification_http_status': verificationHttpStatus,
    'already_deleted': alreadyDeleted,
  };
}

/// One process-wide readiness signal. Surfaces may listen to it, but they do
/// not create their own auth subscriptions.
class EndFlowAuthReadiness {
  EndFlowAuthReadiness._();

  static final EndFlowAuthReadiness instance = EndFlowAuthReadiness._();

  // Unbound keeps legacy presentation intact in isolated widget hosts. Real
  // app surfaces bind synchronously before their first build.
  final ValueNotifier<bool> _ready = ValueNotifier<bool>(true);
  StreamSubscription<AuthState>? _subscription;
  SupabaseClient? _client;
  bool? _testOverride;

  ValueListenable<bool> get listenable => _ready;
  bool get isReady => _ready.value;

  void ensureBound(SupabaseClient client) {
    if (!identical(_client, client)) {
      unawaited(_subscription?.cancel());
      _client = client;
      _subscription = client.auth.onAuthStateChange.listen(
        (_) => _syncFromClient(),
        onError: (_, _) => _setReady(false),
      );
    }
    _syncFromClient();
  }

  void _syncFromClient() {
    final override = _testOverride;
    if (override != null) {
      _setReady(override);
      return;
    }
    final client = _client;
    _setReady(
      client?.auth.currentSession != null && client?.auth.currentUser != null,
    );
  }

  void _setReady(bool value) {
    if (_ready.value == value) return;
    _ready.value = value;
  }

  void debugSetReadyForTesting(bool? value) {
    _testOverride = value;
    _syncFromClient();
  }
}

class EndFlowDiagnostics {
  EndFlowDiagnostics({this.capacity = 40}) : assert(capacity > 0);

  static final EndFlowDiagnostics instance = EndFlowDiagnostics();

  /// Records are ordered newest first and live only for this process.
  final int capacity;
  final List<EndFlowDiagnosticRecord> _records = <EndFlowDiagnosticRecord>[];

  List<EndFlowDiagnosticRecord> get records =>
      List<EndFlowDiagnosticRecord>.unmodifiable(_records);

  EndFlowDiagnosticRecord recordRpcAttempted({
    required int flowId,
    required String operationId,
    required String referenceCode,
    required EndFlowOperationOwner initiatorOwner,
  }) => record(
    EndFlowDiagnosticRecord(
      recordKind: EndFlowDiagnosticRecordKind.rpcAttempted,
      recordedAtUtc: DateTime.now().toUtc(),
      flowId: flowId,
      operationId: operationId,
      referenceCode: referenceCode,
      initiatorOwner: initiatorOwner,
      rpcAttempted: true,
    ),
  );

  EndFlowDiagnosticRecord recordTerminal({
    required int flowId,
    required EndFlowOutcome outcome,
    required EndFlowOperationOwner initiatorOwner,
  }) => record(
    EndFlowDiagnosticRecord(
      recordKind: EndFlowDiagnosticRecordKind.canonicalTerminal,
      recordedAtUtc: DateTime.now().toUtc(),
      flowId: flowId,
      operationId: outcome.operationId,
      referenceCode: outcome.referenceCode,
      initiatorOwner: initiatorOwner,
      result: outcome.result,
      failureKind: outcome.failureKind,
      terminalStage: outcome.terminalStage,
      rpcAttempted: outcome.rpcAttempted,
      postgrestCode: outcome.postgrestCode,
      httpStatus: outcome.httpStatus,
      rpcIdentityStatus: outcome.rpcIdentityStatus,
      rpcReturnedFlowId: outcome.rpcReturnedFlowId,
      rpcReturnedFlowIdRaw: outcome.rpcReturnedFlowIdRaw,
      deletedEventCount: outcome.deletedEventCount,
      retiredNotificationCount: outcome.retiredNotificationCount,
      deletedCompletionCount: outcome.deletedCompletionCount,
      verificationStatus: outcome.verificationStatus,
      verificationFailureKind: outcome.verificationFailureKind,
      verificationPostgrestCode: outcome.verificationPostgrestCode,
      verificationHttpStatus: outcome.verificationHttpStatus,
      alreadyDeleted: outcome.alreadyDeleted,
    ),
  );

  EndFlowDiagnosticRecord recordSideEffect({
    required int flowId,
    required EndFlowOutcome outcome,
    required EndFlowOperationOwner initiatorOwner,
    required EndFlowSideEffectKind sideEffectKind,
  }) => record(
    EndFlowDiagnosticRecord(
      recordKind: EndFlowDiagnosticRecordKind.sideEffect,
      recordedAtUtc: DateTime.now().toUtc(),
      flowId: flowId,
      operationId: outcome.operationId,
      referenceCode: outcome.referenceCode,
      initiatorOwner: initiatorOwner,
      rpcAttempted: outcome.rpcAttempted,
      sideEffectKind: sideEffectKind,
    ),
  );

  EndFlowDiagnosticRecord record(EndFlowDiagnosticRecord value) {
    _records.insert(0, value);
    if (_records.length > capacity) {
      _records.removeRange(capacity, _records.length);
    }
    developer.log(
      jsonEncode(value.toJson()),
      name: 'kemet.end_flow',
      level: value.recordKind == EndFlowDiagnosticRecordKind.canonicalTerminal
          ? 900
          : 800,
    );
    return value;
  }

  EndFlowDiagnosticRecord? terminalRecordFor(String operationId) {
    for (final record in _records) {
      if (record.operationId == operationId &&
          record.recordKind == EndFlowDiagnosticRecordKind.canonicalTerminal) {
        return record;
      }
    }
    return null;
  }

  String? copyPayloadForOperation(String operationId) {
    final record = terminalRecordFor(operationId);
    if (record == null) return null;
    return const JsonEncoder.withIndent('  ').convert(record.toJson());
  }

  Future<bool> copyTerminalDiagnostics(String operationId) async {
    final payload = copyPayloadForOperation(operationId);
    if (payload == null) return false;
    await Clipboard.setData(ClipboardData(text: payload));
    return true;
  }

  void debugReset() => _records.clear();
}

String endFlowReferenceCode(String operationId) {
  final compact = operationId.replaceAll('-', '').toUpperCase();
  final suffix = compact.length >= 8 ? compact.substring(0, 8) : compact;
  return 'EF-$suffix';
}

String? _safeDiagnosticCode(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final redacted = redactLogText(trimmed);
  if (!RegExp(r'^[A-Za-z0-9_.-]{1,48}$').hasMatch(redacted)) {
    return 'redacted';
  }
  return redacted;
}

int? _httpStatusFromCode(String? value) {
  final parsed = int.tryParse(value ?? '');
  if (parsed == null || parsed < 100 || parsed > 599) return null;
  return parsed;
}

EndFlowFailureClassification classifyEndFlowFailure(Object error) {
  if (error is TimeoutException || error is http.ClientException) {
    return const EndFlowFailureClassification(
      failureKind: EndFlowFailureKind.transport,
      terminalStage: EndFlowTerminalStage.rpcNoResponse,
    );
  }
  if (error is AuthRetryableFetchException) {
    return EndFlowFailureClassification(
      failureKind: EndFlowFailureKind.transport,
      terminalStage: EndFlowTerminalStage.rpcNoResponse,
      httpStatus: _httpStatusFromCode(error.statusCode),
    );
  }
  if (error is AuthException) {
    return EndFlowFailureClassification(
      failureKind: EndFlowFailureKind.authorization,
      terminalStage: EndFlowTerminalStage.rpcErrorReturned,
      postgrestCode: _safeDiagnosticCode(error.code),
      httpStatus: _httpStatusFromCode(error.statusCode),
    );
  }
  if (error is PostgrestException) {
    final code = _safeDiagnosticCode(error.code);
    final httpStatus = _httpStatusFromCode(error.code);
    final isAuthorization =
        code == '42501' ||
        code == '401' ||
        code == '403' ||
        code == 'PGRST301' ||
        code == 'PGRST302' ||
        code == 'PGRST303';
    return EndFlowFailureClassification(
      failureKind: isAuthorization
          ? EndFlowFailureKind.authorization
          : EndFlowFailureKind.server,
      terminalStage: EndFlowTerminalStage.rpcErrorReturned,
      postgrestCode: code,
      httpStatus: httpStatus,
    );
  }
  return const EndFlowFailureClassification(
    failureKind: EndFlowFailureKind.unknown,
    terminalStage: EndFlowTerminalStage.rpcNoResponse,
  );
}

String endFlowFailureMessage(EndFlowFailureKind? kind) => switch (kind) {
  EndFlowFailureKind.sessionNotReady =>
    'Your session isn’t ready. Try again in a moment.',
  EndFlowFailureKind.transport =>
    'Couldn’t reach the server. Check your connection and try again.',
  EndFlowFailureKind.authorization =>
    'You don’t have permission to end this flow.',
  EndFlowFailureKind.server =>
    'The server couldn’t end this flow. Try again in a moment.',
  EndFlowFailureKind.unknown ||
  null => 'Could not end this flow right now. Try again.',
};

String endFlowFailureDisplayMessage(EndFlowOutcome outcome) =>
    '${endFlowFailureMessage(outcome.failureKind)}\n'
    'Reference ${outcome.referenceCode}';
