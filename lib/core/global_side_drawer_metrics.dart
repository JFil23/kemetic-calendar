import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const double kGlobalMenuBubbleSize = 56;
const double kGlobalMenuBubbleMargin = 16;
const double kGlobalSideDrawerTabletShortestSide = 600;

double globalMenuBubbleLeft(BuildContext context) {
  return MediaQuery.paddingOf(context).left + kGlobalMenuBubbleMargin;
}

double globalMenuBubbleBottom(BuildContext context) {
  return MediaQuery.paddingOf(context).bottom + kGlobalMenuBubbleMargin;
}

double globalMenuBubbleContentBottomPadding(
  BuildContext context, {
  double extraSpacing = 16,
}) {
  return globalMenuBubbleBottom(context) + kGlobalMenuBubbleSize + extraSpacing;
}

double globalSideDrawerWidth(BuildContext context) {
  final media = MediaQuery.of(context);
  final safeWidth = media.size.width - media.padding.left - media.padding.right;
  final isTablet =
      media.size.shortestSide >= kGlobalSideDrawerTabletShortestSide;
  final isLandscape = media.orientation == Orientation.landscape;

  final target = switch ((isTablet, isLandscape)) {
    (false, false) => math.min(304.0, safeWidth * 0.82),
    (false, true) => math.min(320.0, safeWidth * 0.46),
    (true, false) => math.min(400.0, math.max(360.0, safeWidth * 0.44)),
    (true, true) => math.min(448.0, math.max(400.0, safeWidth * 0.33)),
  };

  final maxPartialWidth = math.max(0.0, safeWidth - 48.0);
  return target.clamp(0.0, maxPartialWidth).toDouble();
}
