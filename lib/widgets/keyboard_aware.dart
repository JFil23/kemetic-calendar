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

/// Opens an editable modal whose route content owns remaining system inset once.
///
/// The whole visible sheet is lifted above remaining system-keyboard occlusion,
/// then raw viewInsets are stripped so descendants cannot consume them again.
/// Inner editable surfaces remain responsible only for leftover custom inset.
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
  bool constrainMediaSizeToAvailableHeight = false,
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
      constrainMediaSizeToAvailableHeight: constrainMediaSizeToAvailableHeight,
      paddingKey: editableModalSystemInsetOwnerKey,
      child: builder(modalContext),
    ),
  );
}

/// One presentation-boundary owner for remaining system-keyboard occlusion.
///
/// Pads the remaining system inset, strips raw [MediaQuery.viewInsets], and
/// records that consumption so descendants receive leftover occlusion plus
/// custom inset once. Does not read an `editable` flag.
class KeyboardInsetBoundary extends StatelessWidget {
  const KeyboardInsetBoundary({
    super.key,
    required this.child,
    this.constrainMediaSizeToAvailableHeight = false,
    this.paddingKey = keyboardInsetBoundaryKey,
  });

  final Widget child;
  final bool constrainMediaSizeToAvailableHeight;
  final Key paddingKey;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final remainingSystem = remainingSystemKeyboardInsetOf(context);
    var consumed = media.removeViewInsets(removeBottom: true);
    if (constrainMediaSizeToAvailableHeight && remainingSystem > 0) {
      consumed = consumed.copyWith(
        size: Size(
          media.size.width,
          math.max(0, media.size.height - remainingSystem),
        ),
      );
    }
    return KeyboardInsetConsumption.apply(
      context: context,
      additionalSystem: remainingSystem,
      additionalCustom: 0,
      child: Padding(
        key: paddingKey,
        padding: EdgeInsets.only(bottom: remainingSystem),
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

double keyboardInsetOf(BuildContext context) {
  return math.max(
    remainingCustomKeyboardInsetOf(context),
    remainingSystemKeyboardInsetOf(context),
  );
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
/// This surface adds clearance only when its caller owns remaining system
/// inset, or when the alternate Kemetic keyboard overlays the app. Flutter
/// also keeps ownership of system-keyboard focus reveal. The scoped reveal
/// below runs only for the custom Kemetic keyboard, whose occupied height
/// Flutter cannot discover. It never searches or scrolls an arbitrary
/// editable elsewhere in the application.
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
    final viewport = keyboardViewportMetricsOf(context);
    final customInset = remainingCustomKeyboardInsetOf(context);
    final systemInset = widget.manageSystemKeyboardInset
        ? remainingSystemKeyboardInsetOf(context)
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
    final remainingCustom = remainingCustomKeyboardInsetOf(context);
    final remainingSystem = widget.manageSystemKeyboardInset
        ? remainingSystemKeyboardInsetOf(context)
        : 0.0;
    return KeyboardInsetConsumption.apply(
      context: context,
      additionalSystem: remainingSystem,
      additionalCustom: remainingCustom,
      child: Padding(
        key: keyboardAwareEditableSurfaceKey,
        padding: EdgeInsets.only(bottom: _geometry().inset),
        child: widget.child,
      ),
    );
  }
}
