import 'dart:async';

import 'package:flutter/foundation.dart';

import 'navigation_trace.dart';

class SwipeLandingDestination {
  const SwipeLandingDestination._();

  static const String planner = 'planner';
  static const String profile = 'profile';
  static const String calendar = 'calendar';
}

class SwipeLandingCoordinator {
  SwipeLandingCoordinator._();

  static final SwipeLandingCoordinator instance = SwipeLandingCoordinator._();
  static const Duration helperGracePeriod = Duration(milliseconds: 850);
  static const Duration landingRetention = Duration(seconds: 4);

  int _nextId = 0;
  _SwipeLanding? _active;
  Timer? _clearTimer;

  String startCalendarSwipe({required String direction}) {
    final swipeId = 'calendar-swipe-${++_nextId}';
    _clearTimer?.cancel();
    _active = _SwipeLanding(
      swipeId: swipeId,
      origin: SwipeLandingDestination.calendar,
      direction: direction,
      startedAtMs: _nowMs(),
    );
    NavigationTrace.instance.record(
      'swipe landing started',
      state: traceState(swipeId: swipeId),
    );
    _scheduleClear(landingRetention);
    return swipeId;
  }

  void markThresholdCrossed(String? swipeId) {
    final landing = _activeFor(swipeId);
    if (landing == null) return;
    landing.thresholdAtMs ??= _nowMs();
  }

  void markDragEnded(String? swipeId, {required bool committed}) {
    final landing = _activeFor(swipeId);
    if (landing == null) return;
    landing.dragEndedAtMs = _nowMs();
    if (!committed) {
      _clear();
    }
  }

  void markCommitted(String? swipeId) {
    final landing = _activeFor(swipeId);
    if (landing == null) return;
    landing.committedAtMs = _nowMs();
    _scheduleClear(landingRetention);
  }

  void markRouteRequested(
    String? swipeId, {
    required String destination,
    String? route,
  }) {
    final landing = _activeFor(swipeId);
    if (landing == null) return;
    landing
      ..destination = destination
      ..route = route
      ..routeRequestedAtMs = _nowMs();
    NavigationTrace.instance.record(
      'swipe landing route requested',
      state: traceState(swipeId: swipeId, destination: destination),
    );
  }

  void markRouteReturned(
    String? swipeId, {
    required String destination,
    String? route,
  }) {
    final landing = _activeFor(swipeId);
    if (landing == null) return;
    landing
      ..destination = destination
      ..route = route
      ..routeReturnedAtMs = _nowMs();
    NavigationTrace.instance.record(
      'swipe landing route returned',
      state: traceState(swipeId: swipeId, destination: destination),
    );
  }

  void markDestinationFirstFrame({required String destination}) {
    final landing = _matchingDestination(destination);
    if (landing == null) return;
    landing.firstFrameAtMs = _nowMs();
    NavigationTrace.instance.record(
      'swipe landing destination first frame',
      state: traceState(swipeId: landing.swipeId, destination: destination),
    );
    _scheduleClear(landingRetention);
  }

