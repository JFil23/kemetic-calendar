import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool _isTouchFirstPlatform(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return true;
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return false;
  }
}

bool shouldUseExpandedTouchTargets({
  required MediaQueryData mediaQuery,
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
}) {
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  return _isTouchFirstPlatform(resolvedPlatform);
}

bool useExpandedTouchTargets(BuildContext context) {
  return shouldUseExpandedTouchTargets(mediaQuery: MediaQuery.of(context));
}

bool shouldEnableGlobalScaleGestures({
  required MediaQueryData mediaQuery,
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
}) {
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  return !_isTouchFirstPlatform(resolvedPlatform);
}

bool useGlobalScaleGestures(BuildContext context) {
  return shouldEnableGlobalScaleGestures(mediaQuery: MediaQuery.of(context));
}

double expandedTouchTargetMinDimension(
  BuildContext context, {
  double fallback = 0,
  double minSize = kMinInteractiveDimension,
}) {
  return useExpandedTouchTargets(context) ? minSize : fallback;
}

double edgeSwipeGestureWidth(
  BuildContext context, {
  double touchWidth = 18,
  double minWidth = 28,
  double maxWidth = 56,
  double viewportFraction = 0.06,
}) {
  if (useExpandedTouchTargets(context)) {
    return touchWidth;
  }

  final viewportWidth = MediaQuery.of(context).size.width;
  return (viewportWidth * viewportFraction)
      .clamp(minWidth, maxWidth)
      .toDouble();
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

BoxConstraints minimumTouchTargetConstraints(
  BuildContext context, {
  double minSize = kMinInteractiveDimension,
  BoxConstraints fallback = const BoxConstraints(),
}) {
  if (!useExpandedTouchTargets(context)) {
    return fallback;
  }

  return BoxConstraints(minWidth: minSize, minHeight: minSize);
}

Widget withMinimumTouchTarget(
  BuildContext context,
  Widget child, {
  double minSize = kMinInteractiveDimension,
  Alignment alignment = Alignment.center,
  BoxConstraints fallback = const BoxConstraints(),
}) {
  return ConstrainedBox(
    constraints: minimumTouchTargetConstraints(
      context,
      minSize: minSize,
      fallback: fallback,
    ),
    child: Align(alignment: alignment, child: child),
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
