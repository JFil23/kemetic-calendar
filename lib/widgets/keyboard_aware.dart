import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'kemetic_keyboard.dart';

/// The one scroll-padding rule for every app text field.
///
/// [EditableText] already keeps its caret visible inside multiline fields. A
/// containing [KeyboardSafeViewport] owns keyboard geometry, so fields must
/// never add the keyboard inset again here.
const EdgeInsets keyboardManagedTextFieldScrollPadding = EdgeInsets.all(20);

const ValueKey<String> keyboardSafeViewportKey = ValueKey<String>(
  'keyboard_safe_viewport',
);

double keyboardInsetOf(BuildContext context) {
  final mediaInset = MediaQuery.viewInsetsOf(context).bottom;
  final scopeInset = KemeticKeyboardScope.maybeOf(context)?.keyboardInset ?? 0;
  return math.max(mediaInset, scopeInset);
}

double keyboardSafeAvailableHeightOf(
  BuildContext context, {
  double topClearance = 12,
}) {
  final media = MediaQuery.of(context);
  return math.max(
    0.0,
    media.size.height -
        keyboardInsetOf(context) -
        media.padding.top -
        topClearance,
  );
}

/// The single keyboard-avoidance model for sheets, dialogs, and overlays.
///
/// This follows the actual system/custom keyboard inset without an additional
/// tween. It also clamps content to the visible screen instead of preserving a
/// minimum height that can extend behind the keyboard after rotation.
class KeyboardSafeViewport extends StatelessWidget {
  const KeyboardSafeViewport({
    super.key,
    required this.child,
    this.maxHeightFactor = 1,
    this.closedHeightFactor,
    this.openHeightFactor,
    this.topClearance = 12,
    this.liftAboveKeyboard = true,
  }) : assert(maxHeightFactor > 0 && maxHeightFactor <= 1),
       assert(
         closedHeightFactor == null ||
             (closedHeightFactor > 0 && closedHeightFactor <= 1),
       ),
       assert(
         openHeightFactor == null ||
             (openHeightFactor > 0 && openHeightFactor <= 1),
       ),
       assert(topClearance >= 0);

  final Widget child;
  final double maxHeightFactor;
  final double? closedHeightFactor;
  final double? openHeightFactor;
  final double topClearance;
  final bool liftAboveKeyboard;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = keyboardInsetOf(context);
    final availableHeight = keyboardSafeAvailableHeightOf(
      context,
      topClearance: topClearance,
    );
    final maxHeight = math.min(
      media.size.height * maxHeightFactor,
      availableHeight,
    );
    final preferredHeightFactor = keyboardInset > 0
        ? (openHeightFactor ?? closedHeightFactor)
        : closedHeightFactor;
    final viewportChild = preferredHeightFactor == null
        ? child
        : SizedBox(
            height: media.size.height * preferredHeightFactor,
            child: child,
          );

    return KemeticKeyboardViewportScope(
      managesKeyboardGeometry: true,
      child: Padding(
        key: keyboardSafeViewportKey,
        padding: EdgeInsets.only(bottom: liftAboveKeyboard ? keyboardInset : 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: viewportChild,
        ),
      ),
    );
  }
}
