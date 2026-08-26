import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:mobile/widgets/keyboard_viewport_metrics.dart';

void main() {
  group('KeyboardViewportMetrics', () {
    test('uses the native keyboard inset against a stable view height', () {
      final metrics = KeyboardViewportMetrics.resolve(
        media: const MediaQueryData(
          size: Size(390, 844),
          viewInsets: EdgeInsets.only(bottom: 344),
        ),
      );

      expect(metrics.visibleTop, 0);
      expect(metrics.visibleBottom, 500);
      expect(metrics.layoutViewInsetBottom, 344);
      expect(metrics.systemKeyboardVisible, isTrue);
    });

    test('uses visual coordinates when Flutter already shrank on web', () {
      final metrics = KeyboardViewportMetrics.resolve(
        media: const MediaQueryData(size: Size(390, 500)),
        webViewport: const (height: 500, layoutHeight: 844, offsetTop: 0),
      );

      expect(metrics.visibleTop, 0);
      expect(metrics.visibleBottom, 500);
      expect(metrics.layoutViewInsetBottom, 0);
      expect(metrics.systemKeyboardVisible, isTrue);
    });

    test('ignores layout-coordinate pan after Flutter already shrank', () {
      final metrics = KeyboardViewportMetrics.resolve(
        media: const MediaQueryData(size: Size(390, 524)),
        webViewport: const (height: 524, layoutHeight: 844, offsetTop: 120),
      );

      expect(metrics.visibleTop, 0);
      expect(metrics.visibleBottom, 524);
      expect(metrics.layoutViewInsetBottom, 0);
      expect(metrics.systemKeyboardVisible, isTrue);
    });

    test('detects maximum-pan web shrink from height, not viewport bottom', () {
      final metrics = KeyboardViewportMetrics.resolve(
        media: const MediaQueryData(size: Size(390, 524)),
        webViewport: const (height: 524, layoutHeight: 844, offsetTop: 320),
      );

      expect(metrics.visibleTop, 0);
      expect(metrics.visibleBottom, 524);
      expect(metrics.layoutViewInsetBottom, 0);
      expect(metrics.systemKeyboardVisible, isTrue);
    });

    test('uses layout coordinates while Flutter remains layout-sized', () {
      final metrics = KeyboardViewportMetrics.resolve(
        media: const MediaQueryData(size: Size(390, 844)),
        webViewport: const (height: 500, layoutHeight: 844, offsetTop: 0),
      );

      expect(metrics.visibleTop, 0);
      expect(metrics.visibleBottom, 500);
      expect(metrics.layoutViewInsetBottom, 344);
      expect(metrics.systemKeyboardVisible, isTrue);
    });

    test('subtracts browser pan from layout-sized bottom occlusion', () {
      final metrics = KeyboardViewportMetrics.resolve(
        media: const MediaQueryData(size: Size(390, 844)),
        webViewport: const (height: 500, layoutHeight: 844, offsetTop: 100),
      );

      expect(metrics.visibleTop, 100);
      expect(metrics.visibleBottom, 600);
      expect(metrics.layoutViewInsetBottom, 244);
      expect(metrics.systemKeyboardVisible, isTrue);
    });

    test('does not double-apply a panned transitional iOS web inset', () {
      final metrics = KeyboardViewportMetrics.resolve(
        media: const MediaQueryData(
          size: Size(390, 524),
          viewInsets: EdgeInsets.only(bottom: 320),
        ),
        webViewport: const (height: 524, layoutHeight: 844, offsetTop: 120),
      );

      expect(metrics.visibleTop, 0);
      expect(metrics.visibleBottom, 524);
      expect(metrics.layoutViewInsetBottom, 0);
      expect(metrics.systemKeyboardVisible, isTrue);
    });
  });

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

    testWidgets('ignores stale focus while a focused input is deactivated', (
      tester,
    ) async {
      var showInput = true;
      late StateSetter updateChild;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              KemeticKeyboardHost(child: child ?? const SizedBox.shrink()),
          home: StatefulBuilder(
            builder: (context, setState) {
              updateChild = setState;
              return Scaffold(
                body: showInput
                    ? const TextField(
                        key: ValueKey('deactivated-focused-input'),
                        autofocus: true,
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
        ),
      );
      await tester.pump();

      updateChild(() => showInput = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const ValueKey('deactivated-focused-input')),
        findsNothing,
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
      'opens quick add settled and waits for the user to focus the field',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(const _QuickAddSheetHarness());
        await tester.tap(find.byKey(const ValueKey('open-quick-add-sheet')));
        await tester.pumpAndSettle();

        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('quick-add-input')),
        );
        expect(field.focusNode?.hasFocus, isFalse);
        expect(find.byKey(const ValueKey('quick-add-input')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'keeps quick add input visible on first system keyboard inset',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final webViewport = ValueNotifier<WebKeyboardViewportSnapshot?>(null);
        addTearDown(webViewport.dispose);

        await tester.pumpWidget(
          _QuickAddSheetHarness(webViewport: webViewport),
        );
        await tester.tap(find.byKey(const ValueKey('open-quick-add-sheet')));
        await tester.pumpAndSettle();

        final field = find.byKey(const ValueKey('quick-add-input'));
        final scrollable = find
            .descendant(
              of: find.byKey(const ValueKey('quick-add-scroll')),
              matching: find.byType(Scrollable),
            )
            .first;
        final scrollState = tester.state<ScrollableState>(scrollable);

        void expectVisibleGeometry(String phase) {
          final fieldRect = tester.getRect(field);
          final textField = tester.widget<TextField>(field);
          final editable = tester.state<EditableTextState>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          );
          final caretRect = editable.renderEditable.getLocalRectForCaret(
            editable.textEditingValue.selection.extent,
          );
          final caretBottom = editable.renderEditable
              .localToGlobal(caretRect.bottomLeft)
              .dy;

          expect(fieldRect.top, greaterThanOrEqualTo(0), reason: phase);
          expect(fieldRect.bottom, lessThanOrEqualTo(500), reason: phase);
          expect(caretBottom, lessThanOrEqualTo(500), reason: phase);
          expect(
            textField.scrollPadding,
            keyboardManagedTextFieldScrollPadding,
            reason: phase,
          );
        }

        Future<void> openKeyboard() async {
          await tester.tap(field);
          await tester.pump();
          webViewport.value = const (
            height: 500,
            layoutHeight: 844,
            offsetTop: 0,
          );
          await tester.pumpAndSettle();
        }

        Future<void> closeKeyboard() async {
          webViewport.value = null;
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        }

        await openKeyboard();
        expectVisibleGeometry('quick add focused');

        await tester.enterText(field, 'Fri 3pm coffee with Amara');
        await tester.pump();
        expectVisibleGeometry('quick add typing');

        final controller = tester.widget<TextField>(field).controller!;
        controller.selection = const TextSelection.collapsed(offset: 4);
        await tester.pump();
        expectVisibleGeometry('quick add cursor moved');

        final openedOffsets = <double>[scrollState.position.pixels];
        final dismissedOffsets = <double>[];
        for (var cycle = 0; cycle < 3; cycle++) {
          await closeKeyboard();
          dismissedOffsets.add(scrollState.position.pixels);

          await openKeyboard();
          expectVisibleGeometry('quick add cycle $cycle');
          openedOffsets.add(scrollState.position.pixels);
        }

        for (final offset in openedOffsets.skip(1)) {
          expect(offset, closeTo(openedOffsets.last, 0.5));
        }
        for (final offset in dismissedOffsets.skip(1)) {
          expect(offset, closeTo(dismissedOffsets.last, 0.5));
        }
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

    testWidgets('keeps the system keyboard cursor above the keyboard inset', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _SystemKeyboardInsetHarness(controller: controller),
      );
      await tester.tap(find.byKey(const ValueKey('system-keyboard-input')));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      controller.value = const TextEditingValue(
        text: 'Visible cursor',
        selection: TextSelection.collapsed(offset: 14),
      );
      await tester.pumpAndSettle();

      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      final caretRect = editable.renderEditable.getLocalRectForCaret(
        controller.selection.extent,
      );
      final caretBottom = editable.renderEditable
          .localToGlobal(caretRect.bottomLeft)
          .dy;

      expect(caretBottom, lessThanOrEqualTo(544));
      expect(tester.takeException(), isNull);
    });

    testWidgets('typing does not animate the surrounding scroll position', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final controller = TextEditingController();
      final scrollController = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        _SystemKeyboardInsetHarness(
          controller: controller,
          scrollController: scrollController,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('system-keyboard-input')));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final focusedOffset = scrollController.offset;

      await tester.enterText(
        find.byKey(const ValueKey('system-keyboard-input')),
        'Typing should stay still',
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(scrollController.offset, closeTo(focusedOffset, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls expanding text fields above the keyboard inset', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final controller = TextEditingController();
      final scrollController = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        _ExpandingSystemKeyboardHarness(
          controller: controller,
          scrollController: scrollController,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('expanding-keyboard-input')));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      final text = List<String>.generate(
        40,
        (index) => 'Journal line ${index + 1}',
      ).join('\n');
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      await tester.pumpAndSettle();

      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      final caretRect = editable.renderEditable.getLocalRectForCaret(
        controller.selection.extent,
      );
      final caretBottom = editable.renderEditable
          .localToGlobal(caretRect.bottomLeft)
          .dy;

      expect(scrollController.offset, greaterThan(0));
      expect(caretBottom, lessThanOrEqualTo(544));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'recovers expanding text fields overscrolled away from the caret',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);

        final controller = TextEditingController();
        final scrollController = ScrollController();
        addTearDown(controller.dispose);
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          _ExpandingSystemKeyboardHarness(
            controller: controller,
            scrollController: scrollController,
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey('expanding-keyboard-input')),
        );
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();

        final text = List<String>.generate(
          40,
          (index) => 'Journal line ${index + 1}',
        ).join('\n');
        final firstSelectionOffset = text.indexOf('Journal line 10');
        controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: firstSelectionOffset),
        );
        await tester.pumpAndSettle();

        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        controller.selection = TextSelection.collapsed(
          offset: firstSelectionOffset + 'Journal'.length,
        );
        await tester.pumpAndSettle();

        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        final caretRect = editable.renderEditable.getLocalRectForCaret(
          controller.selection.extent,
        );
        final caretTop = editable.renderEditable
            .localToGlobal(caretRect.topLeft)
            .dy;
        final caretBottom = editable.renderEditable
            .localToGlobal(caretRect.bottomLeft)
            .dy;
        final editableTop = editable.renderEditable
            .localToGlobal(Offset.zero)
            .dy;

        expect(
          scrollController.offset,
          lessThan(scrollController.position.maxScrollExtent),
        );
        expect(caretTop, greaterThanOrEqualTo(editableTop + 8));
        expect(caretBottom, lessThanOrEqualTo(544));
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

    testWidgets('backspaces text from the custom keyboard', (tester) async {
      final controller = TextEditingController(text: 'maat');

      await tester.pumpWidget(_KeyboardHarness(controller: controller));
      await _openCustomKeyboard(tester);

      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('kemetic-action-backspace')));
      await tester.pumpAndSettle();

      expect(_editableFocusNode(tester).hasFocus, isTrue);
      expect(controller.text, 'maa');
      expect(controller.selection, const TextSelection.collapsed(offset: 3));
    });

    testWidgets('backspace deletes the current selection', (tester) async {
      final controller = TextEditingController(text: 'maat');

      await tester.pumpWidget(_KeyboardHarness(controller: controller));
      await _openCustomKeyboard(tester);

      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 4,
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('kemetic-action-backspace')));
      await tester.pumpAndSettle();

      expect(controller.text, 'm');
      expect(controller.selection, const TextSelection.collapsed(offset: 1));
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
  return find.descendant(
    of: find.byKey(const ValueKey('kemetic-toggle-hit-target')),
    matching: find.byType(FloatingActionButton),
  );
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

