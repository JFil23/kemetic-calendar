import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum HydrationLaunchKind { coldProcess, warmReturn }

enum HydrationTraceCloseReason { settled, timeout, navigation }

enum HydrationFetchStatus {
  successNonempty,
  successfulEmpty,
  failed,
  unauthenticated,
  notRun,
}

@immutable
class HydrationFetchResult<T> {
  const HydrationFetchResult._({required this.status, required this.value});

  const HydrationFetchResult.successNonempty(T value)
    : this._(status: HydrationFetchStatus.successNonempty, value: value);

  const HydrationFetchResult.successfulEmpty(T value)
    : this._(status: HydrationFetchStatus.successfulEmpty, value: value);

  const HydrationFetchResult.failed(T value)
    : this._(status: HydrationFetchStatus.failed, value: value);

  const HydrationFetchResult.unauthenticated(T value)
    : this._(status: HydrationFetchStatus.unauthenticated, value: value);

  final HydrationFetchStatus status;
  final T value;

  bool get succeeded =>
      status == HydrationFetchStatus.successNonempty ||
      status == HydrationFetchStatus.successfulEmpty;

  bool get failed => status == HydrationFetchStatus.failed;
  bool get unauthenticated => status == HydrationFetchStatus.unauthenticated;
}

extension HydrationDiagnosticName on Enum {
  String get diagnosticName {
    final raw = name;
    final result = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      final codeUnit = raw.codeUnitAt(index);
      final isUppercase = codeUnit >= 65 && codeUnit <= 90;
      if (isUppercase && index > 0) result.write('_');
      result.writeCharCode(isUppercase ? codeUnit + 32 : codeUnit);
    }
    return result.toString();
  }
}

@immutable
class HydrationDiagnosticContext {
  const HydrationDiagnosticContext({
    required this.traceId,
    required this.passEpoch,
    required this.requestedSource,
    required this.executedSource,
    required this.operationId,
  });

  final String traceId;
  final int passEpoch;
  final String requestedSource;
  final String executedSource;
  final String operationId;

  HydrationDiagnosticContext child(String operationId) =>
      HydrationDiagnosticContext(
        traceId: traceId,
        passEpoch: passEpoch,
        requestedSource: requestedSource,
        executedSource: executedSource,
        operationId: operationId,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'trace_id': traceId,
    'pass_epoch': passEpoch,
    'requested_source': requestedSource,
    'executed_source': executedSource,
    'operation_id': operationId,
  };
}

@immutable
class HydrationAsyncWorkToken {
  const HydrationAsyncWorkToken({required this.traceId, required this.label});

  final String traceId;
  final String label;
}

({int kYear, int kMonth, int kDay}) selectHydrationDiagnosticDay({
  required int fallbackKYear,
  required int fallbackKMonth,
  required int fallbackKDay,
  bool activeDayViewOpen = false,
  int? activeKYear,
  int? activeKMonth,
  int? activeKDay,
}) {
  if (activeDayViewOpen &&
      activeKYear != null &&
      activeKMonth != null &&
      activeKDay != null) {
    return (kYear: activeKYear, kMonth: activeKMonth, kDay: activeKDay);
  }
  return (kYear: fallbackKYear, kMonth: fallbackKMonth, kDay: fallbackKDay);
}

@immutable
class HydrationSelectedDaySnapshot {
  const HydrationSelectedDaySnapshot({
    required this.dayKey,
    required this.eventCount,
    required this.flowBackedCount,
    required this.reminderCount,
    required this.standaloneCount,
    required this.startMinuteSum,
    required this.multisetChecksum,
  });

  static const empty = HydrationSelectedDaySnapshot(
    dayKey: '',
    eventCount: 0,
    flowBackedCount: 0,
    reminderCount: 0,
    standaloneCount: 0,
    startMinuteSum: 0,
    multisetChecksum: 0,
  );

  final String dayKey;
  final int eventCount;
  final int flowBackedCount;
  final int reminderCount;
  final int standaloneCount;
  final int startMinuteSum;
  final int multisetChecksum;

  Map<String, Object?> toJson() => <String, Object?>{
    'day_key': dayKey,
    'event_count': eventCount,
    'flow_backed_count': flowBackedCount,
    'reminder_count': reminderCount,
    'standalone_count': standaloneCount,
    'start_minute_sum': startMinuteSum,
    'multiset_checksum': multisetChecksum,
  };

  bool structurallyMatches(HydrationSelectedDaySnapshot other) =>
      dayKey == other.dayKey &&
      eventCount == other.eventCount &&
      flowBackedCount == other.flowBackedCount &&
      reminderCount == other.reminderCount &&
      standaloneCount == other.standaloneCount &&
      startMinuteSum == other.startMinuteSum &&
      multisetChecksum == other.multisetChecksum;
}

@immutable
class HydrationBatchMappingStats {
  const HydrationBatchMappingStats({
    required this.requestedFlowCount,
    required this.rawRowCount,
    required this.mappedRowCount,
    required this.mappedFlowCount,
    required this.nullFlowIdRowCount,
    required this.outsideRequestedSetRowCount,
  });

  final int requestedFlowCount;
  final int rawRowCount;
  final int mappedRowCount;
  final int mappedFlowCount;
  final int nullFlowIdRowCount;
  final int outsideRequestedSetRowCount;

  bool get hasEmptyMapFromNonemptyRows =>
      rawRowCount > 0 && mappedRowCount == 0;

  bool get isConsistent =>
      !hasEmptyMapFromNonemptyRows &&
      nullFlowIdRowCount == 0 &&
      outsideRequestedSetRowCount == 0;

  Map<String, Object?> toJson() => <String, Object?>{
    'batch_requested_flow_count': requestedFlowCount,
    'batch_raw_row_count': rawRowCount,
    'batch_mapped_row_count': mappedRowCount,
    'batch_mapped_flow_count': mappedFlowCount,
    'batch_null_flow_id_row_count': nullFlowIdRowCount,
    'batch_outside_requested_set_row_count': outsideRequestedSetRowCount,
  };
}

@immutable
class HydrationCompletenessInput {
  const HydrationCompletenessInput({
    required this.catalogStatus,
    required this.hydrationFlowCount,
    required this.batchStatus,
    required this.fallbackRequestCount,
    required this.fallbackFailedCount,
    required this.fallbackNonemptyCount,
    required this.standaloneStatus,
    required this.mapping,
  });

  final HydrationFetchStatus catalogStatus;
  final int hydrationFlowCount;
  final HydrationFetchStatus batchStatus;
  final int fallbackRequestCount;
  final int fallbackFailedCount;
  final int fallbackNonemptyCount;
  final HydrationFetchStatus standaloneStatus;
  final HydrationBatchMappingStats? mapping;
}

@immutable
class HydrationCompletenessResult {
  const HydrationCompletenessResult({
    required this.fetchComplete,
    required this.mappingConsistent,
    required this.semanticComplete,
    required this.allAttemptsSucceeded,
    required this.completenessAnomaly,
    required this.reasons,
  });

