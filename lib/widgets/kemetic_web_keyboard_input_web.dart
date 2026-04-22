// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js_interop';
import 'dart:js_util' as js_util;

import 'package:web/web.dart' as web;

class _EditingElementState {
  const _EditingElementState({
    required this.inputMode,
    required this.virtualKeyboardPolicy,
  });

  final String? inputMode;
  final String? virtualKeyboardPolicy;
}

final Expando<_EditingElementState> _editingElementState =
    Expando<_EditingElementState>('kemeticWebKeyboardInputState');

web.Element? _trackedEditingElement;
JSFunction? _focusInListener;
bool _customKeyboardActive = false;

bool _hasProperty(JSAny target, String name) {
  return js_util.hasProperty(target, name);
}

bool _isEditableElement(web.Element? element) {
  if (element == null) return false;

  final tagName = element.tagName.toLowerCase();
  if (tagName == 'input' || tagName == 'textarea') {
    return true;
  }

  try {
    return js_util.getProperty<bool?>(element, 'isContentEditable') ?? false;
  } catch (_) {
    return false;
  }
}

web.Element? _currentEditingElement() {
  final active = web.document.activeElement;
  if (_isEditableElement(active)) {
    return active;
  }

  final host = web.document.querySelector('flt-text-editing-host');
  final candidate = host?.querySelector('input, textarea, [contenteditable]');
  return _isEditableElement(candidate) ? candidate : null;
}

void _restoreAttribute(web.Element element, String name, String? value) {
  if (value == null) {
    element.removeAttribute(name);
  } else {
    element.setAttribute(name, value);
  }
}

void _focusElement(web.Element element) {
  try {
    js_util.callMethod<void>(element, 'focus', <Object?>[
      js_util.jsify(<String, Object?>{'preventScroll': true}),
    ]);
  } catch (_) {
    try {
      js_util.callMethod<void>(element, 'focus', const <Object?>[]);
    } catch (_) {}
  }
}

void _blurElement(web.Element element) {
  try {
    js_util.callMethod<void>(element, 'blur', const <Object?>[]);
  } catch (_) {}
}

void _hideBrowserVirtualKeyboard() {
  try {
    final navigator = web.window.navigator;
    if (!_hasProperty(navigator, 'virtualKeyboard')) {
      return;
    }
    final virtualKeyboard = js_util.getProperty<JSAny?>(
      navigator,
      'virtualKeyboard',
    );
    if (virtualKeyboard == null) {
      return;
    }
    js_util.setProperty(virtualKeyboard, 'overlaysContent', true);
    if (_hasProperty(virtualKeyboard, 'hide')) {
      js_util.callMethod<void>(virtualKeyboard, 'hide', const <Object?>[]);
    }
  } catch (_) {}
}

void _saveAndApplyKeyboardSuppression(web.Element element) {
  if (_editingElementState[element] == null) {
    _editingElementState[element] = _EditingElementState(
      inputMode: element.getAttribute('inputmode'),
      virtualKeyboardPolicy: element.getAttribute('virtualkeyboardpolicy'),
    );
  }

  element.setAttribute('inputmode', 'none');
  element.setAttribute('virtualkeyboardpolicy', 'manual');

  try {
    js_util.setProperty(element, 'inputMode', 'none');
  } catch (_) {}

  try {
    js_util.setProperty(element, 'virtualKeyboardPolicy', 'manual');
  } catch (_) {}
}

void _restoreKeyboardBehavior(web.Element element) {
  final saved = _editingElementState[element];
  if (saved == null) return;

  _restoreAttribute(element, 'inputmode', saved.inputMode);
  _restoreAttribute(
    element,
    'virtualkeyboardpolicy',
    saved.virtualKeyboardPolicy,
  );

  try {
    js_util.setProperty(element, 'inputMode', saved.inputMode ?? '');
  } catch (_) {}

  try {
    js_util.setProperty(
      element,
      'virtualKeyboardPolicy',
      saved.virtualKeyboardPolicy ?? 'auto',
    );
  } catch (_) {}
}

void _ensureFocusInListener() {
  if (_focusInListener != null) {
    return;
  }

  _focusInListener = ((web.Event _) {
    syncWebCustomKeyboardInputTarget();
  }).toJS;
  web.document.addEventListener('focusin', _focusInListener);
}

void _removeFocusInListener() {
  if (_focusInListener == null) {
    return;
  }
  web.document.removeEventListener('focusin', _focusInListener);
  _focusInListener = null;
}

void activateWebCustomKeyboardInput() {
  _customKeyboardActive = true;
  _ensureFocusInListener();
  syncWebCustomKeyboardInputTarget();
}

void syncWebCustomKeyboardInputTarget() {
  if (!_customKeyboardActive) {
    return;
  }

  final editingElement = _currentEditingElement();
  if (editingElement == null) {
    return;
  }

  if (!identical(_trackedEditingElement, editingElement)) {
    if (_trackedEditingElement != null) {
      _restoreKeyboardBehavior(_trackedEditingElement!);
    }
    _trackedEditingElement = editingElement;
  }

  _saveAndApplyKeyboardSuppression(editingElement);
  _hideBrowserVirtualKeyboard();
  _focusElement(editingElement);
}

void deactivateWebCustomKeyboardInput({bool requestSystemKeyboard = false}) {
  _customKeyboardActive = false;
  _removeFocusInListener();

  final editingElement = _trackedEditingElement ?? _currentEditingElement();
  if (editingElement != null) {
    _restoreKeyboardBehavior(editingElement);
    if (requestSystemKeyboard) {
      _blurElement(editingElement);
      _focusElement(editingElement);
    }
  }

  _trackedEditingElement = null;
}
