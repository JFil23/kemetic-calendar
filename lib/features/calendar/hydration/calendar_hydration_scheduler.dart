import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'calendar_hydration_models.dart';

enum CalendarHydrationIntentKind {
  viewport,
  catalogReconcile,
  calendarState,
  adjacentWindow,
  horizonChunk,
  accounting,
  filing,
  invitationImport,
  reminderMaintenance,
  journalMaintenance,
  onboardingMaintenance,
  affectedDate,
  affectedSeries,
}

enum CalendarHydrationJobDisposition { completed, cancelled, failed }

@immutable
class CalendarHydrationJobKey {
  const CalendarHydrationJobKey({
    required this.kind,
    required this.reason,
    this.interval,
    this.catalogFingerprint,
  });

  final CalendarHydrationIntentKind kind;
  final String reason;
  final CalendarHydrationInterval? interval;
  final String? catalogFingerprint;

  String? get _unboundedIdentity =>
      interval == null && catalogFingerprint == null ? reason : null;

  @override
  bool operator ==(Object other) =>
      other is CalendarHydrationJobKey &&
      kind == other.kind &&
      interval == other.interval &&
      catalogFingerprint == other.catalogFingerprint &&
      _unboundedIdentity == other._unboundedIdentity;

  @override
  int get hashCode =>
      Object.hash(kind, interval, catalogFingerprint, _unboundedIdentity);

  @override
  String toString() =>
      '${kind.name}:$reason:${interval ?? '-'}:'
      '${catalogFingerprint ?? '-'}';
}

@immutable
class CalendarHydrationRetryPolicy {
  const CalendarHydrationRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 8),
    this.jitterFraction = 0.2,
  }) : assert(maxAttempts > 0),
       assert(jitterFraction >= 0 && jitterFraction <= 1);

  static const none = CalendarHydrationRetryPolicy(maxAttempts: 1);

  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double jitterFraction;

  Duration delayForAttempt(int nextAttempt, double randomUnit) {
    final exponent = math.max(0, nextAttempt - 2);
    final multiplier = math.pow(2, exponent).toInt();
    final baseMs = math.min(
      maxDelay.inMilliseconds,
      initialDelay.inMilliseconds * multiplier,
    );
    final jitter = ((randomUnit * 2) - 1) * jitterFraction;
    return Duration(milliseconds: math.max(0, (baseMs * (1 + jitter)).round()));
  }
}

class CalendarHydrationJobCancelled implements Exception {
  const CalendarHydrationJobCancelled(this.reason);

  final String reason;

  @override
  String toString() => 'CalendarHydrationJobCancelled($reason)';
}

class CalendarHydrationJobContext {
  CalendarHydrationJobContext._({
    required bool Function() isCurrent,
    required this.attempt,
  }) : _isCurrent = isCurrent;

  final bool Function() _isCurrent;
  final int attempt;

  bool get isCurrent => _isCurrent();

  void throwIfCancelled([String reason = 'superseded']) {
    if (!isCurrent) throw CalendarHydrationJobCancelled(reason);
  }
}

typedef CalendarHydrationJobRunner =
    Future<void> Function(CalendarHydrationJobContext context);

@immutable
class CalendarHydrationJob {
  const CalendarHydrationJob({
    required this.key,
    required this.priority,
    required this.run,
    this.retryPolicy = CalendarHydrationRetryPolicy.none,
    this.shouldRetry,
  });

  final CalendarHydrationJobKey key;
  final int priority;
  final CalendarHydrationJobRunner run;
  final CalendarHydrationRetryPolicy retryPolicy;
  final bool Function(Object error)? shouldRetry;
}

class _PendingCalendarHydrationJob {
  _PendingCalendarHydrationJob({
    required this.job,
    required this.sequence,
    required this.schedulerGeneration,
    required this.kindRevision,
  }) : attempt = 1;

  CalendarHydrationJob job;
  final int sequence;
  final int schedulerGeneration;
  final int kindRevision;
  int attempt;
  final List<Completer<CalendarHydrationJobDisposition>> completers =
      <Completer<CalendarHydrationJobDisposition>>[];
}

