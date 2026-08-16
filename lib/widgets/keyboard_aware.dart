import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'kemetic_keyboard.dart';

/// Shared scroll padding for app text fields.
///
/// [EditableText] already keeps its caret visible inside multiline fields, so
/// fields must never add the keyboard inset again here. The containing page or
/// sheet owns keyboard geometry exactly once.
const EdgeInsets keyboardManagedTextFieldScrollPadding = EdgeInsets.all(20);

double keyboardInsetOf(BuildContext context) {
  final mediaInset = MediaQuery.viewInsetsOf(context).bottom;
  final scopeInset = KemeticKeyboardScope.maybeOf(context)?.keyboardInset ?? 0;
  return math.max(mediaInset, scopeInset);
}
