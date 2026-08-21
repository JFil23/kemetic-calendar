import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Stable render marker for the calendar day currently under a pinch focal
/// point. Keeping this render object alive across fractional layout updates
/// lets the viewport preserve a day anchor instead of repairing a month-level
/// jump after paint.
class CalendarPinchDayAnchor extends SingleChildRenderObjectWidget {
  const CalendarPinchDayAnchor({
    super.key,
    required this.year,
    required this.month,
    required this.day,
    required super.child,
  });

  final int year;
  final int month;
  final int day;

  @override
  RenderCalendarPinchDayAnchor createRenderObject(BuildContext context) {
    return RenderCalendarPinchDayAnchor(year: year, month: month, day: day);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCalendarPinchDayAnchor renderObject,
  ) {
    renderObject
      ..year = year
      ..month = month
      ..day = day;
  }
}

class RenderCalendarPinchDayAnchor extends RenderProxyBox {
  RenderCalendarPinchDayAnchor({
    required this.year,
    required this.month,
    required this.day,
  });

  int year;
  int month;
  int day;
}

typedef CalendarLayoutAnchorResolver = RenderObject? Function();

/// One layout-coupled semantic-anchor correction request.
///
/// Requests are consumed by [RenderCalendarEpochViewport] during layout. The
/// page cannot call `correctBy`, `correctPixels`, or `jumpTo` through this API.
final class CalendarLayoutCorrectionRequest {
  const CalendarLayoutCorrectionRequest({
    required this.serial,
    required this.geometryRevision,
    required this.resolveAnchor,
    required this.alignment,
    required this.beforeViewportCoordinate,
  });

  final int serial;
  final String geometryRevision;
  final CalendarLayoutAnchorResolver resolveAnchor;
  final double alignment;
  final double? beforeViewportCoordinate;
}

/// Mailbox between a presentation epoch and the viewport that owns layout.
final class CalendarLayoutCorrectionController {
  CalendarLayoutCorrectionRequest? _pending;
  int _nextSerial = 0;
  int _completedCount = 0;
  int _missingAnchorCount = 0;
  double _lastCorrection = 0;

  CalendarLayoutCorrectionRequest? get pending => _pending;
  int get debugCompletedCount => _completedCount;
  int get debugMissingAnchorCount => _missingAnchorCount;
  double get debugLastCorrection => _lastCorrection;

  void request({
    required String geometryRevision,
    required CalendarLayoutAnchorResolver resolveAnchor,
    double alignment = 0.5,
  }) {
    if (geometryRevision.trim().isEmpty) {
      throw ArgumentError.value(
        geometryRevision,
        'geometryRevision',
        'must not be empty',
      );
    }
    if (!alignment.isFinite || alignment < 0 || alignment > 1) {
      throw RangeError.range(alignment, 0, 1, 'alignment');
    }
    final anchor = resolveAnchor();
    final viewport = anchor == null
        ? null
        : RenderAbstractViewport.maybeOf(anchor);
    double? beforeViewportCoordinate;
    if (anchor != null && anchor.attached && viewport is RenderViewport) {
      try {
        final origin = MatrixUtils.transformPoint(
          anchor.getTransformTo(viewport),
          Offset.zero,
        );
        beforeViewportCoordinate = viewport.axis == Axis.vertical
            ? origin.dy
            : origin.dx;
      } on FlutterError {
        beforeViewportCoordinate = null;
      }
    }
    _pending = CalendarLayoutCorrectionRequest(
      serial: ++_nextSerial,
      geometryRevision: geometryRevision.trim(),
      resolveAnchor: resolveAnchor,
      alignment: alignment,
      beforeViewportCoordinate: beforeViewportCoordinate,
    );
  }

  void complete(
    CalendarLayoutCorrectionRequest request, {
    required double correction,
    required bool anchorFound,
  }) {
    if (_pending?.serial != request.serial) return;
    _pending = null;
    _completedCount++;
    _lastCorrection = correction;
    if (!anchorFound) _missingAnchorCount++;
  }

  void clear() => _pending = null;
}

