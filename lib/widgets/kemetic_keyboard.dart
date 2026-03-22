import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:characters/characters.dart';

/// ChangeNotifier that tracks the currently focused editable field and whether
/// the Medu Neter keyboard is open.
class KemeticKeyboardController extends ChangeNotifier {
  EditableTextState? _editable;
  EditableTextState? _lastEditable;
  bool _open = false;
  bool _opening = false;

  bool get hasTarget => _editable != null || _lastEditable != null;
  bool get isOpen => _open;
  EditableTextState? get editable => _editable;
  EditableTextState? get lastEditable => _lastEditable;

  EditableTextState? _findEditableFromFocus() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context == null) return null;
    return focus!.context!.findAncestorStateOfType<EditableTextState>();
  }

  void ensureEditableFromFocus() {
    final found = _findEditableFromFocus();
    if (found != null) {
      attachEditable(found);
    }
  }

  void attachEditable(EditableTextState? editable) {
    if (editable != null && editable.mounted) {
      _editable = editable;
      _lastEditable = editable;
    } else if (!_open) {
      // Only clear when the custom keyboard is not showing; keep the last known
      // editable while open to survive transient blur (notably on iOS PWA).
      _editable = null;
    }
    if (editable == null && !_open) _open = false;
    notifyListeners();
  }

  void beginOpening() {
    _opening = true;
  }

  void endOpening({required bool success}) {
    _opening = false;
    if (success && _editable != null) {
      _open = true;
    }
    notifyListeners();
  }

  void open() {
    if (_editable == null) return;
    _open = true;
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    notifyListeners();
  }

  void requestSystemKeyboard() {
    final target = _selectUsableEditable();
    target?.widget.focusNode.requestFocus();
    target?.requestKeyboard();
  }

  void insert(String value, _OutputMode mode) {
    final target = _selectUsableEditable();
    if (target == null) return;

    final controller = target.widget.controller;
    final selection = controller.selection;
    final text = controller.text;

    final start = selection.start < 0
        ? text.length
        : min(selection.start, selection.end);
    final end = selection.end < 0
        ? text.length
        : max(selection.start, selection.end);

    final insertValue = mode == _OutputMode.scholarly
        ? _normalizeToUnicode(value)
        : _normalizeToAscii(value);

    var newText = text.replaceRange(start, end, insertValue);
    newText = mode == _OutputMode.scholarly
        ? _normalizeToUnicode(newText)
        : _normalizeToAscii(newText);

    final newOffset = start + insertValue.length;

    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
  }

  EditableTextState? _selectUsableEditable() {
    // Prefer current editable; if unusable, try focused; then last known.
    EditableTextState? candidate = _editable;
    if (!_isUsable(candidate)) {
      final focused = _findEditableFromFocus();
      if (_isUsable(focused)) {
        attachEditable(focused);
        candidate = focused;
      }
    }
    if (!_isUsable(candidate) && _isUsable(_lastEditable)) {
      candidate = _lastEditable;
    }
    return _isUsable(candidate) ? candidate : null;
  }

  bool _isUsable(EditableTextState? editable) {
    return editable != null && editable.mounted && editable.context.mounted;
  }
}

/// Wraps the entire app and shows a floating toggle plus keyboard panel
/// whenever a text input is focused.
class KemeticKeyboardHost extends StatefulWidget {
  final Widget child;

  const KemeticKeyboardHost({super.key, required this.child});

  @override
  State<KemeticKeyboardHost> createState() => _KemeticKeyboardHostState();
}

