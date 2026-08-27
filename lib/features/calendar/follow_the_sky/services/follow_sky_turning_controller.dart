import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';

import '../domain/turning_record.dart';
import 'turning_journal_projector.dart';
import 'turning_record_repository.dart';

typedef FollowSkyCompletionCommit =
    Future<void> Function(CompletionStatus status);

class FollowSkyCompletionSnapshot {
  const FollowSkyCompletionSnapshot({required this.status, this.completedAt});

  final CompletionStatus status;
  final DateTime? completedAt;
}

typedef FollowSkyCompletionLoader =
    Future<FollowSkyCompletionSnapshot> Function();

class FollowSkyCompletionSaveResult {
  const FollowSkyCompletionSaveResult({
    required this.status,
    required this.record,
  });

  final CompletionStatus status;
  final TurningRecord record;
}

/// Owns the nonvisual state for one Follow Sky observation.
///
/// The calendar remains authoritative for completion and the Turning Record
/// remains authoritative for engagement. Journal text is a projection through
/// the shared plain-user-text writer supplied by CalendarPage.
class FollowSkyTurningController {
  FollowSkyTurningController({
    required TurningRecordRepository records,
    required this.clientEventId,
    required this.completionIdentity,
    required this.skyEventId,
    required this.localDate,
    required this.scheduledTimeSnapshot,
    required this.intentionSnapshot,
    required this.onCommitCompletion,
    this.onWriteJournalResponse,
    FollowSkyCompletionLoader? loadExistingCompletion,
    this.reflectionSaveDebounce = const Duration(milliseconds: 450),
  }) : _records = records,
       _loadExistingCompletion =
           loadExistingCompletion ??
           (() async => const FollowSkyCompletionSnapshot(
             status: CompletionStatus.none,
           ));

  factory FollowSkyTurningController.live({
    required SupabaseClient client,
    required String clientEventId,
    required String completionIdentity,
    required String skyEventId,
    required DateTime localDate,
    required DateTime scheduledTimeSnapshot,
    required String? intentionSnapshot,
    required FollowSkyCompletionCommit onCommitCompletion,
    MaatJournalResponseBlockWriter? onWriteJournalResponse,
  }) {
    return FollowSkyTurningController(
      records: TurningRecordRepository(client),
      clientEventId: clientEventId,
      completionIdentity: completionIdentity,
      skyEventId: skyEventId,
      localDate: localDate,
      scheduledTimeSnapshot: scheduledTimeSnapshot,
      intentionSnapshot: intentionSnapshot,
      onCommitCompletion: onCommitCompletion,
      onWriteJournalResponse: onWriteJournalResponse,
      loadExistingCompletion: () => _loadCompletion(
        client: client,
        clientEventId: clientEventId,
        completionIdentity: completionIdentity,
      ),
    );
  }

  final TurningRecordRepository _records;
  final FollowSkyCompletionLoader _loadExistingCompletion;
  final String clientEventId;
  final String completionIdentity;
  final String skyEventId;
  final DateTime localDate;
  final DateTime scheduledTimeSnapshot;
  final String? intentionSnapshot;
  final FollowSkyCompletionCommit onCommitCompletion;
  final MaatJournalResponseBlockWriter? onWriteJournalResponse;
  final Duration reflectionSaveDebounce;
  final TurningJournalProjector _projector = const TurningJournalProjector();

  Future<TurningRecord>? _initialization;
  Future<void> _recordWriteTail = Future<void>.value();
  TurningRecord? _record;
  Timer? _reflectionSaveTimer;
  String? _pendingReflectionText;
  bool _pendingCloudSync = false;

  TurningRecord? get record => _record;
  bool get pendingCloudSync => _pendingCloudSync;
  bool get hasPendingReflection => _pendingReflectionText != null;
  CompletionStatus get completion => completionFromRecord(_record?.completion);

  Future<TurningRecord> initialize() => _initialization ??= _initialize();

  Future<TurningRecord> _initialize() async {
    var record = await _records.loadOrCreate(
      clientEventId: clientEventId,
      skyEventId: skyEventId,
      intentionSnapshot: intentionSnapshot,
      scheduledTimeSnapshot: scheduledTimeSnapshot,
    );
    if (record.completion == null) {
      final priorCompletion = await _loadExistingCompletion();
      if (priorCompletion.status != CompletionStatus.none) {
        final result = await _records.saveWithStatus(
          record.copyWith(
            completion: turningCompletion(priorCompletion.status),
            completedAt: priorCompletion.completedAt,
            lastEditedAt: DateTime.now().toUtc(),
          ),
        );
        record = result.record;
        _pendingCloudSync = !result.cloudSynced;
      }
    }
    _record = record;
    _pendingCloudSync = await _records.isPendingSync(clientEventId);
    await _project(record);
    return record;
  }

