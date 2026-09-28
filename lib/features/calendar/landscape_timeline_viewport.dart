import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show ViewportOffset;

/// One gesture and momentum owner for the calendar's two scroll axes.
/// The pinned day headers and the event columns share the same viewport offsets.
class LandscapeTimeline extends TwoDimensionalScrollView {
  LandscapeTimeline({
    super.key,
    required ScrollController days,
    required ScrollController hours,
    required this.columnWidth,
    required this.dayCount,
    required this.headerHeight,
    required this.dayHeight,
    required IndexedWidgetBuilder dayBuilder,
    required IndexedWidgetBuilder headerBuilder,
  }) : super(
         primary: false,
         mainAxis: Axis.vertical,
         diagonalDragBehavior: DiagonalDragBehavior.free,
         horizontalDetails: ScrollableDetails.horizontal(controller: days),
         verticalDetails: ScrollableDetails.vertical(controller: hours),
         delegate: TwoDimensionalChildBuilderDelegate(
           maxXIndex: dayCount - 1,
           maxYIndex: 1,
           builder: (context, vicinity) => vicinity.yIndex == 0
               ? dayBuilder(context, vicinity.xIndex)
               : ColoredBox(
                   color: Colors.black,
                   child: headerBuilder(context, vicinity.xIndex),
                 ),
         ),
       );

  final double columnWidth;
  final int dayCount;
  final double headerHeight;
  final double dayHeight;

  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset verticalOffset,
    ViewportOffset horizontalOffset,
  ) => Listener(
    behavior: HitTestBehavior.opaque,
    // The pinned SDK's default pointer-signal resolver gives a diagonal wheel
    // event to just the inner axis. Resolve it once for the entire viewport,
    // using the same ScrollPosition pointer behavior for both components.
    onPointerSignal: (event) => _scrollBothAxes(context, event),
    child: _CalendarViewport(
      verticalOffset: verticalOffset,
      horizontalOffset: horizontalOffset,
      delegate: delegate,
      columnWidth: columnWidth,
      dayCount: dayCount,
      headerHeight: headerHeight,
      dayHeight: dayHeight,
    ),
  );

  void _scrollBothAxes(BuildContext context, PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final horizontal = horizontalDetails.controller!.position;
    final vertical = verticalDetails.controller!.position;
    final modifiers = ScrollConfiguration.of(context).pointerAxisModifiers;
    final flip =
        event.kind == PointerDeviceKind.mouse &&
        HardwareKeyboard.instance.logicalKeysPressed.any(modifiers.contains);
    final delta = flip
        ? Offset(event.scrollDelta.dy, event.scrollDelta.dx)
        : event.scrollDelta;
    bool canMove(ScrollPosition position, double change) =>
        position.physics.shouldAcceptUserOffset(position) &&
        change != 0 &&
        (position.pixels + change).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ) !=
            position.pixels;
    final moveX = canMove(horizontal, delta.dx);
    final moveY = canMove(vertical, delta.dy);
    if (moveX || moveY) {
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        if (moveX) horizontal.pointerScroll(delta.dx);
        if (moveY) vertical.pointerScroll(delta.dy);
      });
    }
  }
}

class _CalendarViewport extends TwoDimensionalViewport {
  const _CalendarViewport({
    required super.verticalOffset,
    required super.horizontalOffset,
    required super.delegate,
    required this.columnWidth,
    required this.dayCount,
    required this.headerHeight,
    required this.dayHeight,
  }) : super(
         verticalAxisDirection: AxisDirection.down,
         horizontalAxisDirection: AxisDirection.right,
         mainAxis: Axis.vertical,
       );

  final double columnWidth;
  final int dayCount;
  final double headerHeight;
  final double dayHeight;

  @override
  _RenderCalendarViewport createRenderObject(BuildContext context) =>
      _RenderCalendarViewport(
        verticalOffset: verticalOffset,
        horizontalOffset: horizontalOffset,
        delegate: delegate,
        childManager: context as TwoDimensionalChildManager,
        columnWidth: columnWidth,
        dayCount: dayCount,
        headerHeight: headerHeight,
        dayHeight: dayHeight,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCalendarViewport renderObject,
  ) {
    renderObject
      ..verticalOffset = verticalOffset
      ..horizontalOffset = horizontalOffset
      ..delegate = delegate
      ..configure(columnWidth, dayCount, headerHeight, dayHeight);
  }
}

class _RenderCalendarViewport extends RenderTwoDimensionalViewport {
  _RenderCalendarViewport({
    required super.verticalOffset,
    required super.horizontalOffset,
    required super.delegate,
    required super.childManager,
    required double columnWidth,
    required int dayCount,
    required double headerHeight,
    required double dayHeight,
  }) : _columnWidth = columnWidth,
       _dayCount = dayCount,
       _headerHeight = headerHeight,
       _dayHeight = dayHeight,
       super(
         verticalAxisDirection: AxisDirection.down,
         horizontalAxisDirection: AxisDirection.right,
         mainAxis: Axis.vertical,
       );

  double _columnWidth, _headerHeight, _dayHeight;
  int _dayCount;

  void configure(double width, int count, double header, double day) {
    if (width == _columnWidth &&
        count == _dayCount &&
        header == _headerHeight &&
        day == _dayHeight) {
      return;
    }
    _columnWidth = width;
    _dayCount = count;
    _headerHeight = header;
    _dayHeight = day;
    markNeedsLayout();
  }

  @override
  void layoutChildSequence() {
    horizontalOffset.applyContentDimensions(
      0,
      math.max(0, _dayCount * _columnWidth - viewportDimension.width),
    );
    verticalOffset.applyContentDimensions(
      0,
      math.max(0, _dayHeight + _headerHeight - viewportDimension.height),
    );
    final x = horizontalOffset.pixels;
    // Keep only the visible columns and one warm column on either side.
    final first = math.max(0, (x / _columnWidth).floor() - 1);
    final last = math.min(
      _dayCount - 1,
      ((x + viewportDimension.width) / _columnWidth).ceil(),
    );
    for (var index = first; index <= last; index++) {
      for (var row = 0; row < 2; row++) {
        final child = buildOrObtainChildFor(
          ChildVicinity(xIndex: index, yIndex: row),
        )!;
        child.layout(
          BoxConstraints.tightFor(
            width: _columnWidth,
            height: row == 0 ? _dayHeight : _headerHeight,
          ),
        );
        parentDataOf(child).layoutOffset = Offset(
          index * _columnWidth - x,
          row == 0 ? _headerHeight - verticalOffset.pixels : 0,
        );
      }
    }
  }
}