class _ExpandingSystemKeyboardHarness extends StatelessWidget {
  const _ExpandingSystemKeyboardHarness({
    required this.controller,
    required this.scrollController,
  });

  final TextEditingController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) =>
          KemeticKeyboardHost(child: child ?? const SizedBox.shrink()),
      home: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 280, 24, 0),
          child: TextField(
            key: const ValueKey('expanding-keyboard-input'),
            controller: controller,
            scrollController: scrollController,
            expands: true,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
          ),
        ),
      ),
    );
  }
}

class _SystemKeyboardInsetHarness extends StatelessWidget {
  const _SystemKeyboardInsetHarness({
    required this.controller,
    this.scrollController,
  });

  final TextEditingController controller;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      key: const ValueKey('system-keyboard-input'),
      controller: controller,
      scrollPadding: keyboardManagedTextFieldScrollPadding,
    );
    return MaterialApp(
      builder: (context, child) =>
          KemeticKeyboardHost(child: child ?? const SizedBox.shrink()),
      home: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 720),
                field,
                const SizedBox(height: 360),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAddSheetHarness extends StatelessWidget {
  const _QuickAddSheetHarness({this.webViewport});

  final ValueListenable<WebKeyboardViewportSnapshot?>? webViewport;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        final viewportListenable = webViewport;
        if (viewportListenable == null) {
          return KemeticKeyboardHost(child: child ?? const SizedBox.shrink());
        }
        return ValueListenableBuilder<WebKeyboardViewportSnapshot?>(
          valueListenable: viewportListenable,
          child: child ?? const SizedBox.shrink(),
          builder: (context, viewport, child) => KemeticKeyboardHost(
            viewportMetricsResolver: (media) => KeyboardViewportMetrics.resolve(
              media: media,
              webViewport: viewport,
            ),
            child: child!,
          ),
        );
      },
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
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _focusNode.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('quick-add-scroll'),
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
              TextField(
                key: const ValueKey('quick-add-input'),
                controller: _textCtrl,
                scrollPadding: keyboardManagedTextFieldScrollPadding,
                autofocus: false,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g., Fri 3pm-4pm coffee',
                ),
                minLines: 1,
                maxLines: 3,
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
