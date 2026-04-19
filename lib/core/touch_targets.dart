import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double _tabletBreakpoint = 600;

bool shouldUseExpandedTouchTargets({
  required MediaQueryData mediaQuery,
  bool isWeb = kIsWeb,
}) {
  return isWeb && mediaQuery.size.shortestSide >= _tabletBreakpoint;
}

bool useExpandedTouchTargets(BuildContext context) {
  return shouldUseExpandedTouchTargets(mediaQuery: MediaQuery.of(context));
}

ButtonStyle withExpandedTouchTargets(
  BuildContext context,
  ButtonStyle style, {
  Size minimumSize = const Size(
    kMinInteractiveDimension,
    kMinInteractiveDimension,
  ),
}) {
  if (!useExpandedTouchTargets(context)) {
    return style;
  }

  return style.copyWith(
    minimumSize: WidgetStatePropertyAll<Size>(minimumSize),
    tapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );
}

BoxConstraints expandedIconButtonConstraints(
  BuildContext context, {
  double minSize = kMinInteractiveDimension,
  BoxConstraints fallback = const BoxConstraints(),
}) {
  if (!useExpandedTouchTargets(context)) {
    return fallback;
  }

  return BoxConstraints(minWidth: minSize, minHeight: minSize);
}

EdgeInsetsGeometry expandedIconButtonPadding(
  BuildContext context, {
  double iconSize = 24,
  double minSize = kMinInteractiveDimension,
  EdgeInsetsGeometry fallback = EdgeInsets.zero,
}) {
  if (!useExpandedTouchTargets(context)) {
    return fallback;
  }

  final inset = ((minSize - iconSize) / 2).clamp(0.0, minSize / 2).toDouble();
  return EdgeInsets.all(inset);
}

MaterialTapTargetSize expandedTapTargetSize(
  BuildContext context, {
  MaterialTapTargetSize fallback = MaterialTapTargetSize.shrinkWrap,
}) {
  return useExpandedTouchTargets(context)
      ? MaterialTapTargetSize.padded
      : fallback;
}

VisualDensity expandedVisualDensity(
  BuildContext context, {
  VisualDensity fallback = VisualDensity.compact,
}) {
  return useExpandedTouchTargets(context) ? VisualDensity.standard : fallback;
}
