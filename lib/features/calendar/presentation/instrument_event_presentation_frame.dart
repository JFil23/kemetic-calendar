import 'dart:math' as math;

import 'package:flutter/material.dart';

class CalendarEventDetailSheetCoordinator {
  CalendarEventDetailSheetCoordinator._();

  static bool _openOrOpening = false;

  static bool get isOpenOrOpening => _openOrOpening;

  static bool tryMarkOpenOrOpening() {
    if (_openOrOpening) return false;
    _openOrOpening = true;
    return true;
  }

  static void markClosed() {
    _openOrOpening = false;
  }

  @visibleForTesting
  static void debugResetForTests() {
    _openOrOpening = false;
  }
}

@visibleForTesting
const ValueKey<String> dayViewBottomSheetBackplateKey = ValueKey<String>(
  'day-view-bottom-sheet-backplate',
);

class DayViewBottomSheetFrame extends StatelessWidget {
  const DayViewBottomSheetFrame({
    super.key,
    required this.child,
    this.borderRadius = 20,
  });

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(top: Radius.circular(borderRadius));

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              key: dayViewBottomSheetBackplateKey,
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xF7070605), Color(0xFA050403)],
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0xCC000000),
                    blurRadius: 28,
                    spreadRadius: 6,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

typedef InstrumentEventInputBuilder =
    Widget Function(
      BuildContext context,
      double heroHeight,
      double instrumentHeight,
    );

/// The production geometry shared by instrument-backed calendar details.
///
/// This owns only the frame that Follow the Sky already proved: the fixed
/// instrument, the transparent input layer, and a vertical body that rises
/// over the instrument. Flow-specific art and copy stay with each flow.
class InstrumentEventPresentationFrame extends StatelessWidget {
  const InstrumentEventPresentationFrame({
    super.key,
    required this.decoration,
    required this.instrument,
    required this.instrumentFooter,
    required this.inputBuilder,
    required this.body,
    required this.bodyScrollKey,
    required this.lowerSheetKey,
    this.fixedHeroHeight,
  });

  static const double footerHeight = 76;

  final Decoration decoration;
  final Widget instrument;
  final Widget instrumentFooter;
  final InstrumentEventInputBuilder inputBuilder;
  final Widget body;
  final Key bodyScrollKey;
  final Key lowerSheetKey;
  final double? fixedHeroHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 620.0;
        final heroHeight =
            fixedHeroHeight ??
            math.min(282.0, math.max(238.0, boundedHeight * 0.46));
        final instrumentHeight = heroHeight + footerHeight;
        return DecoratedBox(
          decoration: decoration,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: instrumentHeight,
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: heroHeight,
                      child: ExcludeSemantics(
                        child: IgnorePointer(
                          child: RepaintBoundary(child: instrument),
                        ),
                      ),
                    ),
                    SizedBox(height: footerHeight, child: instrumentFooter),
                  ],
                ),
              ),
              CustomScrollView(
                key: bodyScrollKey,
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: instrumentHeight,
                      child: inputBuilder(
                        context,
                        heroHeight,
                        instrumentHeight,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(key: lowerSheetKey, child: body),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class InstrumentEventSheetTopBar extends StatelessWidget {
  const InstrumentEventSheetTopBar({
    super.key,
    required this.semanticLabel,
    required this.handleColor,
    this.onVerticalDragUpdate,
    this.trailing,
  });

  final String semanticLabel;
  final Color handleColor;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            left: 52,
            right: 52,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              key: const ValueKey<String>('follow-sky-sheet-resize-handle'),
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: onVerticalDragUpdate,
              child: Center(
                child: Semantics(
                  label: semanticLabel,
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}
