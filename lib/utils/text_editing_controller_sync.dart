import 'package:flutter/widgets.dart';

bool textControllerHasActiveComposing(TextEditingController controller) {
  final composing = controller.value.composing;
  return composing.isValid && !composing.isCollapsed;
}

bool syncTextEditingControllerText(
  TextEditingController controller,
  String text, {
  bool deferWhileComposing = true,
}) {
  if (controller.text == text) return true;
  if (deferWhileComposing && textControllerHasActiveComposing(controller)) {
    return false;
  }

  final selection = controller.selection;
  final nextSelection = selection.isValid
      ? TextSelection.collapsed(
          offset: selection.extentOffset.clamp(0, text.length).toInt(),
          affinity: selection.affinity,
        )
      : TextSelection.collapsed(offset: text.length);
  controller.value = TextEditingValue(text: text, selection: nextSelection);
  return true;
}
