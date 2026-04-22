import 'dart:async';

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

    testWidgets('stays stable when mounted above the navigator overlay', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _KeyboardHarness(
          controller: TextEditingController(),
          hostInAppBuilder: true,
        ),
      );

      await _openCustomKeyboard(tester);
      await tester.longPress(find.byKey(const ValueKey('kemetic-action-left')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('kemetic-keyboard-panel')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'closes cleanly from the quick add modal sheet when returning to the system keyboard',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(const _QuickAddSheetHarness());
        await tester.tap(find.byKey(const ValueKey('open-quick-add-sheet')));
        await tester.pumpAndSettle();

        await _openCustomKeyboardOnField(
          tester,
          const ValueKey('quick-add-input'),
        );
        await tester.tap(find.text('ABC'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('kemetic-keyboard-panel')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('quick-add-input')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'dismisses cleanly from the quick add modal sheet when tapping outside',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(const _QuickAddSheetHarness());
        await tester.tap(find.byKey(const ValueKey('open-quick-add-sheet')));
        await tester.pumpAndSettle();

        await _openCustomKeyboardOnField(
          tester,
          const ValueKey('quick-add-input'),
        );
        await tester.tapAt(const Offset(12, 12));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('kemetic-keyboard-panel')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('open-quick-add-sheet')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('wraps header controls on narrow emulator widths', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _KeyboardHarness(
          controller: TextEditingController(),
          hostInAppBuilder: true,
        ),
      );

      await _openCustomKeyboard(tester);

      expect(find.text('ASCII'), findsOneWidget);
      expect(find.text('ABC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'keeps a bottom-anchored text field above the custom keyboard',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _KeyboardHarness(
            controller: TextEditingController(),
            hostInAppBuilder: true,
            bottomAnchoredField: true,
          ),
        );

        await _openCustomKeyboard(tester);

        final fieldRect = tester.getRect(
          find.byKey(const ValueKey('kemetic-input')),
        );
        final panelRect = tester.getRect(
          find.byKey(const ValueKey('kemetic-keyboard-panel')),
        );

        expect(fieldRect.bottom, lessThanOrEqualTo(panelRect.top));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'keeps focus on the text field while typing with the custom keyboard',
      (tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(_KeyboardHarness(controller: controller));
        await _openCustomKeyboard(tester);

        expect(_editableFocusNode(tester).hasFocus, isTrue);

        await _tapKeyboardKey(tester, 'ꜣ');

        expect(_editableFocusNode(tester).hasFocus, isTrue);
        expect(controller.selection, const TextSelection.collapsed(offset: 1));
      },
    );

    testWidgets('keeps focus on the text field when moving the cursor', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'maat');

      await tester.pumpWidget(_KeyboardHarness(controller: controller));
      await _openCustomKeyboard(tester);

      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('kemetic-action-left')));
      await tester.pumpAndSettle();

      expect(_editableFocusNode(tester).hasFocus, isTrue);
      expect(controller.selection, const TextSelection.collapsed(offset: 3));
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

    testWidgets('closes cleanly when returning to the system keyboard', (
      tester,
    ) async {
      await tester.pumpWidget(
        _KeyboardHarness(controller: TextEditingController()),
      );

      await _openCustomKeyboard(tester);
      await tester.tap(find.text('ABC'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('kemetic-keyboard-panel')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'dismisses the custom keyboard when tapping outside the field',
      (tester) async {
        await tester.pumpWidget(
          _KeyboardHarness(controller: TextEditingController()),
        );

        await _openCustomKeyboard(tester);
        await tester.tapAt(const Offset(12, 12));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('kemetic-keyboard-panel')),
          findsNothing,
        );
      },
    );

    testWidgets('dismisses the custom keyboard when the field loses focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        _KeyboardHarness(controller: TextEditingController()),
      );

      await _openCustomKeyboard(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('kemetic-keyboard-panel')),
        findsNothing,
      );
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

    testWidgets('unmounts cleanly while the custom keyboard is open', (
      tester,
    ) async {
      await tester.pumpWidget(
        _KeyboardHarness(controller: TextEditingController()),
      );

      await _openCustomKeyboard(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _openCustomKeyboard(WidgetTester tester) async {
  await _openCustomKeyboardOnField(tester, const ValueKey('kemetic-input'));
}

Future<void> _openCustomKeyboardOnField(
  WidgetTester tester,
  ValueKey<String> fieldKey,
) async {
  await tester.tap(find.byKey(fieldKey));
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

FocusNode _editableFocusNode(WidgetTester tester) {
  return tester.widget<EditableText>(find.byType(EditableText)).focusNode;
}

class _KeyboardHarness extends StatelessWidget {
  const _KeyboardHarness({
    required this.controller,
    this.onChanged,
    this.inputFormatters = const [],
    this.readOnly = false,
    this.autofocus = false,
    this.hostInAppBuilder = false,
    this.bottomAnchoredField = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter> inputFormatters;
  final bool readOnly;
  final bool autofocus;
  final bool hostInAppBuilder;
  final bool bottomAnchoredField;

  Widget _buildInputBody() {
    final input = TextField(
      key: const ValueKey('kemetic-input'),
      controller: controller,
      autofocus: autofocus,
      readOnly: readOnly,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
    );

    if (bottomAnchoredField) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(
              child: ColoredBox(
                key: ValueKey('outside-area'),
                color: Colors.transparent,
              ),
            ),
            const SizedBox(height: 24),
            input,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          input,
          const SizedBox(height: 24),
          const Expanded(
            child: ColoredBox(
              key: ValueKey('outside-area'),
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (hostInAppBuilder) {
      return MaterialApp(
        builder: (context, child) =>
            KemeticKeyboardHost(child: child ?? const SizedBox.shrink()),
        home: Scaffold(body: _buildInputBody()),
      );
    }

    return MaterialApp(
      home: Scaffold(body: KemeticKeyboardHost(child: _buildInputBody())),
    );
  }
}

class _QuickAddSheetHarness extends StatelessWidget {
  const _QuickAddSheetHarness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) =>
          KemeticKeyboardHost(child: child ?? const SizedBox.shrink()),
      home: Builder(
        builder: (modalContext) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('open-quick-add-sheet'),
              onPressed: () {
                showModalBottomSheet<void>(
                  context: modalContext,
                  isScrollControlled: true,
                  backgroundColor: Colors.black,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (_) => const _QuickAddSheetHarnessContent(),
                );
              },
              child: const Text('Open quick add'),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAddSheetHarnessContent extends StatefulWidget {
  const _QuickAddSheetHarnessContent();

  @override
  State<_QuickAddSheetHarnessContent> createState() =>
      _QuickAddSheetHarnessContentState();
}

class _QuickAddSheetHarnessContentState
    extends State<_QuickAddSheetHarnessContent> {
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _fieldKey = GlobalKey();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestInitialFocus());
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestInitialFocus() async {
    if (!mounted) return;
    _focusNode.requestFocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    final fieldContext = _fieldKey.currentContext;
    if (fieldContext == null || !fieldContext.mounted) return;
    await Scrollable.ensureVisible(
      fieldContext,
      alignment: 0.1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick add (natural language)',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              KeyedSubtree(
                key: _fieldKey,
                child: TextField(
                  key: const ValueKey('quick-add-input'),
                  controller: _textCtrl,
                  autofocus: false,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'e.g., Fri 3pm-4pm coffee',
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {});
                    },
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
