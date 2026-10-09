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
bool _syncingTarget = false;

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

void _reenterEditingElement(web.Element element) {
  // Match Flutter's safe focus transfer: a bare blur has no relatedTarget,
  // so the web engine closes the input connection and unfocuses EditableText.
  // Keep focus inside the owning view while Safari re-applies inputmode.
  final view = element.closest('flutter-view');
  if (view != null) {
    _focusElement(view);
  } else {
    try {
      js_util.callMethod<void>(element, 'blur', const <Object?>[]);
    } catch (_) {}
  }
  _focusElement(element);
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
  _restoreAttribute(element, 'inputmode', saved.inputMode);
  _restoreAttribute(
    element,
    'virtualkeyboardpolicy',
    saved.virtualKeyboardPolicy,
  );
  _editingElementState[element] = null;
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
  if (!_customKeyboardActive || _syncingTarget) return;
  final editingElement = _currentEditingElement();
  if (editingElement == null) return;

  _syncingTarget = true;
  try {
    final changedTarget = !identical(_trackedEditingElement, editingElement);
    if (changedTarget) {
      if (_trackedEditingElement != null) {
        _restoreKeyboardBehavior(_trackedEditingElement!);
      }
      _trackedEditingElement = editingElement;
    }
    _saveAndApplyKeyboardSuppression(editingElement);
    _hideBrowserVirtualKeyboard();
    // Safari applies inputmode when focus enters the input. Merely changing
    // the attribute on the already focused Flutter editor leaves its native
    // keyboard covering the custom panel. Re-focus once per target, with
    // preventScroll; subsequent focus notifications must not repeat the handoff.
    if (changedTarget) {
      _reenterEditingElement(editingElement);
    } else {
      _focusElement(editingElement);
    }
  } finally {
    _syncingTarget = false;
  }
}

void deactivateWebCustomKeyboardInput({bool requestSystemKeyboard = false}) {
  _customKeyboardActive = false;
  _removeFocusInListener();

  final editingElement = _trackedEditingElement ?? _currentEditingElement();
  if (editingElement != null) {
    _restoreKeyboardBehavior(editingElement);
    if (requestSystemKeyboard) {
      _reenterEditingElement(editingElement);
    }
  }

  _trackedEditingElement = null;
}

({double height, double layoutHeight, double offsetTop})?
readWebKeyboardViewport() {
  final viewport = web.window.visualViewport;
  if (viewport == null) return null;
  final documentElement = web.document.documentElement;
  final layoutHeight = documentElement?.clientHeight.toDouble();
  if (layoutHeight == null || layoutHeight <= 0) return null;
  return (
    height: viewport.height.toDouble(),
    layoutHeight: layoutHeight,
    offsetTop: viewport.offsetTop.toDouble(),
  );
}
