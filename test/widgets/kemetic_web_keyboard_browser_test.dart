@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:mobile/widgets/kemetic_web_keyboard_input_web.dart';
import 'package:web/web.dart' as web;

void main() {
  for (final modal in [false, true]) {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      testWidgets(
        'real Flutter ${modal ? 'sheet' : 'page'} input survives keyboard switching at $size',
        (tester) async {
          _useRealBrowserInput(tester);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          final controller = TextEditingController(text: 'Welcome to ḥꜣw');
          final focus = FocusNode();
          addTearDown(controller.dispose);
          addTearDown(focus.dispose);
          final field = Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: controller,
              focusNode: focus,
              maxLines: modal ? 3 : 1,
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              builder: (_, child) => KemeticKeyboardHost(child: child!),
              home: Builder(
                builder: (context) => Scaffold(
                  body: modal
                      ? Center(
                          child: TextButton(
                            onPressed: () => showEditableModalBottomSheet<void>(
                              context: context,
                              builder: (_) =>
                                  KeyboardAwareEditableSurface(child: field),
                            ),
                            child: const Text('Open editor'),
                          ),
                        )
                      : Align(alignment: Alignment.topCenter, child: field),
                ),
              ),
            ),
          );
          if (modal) {
            await tester.tap(find.text('Open editor'));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.byType(TextField));
          await _settleBrowserInput(tester);
          expect(focus.hasFocus, isTrue);
          final editor = web.document.activeElement!;
          expect(editor.tagName.toLowerCase(), modal ? 'textarea' : 'input');
          expect(editor.closest('flutter-view'), isNotNull);
          final nativeInputMode = editor.getAttribute('inputmode');
          final nativePolicy = editor.getAttribute('virtualkeyboardpolicy');
          controller.selection = const TextSelection(
            baseOffset: 3,
            extentOffset: 8,
          );
          await _settleBrowserInput(tester);
          final panel = find.byKey(const ValueKey('kemetic-keyboard-panel'));
          final toggle = find.byKey(
            const ValueKey('kemetic-toggle-hit-target'),
          );
          await tester.tap(toggle);
          await _settleBrowserInput(tester);
          expect(
            focus.hasFocus,
            isTrue,
            reason: 'Switching keyboards must not close the input connection.',
          );
          expect(panel, findsOneWidget);
          expect(controller.text, 'Welcome to ḥꜣw');
          expect(
            controller.selection,
            const TextSelection(baseOffset: 3, extentOffset: 8),
          );
          expect(web.document.activeElement, editor);
          expect(editor.isConnected, isTrue);
          expect(editor.getAttribute('inputmode'), 'none');
          for (var i = 0; i < 10; i++) {
            syncWebCustomKeyboardInputTarget();
          }
          await _settleBrowserInput(tester);
          expect(panel, findsOneWidget);
          expect(web.document.activeElement, editor);
          expect(
            controller.selection,
            const TextSelection(baseOffset: 3, extentOffset: 8),
          );
          await tester.tap(find.byKey(const ValueKey('kemetic-key-ꜣ')));
          await _settleBrowserInput(tester);
          expect(controller.text, 'Welꜣto ḥꜣw');
          expect(
            controller.selection,
            const TextSelection.collapsed(offset: 4),
          );
          await tester.tap(find.text('ABC'));
          await _settleBrowserInput(tester);
          expect(panel, findsNothing);
          expect(focus.hasFocus, isTrue);
          expect(editor.isConnected, isTrue);
          expect(web.document.activeElement, editor);
          expect(editor.getAttribute('inputmode'), nativeInputMode);
          expect(editor.getAttribute('virtualkeyboardpolicy'), nativePolicy);
          expect(controller.text, 'Welꜣto ḥꜣw');
          expect(
            controller.selection,
            const TextSelection.collapsed(offset: 4),
          );
          // A browser input event must still reach the same Flutter controller.
          const typed = 'Welꜣto ḥꜣw!';
          if (modal) {
            (editor as web.HTMLTextAreaElement)
              ..value = typed
              ..setSelectionRange(typed.length, typed.length);
          } else {
            (editor as web.HTMLInputElement)
              ..value = typed
              ..setSelectionRange(typed.length, typed.length);
          }
          editor.dispatchEvent(
            web.Event('input', web.EventInit(bubbles: true)),
          );
          await _settleBrowserInput(tester);
          expect(controller.text, typed);
          await tester.tap(toggle);
          await _settleBrowserInput(tester);
          expect(panel, findsOneWidget);
          // Genuine focus loss must still dismiss; the handoff must not mask it.
          (editor as web.HTMLElement).blur();
          await _settleBrowserInput(tester);
          expect(focus.hasFocus, isFalse);
          expect(panel, findsNothing);
          expect(controller.text, typed);
          await tester.tap(find.byType(TextField));
          await _settleBrowserInput(tester);
          await tester.tap(toggle);
          await _settleBrowserInput(tester);
          expect(panel, findsOneWidget);
          await tester.tapAt(modal ? const Offset(4, 4) : const Offset(4, 110));
          await _settleBrowserInput(tester);
          expect(panel, findsNothing);
          expect(focus.hasFocus, isFalse);
          expect(controller.text, typed);
          await tester.pumpWidget(const SizedBox.shrink());
          await _settleBrowserInput(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  test(
    'custom handoff refocuses once, retains selection and restores native input',
    () {
      final editor = web.HTMLTextAreaElement()..value = 'Welcome to ḥꜣw';
      editor.setAttribute('inputmode', 'text');
      web.document.body!.append(editor);
      var focuses = 0;
      var blurs = 0;
      final focusListener = ((web.Event _) => focuses++).toJS;
      final blurListener = ((web.Event _) => blurs++).toJS;
      editor.addEventListener('focus', focusListener);
      editor.addEventListener('blur', blurListener);
      try {
        editor.focus();
        editor.setSelectionRange(3, 8);
        activateWebCustomKeyboardInput();
        expect(editor.getAttribute('inputmode'), 'none');
        expect(web.document.activeElement, editor);
        expect(focuses, 2);
        expect(blurs, 1);
        expect(editor.selectionStart, 3);
        expect(editor.selectionEnd, 8);
        for (var i = 0; i < 10; i++) {
          syncWebCustomKeyboardInputTarget();
        }
        expect(
          focuses,
          2,
          reason:
              'ordinary focus/viewport notifications must not repeat the handoff',
        );
        expect(blurs, 1);
        deactivateWebCustomKeyboardInput(requestSystemKeyboard: true);
        expect(editor.getAttribute('inputmode'), 'text');
        expect(editor.getAttribute('virtualkeyboardpolicy'), isNull);
        expect(web.document.activeElement, editor);
        expect(editor.value, 'Welcome to ḥꜣw');
        expect(editor.selectionStart, 3);
        expect(editor.selectionEnd, 8);
        // A later activation must capture the editor's current native mode.
        editor.setAttribute('inputmode', 'email');
        activateWebCustomKeyboardInput();
        expect(editor.getAttribute('inputmode'), 'none');
        deactivateWebCustomKeyboardInput(requestSystemKeyboard: true);
        expect(editor.getAttribute('inputmode'), 'email');
      } finally {
        deactivateWebCustomKeyboardInput();
        editor.remove();
      }
    },
  );
}

Future<void> _settleBrowserInput(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void _useRealBrowserInput(WidgetTester tester) {
  // Both the binding mock and the engine's test bypass must be disabled to
  // exercise the same DOM/input-connection lifecycle as the deployed web app.
  final environment = ui_web.TestEnvironment.instance;
  ui_web.TestEnvironment.setUp(
    ui_web.TestEnvironment(
      ignorePlatformMessages: false,
      forceTestFonts: environment.forceTestFonts,
      disableFontFallbacks: environment.disableFontFallbacks,
      keepSemanticsDisabledOnUpdate: environment.keepSemanticsDisabledOnUpdate,
      defaultToTestUrlStrategy: environment.defaultToTestUrlStrategy,
    ),
  );
  addTearDown(() => ui_web.TestEnvironment.setUp(environment));
  tester.testTextInput.unregister();
  addTearDown(tester.testTextInput.register);
  // Browser focus may update during layout; keep test pointer highlighting
  // stable without changing focus or intercepting any input events.
  final highlightStrategy = FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  addTearDown(
    () => FocusManager.instance.highlightStrategy = highlightStrategy,
  );
}