/// Single-flight, typed scheduler for calendar database work.
///
/// Jobs are independent in failure semantics but intentionally serialized.
/// New foreground viewport work supersedes older viewport work and can retire
/// an active lower-priority result; an in-flight HTTP request is not forcibly
/// cancelled, so runners must check [CalendarHydrationJobContext] before every
/// lane and immediately before committing.
class CalendarHydrationScheduler {
  CalendarHydrationScheduler({
    required bool Function() isMounted,
    bool Function()? isOnline,
    double Function()? randomUnit,
    void Function(String message)? debugLog,
  }) : _isMounted = isMounted,
       _isOnline = isOnline ?? _alwaysOnline,
       _randomUnit = randomUnit ?? math.Random().nextDouble,
       _debugLog = debugLog;

  final bool Function() _isMounted;
  final bool Function() _isOnline;
  final double Function() _randomUnit;
  final void Function(String message)? _debugLog;

  static bool _alwaysOnline() => true;

  final Map<CalendarHydrationJobKey, _PendingCalendarHydrationJob> _queued =
      <CalendarHydrationJobKey, _PendingCalendarHydrationJob>{};
  final Map<CalendarHydrationIntentKind, int> _kindRevisions =
      <CalendarHydrationIntentKind, int>{};
  final Set<Timer> _retryTimers = <Timer>{};
  _PendingCalendarHydrationJob? _active;
  bool _pumping = false;
  int _sequence = 0;
  int _generation = 0;

  bool get hasActiveJob => _active != null;
  bool get hasQueuedJobs => _queued.isNotEmpty;
  int get generation => _generation;

  Future<CalendarHydrationJobDisposition> schedule(
    CalendarHydrationJob job, {
    bool supersedeKind = false,
    bool preemptLowerPriority = false,
  }) {
    if (!_isMounted()) {
      return Future<CalendarHydrationJobDisposition>.value(
        CalendarHydrationJobDisposition.cancelled,
      );
    }
    if (supersedeKind) _supersedeKind(job.key.kind);
    if (preemptLowerPriority &&
        _active != null &&
        _active!.job.priority < job.priority) {
      _bumpKindRevision(_active!.job.key.kind);
    }

    final completer = Completer<CalendarHydrationJobDisposition>();
    final active = _active;
    if (!supersedeKind &&
        active != null &&
        active.job.key == job.key &&
        _isCurrent(active)) {
      active.completers.add(completer);
      return completer.future;
    }

    final existing = _queued[job.key];
    if (existing != null) {
      // Latest runner/priority wins while every waiter observes one outcome.
      existing.job = job;
      existing.completers.add(completer);
      _pumpSoon();
      return completer.future;
    }

    final pending = _PendingCalendarHydrationJob(
      job: job,
      sequence: _sequence++,
      schedulerGeneration: _generation,
      kindRevision: _revisionFor(job.key.kind),
    )..completers.add(completer);
    _queued[job.key] = pending;
    _pumpSoon();
    return completer.future;
  }

  void invalidateAll({String reason = 'invalidate'}) {
    _generation++;
    for (final pending in _queued.values) {
      _complete(pending, CalendarHydrationJobDisposition.cancelled);
    }
    _queued.clear();
    for (final timer in _retryTimers) {
      timer.cancel();
    }
    _retryTimers.clear();
    _log('invalidate generation=$_generation reason=$reason');
  }

  /// Cancels work that has not started while leaving the active job's token
  /// valid. Catalog rebase uses this after its own atomic commit: it is the
  /// only active database job, and every queued job belongs to the old
  /// fingerprint.
  void cancelQueued({String reason = 'cancel_queued'}) {
    for (final pending in _queued.values) {
      _complete(pending, CalendarHydrationJobDisposition.cancelled);
    }
    _queued.clear();
    for (final timer in _retryTimers) {
      timer.cancel();
    }
    _retryTimers.clear();
    _log('cancel queued reason=$reason');
  }

