import 'package:flutter/foundation.dart';

import 'calendar_coverage_ledger.dart';
import 'calendar_hydration_models.dart';
import 'calendar_hydration_scheduler.dart';

@immutable
class CalendarHydrationControllerState {
  const CalendarHydrationControllerState({
    required this.sessionGeneration,
    required this.viewportRevision,
    required this.authority,
    required this.cacheVisible,
    required this.stale,
    required this.catalogFingerprint,
    required this.freshCatalogFingerprint,
    required this.viewport,
    required this.fullHorizon,
    required this.coverage,
  });

  factory CalendarHydrationControllerState.initial() =>
      CalendarHydrationControllerState(
        sessionGeneration: 0,
        viewportRevision: 0,
        authority: CalendarViewportAuthority.none,
        cacheVisible: false,
        stale: false,
        catalogFingerprint: null,
        freshCatalogFingerprint: null,
        viewport: null,
        fullHorizon: null,
        coverage: CalendarCoverageLedger.empty(''),
      );

  final int sessionGeneration;
  final int viewportRevision;
  final CalendarViewportAuthority authority;
  final bool cacheVisible;
  final bool stale;
  final String? catalogFingerprint;
  final String? freshCatalogFingerprint;
  final CalendarHydrationInterval? viewport;
  final CalendarHydrationInterval? fullHorizon;
  final CalendarCoverageLedger coverage;

  bool get mayPersistWarmCache =>
      authority == CalendarViewportAuthority.fullHorizon &&
      catalogFingerprint != null &&
      catalogFingerprint == freshCatalogFingerprint;

  /// A fresh, atomically committed viewport is safe to checkpoint even while
  /// the wider horizon continues in the background. The page merge preserves
  /// every cached bucket outside [viewport], so this cannot turn a bounded
  /// refresh into destructive replacement.
  bool get mayPersistServerCurrentViewport =>
      (authority == CalendarViewportAuthority.serverCurrent ||
          authority == CalendarViewportAuthority.fullHorizon) &&
      catalogFingerprint != null &&
      catalogFingerprint == freshCatalogFingerprint &&
      viewport != null &&
      coverage.catalogFingerprint == catalogFingerprint &&
      coverage.covers(viewport!);
}

@immutable
class CalendarHydrationCommitToken {
  const CalendarHydrationCommitToken._({
    required this.sessionGeneration,
    required this.viewportRevision,
    required this.interval,
    required this.catalogFingerprint,
    required this.catalogIsFresh,
  });

  final int sessionGeneration;
  final int viewportRevision;
  final CalendarHydrationInterval interval;
  final String catalogFingerprint;
  final bool catalogIsFresh;
}

typedef CalendarHydrationStateListener =
    void Function(CalendarHydrationControllerState state, String reason);

/// Sole owner of calendar hydration authority, coverage, and commit validity.
///
/// Page state changes are supplied as a pure prepared callback and invoked only
/// after this controller validates the session, viewport, and fingerprint.
class CalendarHydrationController {
  CalendarHydrationController({
    required CalendarHydrationScheduler scheduler,
    CalendarHydrationStateListener? onStateChanged,
  }) : _scheduler = scheduler,
       _onStateChanged = onStateChanged;

  final CalendarHydrationScheduler _scheduler;
  final CalendarHydrationStateListener? _onStateChanged;
  CalendarHydrationControllerState _state =
      CalendarHydrationControllerState.initial();
  String? _userId;

  CalendarHydrationControllerState get state => _state;
  String? get userId => _userId;

  void beginSession(String userId) {
    if (_userId == userId) return;
    _scheduler.invalidateAll(reason: 'session_changed');
    _userId = userId;
    _state = CalendarHydrationControllerState(
      sessionGeneration: _state.sessionGeneration + 1,
      viewportRevision: 0,
      authority: CalendarViewportAuthority.none,
      cacheVisible: false,
      stale: false,
      catalogFingerprint: null,
      freshCatalogFingerprint: null,
      viewport: null,
      fullHorizon: null,
      coverage: CalendarCoverageLedger.empty(''),
    );
    _notify('session_started');
  }