  Future<bool> deferHelperIfNeeded({
    required String destination,
    required String helperKey,
    Duration gracePeriod = helperGracePeriod,
  }) async {
    final landing = _matchingDestination(destination);
    if (landing == null) return false;

    final now = _nowMs();
    final anchor =
        landing.firstFrameAtMs ??
        landing.routeReturnedAtMs ??
        landing.routeRequestedAtMs ??
        landing.committedAtMs ??
        landing.startedAtMs;
    final remainingMs = gracePeriod.inMilliseconds - (now - anchor);
    final waitMs = remainingMs.clamp(0, gracePeriod.inMilliseconds).toInt();
    NavigationTrace.instance.record(
      'helper overlay deferred',
      state: <String, Object?>{
        ...traceState(swipeId: landing.swipeId, destination: destination),
        'helperId': helperKey,
        'waitMs': waitMs,
      },
    );
    if (waitMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: waitMs));
    }
    NavigationTrace.instance.record(
      'helper overlay defer completed',
      state: <String, Object?>{
        ...traceState(swipeId: landing.swipeId, destination: destination),
        'helperId': helperKey,
      },
    );
    return true;
  }

  bool deferOriginCalendarHelper({required String helperKey}) {
    final landing = _active;
    if (landing == null ||
        landing.origin != SwipeLandingDestination.calendar ||
        landing.destination == null) {
      return false;
    }
    NavigationTrace.instance.record(
      'helper overlay deferred',
      state: <String, Object?>{
        ...traceState(swipeId: landing.swipeId),
        'destination': SwipeLandingDestination.calendar,
        'helperId': helperKey,
        'reason': 'calendarSwipeLandingActive',
      },
    );
    return true;
  }

  void recordHelperShown({
    required String destination,
    required String helperKey,
  }) {
    final landing = _matchingDestination(destination);
    NavigationTrace.instance.record(
      'helper overlay shown',
      state: <String, Object?>{
        if (landing != null) ...traceState(swipeId: landing.swipeId),
        'destination': destination,
        'helperId': helperKey,
      },
    );
  }

  Map<String, Object?> traceState({String? swipeId, String? destination}) {
    final landing = _activeFor(swipeId) ?? _matchingDestination(destination);
    if (landing == null) {
      return <String, Object?>{
        if (swipeId != null) 'swipeId': swipeId,
        if (destination != null) 'destination': destination,
      };
    }
    final now = _nowMs();
    return <String, Object?>{
      'swipeId': landing.swipeId,
      'origin': landing.origin,
      'direction': landing.direction,
      if (landing.destination != null) 'destination': landing.destination,
      if (landing.route != null) 'route': landing.route,
      'ageMs': now - landing.startedAtMs,
      if (landing.thresholdAtMs != null)
        'thresholdMs': landing.thresholdAtMs! - landing.startedAtMs,
      if (landing.dragEndedAtMs != null)
        'dragEndMs': landing.dragEndedAtMs! - landing.startedAtMs,
      if (landing.committedAtMs != null)
        'commitMs': landing.committedAtMs! - landing.startedAtMs,
      if (landing.routeRequestedAtMs != null)
        'routeRequestMs': landing.routeRequestedAtMs! - landing.startedAtMs,
      if (landing.firstFrameAtMs != null)
        'firstFrameMs': landing.firstFrameAtMs! - landing.startedAtMs,
    };
  }

  _SwipeLanding? _activeFor(String? swipeId) {
    final landing = _active;
    if (landing == null) return null;
    if (_nowMs() - landing.startedAtMs > landingRetention.inMilliseconds) {
      _clear();
      return null;
    }
    if (swipeId != null && landing.swipeId != swipeId) return null;
    return landing;
  }

  _SwipeLanding? _matchingDestination(String? destination) {
    final landing = _activeFor(null);
    if (landing == null) return null;
    if (destination != null && landing.destination != destination) return null;
    return landing;
  }

  void _scheduleClear(Duration delay) {
    _clearTimer?.cancel();
    _clearTimer = Timer(delay, _clear);
  }

  void _clear() {
    _clearTimer?.cancel();
    _clearTimer = null;
    _active = null;
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  @visibleForTesting
  void resetForTesting() {
    _clear();
    _nextId = 0;
  }
}

class _SwipeLanding {
  _SwipeLanding({
    required this.swipeId,
    required this.origin,
    required this.direction,
    required this.startedAtMs,
  });

  final String swipeId;
  final String origin;
  final String direction;
  final int startedAtMs;
  String? destination;
  String? route;
  int? thresholdAtMs;
  int? dragEndedAtMs;
  int? committedAtMs;
  int? routeRequestedAtMs;
  int? routeReturnedAtMs;
  int? firstFrameAtMs;
}
