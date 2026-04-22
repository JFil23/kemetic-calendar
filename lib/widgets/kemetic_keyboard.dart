import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/touch_targets.dart';

import 'kemetic_web_keyboard_input.dart'
    if (dart.library.js_interop) 'kemetic_web_keyboard_input_web.dart';

enum KeyboardMode { system, custom }

/// ChangeNotifier that tracks the currently focused editable field and whether
/// the Medu Neter keyboard is open.
class KemeticKeyboardController extends ChangeNotifier {
  EditableTextState? _editable;
  EditableTextState? _lastEditable;
  KeyboardMode _mode = KeyboardMode.system;
  bool _opening = false;

  bool get hasTarget => hasFocusedEditable || isOpen || isOpening;
  bool get hasFocusedEditable =>
      _isUsable(_editable) && _editable!.widget.focusNode.hasFocus;
  bool get hasUsableEditable =>
      _isUsable(_editable) || _isUsable(_lastEditable);
  bool get shouldShowToggle => hasFocusedEditable && !isOpen && !_opening;
  bool get shouldShowPanel => (isOpen || _opening) && hasUsableEditable;
  bool get isOpen => _mode == KeyboardMode.custom;
  bool get isCustomMode => _mode == KeyboardMode.custom;
  bool get isOpening => _opening;
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
    final nextEditable = _isUsable(editable)
        ? editable
        : (isOpen ? _editable : null);
    final nextLastEditable = _isUsable(editable) ? editable : _lastEditable;
    final changed =
        !identical(_editable, nextEditable) ||
        !identical(_lastEditable, nextLastEditable);
    _editable = nextEditable;
    _lastEditable = nextLastEditable;
    if (changed) notifyListeners();
  }

  void beginOpening() {
    if (_opening) return;
    _opening = true;
    notifyListeners();
  }

  void endOpening({required bool success}) {
    final target = _selectUsableEditable();
    final nextMode = success && target != null
        ? KeyboardMode.custom
        : KeyboardMode.system;
    final changed = _opening || _mode != nextMode;
    _opening = false;
    _mode = nextMode;
    if (changed) notifyListeners();
  }

  void open() {
    if (_selectUsableEditable() == null) return;
    if (_mode == KeyboardMode.custom && !_opening) return;
    _mode = KeyboardMode.custom;
    _opening = false;
    notifyListeners();
  }

  void close() {
    if (_mode == KeyboardMode.system && !_opening) return;
    _mode = KeyboardMode.system;
    _opening = false;
    notifyListeners();
  }

  void closeAndClearTargets() {
    final changed =
        _mode == KeyboardMode.custom ||
        _opening ||
        _editable != null ||
        _lastEditable != null;
    _mode = KeyboardMode.system;
    _opening = false;
    _editable = null;
    _lastEditable = null;
    if (changed) notifyListeners();
  }

  void requestSystemKeyboard() {
    final target = _selectUsableEditable();
    target?.widget.focusNode.requestFocus();
    target?.requestKeyboard();
  }

  void _insert(String value, _OutputMode mode) {
    final target = _selectUsableEditable();
    if (target == null) return;

    final newValue = _buildInsertedValue(
      target.widget.controller.value,
      value,
      mode,
    );

    _applyEditingValue(target, newValue);
  }

  void moveCaretHorizontally(int delta) {
    final target = _selectUsableEditable();
    if (target == null || delta == 0) return;

    final currentValue = target.widget.controller.value;
    final selection = currentValue.selection;
    final textLength = currentValue.text.length;

    final int targetOffset;
    if (!selection.isValid) {
      targetOffset = delta < 0 ? 0 : textLength;
    } else if (!selection.isCollapsed) {
      targetOffset = delta < 0
          ? min(selection.start, selection.end)
          : max(selection.start, selection.end);
    } else {
      targetOffset = (selection.extentOffset + delta)
          .clamp(0, textLength)
          .toInt();
    }

    _applyEditingValue(
      target,
      currentValue.copyWith(
        selection: TextSelection.collapsed(offset: targetOffset),
        composing: TextRange.empty,
      ),
    );
  }

  void moveCaretToBoundary({required bool toStart}) {
    final target = _selectUsableEditable();
    if (target == null) return;

    final currentValue = target.widget.controller.value;
    final targetOffset = toStart ? 0 : currentValue.text.length;
    _applyEditingValue(
      target,
      currentValue.copyWith(
        selection: TextSelection.collapsed(offset: targetOffset),
        composing: TextRange.empty,
      ),
    );
  }

  void _applyEditingValue(EditableTextState target, TextEditingValue newValue) {
    // Route edits through EditableText so input formatters, listeners, and
    // selection handling behave like real keyboard input.
    if (!kIsWeb && !target.widget.focusNode.hasFocus) {
      target.widget.focusNode.requestFocus();
    }
    target.userUpdateTextEditingValue(newValue, SelectionChangedCause.keyboard);
    target.bringIntoView(newValue.selection.extent);
    attachEditable(target);
  }

  TextEditingValue _buildInsertedValue(
    TextEditingValue currentValue,
    String value,
    _OutputMode mode,
  ) {
    final text = currentValue.text;
    final selection = currentValue.selection;
    final start = selection.isValid
        ? min(selection.start, selection.end)
        : text.length;
    final end = selection.isValid
        ? max(selection.start, selection.end)
        : text.length;

    final insertValue = mode == _OutputMode.scholarly
        ? _normalizeToUnicode(value)
        : _normalizeToAscii(value);
    final rawNewText = text.replaceRange(start, end, insertValue);
    final normalizedText = mode == _OutputMode.scholarly
        ? _normalizeToUnicode(rawNewText)
        : _normalizeToAscii(rawNewText);
    final rawCursorText = rawNewText.substring(0, start + insertValue.length);
    final normalizedCursorText = mode == _OutputMode.scholarly
        ? _normalizeToUnicode(rawCursorText)
        : _normalizeToAscii(rawCursorText);
    final newOffset = normalizedCursorText.length.clamp(
      0,
      normalizedText.length,
    );

    return currentValue.copyWith(
      text: normalizedText,
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
    return editable != null &&
        editable.mounted &&
        editable.context.mounted &&
        !editable.widget.readOnly;
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
  final GlobalKey _panelRegionKey = GlobalKey();
  final GlobalKey _toggleRegionKey = GlobalKey();
  double _lastKeyboardHeight = 300;
  bool _opening = false;
  bool _systemKeyboardHidden = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    FocusManager.instance.addListener(_handleFocusChange);
    _handleFocusChange();
  }

  @override
  void dispose() {
    deactivateWebCustomKeyboardInput();
    _controller.removeListener(_handleControllerChanged);
    FocusManager.instance.removeListener(_handleFocusChange);
    _controller.dispose();
    super.dispose();
  }

  double _resolvedPanelHeight() {
    return max(
      260.0,
      min(_lastKeyboardHeight == 0 ? 320.0 : _lastKeyboardHeight, 420.0),
    );
  }

  double _customKeyboardInset(MediaQueryData media) {
    if (!_controller.shouldShowPanel) return 0;
    return _resolvedPanelHeight() + 12 + media.padding.bottom;
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
    if (!_controller.shouldShowPanel) return;
    _scheduleRevealFocusedEditable();
  }

  void _scheduleRevealFocusedEditable() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.shouldShowPanel) return;
      final target = _controller.editable ?? _controller.lastEditable;
      if (!_controller._isUsable(target)) return;

      final editable = target!;
      final selection = editable.widget.controller.selection;
      final textLength = editable.widget.controller.text.length;
      final extentPosition = selection.isValid
          ? selection.extent
          : TextPosition(offset: textLength);

      try {
        editable.bringIntoView(
          TextPosition(offset: extentPosition.offset.clamp(0, textLength)),
        );
      } catch (_) {}

      Scrollable.ensureVisible(
        editable.context,
        alignment: 1.0,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleFocusChange() {
    // Ignore transient focus churn while swapping keyboards.
    if (_opening) return;

    final focus = FocusManager.instance.primaryFocus;
    EditableTextState? editable;
    if (focus?.context != null) {
      editable = focus!.context!.findAncestorStateOfType<EditableTextState>();
    }

    // Custom mode: keep last target, prevent system keyboard from re-opening.
    if (_controller.isCustomMode) {
      if (editable != null) {
        _controller.attachEditable(editable);
        if (kIsWeb) {
          editable.widget.focusNode.requestFocus();
          syncWebCustomKeyboardInputTarget();
        } else {
          try {
            SystemChannels.textInput.invokeMethod('TextInput.hide');
            _systemKeyboardHidden = true;
          } catch (_) {}
        }
      } else {
        _controller.attachEditable(null);
        _dismissCustomKeyboard(unfocusTarget: false);
      }
      return;
    }

    // System mode.
    if (editable == null) {
      // Keep last usable editable so cursor state is preserved while focus
      // briefly leaves the field (e.g., during long-press gestures).
      _controller.attachEditable(null);
      return;
    }

    _controller.attachEditable(editable);
    // If the system keyboard was explicitly hidden (e.g., after custom mode),
    // restore it once a field regains focus so cursor gestures keep working.
    if (_systemKeyboardHidden) {
      _systemKeyboardHidden = false;
      try {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      } catch (_) {}
      _controller.requestSystemKeyboard();
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_controller.isCustomMode || _opening) return;
    if (_containsGlobalPosition(_panelRegionKey, event.position)) return;
    if (_containsGlobalPosition(_toggleRegionKey, event.position)) return;
    if (_containsActiveEditable(event.position)) return;
    _dismissCustomKeyboard();
  }

  bool _containsActiveEditable(Offset globalPosition) {
    final editable = _controller.editable ?? _controller.lastEditable;
    if (!_controller._isUsable(editable)) return false;
    return _containsRenderObject(
      editable!.context.findRenderObject(),
      globalPosition,
    );
  }

  bool _containsGlobalPosition(GlobalKey key, Offset globalPosition) {
    return _containsRenderObject(
      key.currentContext?.findRenderObject(),
      globalPosition,
    );
  }

  bool _containsRenderObject(
    RenderObject? renderObject,
    Offset globalPosition,
  ) {
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return rect.contains(globalPosition);
  }

  void _dismissCustomKeyboard({bool unfocusTarget = true}) {
    final target = _controller.editable ?? _controller.lastEditable;
    deactivateWebCustomKeyboardInput();
    _controller.closeAndClearTargets();
    if (!unfocusTarget) return;
    target?.widget.focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    if (bottomInset > 60 && (bottomInset - _lastKeyboardHeight).abs() > 1) {
      _lastKeyboardHeight = bottomInset;
    }
    final effectiveViewInsets = media.viewInsets.copyWith(
      bottom: max(bottomInset, _customKeyboardInset(media)),
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: Stack(
        children: [
          MediaQuery(
            data: media.copyWith(viewInsets: effectiveViewInsets),
            child: widget.child,
          ),
          _KeyboardToggle(
            controller: _controller,
            regionKey: _toggleRegionKey,
            bottomInset: bottomInset,
            onOpenCustom: _openCustomKeyboard,
          ),
          _KeyboardPanel(
            controller: _controller,
            regionKey: _panelRegionKey,
            keyboardHeight: _lastKeyboardHeight,
            onSystemKeyboard: _closeCustomAndRestoreSystem,
          ),
        ],
      ),
    );
  }

  Future<void> _openCustomKeyboard() async {
    if (_opening) return;
    _opening = true;
    _controller.beginOpening();
    _controller.ensureEditableFromFocus();
    final target = _controller.editable ?? _controller.lastEditable;
    if (target == null) {
      _controller.endOpening(success: false);
      _opening = false;
      return;
    }
    _controller.attachEditable(target); // ensure _editable is set for opening

    if (kIsWeb) {
      target.widget.focusNode.requestFocus();
      activateWebCustomKeyboardInput();
    } else {
      target.widget.focusNode.requestFocus(); // keep the text input connection
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
    if (kIsWeb) {
      deactivateWebCustomKeyboardInput(requestSystemKeyboard: true);
    }
    try {
      SystemChannels.textInput.invokeMethod('TextInput.show');
    } catch (_) {}
    _systemKeyboardHidden = false;
    _controller.requestSystemKeyboard();
  }
}

class _KeyboardToggle extends StatefulWidget {
  final KemeticKeyboardController controller;
  final GlobalKey regionKey;
  final double bottomInset;
  final VoidCallback onOpenCustom;

  const _KeyboardToggle({
    required this.controller,
    required this.regionKey,
    required this.bottomInset,
    required this.onOpenCustom,
  });

  @override
  State<_KeyboardToggle> createState() => _KeyboardToggleState();
}

class _KeyboardToggleState extends State<_KeyboardToggle> {
  static const Size _fallbackSize = Size(176, 56);
  static const double _edgePadding = 12.0;
  static const double _hiddenOffset = 140.0;

  final GlobalKey _fabKey = GlobalKey();
  Size _toggleSize = _fallbackSize;
  Offset? _customOffset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSize());
  }

  void _updateSize() {
    final ctx = _fabKey.currentContext;
    if (ctx == null) return;
    final measured = ctx.size;
    if (measured != null &&
        (((measured.width - _toggleSize.width).abs() > 0.5) ||
            ((measured.height - _toggleSize.height).abs() > 0.5))) {
      final resolvedSize = measured;
      setState(() {
        _toggleSize = resolvedSize;
      });
    }
  }

  Offset _defaultOffset(Size screenSize, EdgeInsets padding) {
    final safeBottom = max(widget.bottomInset, padding.bottom);
    final bottomAnchor = max((safeBottom > 0 ? safeBottom : 0) + 12.0, 32.0);
    final x = screenSize.width - padding.right - 16.0 - _toggleSize.width;
    final y = screenSize.height - bottomAnchor - _toggleSize.height;
    return Offset(x, y);
  }

  Offset _clampOffset(Offset offset, Size screenSize, EdgeInsets padding) {
    final safeBottom = max(widget.bottomInset, padding.bottom);
    final minX = padding.left + _edgePadding;
    final maxX =
        screenSize.width - padding.right - _edgePadding - _toggleSize.width;
    final minY = padding.top + _edgePadding;
    final maxY =
        screenSize.height - safeBottom - _edgePadding - _toggleSize.height;

    final clampedX = offset.dx
        .clamp(minX, maxX < minX ? minX : maxX)
        .toDouble();
    final clampedY = offset.dy
        .clamp(minY, maxY < minY ? minY : maxY)
        .toDouble();
    return Offset(clampedX, clampedY);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final screenSize = media.size;
    final padding = media.padding;

    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSize());

    var targetOffset = _customOffset ?? _defaultOffset(screenSize, padding);
    targetOffset = _clampOffset(targetOffset, screenSize, padding);

    // If the screen/resolved bounds changed (e.g., keyboard opened), keep the
    // saved position clamped without resetting to the default.
    if (_customOffset != null && targetOffset != _customOffset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _customOffset = targetOffset);
      });
    }

    final hiddenOffset = Offset(
      targetOffset.dx,
      screenSize.height + _toggleSize.height + _hiddenOffset,
    );

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final show = widget.controller.shouldShowToggle;
        final positionedOffset = show ? targetOffset : hiddenOffset;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          left: positionedOffset.dx,
          top: positionedOffset.dy,
          child: TextFieldTapRegion(
            child: ExcludeFocus(
              child: SizedBox(
                key: widget.regionKey,
                child: AnimatedOpacity(
                  key: const ValueKey('kemetic-toggle-opacity'),
                  duration: const Duration(milliseconds: 180),
                  opacity: show ? 1 : 0,
                  child: IgnorePointer(
                    key: const ValueKey('kemetic-toggle-ignore-pointer'),
                    ignoring: !show,
                    child: KeyedSubtree(
                      key: const ValueKey('kemetic-toggle-hit-target'),
                      child: GestureDetector(
                        onPanStart: (_) => _updateSize(),
                        onPanUpdate: (details) {
                          final next = _clampOffset(
                            (_customOffset ?? targetOffset) + details.delta,
                            screenSize,
                            padding,
                          );
                          setState(() {
                            _customOffset = next;
                          });
                        },
                        child: FloatingActionButton.extended(
                          key: _fabKey,
                          heroTag: 'kemeticKeyboardToggle',
                          backgroundColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.95),
                          foregroundColor: colorScheme.onSurfaceVariant,
                          icon: const Icon(Icons.translate_outlined),
                          label: const Text('Medu Neter'),
                          onPressed: widget.onOpenCustom,
                        ),
                      ),
                    ),
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

enum _OutputMode { scholarly, ascii }

class _KeyboardPanel extends StatefulWidget {
  final KemeticKeyboardController controller;
  final GlobalKey regionKey;
  final double keyboardHeight;
  final VoidCallback onSystemKeyboard;
  const _KeyboardPanel({
    required this.controller,
    required this.regionKey,
    required this.keyboardHeight,
    required this.onSystemKeyboard,
  });

  @override
  State<_KeyboardPanel> createState() => _KeyboardPanelState();
}

class _KeyboardPanelState extends State<_KeyboardPanel> {
  _OutputMode _mode = _OutputMode.scholarly;

  Widget _buildPanelHeader(BuildContext context, ColorScheme colorScheme) {
    final title = Row(
      children: [
        const Icon(Icons.translate_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Kemetic phonograms — tap to insert',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    final modeToggle = SegmentedButton<_OutputMode>(
      style: ButtonStyle(
        visualDensity: expandedVisualDensity(
          context,
          fallback: VisualDensity.compact,
        ),
        tapTargetSize: expandedTapTargetSize(context),
      ),
      segments: const [
        ButtonSegment(value: _OutputMode.scholarly, label: Text('ꜣ')),
        ButtonSegment(value: _OutputMode.ascii, label: Text('ASCII')),
      ],
      selected: {_mode},
      onSelectionChanged: (v) => setState(() => _mode = v.first),
    );
    final systemKeyboardButton = TextButton.icon(
      onPressed: widget.onSystemKeyboard,
      icon: const Icon(Icons.keyboard_outlined),
      label: const Text('ABC'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactLayout = constraints.maxWidth < 720;
        if (useCompactLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [modeToggle, systemKeyboardButton],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            modeToggle,
            const SizedBox(width: 8),
            systemKeyboardButton,
          ],
        );
      },
    );
  }

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
        final open = widget.controller.shouldShowPanel;
        if (!open) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomPadding),
            child: TextFieldTapRegion(
              child: ExcludeFocus(
                child: SizedBox(
                  key: widget.regionKey,
                  child: Material(
                    key: const ValueKey('kemetic-keyboard-panel'),
                    elevation: 14,
                    color: colorScheme.surface.withValues(alpha: 0.98),
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: targetHeight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          children: [
                            _buildPanelHeader(context, colorScheme),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              child: Row(
                                children: [
                                  _KeyboardActionButton(
                                    key: const ValueKey('kemetic-action-start'),
                                    icon: Icons.first_page_rounded,
                                    tooltip: 'Move cursor to start',
                                    onPressed: () => widget.controller
                                        .moveCaretToBoundary(toStart: true),
                                  ),
                                  const SizedBox(width: 8),
                                  _KeyboardActionButton(
                                    key: const ValueKey('kemetic-action-left'),
                                    icon: Icons.arrow_left_rounded,
                                    tooltip: 'Move cursor left',
                                    onPressed: () => widget.controller
                                        .moveCaretHorizontally(-1),
                                  ),
                                  const SizedBox(width: 8),
                                  _KeyboardActionButton(
                                    key: const ValueKey('kemetic-action-right'),
                                    icon: Icons.arrow_right_rounded,
                                    tooltip: 'Move cursor right',
                                    onPressed: () => widget.controller
                                        .moveCaretHorizontally(1),
                                  ),
                                  const SizedBox(width: 8),
                                  _KeyboardActionButton(
                                    key: const ValueKey('kemetic-action-end'),
                                    icon: Icons.last_page_rounded,
                                    tooltip: 'Move cursor to end',
                                    onPressed: () => widget.controller
                                        .moveCaretToBoundary(toStart: false),
                                  ),
                                ],
                              ),
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
        child: InkWell(
          key: ValueKey('kemetic-key-$displayValue'),
          onTap: () => controller._insert(displayValue, outputMode),
          canRequestFocus: false,
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

class _KeyboardActionButton extends StatelessWidget {
  const _KeyboardActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final button = Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 44, height: 40, child: Icon(icon, size: 20)),
      ),
    );
    final hasOverlay = Overlay.maybeOf(context, rootOverlay: true) != null;
    if (!hasOverlay) {
      return Semantics(label: tooltip, button: true, child: button);
    }
    return Tooltip(message: tooltip, child: button);
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