  final bool fetchComplete;
  final bool mappingConsistent;
  final bool semanticComplete;
  final bool allAttemptsSucceeded;
  final bool completenessAnomaly;
  final List<String> reasons;

  Map<String, Object?> toJson() => <String, Object?>{
    'fetch_complete': fetchComplete,
    'mapping_consistent': mappingConsistent,
    'semantic_complete': semanticComplete,
    'all_attempts_succeeded': allAttemptsSucceeded,
    'semantic_incomplete_reasons': reasons,
    'completeness_anomaly': completenessAnomaly,
  };
}

bool _fetchSucceeded(HydrationFetchStatus status) =>
    status == HydrationFetchStatus.successNonempty ||
    status == HydrationFetchStatus.successfulEmpty;

HydrationCompletenessResult evaluateHydrationCompleteness(
  HydrationCompletenessInput input,
) {
  final reasons = <String>[];
  final catalogSucceeded = _fetchSucceeded(input.catalogStatus);
  final standaloneSucceeded = _fetchSucceeded(input.standaloneStatus);
  if (!catalogSucceeded) {
    reasons.add('flow_catalog_${input.catalogStatus.diagnosticName}');
  }
  if (!standaloneSucceeded) {
    reasons.add('standalone_${input.standaloneStatus.diagnosticName}');
  }

  var flowLaneComplete = false;
  var allAttemptsSucceeded = true;
  var mappingConsistent = input.mapping?.isConsistent ?? true;
  var anomaly = false;

  if (catalogSucceeded && input.hydrationFlowCount == 0) {
    flowLaneComplete = true;
  } else if (catalogSucceeded) {
    final batchSucceeded = _fetchSucceeded(input.batchStatus);
    if (batchSucceeded &&
        input.batchStatus == HydrationFetchStatus.successNonempty) {
      flowLaneComplete = true;
    } else if (input.fallbackRequestCount > 0) {
      flowLaneComplete = input.fallbackFailedCount == 0;
      if (input.fallbackFailedCount > 0) {
        reasons.add('flow_fallback_failed');
        allAttemptsSucceeded = false;
      }
      if (input.batchStatus == HydrationFetchStatus.failed ||
          input.batchStatus == HydrationFetchStatus.unauthenticated) {
        allAttemptsSucceeded = false;
      }
      if (input.batchStatus == HydrationFetchStatus.successfulEmpty &&
          input.fallbackNonemptyCount > 0) {
        anomaly = true;
        mappingConsistent = false;
        reasons.add('empty_batch_vs_fallback_events');
      }
    } else if (batchSucceeded) {
      flowLaneComplete = true;
    } else {
      reasons.add('flow_batch_${input.batchStatus.diagnosticName}');
      allAttemptsSucceeded = false;
    }
  }

  final mapping = input.mapping;
  if (mapping?.hasEmptyMapFromNonemptyRows ?? false) {
    reasons.add('mapping_none_mapped');
  }
  if ((mapping?.nullFlowIdRowCount ?? 0) > 0) {
    reasons.add('mapping_null_flow_id');
  }
  if ((mapping?.outsideRequestedSetRowCount ?? 0) > 0) {
    reasons.add('mapping_outside_requested_set');
  }
  if (!mappingConsistent && reasons.isEmpty) {
    reasons.add('mapping_inconsistent');
  }

  final fetchComplete =
      catalogSucceeded && standaloneSucceeded && flowLaneComplete;
  final semanticComplete = fetchComplete && mappingConsistent && !anomaly;
  return HydrationCompletenessResult(
    fetchComplete: fetchComplete,
    mappingConsistent: mappingConsistent,
    semanticComplete: semanticComplete,
    allAttemptsSucceeded:
        allAttemptsSucceeded && catalogSucceeded && standaloneSucceeded,
    completenessAnomaly: anomaly,
    reasons: List<String>.unmodifiable(reasons),
  );
}

class CalendarHydrationDiagnostics {
  CalendarHydrationDiagnostics({
    this.capacity = 320,
    this.hardTimeout = const Duration(seconds: 15),
    this.quiescentDelay = const Duration(milliseconds: 500),
    this.settleDelay = const Duration(seconds: 1),
  }) : assert(capacity > 0);

  static final CalendarHydrationDiagnostics instance =
      CalendarHydrationDiagnostics();

  static const String _keyPrefix = 'calendar:hydration_trace:v1';
  static const String _backfillKeyPrefix = 'calendar:hydration_backfill:v1';
  static const Set<String> _forbiddenKeys = <String>{
    'title',
    'detail',
    'user_id',
    'userId',
    'event_id',
    'eventId',
    'flow_id',
    'flowId',
    'client_event_id',
    'clientEventId',
  };

  final int capacity;
  final Duration hardTimeout;
  final Duration quiescentDelay;
  final Duration settleDelay;
  final Stopwatch _clock = Stopwatch()..start();

  _HydrationTraceState? _active;
  Map<String, Object?>? _lastCompleted;
  String? _lastCompletedUserId;
  Map<String, Object?>? _lastBackfillSummary;
  String? _lastBackfillUserId;
  String? _currentUserId;
  String _buildLabel = 'unavailable';
  Timer? _hardCloseTimer;
  Timer? _quiescentTimer;
  Timer? _settleTimer;

  bool get hasActiveTrace => _active != null;
  Map<String, Object?>? get lastCompletedTrace => _lastCompleted == null
      ? null
      : Map<String, Object?>.unmodifiable(_lastCompleted!);
  Map<String, Object?>? get lastBackfillSummary => _lastBackfillSummary == null
      ? null
      : Map<String, Object?>.unmodifiable(_lastBackfillSummary!);

  HydrationDiagnosticContext? contextForExecutedSource(String source) {
    final trace = _active;
    if (trace == null) return null;
    _HydrationPassState? match;
    for (final pass in trace.passes.values) {
      if (pass.context.executedSource != source) continue;
      if (match == null || pass.context.passEpoch > match.context.passEpoch) {
        match = pass;
      }
    }
    return match?.context;
  }

  int get nowMs => _clock.elapsedMilliseconds;

  String _key(String userId) => '$_keyPrefix:$userId';
  String _backfillKey(String userId) => '$_backfillKeyPrefix:$userId';