  void scheduleReflection(String text) {
    _pendingReflectionText = text;
    _reflectionSaveTimer?.cancel();
    _reflectionSaveTimer = Timer(
      reflectionSaveDebounce,
      () => unawaited(flushReflection()),
    );
  }

  Future<TurningRecordSaveResult?> flushReflection() async {
    _reflectionSaveTimer?.cancel();
    _reflectionSaveTimer = null;
    final reflection = _pendingReflectionText;
    if (reflection == null) return null;
    _pendingReflectionText = null;
    await initialize();
    final current = _record;
    if (current == null) {
      throw StateError('Turning record is not ready.');
    }
    if (current.reflectionText == reflection) return null;
    return mutateRecord(
      (latest) => latest.copyWith(
        reflectionText: reflection,
        lastEditedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<TurningRecordSaveResult> mutateRecord(
    TurningRecord Function(TurningRecord current) mutation,
  ) async {
    await initialize();
    final operation = _recordWriteTail.then((_) async {
      final current = _record;
      if (current == null) {
        throw StateError('Turning record is not ready.');
      }
      final result = await _records.saveWithStatus(mutation(current));
      _record = result.record;
      _pendingCloudSync = !result.cloudSynced;
      await _project(result.record);
      return result;
    });
    _recordWriteTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<FollowSkyCompletionSaveResult> toggleCompletion(
    CompletionStatus selected,
  ) async {
    await initialize();
    final nextStatus = selected == completion
        ? CompletionStatus.none
        : selected;
    await onCommitCompletion(nextStatus);
    await const CalendarCompletionLocalStore().save(
      identity: completionIdentity,
      status: nextStatus,
    );
    final now = DateTime.now().toUtc();
    final result = await mutateRecord(
      (current) => current.copyWith(
        completion: turningCompletion(nextStatus),
        clearCompletion: nextStatus == CompletionStatus.none,
        completedAt: nextStatus == CompletionStatus.none ? null : now,
        clearCompletedAt: nextStatus == CompletionStatus.none,
        lastEditedAt: now,
      ),
    );
    return FollowSkyCompletionSaveResult(
      status: nextStatus,
      record: result.record,
    );
  }

  Future<void> close() async {
    await flushReflection();
    await _recordWriteTail;
  }

  Future<void> _project(TurningRecord record) async {
    final writer = onWriteJournalResponse;
    if (writer == null) return;
    try {
      await writer(_projector.project(record: record, localDate: localDate));
    } on Object {
      // A Turning Record save remains authoritative. The next load or edit
      // retries the plain-text Journal projection without duplicating prose.
    }
  }

  static CompletionStatus completionFromRecord(TurningCompletion? value) {
    return switch (value) {
      TurningCompletion.observed => CompletionStatus.observed,
      TurningCompletion.partly => CompletionStatus.partial,
      TurningCompletion.skipped => CompletionStatus.skipped,
      null => CompletionStatus.none,
    };
  }

  static TurningCompletion? turningCompletion(CompletionStatus value) {
    return switch (value) {
      CompletionStatus.observed => TurningCompletion.observed,
      CompletionStatus.partial => TurningCompletion.partly,
      CompletionStatus.skipped => TurningCompletion.skipped,
      CompletionStatus.none => null,
    };
  }

  static Future<FollowSkyCompletionSnapshot> _loadCompletion({
    required SupabaseClient client,
    required String clientEventId,
    required String completionIdentity,
  }) async {
    final user = client.auth.currentUser;
    if (user != null) {
      try {
        final row = await client
            .from('user_event_completions')
            .select('completed_at,metadata')
            .eq('user_id', user.id)
            .eq('client_event_id', clientEventId)
            .maybeSingle();
        if (row != null) {
          final metadata = row['metadata'];
          final rawStatus = metadata is Map
              ? metadata['completion_status']?.toString() ??
                    metadata['status']?.toString()
              : null;
          final parsed = CompletionStatusX.fromWireName(rawStatus);
          return FollowSkyCompletionSnapshot(
            status: parsed == CompletionStatus.none
                ? CompletionStatus.observed
                : parsed,
            completedAt: DateTime.tryParse(
              row['completed_at']?.toString() ?? '',
            )?.toUtc(),
          );
        }
      } on Object {
        // Fall through to the on-device completion cache.
      }
    }
    final local = await const CalendarCompletionLocalStore().load(
      completionIdentity,
    );
    return FollowSkyCompletionSnapshot(status: local.completionStatus);
  }
}
