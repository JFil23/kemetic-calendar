import 'package:flutter/foundation.dart';

/// Receipt after one Cut 3.1 migration job finishes planning + persistence.
@immutable
class FollowSkyMigrationJobReceipt {
  const FollowSkyMigrationJobReceipt({
    required this.stamped,
    required this.added,
    required this.failed,
    required this.represented,
    required this.canonical,
    required this.plannedStampIds,
    required this.plannedAddSkyEventIds,
  });

  final int stamped;
  final int added;
  final int failed;
  final int represented;
  final int canonical;
  final List<String> plannedStampIds;
  final List<String> plannedAddSkyEventIds;

  String get completeAuditLine =>
      'stamped=$stamped added=$added failed=$failed '
      'represented=$represented canonical=$canonical';
}

/// Process-wide coalescing for Follow the Sky Cut 3.1 migration.
///
/// One physical job per `(userId, flowId)` at a time. Concurrent callers await
/// the same [Future] instead of independently planning against half-written
/// state.
class FollowSkyMigrationJobCoordinator {
  FollowSkyMigrationJobCoordinator._();

  static final FollowSkyMigrationJobCoordinator instance =
      FollowSkyMigrationJobCoordinator._();

  final Map<String, Future<FollowSkyMigrationJobReceipt>> _inflight =
      <String, Future<FollowSkyMigrationJobReceipt>>{};

  @visibleForTesting
  int get debugInflightCount => _inflight.length;

  @visibleForTesting
  void debugReset() => _inflight.clear();

  String jobKey({required String? userId, required int flowId}) {
    final uid = (userId ?? '').trim();
    return '${uid.isEmpty ? '_' : uid}:$flowId';
  }

  /// Runs [job], coalescing onto any in-flight job for the same key.
  Future<FollowSkyMigrationJobReceipt> run({
    required String? userId,
    required int flowId,
    required Future<FollowSkyMigrationJobReceipt> Function() job,
  }) {
    final key = jobKey(userId: userId, flowId: flowId);
    final existing = _inflight[key];
    if (existing != null) return existing;

    late final Future<FollowSkyMigrationJobReceipt> started;
    started = () async {
      try {
        return await job();
      } finally {
        if (identical(_inflight[key], started)) {
          _inflight.remove(key);
        }
      }
    }();
    _inflight[key] = started;
    return started;
  }
}
