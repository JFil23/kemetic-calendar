import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'kemetic_web_keyboard_input.dart'
    if (dart.library.js_interop) 'kemetic_web_keyboard_input_web.dart';

typedef WebKeyboardViewportSnapshot = ({
  double height,
  double layoutHeight,
  double offsetTop,
});

typedef KeyboardViewportMetricsResolver =
    KeyboardViewportMetrics Function(MediaQueryData media);

/// Raw Flutter geometry exposed by the existing keyboard-metrics authority.
///
/// Diagnostic surfaces use this snapshot instead of becoming another reader
/// of raw keyboard insets.
@immutable
class KeyboardMediaGeometry {
  const KeyboardMediaGeometry({
    required this.size,
    required this.viewInsetBottom,
    required this.viewPaddingBottom,
    required this.paddingTop,
  });

  final Size size;
  final double viewInsetBottom;
  final double viewPaddingBottom;
  final double paddingTop;
}

KeyboardMediaGeometry keyboardMediaGeometryOf(BuildContext context) {
  final media = MediaQuery.of(context);
  return KeyboardMediaGeometry(
    size: media.size,
    viewInsetBottom: media.viewInsets.bottom,
    viewPaddingBottom: media.viewPadding.bottom,
    paddingTop: media.padding.top,
  );
}

/// One resolved description of the portion of the app viewport that is
/// actually visible while a keyboard is present.
///
/// Native platforms normally keep [MediaQueryData.size] stable and report an
/// inset. Mobile web can instead shrink the visual viewport while reporting no
/// inset. Browser offsets are expressed in layout-viewport coordinates, so
/// they are applied only while Flutter still uses that coordinate space. Once
/// Flutter's viewport already matches the browser's visual viewport, local
/// coordinates start at zero and [layoutViewInsetBottom] suppresses any
/// duplicate transitional inset.
@immutable
class KeyboardViewportMetrics {
  const KeyboardViewportMetrics({
    required this.visibleTop,
    required this.visibleBottom,
    required this.layoutViewInsetBottom,
    required this.systemKeyboardVisible,
  });

  final double visibleTop;
  final double visibleBottom;
  final double layoutViewInsetBottom;
  final bool systemKeyboardVisible;

  double get visibleHeight => math.max(0, visibleBottom - visibleTop);

  factory KeyboardViewportMetrics.resolve({
    required MediaQueryData media,
    WebKeyboardViewportSnapshot? webViewport,
  }) {
    const coordinateEpsilon = 1.0;
    final mediaHeight = media.size.height;
    final mediaInset = media.viewInsets.bottom
        .clamp(0.0, mediaHeight)
        .toDouble();
    if (webViewport == null) {
      return KeyboardViewportMetrics(
        visibleTop: 0,
        visibleBottom: math.max(0, mediaHeight - mediaInset),
        layoutViewInsetBottom: mediaInset,
        systemKeyboardVisible: mediaInset > 0,
      );
    }

    final layoutHeight = math.max(0.0, webViewport.layoutHeight);
    final visualHeight = math.max(0.0, webViewport.height);
    final browserViewportShrank =
        visualHeight < layoutHeight - coordinateEpsilon;
    if (!browserViewportShrank) {
      return KeyboardViewportMetrics(
        visibleTop: 0,
        visibleBottom: math.max(0, mediaHeight - mediaInset),
        layoutViewInsetBottom: mediaInset,
        systemKeyboardVisible: mediaInset > 0,
      );
    }

    final flutterUsesVisualViewportCoordinates =
        (mediaHeight - visualHeight).abs() <= coordinateEpsilon;
    if (flutterUsesVisualViewportCoordinates) {
      return KeyboardViewportMetrics(
        visibleTop: 0,
        visibleBottom: mediaHeight,
        layoutViewInsetBottom: 0,
        systemKeyboardVisible: true,
      );
    }

    final viewportTop = webViewport.offsetTop
        .clamp(0.0, mediaHeight)
        .toDouble();
    final viewportBottom = (webViewport.offsetTop + visualHeight)
        .clamp(viewportTop, mediaHeight)
        .toDouble();
    final bottomOcclusion = math.max(0.0, mediaHeight - viewportBottom);

    return KeyboardViewportMetrics(
      visibleTop: viewportTop,
      visibleBottom: viewportBottom,
      layoutViewInsetBottom: bottomOcclusion,
      systemKeyboardVisible: true,
    );
  }
}

KeyboardViewportMetrics resolveKeyboardViewportMetrics(MediaQueryData media) {
  return KeyboardViewportMetrics.resolve(
    media: media,
    webViewport: readWebKeyboardViewport(),
  );
}
