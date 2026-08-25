import 'package:flutter/material.dart';

/// Sky detail is pushed on the nested Flow Studio navigator.
class MaatFlowsListTransitionShell extends StatelessWidget {
  const MaatFlowsListTransitionShell({super.key, required this.child});

  final Widget child;

  static const Duration transformDuration = Duration(milliseconds: 500);
  static const Duration opacityDuration = Duration(milliseconds: 380);
  static const double outgoingShiftFraction = 0.16;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final secondary = route?.secondaryAnimation;
    if (secondary == null || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    final transformCurve = CurvedAnimation(
      parent: secondary,
      curve: const Cubic(0.22, 0.9, 0.3, 1),
      reverseCurve: const Cubic(0.22, 0.9, 0.3, 1),
    );
    final opacityCurve = CurvedAnimation(
      parent: secondary,
      curve: Interval(
        0,
        opacityDuration.inMilliseconds / transformDuration.inMilliseconds,
        curve: Curves.easeOut,
      ),
      reverseCurve: Curves.easeIn,
    );

    return AnimatedBuilder(
      animation: secondary,
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        return Opacity(
          opacity: 1 - opacityCurve.value,
          child: Transform.translate(
            offset: Offset(-width * outgoingShiftFraction * transformCurve.value, 0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Detail route for Follow Sky inside the nested Ma’at navigator.
class FollowSkyDetailPageRoute<T> extends PageRouteBuilder<T> {
  FollowSkyDetailPageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          transitionDuration: MaatFlowsListTransitionShell.transformDuration,
          reverseTransitionDuration:
              MaatFlowsListTransitionShell.transformDuration,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.disableAnimationsOf(context)) return child;
            final fade = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.08, 1, curve: Curves.easeOut),
            );
            return FadeTransition(opacity: fade, child: child);
          },
        );
}

@visibleForTesting
PageRoute<T> buildFollowSkyDetailRouteForTesting<T>(Widget child) {
  return FollowSkyDetailPageRoute<T>(builder: (_) => child);
}
