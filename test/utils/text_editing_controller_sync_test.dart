import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/text_editing_controller_sync.dart';

void main() {
  group('syncTextEditingControllerText', () {
    test('does not mutate active composing text', () {
      final controller = TextEditingController();
      controller.value = const TextEditingValue(
        text: 'typing',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 1, end: 6),
      );

      final synced = syncTextEditingControllerText(controller, 'remote');

      expect(synced, isFalse);
      expect(controller.text, 'typing');
      expect(controller.value.composing, const TextRange(start: 1, end: 6));
    });

    test('updates text when not composing and clamps selection', () {
      final controller = TextEditingController(text: 'old text');
      controller.selection = const TextSelection.collapsed(offset: 8);

      final synced = syncTextEditingControllerText(controller, 'new');

      expect(synced, isTrue);
      expect(controller.text, 'new');
      expect(controller.selection.extentOffset, 3);
      expect(controller.value.composing, TextRange.empty);
    });

    test('treats matching text as already synced', () {
      final controller = TextEditingController(text: 'same');
      controller.value = const TextEditingValue(
        text: 'same',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 3),
      );

      final synced = syncTextEditingControllerText(controller, 'same');

      expect(synced, isTrue);
      expect(controller.value.composing, const TextRange(start: 1, end: 3));
    });
  });
}
