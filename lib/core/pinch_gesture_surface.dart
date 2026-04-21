import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Raw two-finger pinch handling that stays out of the gesture arena for
/// single-finger tap and scroll interactions.
class PinchGestureSurface extends StatefulWidget {
  const PinchGestureSurface({
    super.key,
    required this.child,
    this.enableTouchPinch = true,
    this.enableGlobalScaleGestures = false,
    this.behavior = HitTestBehavior.translucent,
    this.touchScaleSlop = 12.0,
    this.touchScaleRatioSlop = 0.04,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
  });

  final Widget child;
  final bool enableTouchPinch;
  final bool enableGlobalScaleGestures;
  final HitTestBehavior behavior;
  final double touchScaleSlop;
  final double touchScaleRatioSlop;
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;

  @override
  State<PinchGestureSurface> createState() => _PinchGestureSurfaceState();
}

class _PinchGestureSurfaceState extends State<PinchGestureSurface> {
  final Map<int, Offset> _activeTouchPointers = <int, Offset>{};

  _TouchPinchMetrics? _touchBaselineMetrics;
  Offset? _lastFocalPoint;
  bool _touchPinchActive = false;

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enableTouchPinch || event.kind != PointerDeviceKind.touch) {
      return;
    }

    _activeTouchPointers[event.pointer] = event.position;
    if (_activeTouchPointers.length >= 2) {
      final metrics = _computeTouchMetrics();
      if (metrics != null) {
        _rebalanceTouchPinch(metrics);
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!widget.enableTouchPinch ||
        event.kind != PointerDeviceKind.touch ||
        !_activeTouchPointers.containsKey(event.pointer)) {
      return;
    }

    _activeTouchPointers[event.pointer] = event.position;
    if (_activeTouchPointers.length < 2) {
      return;
    }

    final metrics = _computeTouchMetrics();
    if (metrics == null) return;

    _touchBaselineMetrics ??= metrics;
    final baseline = _touchBaselineMetrics!;
    final spanDelta = (metrics.span - baseline.span).abs();
    final scale = baseline.span > 0 ? metrics.span / baseline.span : 1.0;
    final scaleDelta = (scale - 1.0).abs();

    if (!_touchPinchActive) {
      if (spanDelta < widget.touchScaleSlop ||
          scaleDelta < widget.touchScaleRatioSlop) {
        return;
      }

      _touchPinchActive = true;
      _lastFocalPoint = metrics.focalPoint;
      widget.onScaleStart?.call(
        ScaleStartDetails(
          focalPoint: metrics.focalPoint,
          localFocalPoint: _toLocal(metrics.focalPoint),
          pointerCount: _activeTouchPointers.length,
          sourceTimeStamp: event.timeStamp,
          kind: PointerDeviceKind.touch,
        ),
      );
    }

    final focalPointDelta = _lastFocalPoint == null
        ? Offset.zero
        : metrics.focalPoint - _lastFocalPoint!;
    _lastFocalPoint = metrics.focalPoint;

    widget.onScaleUpdate?.call(
      ScaleUpdateDetails(
        focalPoint: metrics.focalPoint,
        localFocalPoint: _toLocal(metrics.focalPoint),
        scale: scale,
        horizontalScale: scale,
        verticalScale: scale,
        pointerCount: _activeTouchPointers.length,
        focalPointDelta: focalPointDelta,
        sourceTimeStamp: event.timeStamp,
      ),
    );
  }

  void _handlePointerUp(PointerUpEvent event) => _handlePointerFinished(event);

  void _handlePointerCancel(PointerCancelEvent event) =>
      _handlePointerFinished(event);

  void _handlePointerFinished(PointerEvent event) {
    if (!widget.enableTouchPinch ||
        !_activeTouchPointers.containsKey(event.pointer)) {
      return;
    }

    final previousCount = _activeTouchPointers.length;
    _activeTouchPointers.remove(event.pointer);

    if (_touchPinchActive && _activeTouchPointers.length < 2) {
      widget.onScaleEnd?.call(ScaleEndDetails(pointerCount: previousCount));
      _resetTouchPinchState();
      return;
    }

    if (_activeTouchPointers.length >= 2) {
      final metrics = _computeTouchMetrics();
      if (metrics != null) {
        _rebalanceTouchPinch(metrics);
      }
      return;
    }

    _resetTouchPinchState();
  }

  void _rebalanceTouchPinch(_TouchPinchMetrics metrics) {
    _touchBaselineMetrics = metrics;
    _lastFocalPoint = metrics.focalPoint;
  }

  void _resetTouchPinchState() {
    _touchBaselineMetrics = null;
    _lastFocalPoint = null;
    _touchPinchActive = false;
  }

  _TouchPinchMetrics? _computeTouchMetrics() {
    if (_activeTouchPointers.length < 2) return null;

    final points = _activeTouchPointers.values.toList(growable: false);
    final focalPoint =
        points.reduce((sum, point) => sum + point) / points.length.toDouble();

    double totalDeviation = 0.0;
    for (final point in points) {
      totalDeviation += (focalPoint - point).distance;
    }

    return _TouchPinchMetrics(
      focalPoint: focalPoint,
      span: totalDeviation / points.length.toDouble(),
    );
  }

  Offset _toLocal(Offset globalPoint) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return globalPoint;
    return renderObject.globalToLocal(globalPoint);
  }

  @override
  Widget build(BuildContext context) {
    Widget current = Listener(
      behavior: widget.behavior,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );

    if (!widget.enableGlobalScaleGestures) {
      return current;
    }

    current = GestureDetector(
      behavior: widget.behavior,
      onScaleStart: widget.onScaleStart,
      onScaleUpdate: widget.onScaleUpdate,
      onScaleEnd: widget.onScaleEnd,
      child: current,
    );

    return current;
  }
}

class _TouchPinchMetrics {
  const _TouchPinchMetrics({required this.focalPoint, required this.span});

  final Offset focalPoint;
  final double span;
}
