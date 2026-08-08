import 'dart:async';

import 'package:flutter/foundation.dart';

import 'calendar_invalidation.dart';

/// Runs one hydration pass. [epoch] identifies the pass; the runner must gate
/// every commit on [CalendarLoadCoordinator.isCurrent] so a superseded pass
/// discards its own result instead of overwriting newer state.
///
/// **Mutation invariant:** all live calendar state writes from a hydration pass
/// (`_notes`, `_flows`, sentinels, `setState`) must go through the two guarded
/// sites (`commitVisibleCalendarState`, `finishNonCriticalPostProcessing`).
/// Early returns / catch paths in the runner body must stay mutation-free.
typedef CalendarLoadRunner =
    Future<void> Function({
      required String source,
      required bool preserveViewport,
      required int epoch,
    });

/// Owns all hydration scheduling for the calendar page: epoch tokens,
/// single-flight with a drain queue, and the CalendarInvalidationBus
/// subscription plus its debounce and revision bookkeeping.
///
/// Replaces on `_CalendarPageState` (a120756 line numbers):
/// `_isLoadingFromDisk` (8733), `_calendarInvalidationSub` (13648),
/// `_calendarInvalidationReloadDebounce`, `_calendarInvalidationReloadPending`,
/// `_calendarInvalidationReloadInFlight`, `_calendarInvalidationReloadReason`,
/// `_calendarInvalidationReloadRevision`,
/// `_calendarInvalidationScheduledRevision`, `_handleCalendarInvalidated`
/// (13765), `_schedulePendingCalendarInvalidationReload` (13770),
/// `_scheduleCalendarInvalidationReload` (13783),
/// `_flushCalendarInvalidationReload` (13801).
class CalendarLoadCoordinator {
  CalendarLoadCoordinator({
    required CalendarLoadRunner runner,
    required bool Function() isMounted,
    bool Function()? isDeferred,
    void Function(String message)? debugLog,
    Duration debounce = const Duration(milliseconds: 80),
    CalendarInvalidationBus? bus,
  }) : _runner = runner,
       _isMounted = isMounted,
       _isDeferred = isDeferred ?? _never,
       _debugLog = debugLog,
       _debounce = debounce,
       _bus = bus ?? CalendarInvalidationBus.instance;

  final CalendarLoadRunner _runner;
  final bool Function() _isMounted;

  /// Holds back invalidation-driven reloads only — wire to
  /// `_sharedCalendarRealDayViewOpening`. Explicit [request] calls are never
  /// deferred, matching today's behaviour.
  final bool Function() _isDeferred;

  final void Function(String message)? _debugLog;
  final Duration _debounce;
  final CalendarInvalidationBus _bus;

  static bool _never() => false;

  // ── epoch ──────────────────────────────────────────────────────────────────

  int _epoch = 0;

  int get epoch => _epoch;

  /// Gate every commit on this. Must be checked before *any* visible side
  /// effect, including sentinel writes such as
  /// `_serverHydrationCommittedForUserId` (30488) — a superseded pass that sets
  /// that sentinel would make a concurrent warm-start restore abandon on the
  /// strength of a discarded commit.
  bool isCurrent(int epoch) => _isMounted() && epoch == _epoch;

  /// Retires every in-flight pass without starting a new one. Call from the
  /// signedOut handler (13715–13741): a load started under the previous session
  /// would otherwise repopulate the maps sign-out just cleared.
  ///
  /// Does **not** cancel the in-flight network await — the runner still
  /// completes and must hit both guarded commit sites, which then no-op.
  void invalidate({String reason = 'invalidate'}) {
    _epoch++;
    _queued = false;
    _log('epoch invalidated reason=$reason -> $_epoch');
  }

  // ── single-flight ──────────────────────────────────────────────────────────

  Completer<void>? _idle;
  Future<void>? _inFlight;
  bool _queued = false;
  bool _pumping = false;
  bool _lastPassSucceeded = true;
  String _queuedSource = 'manual';
  bool _queuedPreserveViewport = false;

  bool get isLoading => _inFlight != null;