class _KemeticKeyboardHostState extends State<KemeticKeyboardHost> {
  final KemeticKeyboardController _controller = KemeticKeyboardController();
  double _lastKeyboardHeight = 300;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChange);
    _handleFocusChange();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    // Ignore transient focus churn while swapping keyboards.
    if (_opening) return;

    final focus = FocusManager.instance.primaryFocus;
    EditableTextState? editable;
    if (focus?.context != null) {
      editable = focus!.context!.findAncestorStateOfType<EditableTextState>();
    }
    if (editable == null) {
      // On iOS web/PWA the system keyboard toggle can null focus; keep the last
      // target instead of clearing so inserts continue to work.
      if (_isIosWebPwa()) {
        return;
      }
      // If the custom keyboard is open, keep the last target so PWA/iOS blur
      // doesn't drop inserts. If we're closed, clear the target.
      if (!_controller.isOpen) {
        _controller.close();
        _controller.attachEditable(null);
      }
      return;
    }

    _controller.attachEditable(editable);
    // If we have a text field in focus and the custom keyboard is not showing,
    // ensure the system keyboard is available.
    if (!_controller.isOpen) {
      _controller.requestSystemKeyboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset > 60 && (bottomInset - _lastKeyboardHeight).abs() > 1) {
      _lastKeyboardHeight = bottomInset;
    }

    return Stack(
      children: [
        widget.child,
        _KeyboardToggle(
          controller: _controller,
          bottomInset: bottomInset,
          onOpenCustom: _openCustomKeyboard,
        ),
        _KeyboardPanel(
          controller: _controller,
          keyboardHeight: _lastKeyboardHeight,
          onSystemKeyboard: _closeCustomAndRestoreSystem,
        ),
      ],
    );
  }

  Future<void> _openCustomKeyboard() async {
    if (_opening) return;
    _opening = true;
    _controller.beginOpening();
    _controller.ensureEditableFromFocus();
    final target =
        _controller.editable ?? _controller.lastEditable ?? _controller.editable;
    if (target == null) {
      _controller.endOpening(success: false);
      _opening = false;
      return;
    }
    target.widget.focusNode.requestFocus(); // keep the text input connection
    _controller.attachEditable(target); // ensure _editable is set for opening
    // On iOS web/PWA, avoid hiding the system keyboard to prevent focus loss
    // while still letting native builds behave as before.
    if (!_isIosWebPwa()) {
      try {
        await SystemChannels.textInput.invokeMethod('TextInput.hide');
      } catch (_) {
        // ignore platform quirks
      }
    }
    _controller.endOpening(success: true);
    _opening = false;
  }

  void _closeCustomAndRestoreSystem() {
    _controller.close();
    _controller.requestSystemKeyboard();
  }

  bool _isIosWebPwa() {
    // Web-only guard; iOS Safari PWAs lose focus when hiding keyboards.
    return kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }
}

class _KeyboardToggle extends StatelessWidget {
  final KemeticKeyboardController controller;
  final double bottomInset;
  final VoidCallback onOpenCustom;