  Future<void> startBackfillSummary({
    required String userId,
    required DateTime focusStartUtc,
    required DateTime focusEndUtc,
    required DateTime unionStartUtc,
    required DateTime unionEndUtc,
    required List<({DateTime startUtc, DateTime endUtc})> chunks,
  }) async {
    _lastBackfillUserId = userId;
    _lastBackfillSummary = <String, Object?>{
      'schema': 1,
      'build': _buildLabel,
      'trace_id': _active?.traceId,
      'started_at_utc': DateTime.now().toUtc().toIso8601String(),
      'focus_start_utc': focusStartUtc.toUtc().toIso8601String(),
      'focus_end_utc': focusEndUtc.toUtc().toIso8601String(),
      'union_start_utc': unionStartUtc.toUtc().toIso8601String(),
      'union_end_utc': unionEndUtc.toUtc().toIso8601String(),
      'chunk_count': chunks.length,
      'chunks': <Object?>[
        for (var index = 0; index < chunks.length; index++)
          <String, Object?>{
            'index': index,
            'start_utc': chunks[index].startUtc.toUtc().toIso8601String(),
            'end_utc': chunks[index].endUtc.toUtc().toIso8601String(),
            'flow_status': HydrationFetchStatus.notRun.diagnosticName,
            'standalone_status': HydrationFetchStatus.notRun.diagnosticName,
            'merged': false,
          },
      ],
      'full_horizon_complete': false,
      'accounting_status': HydrationFetchStatus.notRun.diagnosticName,
      'accounting_duration_ms': 0,
      'cache_save_ended': false,
      'cache_save_outcome': null,
      'cancellation_reason': null,
    };
    await _persistBackfillSummary(userId);
  }

  Future<void> recordBackfillChunk({
    required String userId,
    required int index,
    required HydrationFetchStatus flowStatus,
    required int flowDurationMs,
    DateTime? flowStartedAtUtc,
    DateTime? flowEndedAtUtc,
    required HydrationFetchStatus standaloneStatus,
    required int standaloneDurationMs,
    DateTime? standaloneStartedAtUtc,
    DateTime? standaloneEndedAtUtc,
    required bool merged,
    String? failureReason,
  }) async {
    final summary = _lastBackfillUserId == userId ? _lastBackfillSummary : null;
    final chunks = summary?['chunks'];
    if (summary == null ||
        chunks is! List ||
        index < 0 ||
        index >= chunks.length) {
      return;
    }
    final raw = chunks[index];
    if (raw is! Map) return;
    final chunk = Map<String, Object?>.from(raw);
    chunk
      ..['flow_status'] = flowStatus.diagnosticName
      ..['flow_duration_ms'] = flowDurationMs
      ..['flow_started_at_utc'] = flowStartedAtUtc?.toUtc().toIso8601String()
      ..['flow_ended_at_utc'] = flowEndedAtUtc?.toUtc().toIso8601String()
      ..['standalone_status'] = standaloneStatus.diagnosticName
      ..['standalone_duration_ms'] = standaloneDurationMs
      ..['standalone_started_at_utc'] = standaloneStartedAtUtc
          ?.toUtc()
          .toIso8601String()
      ..['standalone_ended_at_utc'] = standaloneEndedAtUtc
          ?.toUtc()
          .toIso8601String()
      ..['lane_overlap_detected'] =
          flowEndedAtUtc != null &&
          standaloneStartedAtUtc != null &&
          standaloneStartedAtUtc.isBefore(flowEndedAtUtc)
      ..['merged'] = merged
      ..['failure_reason'] = _safeSource(failureReason);
    chunks[index] = chunk;
    await _persistBackfillSummary(userId);
  }

  Future<void> finishBackfillSummary({
    required String userId,
    required bool fullHorizonComplete,
    required bool cacheSaveEnded,
    HydrationFetchStatus accountingStatus = HydrationFetchStatus.notRun,
    int accountingDurationMs = 0,
    DateTime? accountingStartedAtUtc,
    DateTime? accountingEndedAtUtc,
    String? cacheSaveOutcome,
    String? cancellationReason,
  }) async {
    final summary = _lastBackfillUserId == userId ? _lastBackfillSummary : null;
    if (summary == null) return;
    DateTime? finalStandaloneEndedAtUtc;
    final chunks = summary['chunks'];
    if (chunks is List && chunks.isNotEmpty) {
      final lastChunk = chunks.last;
      if (lastChunk is Map) {
        final raw = lastChunk['standalone_ended_at_utc']?.toString();
        finalStandaloneEndedAtUtc = raw == null ? null : DateTime.tryParse(raw);
      }
    }
    summary
      ..['finished_at_utc'] = DateTime.now().toUtc().toIso8601String()
      ..['full_horizon_complete'] = fullHorizonComplete
      ..['accounting_status'] = accountingStatus.diagnosticName
      ..['accounting_duration_ms'] = accountingDurationMs
      ..['accounting_started_at_utc'] = accountingStartedAtUtc
          ?.toUtc()
          .toIso8601String()
      ..['accounting_ended_at_utc'] = accountingEndedAtUtc
          ?.toUtc()
          .toIso8601String()
      ..['accounting_overlap_detected'] =
          finalStandaloneEndedAtUtc != null &&
          accountingStartedAtUtc != null &&
          accountingStartedAtUtc.isBefore(finalStandaloneEndedAtUtc)
      ..['cache_save_ended'] = cacheSaveEnded
      ..['cache_save_outcome'] = _safeSource(cacheSaveOutcome)
      ..['cancellation_reason'] = _safeSource(cancellationReason);
    await _persistBackfillSummary(userId);
  }