/// A `CustomScrollView` whose render viewport is the sole owner of epoch
/// corrections. The correction happens inside layout, without scroll events or
/// a new scroll activity.
class CalendarEpochScrollView extends CustomScrollView {
  const CalendarEpochScrollView({
    super.key,
    required this.correctionController,
    super.scrollDirection,
    super.reverse,
    super.controller,
    super.primary,
    super.physics,
    super.scrollBehavior,
    super.shrinkWrap,
    super.center,
    super.anchor,
    super.cacheExtent,
    super.slivers,
    super.semanticChildCount,
    super.dragStartBehavior,
    super.keyboardDismissBehavior,
    super.restorationId,
    super.clipBehavior,
    super.hitTestBehavior,
    super.paintOrder,
  });

  final CalendarLayoutCorrectionController correctionController;

  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset offset,
    AxisDirection axisDirection,
    List<Widget> slivers,
  ) {
    if (shrinkWrap) {
      throw StateError('CalendarEpochScrollView does not support shrinkWrap');
    }
    return _CalendarEpochViewport(
      axisDirection: axisDirection,
      crossAxisDirection: Viewport.getDefaultCrossAxisDirection(
        context,
        axisDirection,
      ),
      offset: offset,
      slivers: slivers,
      cacheExtent: cacheExtent,
      center: center,
      anchor: anchor,
      paintOrder: paintOrder,
      clipBehavior: clipBehavior,
      correctionController: correctionController,
    );
  }
}

class _CalendarEpochViewport extends Viewport {
  _CalendarEpochViewport({
    required super.axisDirection,
    required super.crossAxisDirection,
    required super.offset,
    required super.slivers,
    required super.cacheExtent,
    required super.center,
    required super.anchor,
    required super.paintOrder,
    required super.clipBehavior,
    required this.correctionController,
  });

  final CalendarLayoutCorrectionController correctionController;

  @override
  RenderCalendarEpochViewport createRenderObject(BuildContext context) {
    return RenderCalendarEpochViewport(
      axisDirection: axisDirection,
      crossAxisDirection: crossAxisDirection!,
      anchor: anchor,
      offset: offset,
      cacheExtent: cacheExtent,
      cacheExtentStyle: cacheExtentStyle,
      paintOrder: paintOrder,
      clipBehavior: clipBehavior,
      correctionController: correctionController,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCalendarEpochViewport renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    renderObject.correctionController = correctionController;
  }
}

class RenderCalendarEpochViewport extends RenderViewport {
  RenderCalendarEpochViewport({
    required super.axisDirection,
    required super.crossAxisDirection,
    required super.anchor,
    required super.offset,
    required super.cacheExtent,
    required super.cacheExtentStyle,
    required super.paintOrder,
    required super.clipBehavior,
    required CalendarLayoutCorrectionController correctionController,
  }) : _correctionController = correctionController;

  CalendarLayoutCorrectionController _correctionController;

  set correctionController(CalendarLayoutCorrectionController value) {
    if (identical(value, _correctionController)) return;
    _correctionController = value;
  }

  @override
  void performLayout() {
    final request = _correctionController.pending;
    if (request == null) {
      super.performLayout();
      return;
    }

    final before = request.beforeViewportCoordinate;
    super.performLayout();

    final afterAnchor = request.resolveAnchor();
    final after = _viewportCoordinate(afterAnchor);
    if (before == null || after == null) {
      _correctionController.complete(
        request,
        correction: 0,
        anchorFound: false,
      );
      return;
    }

    final coordinateDelta = after - before;
    final correction = switch (axisDirection) {
      AxisDirection.down || AxisDirection.right => coordinateDelta,
      AxisDirection.up || AxisDirection.left => -coordinateDelta,
    };
    if (correction.abs() > 0.000001) {
      offset.correctBy(correction);
      // The corrected offset participates in the same layout transaction. No
      // listener notification or synthetic scroll lifecycle is emitted.
      super.performLayout();
    }
    _correctionController.complete(
      request,
      correction: correction,
      anchorFound: true,
    );
  }

  double? _viewportCoordinate(RenderObject? target) {
    if (target == null || !target.attached) return null;
    try {
      final origin = MatrixUtils.transformPoint(
        target.getTransformTo(this),
        Offset.zero,
      );
      return axis == Axis.vertical ? origin.dy : origin.dx;
    } on FlutterError {
      return null;
    }
  }
}