  void signOut() {
    _scheduler.invalidateAll(reason: 'signed_out');
    _userId = null;
    _state = CalendarHydrationControllerState(
      sessionGeneration: _state.sessionGeneration + 1,
      viewportRevision: 0,
      authority: CalendarViewportAuthority.none,
      cacheVisible: false,
      stale: false,
      catalogFingerprint: null,
      freshCatalogFingerprint: null,
      viewport: null,
      fullHorizon: null,
      coverage: CalendarCoverageLedger.empty(''),
    );
    _notify('signed_out');
  }

  void restoreCache({
    required String catalogFingerprint,
    required void Function() applyPreparedState,
  }) {
    if (_userId == null) return;
    applyPreparedState();
    final coverage = CalendarCoverageLedger.empty(catalogFingerprint);
    _state = _copyState(
      cacheVisible: true,
      stale: true,
      catalogFingerprint: catalogFingerprint,
      freshCatalogFingerprint: null,
      coverage: coverage,
    );
    _deriveAuthority(reason: 'cache_restored');
  }

  int reportViewport(CalendarHydrationInterval interval) {
    if (_state.viewport == interval) return _state.viewportRevision;
    _state = _copyState(
      viewportRevision: _state.viewportRevision + 1,
      viewport: interval,
    );
    _deriveAuthority(reason: 'viewport_changed');
    return _state.viewportRevision;
  }

  void setFullHorizon(CalendarHydrationInterval interval) {
    _state = _copyState(fullHorizon: interval);
    _deriveAuthority(reason: 'full_horizon_changed');
  }

  CalendarHydrationCommitToken beginViewportCommit({
    required String catalogFingerprint,
    required bool catalogIsFresh,
  }) {
    final viewport = _state.viewport;
    if (viewport == null) {
      throw StateError('Cannot hydrate before a viewport is reported');
    }
    return CalendarHydrationCommitToken._(
      sessionGeneration: _state.sessionGeneration,
      viewportRevision: _state.viewportRevision,
      interval: viewport,
      catalogFingerprint: catalogFingerprint,
      catalogIsFresh: catalogIsFresh,
    );
  }

  bool isCurrent(CalendarHydrationCommitToken token) =>
      _userId != null &&
      token.sessionGeneration == _state.sessionGeneration &&
      token.viewportRevision == _state.viewportRevision &&
      token.interval == _state.viewport;

  bool commitViewport({
    required CalendarHydrationCommitToken token,
    required void Function() applyPreparedState,
  }) {
    if (!isCurrent(token)) return false;
    applyPreparedState();
    final previousFingerprint = _state.catalogFingerprint;
    var coverage = _state.coverage;
    if (coverage.catalogFingerprint != token.catalogFingerprint) {
      coverage = CalendarCoverageLedger.empty(token.catalogFingerprint);
    }
    final commitIsFresh =
        token.catalogIsFresh ||
        token.catalogFingerprint == _state.freshCatalogFingerprint;
    coverage = coverage.add(
      fingerprint: token.catalogFingerprint,
      interval: token.interval,
    );
    _state = _copyState(
      cacheVisible: true,
      stale: !commitIsFresh,
      catalogFingerprint: token.catalogFingerprint,
      freshCatalogFingerprint: token.catalogIsFresh
          ? token.catalogFingerprint
          : _state.freshCatalogFingerprint,
      coverage: coverage,
    );
    if (previousFingerprint != null &&
        previousFingerprint != token.catalogFingerprint) {
      _scheduler.cancelQueued(reason: 'catalog_fingerprint_changed');
    }
    _deriveAuthority(
      reason: commitIsFresh
          ? 'server_current_committed'
          : 'provisional_viewport_committed',
    );
    return true;
  }

  bool promoteMatchingFreshCatalog(String freshFingerprint) {
    if (_state.catalogFingerprint != freshFingerprint) return false;
    _state = _copyState(
      freshCatalogFingerprint: freshFingerprint,
      stale: false,
    );
    _deriveAuthority(reason: 'fresh_catalog_matched');
    return _state.authority == CalendarViewportAuthority.serverCurrent ||
        _state.authority == CalendarViewportAuthority.fullHorizon;
  }