  Future<void> _persistBackfillSummary(String userId) async {
    final summary = _lastBackfillSummary;
    if (summary == null || _lastBackfillUserId != userId) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _backfillKey(userId),
        const JsonEncoder.withIndent(' ').convert(_sanitizeMap(summary)),
      );
    } catch (_) {
      // The in-memory artifact remains available when local persistence fails.
    }
  }

  void setBuildLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _buildLabel = trimmed;
    _active?.build = trimmed;
  }

  void startColdProcess({required String userId, String? firstRoute}) {
    startTrace(
      userId: userId,
      launchKind: HydrationLaunchKind.coldProcess,
      firstRoute: firstRoute,
    );
  }

  void startWarmReturn({required String userId, String? firstRoute}) {
    startTrace(
      userId: userId,
      launchKind: HydrationLaunchKind.warmReturn,
      firstRoute: firstRoute,
    );
  }

  void startTrace({
    required String userId,
    required HydrationLaunchKind launchKind,
    String? firstRoute,
  }) {
    if (userId.trim().isEmpty) return;
    if (_active != null) return;
    _currentUserId = userId;
    final traceId = const Uuid().v4();
    _active = _HydrationTraceState(
      traceId: traceId,
      userId: userId,
      launchKind: launchKind,
      build: _buildLabel,
      startedAtUtc: DateTime.now().toUtc(),
      startedAtMs: nowMs,
      firstRoute: firstRoute,
      capacity: capacity,
    );
    _hardCloseTimer?.cancel();
    _hardCloseTimer = Timer(hardTimeout, () {
      unawaited(close(HydrationTraceCloseReason.timeout));
    });
    _record('trace_started', <String, Object?>{
      'launch_kind': launchKind.diagnosticName,
      'first_route': _safeSource(firstRoute),
    });
    _scheduleQuietMarkers();
  }

  void recordCalendarShellMounted({String? firstRoute}) {
    _record('calendar_shell_mounted', <String, Object?>{
      'first_route': _safeSource(firstRoute),
    });
  }

  void recordDayViewMounted() => _record('day_view_mounted');

  void recordCoordinatorRequest({
    required String source,
    required bool passActive,
    String? overwrittenSource,
  }) {
    final trace = _active;
    if (trace == null) return;
    trace.requestedLoadCount++;
    trace.coordinatorIdle = false;
    _record('coordinator_request', <String, Object?>{
      'requested_source': _safeSource(source),
      'pass_active': passActive,
      'overwritten_source': _safeSource(overwrittenSource),
    });
  }

  void recordCoordinatorIdle() {
    final trace = _active;
    if (trace == null) return;
    trace.coordinatorIdle = true;
    trace.lastCoordinatorIdleMs = _elapsed(trace);
    _record('coordinator_idle');
    _scheduleQuietMarkers();
  }

  void recordCoordinatorPassStarted() {
    final trace = _active;
    if (trace == null) return;
    final idleAt = trace.lastCoordinatorIdleMs;
    trace.coordinatorIdle = false;
    _record('coordinator_pass_started', <String, Object?>{
      'idle_gap_ms': idleAt == null ? null : _elapsed(trace) - idleAt,
    });
  }

  HydrationDiagnosticContext? beginPass({
    required int epoch,
    required String requestedSource,
    required String executedSource,
  }) {
    final trace = _active;
    if (trace == null) return null;
    final context = HydrationDiagnosticContext(
      traceId: trace.traceId,
      passEpoch: epoch,
      requestedSource: _safeSource(requestedSource) ?? 'unknown',
      executedSource: _safeSource(executedSource) ?? 'unknown',
      operationId: 'pass:$epoch',
    );
    trace.executedLoadCount++;
    trace.coordinatorIdle = false;
    trace.openOperationCount++;
    trace.passes[epoch] = _HydrationPassState(
      context: context,
      startedAtMs: _elapsed(trace),
    );
    _record('pass_started', context.toJson());
    _noteMutation();
    return context;
  }

  void endPass(HydrationDiagnosticContext? context, {required bool succeeded}) {
    final trace = _traceFor(context);
    if (trace == null || context == null) return;
    final pass = trace.passes[context.passEpoch];
    if (pass == null || pass.endedAtMs != null) return;
    pass
      ..endedAtMs = _elapsed(trace)
      ..succeeded = succeeded;
    trace.openOperationCount = (trace.openOperationCount - 1)
        .clamp(0, 1 << 30)
        .toInt();
    _record('pass_ended', <String, Object?>{
      ...context.toJson(),
      'succeeded': succeeded,
      'duration_ms': pass.endedAtMs! - pass.startedAtMs,
    });
    _scheduleQuietMarkers();
  }

  void recordRepositoryFetch({
    required HydrationDiagnosticContext? context,
    required String operation,
    required HydrationFetchStatus status,
    required int durationMs,
    int rowCount = 0,
    int requestCount = 1,
    int pageCount = 0,
    String? safeErrorClass,
    bool critical = true,
  }) {
    final trace = _traceFor(context);
    if (trace == null || context == null) return;
    final pass = trace.passes[context.passEpoch];
    if (pass == null) return;
    final safeOperation = _safeSource(operation) ?? 'unknown';
    final observation = <String, Object?>{
      ...context.child(safeOperation).toJson(),
      'operation': safeOperation,
      'status': status.diagnosticName,
      'duration_ms': durationMs,
      'row_count': rowCount,
      'request_count': requestCount,
      'page_count': pageCount,
      'safe_error_class': _safeErrorClass(safeErrorClass),
      'critical': critical,
      't_ms': _elapsed(trace),
    };
    trace.addBounded(trace.requests, observation);
    pass.fetchStatuses[safeOperation] = status;
    pass.networkSummedMs += durationMs;
    pass.networkRequestCount += requestCount;
    if (critical) {
      pass.firstCriticalRequestMs ??= _elapsed(trace) - durationMs;
      pass.lastCriticalResponseMs = _elapsed(trace);
    }
    if (safeOperation == 'flow_batch') {
      pass.batchStatus = status;
    } else if (safeOperation.startsWith('flow_fallback')) {
      pass.fallbackRequestCount++;
      if (status == HydrationFetchStatus.failed ||
          status == HydrationFetchStatus.unauthenticated) {
        pass.fallbackFailedCount++;
      } else {
        pass.fallbackSuccessCount++;
        if (status == HydrationFetchStatus.successfulEmpty) {
          pass.fallbackEmptyCount++;
        } else if (status == HydrationFetchStatus.successNonempty) {
          pass.fallbackNonemptyCount++;
        }
      }
    }
  }

  /// Records a semantic status derived from other operations without counting
  /// it as another network request. The aggregate flow-catalog status uses
  /// this so completeness remains stable while view and timestamp requests
  /// are timed independently.
  void recordDerivedFetchStatus({
    required HydrationDiagnosticContext? context,
    required String operation,
    required HydrationFetchStatus status,
    int rowCount = 0,
  }) {
    final trace = _traceFor(context);
    if (trace == null || context == null) return;
    final pass = trace.passes[context.passEpoch];
    if (pass == null) return;
    final safeOperation = _safeSource(operation) ?? 'unknown';
    pass.fetchStatuses[safeOperation] = status;
    trace.addBounded(trace.requests, <String, Object?>{
      ...context.child(safeOperation).toJson(),
      'operation': safeOperation,
      'status': status.diagnosticName,
      'duration_ms': 0,
      'row_count': rowCount,
      'request_count': 0,
      'page_count': 0,
      'safe_error_class': null,
      'critical': false,
      'derived': true,
      't_ms': _elapsed(trace),
    });
  }

  void recordBatchMapping({
    required HydrationDiagnosticContext? context,
    required HydrationBatchMappingStats stats,
  }) {
    final trace = _traceFor(context);
    if (trace == null || context == null) return;
    final pass = trace.passes[context.passEpoch];
    if (pass == null) return;
    pass.mapping = stats;
    _record('batch_mapping', <String, Object?>{
      ...context.toJson(),
      ...stats.toJson(),
    });
  }

  HydrationCompletenessResult recordCompleteness({
    required HydrationDiagnosticContext? context,
    required int hydrationFlowCount,
    required bool claimedComplete,
  }) {
    final trace = _traceFor(context);
    final pass = trace == null || context == null
        ? null
        : trace.passes[context.passEpoch];
    final result = evaluateHydrationCompleteness(
      HydrationCompletenessInput(
        catalogStatus:
            pass?.fetchStatuses['flow_catalog'] ?? HydrationFetchStatus.notRun,
        hydrationFlowCount: hydrationFlowCount,
        batchStatus: pass?.batchStatus ?? HydrationFetchStatus.notRun,
        fallbackRequestCount: pass?.fallbackRequestCount ?? 0,
        fallbackFailedCount: pass?.fallbackFailedCount ?? 0,
        fallbackNonemptyCount: pass?.fallbackNonemptyCount ?? 0,
        standaloneStatus:
            pass?.fetchStatuses['standalone'] ?? HydrationFetchStatus.notRun,
        mapping: pass?.mapping,
      ),
    );
    if (trace == null || context == null || pass == null) return result;
    pass
      ..claimedComplete = claimedComplete
      ..hydrationFlowCount = hydrationFlowCount
      ..completeness = result;
    if (claimedComplete && !result.semanticComplete) {
      trace.claimedSemanticCompleteMismatch = true;
    }
    if (result.semanticComplete && trace.firstSemanticPassEpoch == null) {
      trace.firstSemanticPassEpoch = context.passEpoch;
      pass.semanticCompleteAtMs = _elapsed(trace);
    }
    _record('pass_completeness', <String, Object?>{
      ...context.toJson(),
      'claimed_complete': claimedComplete,
      ...result.toJson(),
    });
    return result;
  }

  void recordVisibleCommit({
    required HydrationDiagnosticContext? context,
    required String phase,
    required String originClass,
    required int totalFlows,
    required int totalEvents,
    required int totalDayBuckets,
    required HydrationSelectedDaySnapshot selectedDay,
    required bool claimedComplete,
    HydrationCompletenessResult? completeness,
    String? authorityScope,
  }) {
    final trace = _traceFor(context);
    if (trace == null || context == null) return;
    final previous = trace.lastSelectedDay;
    final delta = _selectedDayDelta(previous, selectedDay);
    final revision = ++trace.commitRevision;
    trace.visibleCommitCount++;
    trace
      ..lastSelectedDay = selectedDay
      ..finalSelectedDay = selectedDay;
    if (originClass == 'warm_cache') trace.warmSelectedDay ??= selectedDay;
    final commit = <String, Object?>{
      ...context.toJson(),
      'revision': revision,
      'phase': _safeSource(phase),
      'origin_class': _safeSource(originClass),
      't_ms': _elapsed(trace),
      'total_flows': totalFlows,
      'total_events': totalEvents,
      'total_day_buckets': totalDayBuckets,
      ...selectedDay.toJson(),
      ...delta,
      'claimed_complete': claimedComplete,
      'authority_scope': _safeSource(authorityScope),
      if (completeness != null) ...completeness.toJson(),
      'ms_until_next_frame': null,
    };
    trace.addBounded(trace.commits, commit);
    trace.pendingCommitFrames[revision] = commit;
    trace.pendingCommitSnapshots[revision] = selectedDay;
    _noteMutation();
  }

  void recordWarmCacheCommit({
    required int totalFlows,
    required int totalEvents,
    required int totalDayBuckets,
    required HydrationSelectedDaySnapshot selectedDay,
    HydrationAsyncWorkToken? token,
  }) {
    final active = _active;
    final trace = token == null
        ? active
        : active != null && active.traceId == token.traceId
        ? active
        : null;
    if (trace == null) return;
    final previous = trace.lastSelectedDay;
    final revision = ++trace.commitRevision;
    trace.visibleCommitCount++;
    trace
      ..lastSelectedDay = selectedDay
      ..warmSelectedDay = selectedDay
      ..finalSelectedDay = selectedDay;
    final commit = <String, Object?>{
      'revision': revision,
      'phase': 'warm_cache',
      'origin_class': 'warm_cache',
      't_ms': _elapsed(trace),
      'total_flows': totalFlows,
      'total_events': totalEvents,
      'total_day_buckets': totalDayBuckets,
      ...selectedDay.toJson(),
      ..._selectedDayDelta(previous, selectedDay),
      'claimed_complete': false,
      'semantic_complete': false,
      'ms_until_next_frame': null,
    };
    trace.addBounded(trace.commits, commit);
    trace.pendingCommitFrames[revision] = commit;
    trace.pendingCommitSnapshots[revision] = selectedDay;
    _noteMutation();
  }

  void recordDayViewFrame({
    required HydrationSelectedDaySnapshot selectedDay,
    required int dataVersion,
    bool firstFrame = false,
    bool hasLocalSnapshot = true,
  }) {
    final trace = _active;
    if (trace == null) return;
    final tMs = _elapsed(trace);
    if (firstFrame) trace.timeToFirstFrameMs ??= tMs;
    if (hasLocalSnapshot) trace.timeToFirstLocalSnapshotFrameMs ??= tMs;
    if (selectedDay.eventCount > 0) {
      trace.timeToFirstNonemptyVisibleDayMs ??= tMs;
    }
    final acknowledgedRevisions = <int>[];
    var acknowledgedSemanticCommit = false;
    for (final entry in trace.pendingCommitFrames.entries) {
      final committedDay = trace.pendingCommitSnapshots[entry.key];
      if (committedDay == null ||
          !committedDay.structurallyMatches(selectedDay)) {
        final mismatchKey =
            '${entry.key}|${selectedDay.dayKey}|${selectedDay.multisetChecksum}';
        if (trace.reportedCommitFrameMismatches.add(mismatchKey)) {
          final dayMismatch = committedDay?.dayKey != selectedDay.dayKey;
          _record(
            dayMismatch
                ? 'frame_commit_day_mismatch'
                : 'frame_commit_checksum_mismatch',
            <String, Object?>{
              'revision': entry.key,
              'commit_day_key': committedDay?.dayKey,
              'frame_day_key': selectedDay.dayKey,
              'commit_multiset_checksum': committedDay?.multisetChecksum,
              'frame_multiset_checksum': selectedDay.multisetChecksum,
            },
          );
        }
        continue;
      }
      entry.value['ms_until_next_frame'] =
          tMs - ((entry.value['t_ms'] as int?) ?? tMs);
      acknowledgedSemanticCommit =
          acknowledgedSemanticCommit ||
          entry.value['semantic_complete'] == true;
      acknowledgedRevisions.add(entry.key);
    }
    for (final revision in acknowledgedRevisions) {
      trace.pendingCommitFrames.remove(revision);
      trace.pendingCommitSnapshots.remove(revision);
    }
    if (acknowledgedSemanticCommit &&
        trace.timeToFirstServerConfirmedCompleteFrameMs == null) {
      trace.timeToFirstServerConfirmedCompleteFrameMs = tMs;
    }
    trace.addBounded(trace.frames, <String, Object?>{
      't_ms': tMs,
      'first_frame': firstFrame,
      'data_version': dataVersion,
      'acknowledged_commit_revisions': acknowledgedRevisions,
      ...selectedDay.toJson(),
    });
    trace.finalRenderedSelectedDay = selectedDay;
    final previous = trace.lastFrameSelectedDay;
    if (previous == null || !previous.structurallyMatches(selectedDay)) {
      trace.lastFrameSelectedDay = selectedDay;
      _record('visible_day_changed', <String, Object?>{
        'data_version': dataVersion,
        ...selectedDay.toJson(),
        ..._selectedDayDelta(previous, selectedDay),
      });
      _noteMutation();
    } else {
      _scheduleQuietMarkers();
    }
  }

  void recordCacheEvent(
    String marker,
    Map<String, Object?> fields, {
    HydrationAsyncWorkToken? token,
  }) {
    final active = _active;
    final trace = token == null
        ? active
        : active != null && active.traceId == token.traceId
        ? active
        : null;
    if (trace == null) return;
    trace.addBounded(trace.cache, <String, Object?>{
      'marker': _safeSource(marker),
      't_ms': _elapsed(trace),
      ..._sanitizeMap(fields),
    });
  }

  void recordPostProcessing(
    HydrationDiagnosticContext? context,
    String marker, {
    int? durationMs,
    bool changedNotes = false,
    bool countsApplied = false,
    HydrationAsyncWorkToken? token,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    final active = _active;
    final trace = token == null
        ? _traceFor(context)
        : active != null && active.traceId == token.traceId
        ? active
        : null;
    if (trace == null) return;
    final afterCompleteCommit = trace.commits.any(
      (commit) => commit['claimed_complete'] == true,
    );
    if (changedNotes && afterCompleteCommit) {
      trace.postCompleteNotesChanged = true;
    }
    if (countsApplied && afterCompleteCommit) {
      trace.postCompleteCountsApplied = true;
    }
    trace.addBounded(trace.postProcessing, <String, Object?>{
      'marker': _safeSource(marker),
      't_ms': _elapsed(trace),
      if (context != null) ...context.toJson(),
      if (durationMs != null) 'duration_ms': durationMs,
      'changed_notes': changedNotes,
      'counts_applied': countsApplied,
      ..._sanitizeMap(fields),
    });
    if (changedNotes || countsApplied) _noteMutation();
  }

  HydrationAsyncWorkToken? markAsyncWorkStarted(
    HydrationDiagnosticContext? context,
    String label,
  ) {
    final trace = _traceFor(context);
    if (trace == null) return null;
    trace.openOperationCount++;
    _record('async_work_started', <String, Object?>{
      if (context != null) ...context.toJson(),
      'label': _safeSource(label),
    });
    return HydrationAsyncWorkToken(traceId: trace.traceId, label: label);
  }

  void markAsyncWorkEnded(
    HydrationDiagnosticContext? context,
    String label, {
    HydrationAsyncWorkToken? token,
  }) {
    final active = _active;
    final trace = token == null
        ? _traceFor(context)
        : active != null && active.traceId == token.traceId
        ? active
        : null;
    if (trace == null) return;
    trace.openOperationCount = (trace.openOperationCount - 1)
        .clamp(0, 1 << 30)
        .toInt();
    _record('async_work_ended', <String, Object?>{
      if (context != null) ...context.toJson(),
      'label': _safeSource(label),
    });
    _scheduleQuietMarkers();
  }

  Future<void> closeForNavigation() =>
      close(HydrationTraceCloseReason.navigation);

  Future<void> close(HydrationTraceCloseReason reason) async {
    final trace = _active;
    if (trace == null || trace.closing) return;
    trace.closing = true;
    _cancelTimers();
    final finalSelected = trace.finalSelectedDay;
    final warmSelected = trace.warmSelectedDay;
    if (warmSelected != null && finalSelected != null) {
      trace.warmSnapshotMatchesFinal = warmSelected.structurallyMatches(
        finalSelected,
      );
      if (warmSelected.dayKey == finalSelected.dayKey) {
        final delta = _selectedDayDelta(warmSelected, finalSelected);
        trace.warmToFinalAdded = delta['selected_day_added'] as int?;
        trace.warmToFinalRemoved = delta['selected_day_removed'] as int?;
      }
    }
    final closedAt = _elapsed(trace);
    if (reason == HydrationTraceCloseReason.settled) {
      trace.timeToSettledMs = closedAt;
    }
    final payload = _sanitizeMap(
      trace.toJson(closedBy: reason, closedAtMs: closedAt),
    );
    _lastCompleted = payload;
    _lastCompletedUserId = trace.userId;
    _active = null;
    final userId = trace.userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUserId == userId) {
        await prefs.setString(
          _key(userId),
          const JsonEncoder.withIndent('  ').convert(payload),
        );
      }
    } catch (_) {
      // The in-memory trace remains copyable even when persistence fails.
    }
  }

  Future<Map<String, Object?>?> restoreLastCompletedForUser(
    String? userId,
  ) async {
    final trimmed = userId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    _currentUserId = trimmed;
    if (_lastCompleted != null &&
        _lastCompletedUserId == trimmed &&
        _lastBackfillUserId == trimmed) {
      return lastCompletedTrace;
    }
    _lastCompleted = null;
    _lastCompletedUserId = null;
    _lastBackfillSummary = null;
    _lastBackfillUserId = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(trimmed));
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _lastCompleted = _sanitizeMap(Map<String, Object?>.from(decoded));
          _lastCompletedUserId = trimmed;
        }
      }
      final backfillRaw = prefs.getString(_backfillKey(trimmed));
      if (backfillRaw != null && backfillRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(backfillRaw);
        if (decoded is Map) {
          _lastBackfillSummary = _sanitizeMap(
            Map<String, Object?>.from(decoded),
          );
          _lastBackfillUserId = trimmed;
        }
      }
    } catch (_) {
      return null;
    }
    return lastCompletedTrace;
  }

  Map<String, Object?>? buildLastCompletedExport({String? exportedByBuild}) {
    final trace = _lastCompleted;
    if (trace == null) return null;
    final payload = Map<String, Object?>.from(trace);
    final exporterBuild = exportedByBuild?.trim();
    if (exporterBuild != null && exporterBuild.isNotEmpty) {
      payload['exported_by_build'] = exporterBuild;
    }
    if (_lastBackfillSummary != null &&
        _lastBackfillUserId == _lastCompletedUserId &&
        _lastBackfillSummary!['trace_id'] == trace['trace_id']) {
      payload['backfill_summary'] = Map<String, Object?>.from(
        _lastBackfillSummary!,
      );
    }
    return _sanitizeMap(payload);
  }

  Future<bool> copyLastCompleted({String? exportedByBuild}) async {
    final payload = buildLastCompletedExport(exportedByBuild: exportedByBuild);
    if (payload == null) return false;
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(payload)),
    );
    return true;
  }

  Future<void> clearForAccountChange({String? previousUserId}) async {
    _cancelTimers();
    _active = null;
    _lastCompleted = null;
    _lastCompletedUserId = null;
    _lastBackfillSummary = null;
    _lastBackfillUserId = null;
    final previous = previousUserId?.trim();
    _currentUserId = null;
    if (previous == null || previous.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(previous));
      await prefs.remove(_backfillKey(previous));
    } catch (_) {}
  }

  @visibleForTesting
  void debugReset() {
    _cancelTimers();
    _active = null;
    _lastCompleted = null;
    _lastCompletedUserId = null;
    _lastBackfillSummary = null;
    _lastBackfillUserId = null;
    _currentUserId = null;
    _buildLabel = 'unavailable';
  }

  @visibleForTesting
  Future<void> debugClose(HydrationTraceCloseReason reason) => close(reason);

  _HydrationTraceState? _traceFor(HydrationDiagnosticContext? context) {
    final trace = _active;
    if (trace == null) return null;
    if (context == null) return trace;
    if (trace.traceId != context.traceId) {
      return null;
    }
    return trace;
  }

  void _record(String marker, [Map<String, Object?> fields = const {}]) {
    final trace = _active;
    if (trace == null) return;
    trace.addBounded(trace.events, <String, Object?>{
      'marker': _safeSource(marker),
      't_ms': _elapsed(trace),
      ..._sanitizeMap(fields),
    });
  }

  int _elapsed(_HydrationTraceState trace) => nowMs - trace.startedAtMs;

  void _noteMutation() {
    final trace = _active;
    if (trace == null) return;
    trace.lastMutationMs = _elapsed(trace);
    _scheduleQuietMarkers();
  }

  void _scheduleQuietMarkers() {
    final trace = _active;
    if (trace == null || trace.closing) return;
    _quiescentTimer?.cancel();
    _settleTimer?.cancel();
    _quiescentTimer = Timer(quiescentDelay, () {
      final current = _active;
      if (!identical(current, trace) || trace.closing) return;
      trace.timeToFirstQuiescent500Ms ??= _elapsed(trace);
      _record('quiescent_500ms');
    });
    if (trace.openOperationCount != 0 || !trace.coordinatorIdle) return;
    _settleTimer = Timer(settleDelay, () {
      final current = _active;
      if (!identical(current, trace) || trace.closing) return;
      if (trace.openOperationCount == 0 &&
          trace.coordinatorIdle &&
          _elapsed(trace) - trace.lastMutationMs >=
              settleDelay.inMilliseconds) {
        unawaited(close(HydrationTraceCloseReason.settled));
      }
    });
  }

  void _cancelTimers() {
    _hardCloseTimer?.cancel();
    _quiescentTimer?.cancel();
    _settleTimer?.cancel();
    _hardCloseTimer = null;
    _quiescentTimer = null;
    _settleTimer = null;
  }

  static Map<String, Object?> _selectedDayDelta(
    HydrationSelectedDaySnapshot? previous,
    HydrationSelectedDaySnapshot next,
  ) {
    if (previous == null) {
      return <String, Object?>{
        'selected_day_added': next.eventCount,
        'selected_day_removed': 0,
      };
    }
    return <String, Object?>{
      'selected_day_added': (next.eventCount - previous.eventCount)
          .clamp(0, 1 << 30)
          .toInt(),
      'selected_day_removed': (previous.eventCount - next.eventCount)
          .clamp(0, 1 << 30)
          .toInt(),
    };
  }

  static String? _safeSource(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return RegExp(r'^[A-Za-z0-9_.:+-]{1,120}$').hasMatch(value)
        ? value
        : 'redacted';
  }

  static String? _safeErrorClass(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return RegExp(r'^[A-Za-z0-9_.]{1,96}$').hasMatch(value)
        ? value
        : 'redacted';
  }

  static Map<String, Object?> _sanitizeMap(Map<dynamic, dynamic> input) {
    final result = <String, Object?>{};
    input.forEach((rawKey, rawValue) {
      final key = rawKey.toString();
      if (_forbiddenKeys.contains(key)) return;
      result[key] = _sanitizeValue(rawValue);
    });
    return result;
  }

  static Object? _sanitizeValue(Object? value) {
    if (value is Map) return _sanitizeMap(value);
    if (value is Iterable) {
      return value.map(_sanitizeValue).toList(growable: false);
    }
    if (value is String && value.length > 240) {
      return '${value.substring(0, 240)}…';
    }
    if (value is num || value is bool || value is String || value == null) {
      return value;
    }
    return value.runtimeType.toString();
  }
}

