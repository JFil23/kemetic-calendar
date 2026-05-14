import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'kemetic_keyboard.dart';

/// Use inside sheets/dialogs/composers that already lift themselves above the
/// keyboard with viewInsets or [keyboardInsetOf].
const EdgeInsets keyboardManagedTextFieldScrollPadding = EdgeInsets.all(20);

double keyboardInsetOf(BuildContext context) {
  final mediaInset = MediaQuery.viewInsetsOf(context).bottom;
  final scopeInset = KemeticKeyboardScope.maybeOf(context)?.keyboardInset ?? 0;
  return math.max(mediaInset, scopeInset);
}

EdgeInsets addKeyboardBottomInset(BuildContext context, EdgeInsets padding) {
  final keyboardInset = keyboardInsetOf(context);
  return EdgeInsets.fromLTRB(
    padding.left,
    padding.top,
    padding.right,
    padding.bottom + keyboardInset,
  );
}

EdgeInsets keyboardAwareTextFieldScrollPadding(
  BuildContext context, {
  double clearance = 32,
}) {
  return EdgeInsets.only(bottom: keyboardInsetOf(context) + clearance);
}
