@TestOn('browser')
library;

import 'dart:js_interop';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/kemetic_web_keyboard_input_web.dart';
import 'package:web/web.dart' as web;

void main() {
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
