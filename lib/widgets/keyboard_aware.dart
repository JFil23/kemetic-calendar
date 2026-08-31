import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'kemetic_keyboard.dart';
import 'keyboard_viewport_metrics.dart';

const ValueKey<String> keyboardAwareEditableSurfaceKey = ValueKey<String>(
  'keyboard-aware-editable-surface',
);

KeyboardViewportMetrics keyboardViewportMetricsOf(BuildContext context) {
  final scope = KemeticKeyboardScope.maybeOf(context);
  if (scope != null) {
    return KeyboardViewportMetrics(
      visibleTop: scope.visibleTop,
      visibleBottom: scope.visibleBottom,
      layoutViewInsetBottom: scope.systemKeyboardInset,
      systemKeyboardVisible: scope.isSystemKeyboardVisible,
    );
  }
  return resolveKeyboardViewportMetrics(MediaQuery.of(context));
}

double keyboardInsetOf(BuildContext context) {
  final scope = KemeticKeyboardScope.maybeOf(context);
  if (scope != null) return scope.keyboardInset;
  return keyboardViewportMetricsOf(context).layoutViewInsetBottom;
}

bool keyboardIsVisible(BuildContext context) {
  final scope = KemeticKeyboardScope.maybeOf(context);
  if (scope != null) {
    return scope.isCustomKeyboardVisible || scope.isSystemKeyboardVisible;
  }
  return keyboardViewportMetricsOf(context).systemKeyboardVisible;
}

/// The single shared layout owner for an editable page or sheet.
///
/// Flutter and [Scaffold] continue to own ordinary system-keyboard resizing.
/// This surface adds clearance only when its caller owns a modal inset, or
/// when the alternate Kemetic keyboard overlays the app. Flutter also keeps
/// ownership of system-keyboard focus reveal. The scoped reveal below runs
/// only for the custom Kemetic keyboard, whose occupied height Flutter cannot
/// discover. It never searches or scrolls an arbitrary editable elsewhere in
/// the application.
class KeyboardAwareEditableSurface extends StatefulWidget {
  const KeyboardAwareEditableSurface({
    super.key,
    required this.child,
    this.manageSystemKeyboardInset = false,
    this.focusClearance = 20,
  });

  final Widget child;
  final bool manageSystemKeyboardInset;
  final double focusClearance;

  @override
  State<KeyboardAwareEditableSurface> createState() =>
      _KeyboardAwareEditableSurfaceState();
}

class _KeyboardAwareEditableSurfaceState
    extends State<KeyboardAwareEditableSurface> {
  ({double top, double bottom, double inset})? _lastGeometry;
  bool _revealScheduled = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final geometry = _geometry();
    if (_lastGeometry == geometry) return;
    _lastGeometry = geometry;
    if (_customKeyboardIsVisible) _scheduleReveal();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChanged);
    super.dispose();
  }

  ({double top, double bottom, double inset}) _geometry() {
    final media = MediaQuery.of(context);
    final scope = KemeticKeyboardScope.maybeOf(context);
    final viewport = keyboardViewportMetricsOf(context);
    final customInset = scope?.customKeyboardInset ?? 0;
    final systemInset = widget.manageSystemKeyboardInset
        ? viewport.layoutViewInsetBottom
        : 0.0;
    final inset = math.max(customInset, systemInset);
    final customBottom = media.size.height - customInset;
    return (
      top: math.max(viewport.visibleTop, media.padding.top),
      bottom: customInset > 0
          ? math.min(viewport.visibleBottom, customBottom)
          : viewport.visibleBottom,
      inset: inset,
    );
  }

  bool get _customKeyboardIsVisible =>
      KemeticKeyboardScope.maybeOf(context)?.isCustomKeyboardVisible == true;

  void _handleFocusChanged() {
    if (_customKeyboardIsVisible) _scheduleReveal();
  }

  void _scheduleReveal() {
    if (_revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted) return;
      _revealFocusedDescendant();
    });
  }

  bool _owns(BuildContext focusedContext) {
    if (identical(focusedContext, context)) return true;
    var owns = false;
    focusedContext.visitAncestorElements((element) {
      if (identical(element, context)) {
        owns = true;
        return false;
      }
      return true;
    });
    return owns;
  }

  void _revealFocusedDescendant() {
    if (!_customKeyboardIsVisible) return;
    final focus = FocusManager.instance.primaryFocus;
    final focusedContext = focus?.context;
    if (focusedContext == null || !focus!.hasFocus || !_owns(focusedContext)) {
      return;
    }

    final scrollable = Scrollable.maybeOf(focusedContext);
    final renderObject = focusedContext.findRenderObject();
    if (scrollable == null ||
        renderObject is! RenderBox ||
        !renderObject.hasSize) {
      return;
    }
    final position = scrollable.position;
    if (position.axis != Axis.vertical || !position.hasPixels) return;

    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final geometry = _geometry();
    final visibleTop = geometry.top + widget.focusClearance;
    final visibleBottom = geometry.bottom - widget.focusClearance;
    final lowerOverflow = rect.bottom - visibleBottom;
    final upperOverflow = rect.top - visibleTop;
    if (lowerOverflow <= 0 && upperOverflow >= 0) return;

    final overflow = lowerOverflow > 0 ? lowerOverflow : upperOverflow;
    final delta = position.axisDirection == AxisDirection.up
        ? -overflow
        : overflow;
    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() < 0.5) return;
    position.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: keyboardAwareEditableSurfaceKey,
      padding: EdgeInsets.only(bottom: _geometry().inset),
      child: widget.child,
    );
  }
}
