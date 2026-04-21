import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';

void main() {
  group('KemeticKeyboardHost', () {
    testWidgets('inserts text through the normal EditableText pipeline', (
      tester,
    ) async {
      final controller = TextEditingController();
      final changes = <String>[];

      await tester.pumpWidget(
        _KeyboardHarness(controller: controller, onChanged: changes.add),
      );

      await _openCustomKeyboard(tester);
      await _tapKeyboardKey(tester, 'ꜣ');

      expect(controller.text, 'ꜣ');
      expect(controller.selection, const TextSelection.collapsed(offset: 1));
      expect(changes, ['ꜣ']);
    });

    testWidgets('applies input formatters to custom keyboard edits', (
      tester,
    ) async {
      final controller = TextEditingController();
      final formatter = TextInputFormatter.withFunction((oldValue, newValue) {
        final normalized = newValue.text.replaceAll('ꜣ', 'A');
        return newValue.copyWith(
          text: normalized,
          selection: TextSelection.collapsed(offset: normalized.length),
          composing: TextRange.empty,
        );
      });

      await tester.pumpWidget(
        _KeyboardHarness(controller: controller, inputFormatters: [formatter]),
      );

      await _openCustomKeyboard(tester);
      await _tapKeyboardKey(tester, 'ꜣ');

      expect(controller.text, 'A');
      expect(controller.selection, const TextSelection.collapsed(offset: 1));
    });

    testWidgets('replaces the current selection and keeps the cursor stable', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'maat');

      await tester.pumpWidget(_KeyboardHarness(controller: controller));
      await tester.tap(find.byKey(const ValueKey('kemetic-input')));
      await tester.pumpAndSettle();

      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 4,
      );
      await tester.pump();

      await _pressToggle(tester);
      await tester.pumpAndSettle();
      await _tapKeyboardKey(tester, 'ḏ');

      expect(controller.text, 'mḏ');
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
    });

    testWidgets(
      'keeps the cursor offset aligned after scholarly normalization',
      (tester) async {
        final controller = TextEditingController(text: 'sh');

        await tester.pumpWidget(_KeyboardHarness(controller: controller));
        await tester.tap(find.byKey(const ValueKey('kemetic-input')));
        await tester.pumpAndSettle();

        controller.selection = const TextSelection.collapsed(offset: 2);
        await tester.pump();

        await _pressToggle(tester);
        await tester.pumpAndSettle();
        await _tapKeyboardKey(tester, 'ꜣ');

        expect(controller.text, 'šꜣ');
        expect(controller.selection, const TextSelection.collapsed(offset: 2));
      },
    );

    testWidgets('does not offer the custom keyboard for read only fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        _KeyboardHarness(
          controller: TextEditingController(text: 'immutable'),
          readOnly: true,
          autofocus: true,
        ),
      );
      await tester.pumpAndSettle();

      final opacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('kemetic-toggle-opacity')),
      );
      final ignorePointer = tester.widget<IgnorePointer>(
        find.byKey(const ValueKey('kemetic-toggle-ignore-pointer')),
      );

      expect(opacity.opacity, 0);
      expect(ignorePointer.ignoring, isTrue);
      expect(
        find.byKey(const ValueKey('kemetic-keyboard-panel')),
        findsNothing,
      );
    });

    testWidgets('moves the cursor left and right from the custom keyboard', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'maat');

      await tester.pumpWidget(_KeyboardHarness(controller: controller));
      await _openCustomKeyboard(tester);

      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('kemetic-action-left')));
      await tester.pumpAndSettle();
      expect(controller.selection, const TextSelection.collapsed(offset: 3));

      await tester.tap(find.byKey(const ValueKey('kemetic-action-right')));
      await tester.pumpAndSettle();
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
    });

    testWidgets('moves the cursor to the start and end of the field', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'maat');

      await tester.pumpWidget(_KeyboardHarness(controller: controller));
      await _openCustomKeyboard(tester);

      controller.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('kemetic-action-start')));
      await tester.pumpAndSettle();
      expect(controller.selection, const TextSelection.collapsed(offset: 0));

      await tester.tap(find.byKey(const ValueKey('kemetic-action-end')));
      await tester.pumpAndSettle();
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
    });

    testWidgets('collapses expanded selections when navigating', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'maat');

      await tester.pumpWidget(_KeyboardHarness(controller: controller));
      await _openCustomKeyboard(tester);

      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 4,
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('kemetic-action-left')));
      await tester.pumpAndSettle();
      expect(controller.selection, const TextSelection.collapsed(offset: 1));

      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 4,
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('kemetic-action-right')));
      await tester.pumpAndSettle();
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
    });
  });
}

Future<void> _openCustomKeyboard(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('kemetic-input')));
  await tester.pumpAndSettle();
  await _pressToggle(tester);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('kemetic-keyboard-panel')), findsOneWidget);
}

Future<void> _tapKeyboardKey(WidgetTester tester, String symbol) async {
  final keyFinder = find.byKey(ValueKey('kemetic-key-$symbol'));
  await tester.ensureVisible(keyFinder);
  await tester.tap(keyFinder);
  await tester.pumpAndSettle();
}

Finder _toggleFinder() {
  return find.widgetWithText(FloatingActionButton, 'Medu Neter');
}

Future<void> _pressToggle(WidgetTester tester) async {
  final toggle = tester.widget<FloatingActionButton>(_toggleFinder());
  toggle.onPressed?.call();
}

class _KeyboardHarness extends StatelessWidget {
  const _KeyboardHarness({
    required this.controller,
    this.onChanged,
    this.inputFormatters = const [],
    this.readOnly = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter> inputFormatters;
  final bool readOnly;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: KemeticKeyboardHost(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: TextField(
              key: const ValueKey('kemetic-input'),
              controller: controller,
              autofocus: autofocus,
              readOnly: readOnly,
              onChanged: onChanged,
              inputFormatters: inputFormatters,
            ),
          ),
        ),
      ),
    );
  }
}