  bool commitBackgroundInterval({
    required int sessionGeneration,
    required String catalogFingerprint,
    required CalendarHydrationInterval interval,
    required void Function() applyPreparedState,
  }) {
    if (_userId == null ||
        sessionGeneration != _state.sessionGeneration ||
        catalogFingerprint != _state.freshCatalogFingerprint) {
      return false;
    }
    applyPreparedState();
    final coverage = _state.coverage.add(
      fingerprint: catalogFingerprint,
      interval: interval,
    );
    _state = _copyState(coverage: coverage, stale: false);
    _deriveAuthority(reason: 'background_interval_committed');
    return true;
  }

  void markFailure() {
    _state = _copyState(stale: true);
    _deriveAuthority(reason: 'hydration_failed');
  }

  bool validateCacheWrite({
    required int sessionGeneration,
    required String catalogFingerprint,
    bool allowServerCurrentViewport = false,
  }) =>
      _userId != null &&
      sessionGeneration == _state.sessionGeneration &&
      catalogFingerprint == _state.freshCatalogFingerprint &&
      catalogFingerprint == _state.catalogFingerprint &&
      (_state.mayPersistWarmCache ||
          (allowServerCurrentViewport &&
              _state.mayPersistServerCurrentViewport));

  void dispose() => _scheduler.dispose();

  void _deriveAuthority({required String reason}) {
    final viewport = _state.viewport;
    final fingerprint = _state.catalogFingerprint;
    final viewportCovered =
        viewport != null &&
        fingerprint != null &&
        _state.coverage.catalogFingerprint == fingerprint &&
        _state.coverage.covers(viewport);
    final fresh =
        fingerprint != null && fingerprint == _state.freshCatalogFingerprint;
    final horizon = _state.fullHorizon;
    final horizonCovered =
        horizon != null && fresh && _state.coverage.covers(horizon);

    final authority = horizonCovered
        ? CalendarViewportAuthority.fullHorizon
        : viewportCovered && fresh
        ? CalendarViewportAuthority.serverCurrent
        : viewportCovered
        ? CalendarViewportAuthority.viewportRefreshed
        : _state.cacheVisible
        ? CalendarViewportAuthority.cacheVisible
        : CalendarViewportAuthority.none;
    _state = _copyState(authority: authority);
    _notify(reason);
  }

  CalendarHydrationControllerState _copyState({
    int? sessionGeneration,
    int? viewportRevision,
    CalendarViewportAuthority? authority,
    bool? cacheVisible,
    bool? stale,
    Object? catalogFingerprint = _unset,
    Object? freshCatalogFingerprint = _unset,
    Object? viewport = _unset,
    Object? fullHorizon = _unset,
    CalendarCoverageLedger? coverage,
  }) => CalendarHydrationControllerState(
    sessionGeneration: sessionGeneration ?? _state.sessionGeneration,
    viewportRevision: viewportRevision ?? _state.viewportRevision,
    authority: authority ?? _state.authority,
    cacheVisible: cacheVisible ?? _state.cacheVisible,
    stale: stale ?? _state.stale,
    catalogFingerprint: identical(catalogFingerprint, _unset)
        ? _state.catalogFingerprint
        : catalogFingerprint as String?,
    freshCatalogFingerprint: identical(freshCatalogFingerprint, _unset)
        ? _state.freshCatalogFingerprint
        : freshCatalogFingerprint as String?,
    viewport: identical(viewport, _unset)
        ? _state.viewport
        : viewport as CalendarHydrationInterval?,
    fullHorizon: identical(fullHorizon, _unset)
        ? _state.fullHorizon
        : fullHorizon as CalendarHydrationInterval?,
    coverage: coverage ?? _state.coverage,
  );

  void _notify(String reason) => _onStateChanged?.call(_state, reason);
}

const Object _unset = Object();
