import 'package:flutter/widgets.dart';

import 'global_side_drawer_metrics.dart';

class AppBottomInsets {
  const AppBottomInsets._();

  static const double pageGap = 16;

  static double contentBottomPadding(
    BuildContext context, {
    double extraSpacing = pageGap,
  }) {
    return globalMenuBubbleContentBottomPadding(
      context,
      extraSpacing: extraSpacing,
    );
  }

  static double scrollBottomPadding(BuildContext context, double basePadding) {
    return contentBottomPadding(context, extraSpacing: basePadding);
  }
}

double bottomPaddingAboveGlobalChrome(
  BuildContext context,
  double basePadding,
) {
  return AppBottomInsets.scrollBottomPadding(context, basePadding);
}

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.child,
    this.applyBottomNavInset = true,
    this.extraSpacing = AppBottomInsets.pageGap,
    this.disableWhenKeyboardVisible = true,
  });

  final Widget child;
  final bool applyBottomNavInset;
  final double extraSpacing;
  final bool disableWhenKeyboardVisible;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class AppScrollPage extends StatelessWidget {
  const AppScrollPage({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.applyBottomNavInset = true,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final bool applyBottomNavInset;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = applyBottomNavInset
        ? AppBottomInsets.contentBottomPadding(context)
        : 0.0;

    return SingleChildScrollView(
      padding: padding.copyWith(bottom: padding.bottom + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