class _HydrationPassState {
  _HydrationPassState({required this.context, required this.startedAtMs});

  final HydrationDiagnosticContext context;
  final int startedAtMs;
  final Map<String, HydrationFetchStatus> fetchStatuses =
      <String, HydrationFetchStatus>{};
  HydrationFetchStatus batchStatus = HydrationFetchStatus.notRun;
  HydrationBatchMappingStats? mapping;
  HydrationCompletenessResult? completeness;
  int? endedAtMs;
  int? semanticCompleteAtMs;
  bool? succeeded;
  bool claimedComplete = false;
  int? hydrationFlowCount;
  int networkSummedMs = 0;
  int networkRequestCount = 0;
  int? firstCriticalRequestMs;
  int? lastCriticalResponseMs;
  int fallbackRequestCount = 0;
  int fallbackSuccessCount = 0;
  int fallbackFailedCount = 0;
  int fallbackEmptyCount = 0;
  int fallbackNonemptyCount = 0;

  Map<String, Object?> toJson() => <String, Object?>{
    ...context.toJson(),
    'started_at_ms': startedAtMs,
    'ended_at_ms': endedAtMs,
    'succeeded': succeeded,
    'batch_outcome': batchOutcomeName,
    if (mapping != null) ...mapping!.toJson(),
    'per_flow_fallback_request_count': fallbackRequestCount,
    'per_flow_fallback_success_count': fallbackSuccessCount,
    'per_flow_fallback_failed_count': fallbackFailedCount,
    'per_flow_fallback_empty_count': fallbackEmptyCount,
    'network_request_count': networkRequestCount,
    'network_summed_ms': networkSummedMs,
    'network_window_ms':
        firstCriticalRequestMs == null || lastCriticalResponseMs == null
        ? 0
        : lastCriticalResponseMs! - firstCriticalRequestMs!,
    'critical_hydration_ms': semanticCompleteAtMs == null
        ? null
        : semanticCompleteAtMs! - startedAtMs,
    'claimed_complete': claimedComplete,
    if (completeness != null) ...completeness!.toJson(),
  };