  /// True when the most recently completed pass finished without throwing.
  /// Invalidation revisions are consumed only when this holds — consuming on
  /// failure would silently mark a reload as handled.
  bool get lastPassSucceeded => _lastPassSucceeded;

  /// Requests a hydration pass. The returned future resolves only once the
  /// queue has fully drained, so a caller that awaits a reload after a write
  /// sees its own data — the behaviour the old `if (_isLoadingFromDisk) return;`
  /// early-return silently broke.
  ///
  /// There is deliberately no opt-out parameter: fire-and-forget callers use
  /// `unawaited(request(...))`, which still queues.
  Future<void> request({
    String source = 'manual',
    bool preserveViewport = false,
  }) {
    _queued = true;
    _queuedSource = source;
    _queuedPreserveViewport = preserveViewport;
    final idle = (_idle ??= Completer<void>()).future;
    if (!_pumping) unawaited(_pump());
    return idle;
  }

  Future<void> _pump() async {
    _pumping = true;
    try {
      while (_queued && _isMounted()) {
        _queued = false;
        final source = _queuedSource;
        final preserveViewport = _queuedPreserveViewport;
        final epoch = ++_epoch;
        try {
          _inFlight = _runner(
            source: source,
            preserveViewport: preserveViewport,
            epoch: epoch,
          );
          await _inFlight;
          _lastPassSucceeded = true;
        } catch (err, st) {
          _lastPassSucceeded = false;
          _log('load failed source=$source: $err');
          if (kDebugMode) _log('$st');
        } finally {
          _inFlight = null;
        }
      }
    } finally {
      // Runs synchronously after the loop, so no window exists where work is
      // queued with no pump. A request arriving from a completer continuation
      // lands as a microtask and starts a fresh cycle.
      _pumping = false;
      final completer = _idle;
      _idle = null;
      completer?.complete();
    }
  }

  // ── invalidation bus ───────────────────────────────────────────────────────

  StreamSubscription<CalendarInvalidated>? _sub;
  Timer? _debounceTimer;
  bool _pending = false;
  CalendarInvalidationReason? _pendingReason;
  int? _pendingRevision;
  int _scheduledRevision = 0;

  /// Call from `initState`, replacing the bus subscription (13648) and the
  /// `_schedulePendingCalendarInvalidationReload()` drain beside it.
  void attach() {
    _sub = _bus.stream.listen((_) {
      if (!_isMounted()) return;
      _drainBusBacklog();
    });
    _drainBusBacklog();
  }

  void _drainBusBacklog() {
    if (!_isMounted()) return;
    final pending = _bus.peekPendingAfter(_scheduledRevision);
    if (pending == null) return;
    _scheduledRevision = pending.revision;
    _schedule(pending.invalidation.reason, revision: pending.revision);
  }

  void _schedule(CalendarInvalidationReason reason, {int? revision}) {
    _pending = true;
    _pendingReason = reason;
    if (revision != null) _pendingRevision = revision;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _flush);
  }

  void _flush() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (!_isMounted() || !_pending) return;

    // Only the deferral gate still polls. The old
    // `_calendarInvalidationReloadInFlight || _isLoadingFromDisk` retry loop
    // (13805-13816) is gone: request() queues instead of dropping.
    if (_isDeferred()) {
      _debounceTimer = Timer(_debounce, _flush);
      return;
    }

    final reason = _pendingReason;
    final revision = _pendingRevision;
    _pending = false;
    _pendingReason = null;
    _pendingRevision = null;

    unawaited(
      request(
        source: 'invalidation:${reason?.name ?? 'coalesced'}',
        preserveViewport: true,
      ).then((_) {
        // Queue-level signal: with coalescing a revision may be satisfied by a
        // later pass than the one this request started. That is fine — what
        // matters is that some pass succeeded.
        if (revision != null && _lastPassSucceeded) {
          _bus.markConsumed(revision);
        }
      }),
    );
  }

  void dispose() {
    invalidate(reason: 'dispose');
    _sub?.cancel();
    _sub = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _queued = false;
  }

  void _log(String message) {
    if (!kDebugMode) return;
    _debugLog?.call('[loadCoordinator] $message');
  }
}