  const _KeyboardToggle({
    required this.controller,
    required this.bottomInset,
    required this.onOpenCustom,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final visible = controller.hasTarget && !controller.isOpen;
        final anchor = (bottomInset > 0 ? bottomInset : 0) + 12.0;
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          right: 16,
          bottom: visible ? max(anchor, 32.0) : -72.0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: visible ? 1 : 0,
            child: IgnorePointer(
              ignoring: !visible,
              child: FloatingActionButton.extended(
                heroTag: 'kemeticKeyboardToggle',
                backgroundColor: colorScheme.surfaceVariant.withOpacity(0.95),
                foregroundColor: colorScheme.onSurfaceVariant,
                icon: const Icon(Icons.translate_outlined),
                label: const Text('Medu Neter'),
                onPressed: onOpenCustom,
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _OutputMode { scholarly, ascii }

class _KeyboardPanel extends StatefulWidget {
  final KemeticKeyboardController controller;
  final double keyboardHeight;
  final VoidCallback onSystemKeyboard;
  const _KeyboardPanel({
    required this.controller,
    required this.keyboardHeight,
    required this.onSystemKeyboard,
  });

  @override
  State<_KeyboardPanel> createState() => _KeyboardPanelState();
}

class _KeyboardPanelState extends State<_KeyboardPanel> {
  _OutputMode _mode = _OutputMode.scholarly;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final targetHeight = max(
      260.0,
      min(widget.keyboardHeight == 0 ? 320.0 : widget.keyboardHeight, 420.0),
    );

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final open = widget.controller.hasTarget && widget.controller.isOpen;
        if (!open) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomPadding),
            child: Material(
              elevation: 14,
              color: colorScheme.surface.withOpacity(0.98),
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: targetHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.translate_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kemetic phonograms — tap to insert',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SegmentedButton<_OutputMode>(
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                            segments: const [
                              ButtonSegment(
                                value: _OutputMode.scholarly,
                                label: Text('ꜣ'),
                              ),
                              ButtonSegment(
                                value: _OutputMode.ascii,
                                label: Text('ASCII'),
                              ),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (v) =>
                                setState(() => _mode = v.first),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: widget.onSystemKeyboard,
                            icon: const Icon(Icons.keyboard_outlined),
                            label: const Text('ABC'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _UniliteralLayout(
                          key: const ValueKey('uniliteral'),
                          controller: widget.controller,
                          outputMode: _mode,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class KemeticKeyGroup {
  final String anchor;
  final String unicode;
  final String ascii;
  final String hint;

  const KemeticKeyGroup({
    required this.anchor,
    required this.unicode,
    required this.ascii,
    required this.hint,
  });
}

class _UniliteralLayout extends StatelessWidget {
  final KemeticKeyboardController controller;
  final _OutputMode outputMode;

  const _UniliteralLayout({
    super.key,
    required this.controller,
    required this.outputMode,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        const spacing = 6.0;
        // Scrollable grid with 6 columns to fit all phonograms without overflow.
        final keyWidth = (maxWidth - spacing * 7) / 6;
        final layoutSymbols = outputMode == _OutputMode.scholarly
            ? _layoutScholarly
            : _layoutAscii;

        final keys = <KemeticKeyGroup>[];
        for (final row in layoutSymbols) {
          for (final sym in row) {
            final k = _symbolToPhonogram[sym];
            if (k != null) keys.add(k);
          }
        }

        return SingleChildScrollView(
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: keys
                .map(
                  (key) => _PhonogramKey(
                    width: keyWidth,
                    group: key,
                    controller: controller,
                    outputMode: outputMode,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _PhonogramKey extends StatelessWidget {
  final KemeticKeyGroup group;
  final KemeticKeyboardController controller;
  final double width;
  final _OutputMode outputMode;

  const _PhonogramKey({
    required this.group,
    required this.controller,
    required this.width,
    required this.outputMode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = outputMode == _OutputMode.scholarly
        ? group.unicode
        : group.ascii;

    return SizedBox(
      width: width,
      height: 52,
      child: Material(
        borderRadius: BorderRadius.circular(10),
        color: colorScheme.surfaceVariant.withOpacity(0.92),
        child: InkWell(
          onTap: () => controller.insert(displayValue, outputMode),
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ─────────────── Keyboard data (single grid, scrollable) ─────────────── */

const List<KemeticKeyGroup> _allPhonograms = [
  // Weak consonants
  KemeticKeyGroup(anchor: 'ꜣ', unicode: 'ꜣ', ascii: '3', hint: 'alef'),
  KemeticKeyGroup(anchor: 'ꜥ', unicode: 'ꜥ', ascii: "'", hint: 'ayin'),
  KemeticKeyGroup(anchor: 'j', unicode: 'j', ascii: 'j', hint: 'jod'),
  KemeticKeyGroup(anchor: 'y', unicode: 'y', ascii: 'y', hint: 'yod variant'),
  KemeticKeyGroup(anchor: 'w', unicode: 'w', ascii: 'w', hint: 'waw'),

  // Basic consonants
  KemeticKeyGroup(anchor: 'b', unicode: 'b', ascii: 'b', hint: 'b'),
  KemeticKeyGroup(anchor: 'p', unicode: 'p', ascii: 'p', hint: 'p'),
  KemeticKeyGroup(anchor: 'f', unicode: 'f', ascii: 'f', hint: 'f'),
  KemeticKeyGroup(anchor: 'm', unicode: 'm', ascii: 'm', hint: 'm'),
  KemeticKeyGroup(anchor: 'n', unicode: 'n', ascii: 'n', hint: 'n'),
  KemeticKeyGroup(anchor: 'r', unicode: 'r', ascii: 'r', hint: 'r'),

  // H-series
  KemeticKeyGroup(anchor: 'h', unicode: 'h', ascii: 'h', hint: 'h'),
  KemeticKeyGroup(anchor: 'ḥ', unicode: 'ḥ', ascii: 'H', hint: 'emphatic h'),
  KemeticKeyGroup(anchor: 'ḫ', unicode: 'ḫ', ascii: 'x', hint: 'kh (loch)'),
  KemeticKeyGroup(anchor: 'ẖ', unicode: 'ẖ', ascii: 'X', hint: 'palatal h'),

  // S-series
  KemeticKeyGroup(anchor: 's', unicode: 's', ascii: 's', hint: 's'),
  KemeticKeyGroup(anchor: 'z', unicode: 'z', ascii: 'z', hint: 'voiced s'),
  KemeticKeyGroup(anchor: 'š', unicode: 'š', ascii: 'S', hint: 'sh'),

  // K-series
  KemeticKeyGroup(anchor: 'q', unicode: 'q', ascii: 'q', hint: 'deep k'),
  KemeticKeyGroup(anchor: 'k', unicode: 'k', ascii: 'k', hint: 'k'),
  KemeticKeyGroup(anchor: 'g', unicode: 'g', ascii: 'g', hint: 'g'),

  // T/D-series
  KemeticKeyGroup(anchor: 't', unicode: 't', ascii: 't', hint: 't'),
  KemeticKeyGroup(anchor: 'ṯ', unicode: 'ṯ', ascii: 'T', hint: 'tj / ch'),
  KemeticKeyGroup(anchor: 'd', unicode: 'd', ascii: 'd', hint: 'd'),
  KemeticKeyGroup(anchor: 'ḏ', unicode: 'ḏ', ascii: 'D', hint: 'dj'),
];

const List<List<String>> _layoutScholarly = [
  ['ꜣ', 'ꜥ', 'j', 'y', 'w'],
  ['b', 'p', 'f', 'm', 'n', 'r'],
  ['h', 'ḥ', 'ḫ', 'ẖ'],
  ['s', 'z', 'š'],
  ['q', 'k', 'g'],
  ['t', 'ṯ', 'd', 'ḏ'],
];

const List<List<String>> _layoutAscii = [
  ['3', "'", 'j', 'y', 'w'],
  ['b', 'p', 'f', 'm', 'n', 'r'],
  ['h', 'H', 'x', 'X'],
  ['s', 'z', 'S'],
  ['q', 'k', 'g'],
  ['t', 'T', 'd', 'D'],
];

final Map<String, KemeticKeyGroup> _symbolToPhonogram = {
  for (final p in _allPhonograms) p.unicode: p,
  for (final p in _allPhonograms) p.ascii: p,
};

// Normalization maps
const Map<String, String> _asciiToUnicodeMap = {
  '3': 'ꜣ',
  'ʿ': 'ꜥ',
  '‘': 'ꜥ',
  "'": 'ꜥ',
  'H': 'ḥ',
  'x': 'ḫ',
  'X': 'ẖ',
  'S': 'š',
  'sh': 'š',
  'T': 'ṯ',
  'tj': 'ṯ',
  'D': 'ḏ',
  'dj': 'ḏ',
};

const Map<String, String> _unicodeToAsciiMap = {
  'ꜣ': '3',
  'ꜥ': "'",
  'ḥ': 'H',
  'ḫ': 'x',
  'ẖ': 'X',
  'š': 'S',
  'ṯ': 'T',
  'ḏ': 'D',
};

const List<String> _multiCharAliases = ['sh', 'tj', 'dj'];
const List<String> _singleCharAliases = [
  '3',
  'ʿ',
  '‘',
  "'",
  'H',
  'x',
  'X',
  'S',
  'T',
  'D',
];

String _normalizeToUnicode(String input) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < input.length) {
    bool matched = false;
    for (final alias in _multiCharAliases) {
      if (input.startsWith(alias, i)) {
        buffer.write(_asciiToUnicodeMap[alias] ?? alias);
        i += alias.length;
        matched = true;
        break;
      }
    }
    if (matched) continue;
    final ch = input[i];
    buffer.write(_asciiToUnicodeMap[ch] ?? ch);
    i += 1;
  }
  return buffer.toString();
}

String _normalizeToAscii(String input) {
  final buffer = StringBuffer();
  for (final ch in input.characters) {
    buffer.write(_unicodeToAsciiMap[ch] ?? ch);
  }
  return buffer.toString();
}