  String get batchOutcomeName {
    final catalog = fetchStatuses['flow_catalog'];
    if (hydrationFlowCount == 0 &&
        catalog == HydrationFetchStatus.successfulEmpty) {
      return 'no_flows';
    }
    return switch (batchStatus) {
      HydrationFetchStatus.successNonempty => 'batch_nonempty',
      HydrationFetchStatus.successfulEmpty => 'successful_empty',
      HydrationFetchStatus.failed => 'batch_failed',
      HydrationFetchStatus.unauthenticated => 'unauthenticated',
      HydrationFetchStatus.notRun => 'not_run',
    };
  }
}

class _HydrationTraceState {
  _HydrationTraceState({
    required this.traceId,
    required this.userId,
    required this.launchKind,
    required this.build,
    required this.startedAtUtc,
    required this.startedAtMs,
    required this.firstRoute,
    required this.capacity,
  });

  final String traceId;
  final String userId;
  final HydrationLaunchKind launchKind;
  String build;
  final DateTime startedAtUtc;
  final int startedAtMs;
  final String? firstRoute;
  final int capacity;
  final List<Map<String, Object?>> events = <Map<String, Object?>>[];
  final List<Map<String, Object?>> cache = <Map<String, Object?>>[];
  final List<Map<String, Object?>> requests = <Map<String, Object?>>[];
  final List<Map<String, Object?>> commits = <Map<String, Object?>>[];
  final List<Map<String, Object?>> frames = <Map<String, Object?>>[];
  final List<Map<String, Object?>> postProcessing = <Map<String, Object?>>[];
  final Map<int, _HydrationPassState> passes = <int, _HydrationPassState>{};
  final Map<int, Map<String, Object?>> pendingCommitFrames =
      <int, Map<String, Object?>>{};
  final Map<int, HydrationSelectedDaySnapshot> pendingCommitSnapshots =
      <int, HydrationSelectedDaySnapshot>{};
  final Set<String> reportedCommitFrameMismatches = <String>{};
  int droppedEventCount = 0;
  int requestedLoadCount = 0;
  int executedLoadCount = 0;
  int visibleCommitCount = 0;
  int commitRevision = 0;
  int openOperationCount = 0;
  int lastMutationMs = 0;
  bool closing = false;
  bool coordinatorIdle = true;
  int? lastCoordinatorIdleMs;
  bool claimedSemanticCompleteMismatch = false;
  bool postCompleteNotesChanged = false;
  bool postCompleteCountsApplied = false;
  int? firstSemanticPassEpoch;
  int? timeToFirstFrameMs;
  int? timeToFirstLocalSnapshotFrameMs;
  int? timeToFirstNonemptyVisibleDayMs;
  int? timeToFirstServerConfirmedCompleteFrameMs;
  int? timeToFirstQuiescent500Ms;
  int? timeToSettledMs;
  HydrationSelectedDaySnapshot? lastSelectedDay;
  HydrationSelectedDaySnapshot? lastFrameSelectedDay;
  HydrationSelectedDaySnapshot? warmSelectedDay;
  HydrationSelectedDaySnapshot? finalSelectedDay;
  HydrationSelectedDaySnapshot? finalRenderedSelectedDay;
  bool? warmSnapshotMatchesFinal;
  int? warmToFinalAdded;
  int? warmToFinalRemoved;

