import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
    required this.onCommit,
    this.enabled = true,
    this.top = 0,
    this.bottom = 0,
    this.width,
    this.minDistance = 52,
    this.minVelocity = 820,
  });

  final PageNavigationSwipeDirection direction;
  final VoidCallback onCommit;
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
        minDistance: minDistance,
        minVelocity: minVelocity,
        onCommit: onCommit,
      ),
    );
  }
}

class _PageNavigationEdgeSwipePad extends StatefulWidget {
  const _PageNavigationEdgeSwipePad({
    required this.direction,
    required this.enabled,
    required this.minDistance,
    required this.minVelocity,
    required this.onCommit,
  });

  final PageNavigationSwipeDirection direction;
  final bool enabled;
  final double minDistance;
  final double minVelocity;
  final VoidCallback onCommit;

  @override
  State<_PageNavigationEdgeSwipePad> createState() =>
      _PageNavigationEdgeSwipePadState();
}

class _PageNavigationEdgeSwipePadState
    extends State<_PageNavigationEdgeSwipePad> {
  double _travel = 0.0;
  bool _committed = false;

  void _reset() {
    _travel = 0.0;
    _committed = false;
  }

  @override
  void didUpdateWidget(covariant _PageNavigationEdgeSwipePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled != widget.enabled) {
      _reset();
    }
  }

  void _handleDragStart(DragStartDetails details) {
    _reset();
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
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!widget.enabled || _committed) {
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
    if (shouldCommit) {
      _committed = true;
      widget.onCommit();
    }
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragCancel: _reset,
      onHorizontalDragEnd: _handleDragEnd,
      child: const SizedBox.expand(),
    );
  }
}
