import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'kemetic_keyboard.dart';
import 'keyboard_viewport_metrics.dart';

const ValueKey<String> keyboardAwareEditableSurfaceKey = ValueKey<String>(
  'keyboard-aware-editable-surface',
);
const ValueKey<String> editableModalSystemInsetOwnerKey = ValueKey<String>(
  'editable-modal-system-inset-owner',
);
const ValueKey<String> keyboardInsetBoundaryKey = ValueKey<String>(
  'keyboard-inset-boundary',
);

/// Records system and custom inset already applied by ancestor presentation
/// boundaries so descendants consume only what remains.
class KeyboardInsetConsumption extends InheritedWidget {
  const KeyboardInsetConsumption({
    super.key,
    required this.consumedSystemInset,
    required this.consumedCustomInset,
    required super.child,
  });

  final double consumedSystemInset;
  final double consumedCustomInset;

  static KeyboardInsetConsumption? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<KeyboardInsetConsumption>();
  }

  static Widget apply({
    required BuildContext context,
    required double additionalSystem,
    required double additionalCustom,
    required Widget child,
  }) {
    final parent = maybeOf(context);
    return KeyboardInsetConsumption(
      consumedSystemInset:
          (parent?.consumedSystemInset ?? 0) + additionalSystem,
      consumedCustomInset:
          (parent?.consumedCustomInset ?? 0) + additionalCustom,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(covariant KeyboardInsetConsumption oldWidget) {
    return consumedSystemInset != oldWidget.consumedSystemInset ||
        consumedCustomInset != oldWidget.consumedCustomInset;
  }
}

double publishedSystemKeyboardInsetOf(BuildContext context) {
  final scope = KemeticKeyboardScope.maybeOf(context);
  if (scope != null) return scope.systemKeyboardInset;
  return resolveKeyboardViewportMetrics(
    MediaQuery.of(context),
  ).layoutViewInsetBottom;
}

double remainingSystemKeyboardInsetOf(BuildContext context) {
  final consumed =
      KeyboardInsetConsumption.maybeOf(context)?.consumedSystemInset ?? 0;
  return math.max(0, publishedSystemKeyboardInsetOf(context) - consumed);
}

double remainingCustomKeyboardInsetOf(BuildContext context) {
  final published =
      KemeticKeyboardScope.maybeOf(context)?.customKeyboardInset ?? 0;
  final consumed =
      KeyboardInsetConsumption.maybeOf(context)?.consumedCustomInset ?? 0;
  return math.max(0, published - consumed);
}

/// Opens an editable modal whose route content owns remaining occlusion once.
///
/// The visible sheet is lifted above the larger remaining system or custom
/// keyboard occlusion. Raw viewInsets are stripped and the published size is
/// reduced so descendants cannot consume the same space again.
Future<T?> showEditableModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
  ShapeBorder? shape,
  Clip? clipBehavior,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: true,
    useRootNavigator: useRootNavigator,
    requestFocus: true,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    shape: shape,
    clipBehavior: clipBehavior,
    builder: (modalContext) => KeyboardInsetBoundary(
      paddingKey: editableModalSystemInsetOwnerKey,
      child: builder(modalContext),
    ),
  );
}

Future<T?> showEditableDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    builder: (dialogContext) => KeyboardInsetBoundary(
      child: KeyboardAwareEditableSurface(child: builder(dialogContext)),
    ),
  );
}

/// One presentation-boundary owner for remaining keyboard occlusion.
///
/// Pads the larger remaining system or custom inset, strips raw
/// [MediaQuery.viewInsets], publishes the visible size, and records both kinds
/// of consumption so descendants cannot apply either again.
class KeyboardInsetBoundary extends StatelessWidget {
  const KeyboardInsetBoundary({
    super.key,
    required this.child,
    this.paddingKey = keyboardInsetBoundaryKey,
  });

  final Widget child;
  final Key paddingKey;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final remainingSystem = remainingSystemKeyboardInsetOf(context);
    final remainingCustom = remainingCustomKeyboardInsetOf(context);
    final remainingOcclusion = math.max(remainingSystem, remainingCustom);
    var consumed = media.removeViewInsets(removeBottom: true);
    if (remainingOcclusion > 0) {
      consumed = consumed.copyWith(
        size: Size(
          media.size.width,
          math.max(0, media.size.height - remainingOcclusion),
        ),
      );
    }
    return KeyboardInsetConsumption.apply(
      context: context,
      additionalSystem: remainingSystem,
      additionalCustom: remainingCustom,
      child: Padding(
        key: paddingKey,
        padding: EdgeInsets.only(bottom: remainingOcclusion),
        child: MediaQuery(data: consumed, child: child),
      ),
    );
  }
}

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

bool keyboardIsVisible(BuildContext context) {
  final scope = KemeticKeyboardScope.maybeOf(context);
  if (scope != null) {
    return scope.isCustomKeyboardVisible || scope.isSystemKeyboardVisible;
  }
  return keyboardViewportMetricsOf(context).systemKeyboardVisible;
}

/// The single custom-keyboard owner for an editable page or sheet.
///
/// Flutter and [Scaffold] own ordinary page system-keyboard resizing. Editable
/// modal boundaries own modal occlusion. This surface adds only remaining
/// custom-keyboard clearance and performs the one scoped reveal needed for
/// that alternate keyboard. It never scrolls for the system keyboard or
/// searches for an editable outside its own subtree.
class KeyboardAwareEditableSurface extends StatefulWidget {
  const KeyboardAwareEditableSurface({
    super.key,
    required this.child,
    this.focusClearance = 20,
  });

  final Widget child;
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
    final viewport = keyboardViewportMetricsOf(context);
    final customInset = remainingCustomKeyboardInsetOf(context);
    final customBottom = media.size.height - customInset;
    return (
      top: math.max(viewport.visibleTop, media.padding.top),
      bottom: customInset > 0
          ? math.min(viewport.visibleBottom, customBottom)
          : viewport.visibleBottom,
      inset: customInset,
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
    final remainingCustom = remainingCustomKeyboardInsetOf(context);
    return KeyboardInsetConsumption.apply(
      context: context,
      additionalSystem: 0,
      additionalCustom: remainingCustom,
      child: Padding(
        key: keyboardAwareEditableSurfaceKey,
        padding: EdgeInsets.only(bottom: _geometry().inset),
        child: widget.child,
      ),
    );
  }
}