  void resumeRetries() {
    if (!_isMounted() || !_isOnline()) return;
    _pumpSoon();
  }

  void dispose() {
    invalidateAll(reason: 'dispose');
  }

  void _supersedeKind(CalendarHydrationIntentKind kind) {
    _bumpKindRevision(kind);
    final staleKeys = _queued.keys
        .where((key) => key.kind == kind)
        .toList(growable: false);
    for (final key in staleKeys) {
      final pending = _queued.remove(key);
      if (pending != null) {
        _complete(pending, CalendarHydrationJobDisposition.cancelled);
      }
    }
  }

  void _bumpKindRevision(CalendarHydrationIntentKind kind) {
    _kindRevisions[kind] = _revisionFor(kind) + 1;
  }

  int _revisionFor(CalendarHydrationIntentKind kind) =>
      _kindRevisions[kind] ?? 0;

  bool _isCurrent(_PendingCalendarHydrationJob pending) =>
      _isMounted() &&
      pending.schedulerGeneration == _generation &&
      pending.kindRevision == _revisionFor(pending.job.key.kind);

  void _pumpSoon() {
    if (_pumping) return;
    scheduleMicrotask(_pump);
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_queued.isNotEmpty && _isMounted()) {
        final pending = _takeNext();
        if (pending == null) break;
        if (!_isCurrent(pending)) {
          _complete(pending, CalendarHydrationJobDisposition.cancelled);
          continue;
        }
        _active = pending;
        try {
          final context = CalendarHydrationJobContext._(
            isCurrent: () => _isCurrent(pending),
            attempt: pending.attempt,
          );
          context.throwIfCancelled();
          await pending.job.run(context);
          context.throwIfCancelled();
          _complete(pending, CalendarHydrationJobDisposition.completed);
        } on CalendarHydrationJobCancelled {
          _complete(pending, CalendarHydrationJobDisposition.cancelled);
        } catch (error) {
          if (_shouldRetry(pending, error)) {
            _scheduleRetry(pending);
          } else {
            _complete(pending, CalendarHydrationJobDisposition.failed);
          }
        } finally {
          _active = null;
        }
      }
    } finally {
      _pumping = false;
      if (_queued.isNotEmpty && _isMounted()) _pumpSoon();
    }
  }

  _PendingCalendarHydrationJob? _takeNext() {
    if (_queued.isEmpty) return null;
    final next = _queued.values.reduce((a, b) {
      final priorityOrder = b.job.priority.compareTo(a.job.priority);
      if (priorityOrder != 0) return priorityOrder > 0 ? b : a;
      return a.sequence <= b.sequence ? a : b;
    });
    _queued.remove(next.job.key);
    return next;
  }

  bool _shouldRetry(_PendingCalendarHydrationJob pending, Object error) {
    if (!_isCurrent(pending) || !_isOnline()) return false;
    if (pending.attempt >= pending.job.retryPolicy.maxAttempts) return false;
    return pending.job.shouldRetry?.call(error) ?? true;
  }

  void _scheduleRetry(_PendingCalendarHydrationJob pending) {
    pending.attempt++;
    final delay = pending.job.retryPolicy.delayForAttempt(
      pending.attempt,
      _randomUnit(),
    );
    late final Timer timer;
    timer = Timer(delay, () {
      _retryTimers.remove(timer);
      if (!_isCurrent(pending) || !_isOnline()) {
        _complete(pending, CalendarHydrationJobDisposition.cancelled);
        return;
      }
      final duplicate = _queued[pending.job.key];
      if (duplicate != null) {
        duplicate.completers.addAll(pending.completers);
      } else {
        _queued[pending.job.key] = pending;
      }
      _pumpSoon();
    });
    _retryTimers.add(timer);
  }

  void _complete(
    _PendingCalendarHydrationJob pending,
    CalendarHydrationJobDisposition disposition,
  ) {
    for (final completer in pending.completers) {
      if (!completer.isCompleted) completer.complete(disposition);
    }
  }

  void _log(String message) {
    if (kDebugMode) _debugLog?.call('[hydrationScheduler] $message');
  }
}
