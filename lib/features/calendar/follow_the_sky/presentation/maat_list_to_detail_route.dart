import 'dart:async';

import 'package:flutter/material.dart';

typedef MaatFlowDetailRevealer<T> =
    Future<T?> Function(WidgetBuilder detailBuilder);

typedef MaatFlowsListForegroundBuilder<T> =
    Widget Function(
      BuildContext context,
      MaatFlowDetailRevealer<T> revealDetail,
    );

/// Owns the Ma’at list-to-detail reveal as one layered presentation.
///
/// The selected detail is stationary underneath. Only the foreground list
/// translates and fades, matching the V11 HTML interaction in both directions.
class MaatFlowsListDetailReveal<T> extends StatefulWidget {
  const MaatFlowsListDetailReveal({
    super.key,
    required this.foregroundBuilder,
    this.initialDetailBuilder,
    this.onInitialDetailDismissed,
  });

  static const Duration transformDuration = Duration(milliseconds: 500);
  static const Duration opacityDuration = Duration(milliseconds: 380);
  static const double outgoingShiftFraction = 0.16;
  static const Cubic transformCurve = Cubic(0.22, 0.9, 0.3, 1);

  @visibleForTesting
  static const Key foregroundTransformKey = ValueKey<String>(
    'maat-flows-list-foreground-transform',
  );

  @visibleForTesting
  static const Key foregroundOpacityKey = ValueKey<String>(
    'maat-flows-list-foreground-opacity',
  );

  @visibleForTesting
  static const Key detailSurfaceKey = ValueKey<String>(
    'maat-flows-stationary-detail-surface',
  );

  final MaatFlowsListForegroundBuilder<T> foregroundBuilder;
  final WidgetBuilder? initialDetailBuilder;
  final ValueChanged<T?>? onInitialDetailDismissed;

  @override
  State<MaatFlowsListDetailReveal<T>> createState() =>
      _MaatFlowsListDetailRevealState<T>();
}

class _MaatFlowsListDetailRevealState<T>
    extends State<MaatFlowsListDetailReveal<T>>
    with TickerProviderStateMixin {
  late final AnimationController _transformController;
  late final AnimationController _opacityController;
  late final Listenable _animation;
  late final Animation<double> _transformProgress;
  late final Animation<double> _opacityProgress;
  WidgetBuilder? _detailBuilder;
  Completer<T?>? _detailResult;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _detailBuilder = widget.initialDetailBuilder;
    final initialValue = _detailBuilder == null ? 0.0 : 1.0;
    _transformController = AnimationController(
      vsync: this,
      duration: MaatFlowsListDetailReveal.transformDuration,
      reverseDuration: MaatFlowsListDetailReveal.transformDuration,
      value: initialValue,
    );
    _opacityController = AnimationController(
      vsync: this,
      duration: MaatFlowsListDetailReveal.opacityDuration,
      reverseDuration: MaatFlowsListDetailReveal.opacityDuration,
      value: initialValue,
    );
    _transformProgress = CurvedAnimation(
      parent: _transformController,
      curve: MaatFlowsListDetailReveal.transformCurve,
      reverseCurve: MaatFlowsListDetailReveal.transformCurve.flipped,
    );
    _opacityProgress = CurvedAnimation(
      parent: _opacityController,
      curve: Curves.ease,
      reverseCurve: Curves.ease.flipped,
    );
    _animation = Listenable.merge([_transformController, _opacityController]);
  }

  @override
  void dispose() {
    if (!(_detailResult?.isCompleted ?? true)) {
      _detailResult!.complete(null);
    }
    _transformController.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  Future<T?> _revealDetail(WidgetBuilder detailBuilder) {
    final activeResult = _detailResult;
    if (_detailBuilder != null && activeResult != null) {
      return activeResult.future;
    }
    if (_detailBuilder != null) {
      return Future<T?>.value(null);
    }

    final result = Completer<T?>();
    setState(() {
      _detailBuilder = detailBuilder;
      _detailResult = result;
    });
    unawaited(_transformController.forward());
    unawaited(_opacityController.forward());
    return result.future;
  }

  Future<void> _dismissDetail(T? result) async {
    if (_detailBuilder == null || _dismissing) return;
    _dismissing = true;
    await Future.wait<void>([
      _transformController.reverse(),
      _opacityController.reverse(),
    ]);
    if (!mounted) return;

    final detailResult = _detailResult;
    final dismissedInitialDetail = detailResult == null;
    setState(() {
      _detailBuilder = null;
      _detailResult = null;
      _dismissing = false;
    });
    if (dismissedInitialDetail) {
      widget.onInitialDetailDismissed?.call(result);
    } else if (!detailResult.isCompleted) {
      detailResult.complete(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.foregroundBuilder(context, _revealDetail);
    final detailBuilder = _detailBuilder;

    return PopScope<T>(
      canPop: detailBuilder == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _detailBuilder == null) return;
        unawaited(_dismissDetail(result));
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (detailBuilder != null)
            KeyedSubtree(
              key: MaatFlowsListDetailReveal.detailSurfaceKey,
              child: Builder(builder: detailBuilder),
            ),
          AnimatedBuilder(
            animation: _animation,
            child: foreground,
            builder: (context, child) {
              final animationsDisabled = MediaQuery.disableAnimationsOf(
                context,
              );
              final transformProgress = animationsDisabled
                  ? (_transformController.value == 0 ? 0.0 : 1.0)
                  : _transformProgress.value;
              final opacityProgress = animationsDisabled
                  ? (_opacityController.value == 0 ? 0.0 : 1.0)
                  : _opacityProgress.value;
              final width = MediaQuery.sizeOf(context).width;
              final hidden = opacityProgress > 0;
              return ExcludeSemantics(
                excluding: hidden,
                child: IgnorePointer(
                  ignoring: hidden,
                  child: Opacity(
                    key: MaatFlowsListDetailReveal.foregroundOpacityKey,
                    opacity: 1 - opacityProgress,
                    child: Transform.translate(
                      key: MaatFlowsListDetailReveal.foregroundTransformKey,
                      offset: Offset(
                        -width *
                            MaatFlowsListDetailReveal.outgoingShiftFraction *
                            transformProgress,
                        0,
                      ),
                      child: child,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