  void addBounded(
    List<Map<String, Object?>> target,
    Map<String, Object?> event,
  ) {
    final used =
        events.length +
        cache.length +
        requests.length +
        commits.length +
        frames.length +
        postProcessing.length;
    if (used >= capacity) {
      droppedEventCount++;
      return;
    }
    target.add(event);
  }

  Map<String, Object?> toJson({
    required HydrationTraceCloseReason closedBy,
    required int closedAtMs,
  }) {
    final passList = passes.values.toList(growable: false)
      ..sort((a, b) => a.context.passEpoch.compareTo(b.context.passEpoch));
    final anyFallback = passList.any((pass) => pass.fallbackRequestCount > 0);
    final totalFallback = passList.fold<int>(
      0,
      (sum, pass) => sum + pass.fallbackRequestCount,
    );
    final networkRequests = passList.fold<int>(
      0,
      (sum, pass) => sum + pass.networkRequestCount,
    );
    final networkSummed = passList.fold<int>(
      0,
      (sum, pass) => sum + pass.networkSummedMs,
    );
    final firstStarts = passList
        .map((pass) => pass.firstCriticalRequestMs)
        .whereType<int>();
    final lastEnds = passList
        .map((pass) => pass.lastCriticalResponseMs)
        .whereType<int>();
    final firstStart = firstStarts.isEmpty
        ? null
        : firstStarts.reduce((a, b) => a < b ? a : b);
    final lastEnd = lastEnds.isEmpty
        ? null
        : lastEnds.reduce((a, b) => a > b ? a : b);
    final semanticPass = firstSemanticPassEpoch == null
        ? null
        : passes[firstSemanticPassEpoch!];
    final finalPass = passList.isEmpty ? null : passList.last;
    return <String, Object?>{
      'schema': 1,
      'build': build,
      'trace_id': traceId,
      'launch_kind': launchKind.diagnosticName,
      'started_at_utc': startedAtUtc.toIso8601String(),
      'closed_by': closedBy.diagnosticName,
      'closed_at_ms': closedAtMs,
      'first_route': firstRoute,
      'cache': cache,
      'requests': requests,
      'passes': passList.map((pass) => pass.toJson()).toList(growable: false),
      'commits': commits,
      'frames': frames,
      'events': events,
      'post_processing': postProcessing,
      'summary': <String, Object?>{
        'time_to_first_frame_ms': timeToFirstFrameMs,
        'time_to_first_local_snapshot_frame_ms':
            timeToFirstLocalSnapshotFrameMs,
        'time_to_first_nonempty_visible_day_ms':
            timeToFirstNonemptyVisibleDayMs,
        'time_to_first_server_confirmed_complete_frame_ms':
            timeToFirstServerConfirmedCompleteFrameMs,
        'time_to_first_quiescent_500ms': timeToFirstQuiescent500Ms,
        'time_to_settled_ms': timeToSettledMs,
        'requested_load_count': requestedLoadCount,
        'executed_load_count': executedLoadCount,
        'visible_commit_count': visibleCommitCount,
        'network_request_count': networkRequests,
        'network_summed_ms': networkSummed,
        'network_window_ms': firstStart == null || lastEnd == null
            ? 0
            : lastEnd - firstStart,
        'critical_hydration_ms': semanticPass?.semanticCompleteAtMs == null
            ? null
            : semanticPass!.semanticCompleteAtMs! - semanticPass.startedAtMs,
        'any_batch_fallback_used': anyFallback,
        'total_fallback_requests': totalFallback,
        'first_semantically_complete_pass_epoch': firstSemanticPassEpoch,
        'final_pass_batch_outcome': finalPass?.batchOutcomeName ?? 'not_run',
        'warm_snapshot_selected_day_matches_final': warmSnapshotMatchesFinal,
        'warm_to_final_selected_day_added': warmToFinalAdded,
        'warm_to_final_selected_day_removed': warmToFinalRemoved,
        'claimed_semantic_complete_mismatch': claimedSemanticCompleteMismatch,
        'final_committed_selected_day_key': finalSelectedDay?.dayKey,
        'final_committed_selected_day_event_count':
            finalSelectedDay?.eventCount ?? 0,
        'final_committed_selected_day_multiset_checksum':
            finalSelectedDay?.multisetChecksum,
        'final_rendered_selected_day_key': finalRenderedSelectedDay?.dayKey,
        'final_rendered_selected_day_event_count':
            finalRenderedSelectedDay?.eventCount ?? 0,
        'final_rendered_selected_day_multiset_checksum':
            finalRenderedSelectedDay?.multisetChecksum,
        'final_visible_day_event_count':
            finalRenderedSelectedDay?.eventCount ?? 0,
        'post_complete_notes_changed': postCompleteNotesChanged,
        'post_complete_counts_applied': postCompleteCountsApplied,
        'cache_hit': cache.any((event) => event['marker'] == 'cache_hit'),
        'dropped_event_count': droppedEventCount,
      },
    };
  }
}
