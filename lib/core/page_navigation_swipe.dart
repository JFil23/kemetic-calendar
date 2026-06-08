import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/app_haptics.dart';
import '../services/navigation_trace.dart';
import '../services/swipe_landing_coordinator.dart';
import 'touch_targets.dart';

enum PageNavigationSwipeDirection { leftToRight, rightToLeft }

double pageNavigationEdgeSwipeWidth(BuildContext context) {
  return edgeSwipeGestureWidth(
    context,
    touchWidth: 30,
    minWidth: 30,
    maxWidth: 64,
    viewportFraction: 0.075,
  );
}

class PageNavigationEdgeSwipe extends StatelessWidget {
  const PageNavigationEdgeSwipe({
    super.key,
    required this.direction,
    this.onCommit,
    this.onCommitWithSwipeId,
    this.enabled = true,
    this.top = 0,
    this.bottom = 0,
    this.width,
    this.minDistance = 52,
    this.minVelocity = 820,
  }) : assert(
         onCommit != null || onCommitWithSwipeId != null,
         'Provide onCommit or onCommitWithSwipeId.',
       );

  final PageNavigationSwipeDirection direction;
  final VoidCallback? onCommit;
  final ValueChanged<String>? onCommitWithSwipeId;
  final bool enabled;
  final double top;
  final double bottom;
  final double? width;
  final double minDistance;
  final double minVelocity;

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = width ?? pageNavigationEdgeSwipeWidth(context);

    return Positioned(
      top: top,
      bottom: bottom,
      left: direction == PageNavigationSwipeDirection.leftToRight ? 0 : null,
      right: direction == PageNavigationSwipeDirection.rightToLeft ? 0 : null,
      width: resolvedWidth,
      child: _PageNavigationEdgeSwipePad(
        direction: direction,
        enabled: enabled,
        edgeWidth: resolvedWidth,
        minDistance: minDistance,
        minVelocity: minVelocity,
        onCommit: onCommit,
        onCommitWithSwipeId: onCommitWithSwipeId,
      ),
    );
  }
}

class _PageNavigationEdgeSwipePad extends StatefulWidget {
  const _PageNavigationEdgeSwipePad({
    required this.direction,
    required this.enabled,
    required this.edgeWidth,
    required this.minDistance,
    required this.minVelocity,
    required this.onCommit,
    required this.onCommitWithSwipeId,
  });

  final PageNavigationSwipeDirection direction;
  final bool enabled;
  final double edgeWidth;
  final double minDistance;
  final double minVelocity;
  final VoidCallback? onCommit;
  final ValueChanged<String>? onCommitWithSwipeId;

  @override
  State<_PageNavigationEdgeSwipePad> createState() =>
      _PageNavigationEdgeSwipePadState();
}

class _PageNavigationEdgeSwipePadState
    extends State<_PageNavigationEdgeSwipePad> {
  double _travel = 0.0;
  bool _committed = false;
  bool _thresholdFeedbackSent = false;
  int? _dragStartedAtMs;
  String? _swipeId;

  void _reset() {
    _travel = 0.0;
    _committed = false;
    _thresholdFeedbackSent = false;
    _dragStartedAtMs = null;
    _swipeId = null;
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  String get _directionLabel {
    return switch (widget.direction) {
      PageNavigationSwipeDirection.leftToRight => 'leftToRight',
      PageNavigationSwipeDirection.rightToLeft => 'rightToLeft',
    };
  }

  Map<String, Object?> _traceState({
    int? nowMs,
    double? velocity,
    bool? shouldCommit,
  }) {
    final timestampMs = nowMs ?? _nowMs();
    final startedAtMs = _dragStartedAtMs;
    return <String, Object?>{
      'direction': _directionLabel,
      if (_swipeId != null) 'swipeId': _swipeId,
      'timestampMs': timestampMs,
      if (startedAtMs != null) 'elapsedMs': timestampMs - startedAtMs,
      'travel': _travel.round(),
      'edgeWidth': widget.edgeWidth.round(),
      'minDistance': widget.minDistance.round(),
      'minVelocity': widget.minVelocity.round(),
      if (velocity != null) 'velocity': velocity.round(),
      if (shouldCommit != null) 'shouldCommit': shouldCommit,
    };
  }

  @override
  void didUpdateWidget(covariant _PageNavigationEdgeSwipePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled != widget.enabled) {
      _reset();
    }
  }

  void _handleDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    _reset();
    _dragStartedAtMs = _nowMs();
    _swipeId = SwipeLandingCoordinator.instance.startCalendarSwipe(
      direction: _directionLabel,
    );
    NavigationTrace.instance.record(
      'edge swipe drag start',
      state: _traceState(nowMs: _dragStartedAtMs),
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _committed) return;

    final delta = details.delta.dx;
    switch (widget.direction) {
      case PageNavigationSwipeDirection.leftToRight:
        _travel = (_travel + delta).clamp(0.0, double.infinity);
        break;
      case PageNavigationSwipeDirection.rightToLeft:
        _travel = (_travel - delta).clamp(0.0, double.infinity);
        break;
    }
    if (!_thresholdFeedbackSent && _travel >= widget.minDistance) {
      _thresholdFeedbackSent = true;
      SwipeLandingCoordinator.instance.markThresholdCrossed(_swipeId);
      NavigationTrace.instance.record(
        'edge swipe threshold crossed',
        state: _traceState(),
      );
      unawaited(AppHaptics.selection(reason: 'page_navigation_edge_threshold'));
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.enabled || _committed) {
      if (!_committed) {
        SwipeLandingCoordinator.instance.markDragEnded(
          _swipeId,
          committed: false,
        );
      }
      _reset();
      return;
    }

    final velocity = switch (widget.direction) {
      PageNavigationSwipeDirection.leftToRight =>
        details.velocity.pixelsPerSecond.dx,
      PageNavigationSwipeDirection.rightToLeft =>
        -details.velocity.pixelsPerSecond.dx,
    };

    final shouldCommit =
        _travel >= widget.minDistance || velocity >= widget.minVelocity;
    SwipeLandingCoordinator.instance.markDragEnded(
      _swipeId,
      committed: shouldCommit,
    );
    NavigationTrace.instance.record(
      'edge swipe drag end',
      state: _traceState(velocity: velocity, shouldCommit: shouldCommit),
    );
    if (shouldCommit) {
      _committed = true;
      final swipeId = _swipeId;
      SwipeLandingCoordinator.instance.markCommitted(swipeId);
      NavigationTrace.instance.record(
        'edge swipe commit fired',
        state: _traceState(velocity: velocity, shouldCommit: true),
      );
      if (swipeId != null) {
        widget.onCommitWithSwipeId?.call(swipeId);
      }
      widget.onCommit?.call();
    }
    _reset();
  }

  void _handleDragCancel() {
    SwipeLandingCoordinator.instance.markDragEnded(_swipeId, committed: false);
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragCancel: _handleDragCancel,
      onHorizontalDragEnd: _handleDragEnd,
      child: const SizedBox.expand(),
    );
  }
}
