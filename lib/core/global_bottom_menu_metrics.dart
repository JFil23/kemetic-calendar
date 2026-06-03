import 'package:flutter/widgets.dart';

const double kGlobalBottomMenuBaseHeight = 50;
const double kGlobalBottomMenuLandscapeBaseHeight = 25;
const double kGlobalBottomMenuTabletShortestSide = 600;

bool _usesTabletLandscapeBottomMenuMetrics(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return MediaQuery.orientationOf(context) == Orientation.landscape &&
      size.shortestSide >= kGlobalBottomMenuTabletShortestSide;
}

double globalBottomMenuBaseHeight(BuildContext context) {
  if (MediaQuery.orientationOf(context) != Orientation.landscape) {
    return kGlobalBottomMenuBaseHeight;
  }
  return _usesTabletLandscapeBottomMenuMetrics(context)
      ? kGlobalBottomMenuBaseHeight
      : kGlobalBottomMenuLandscapeBaseHeight;
}

double globalBottomMenuHeight(BuildContext context) {
  return globalBottomMenuBaseHeight(context) +
      MediaQuery.paddingOf(context).bottom;
}

class AppBottomInsets {
  const AppBottomInsets._();

  static const double pageGap = 16;

  static double contentBottomPadding(
    BuildContext context, {
    double extraSpacing = pageGap,
  }) {
    return globalBottomMenuHeight(context) + extraSpacing;
  }

  static double scrollBottomPadding(BuildContext context, double basePadding) {
    return contentBottomPadding(context, extraSpacing: basePadding);
  }
}

double bottomPaddingAboveGlobalMenu(BuildContext context, double basePadding) {
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
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final shouldApply =
        applyBottomNavInset && !(disableWhenKeyboardVisible && keyboardVisible);
    final bottomPadding = shouldApply
        ? AppBottomInsets.contentBottomPadding(
            context,
            extraSpacing: extraSpacing,
          )
        : 0.0;

    final content = MediaQuery.removePadding(
      context: context,
      removeBottom: shouldApply,
      child: child,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: content,
    );
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
