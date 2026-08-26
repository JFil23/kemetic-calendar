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

/// One resolved description of the portion of the app viewport that is
/// actually visible while a keyboard is present.
///
/// Native platforms normally keep [MediaQueryData.size] stable and report an
/// inset. Mobile web can instead shrink the visual viewport while reporting no
/// inset. During an iOS web transition both signals can briefly be present; in
/// that case [layoutViewInsetBottom] suppresses the duplicate inset once the
/// Flutter viewport already matches the browser's visual viewport.
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

    final layoutHeight = math.max(0, webViewport.layoutHeight);
    final viewportTop = webViewport.offsetTop
        .clamp(0.0, mediaHeight)
        .toDouble();
    final viewportBottom = (viewportTop + math.max(0.0, webViewport.height))
        .clamp(viewportTop, mediaHeight)
        .toDouble();
    final browserViewportShrank =
        layoutHeight - (webViewport.offsetTop + webViewport.height) > 1;
    final flutterViewportAlreadyShrank =
        browserViewportShrank && mediaHeight <= viewportBottom + 1;
    final layoutInset = flutterViewportAlreadyShrank ? 0.0 : mediaInset;
    final mediaVisibleBottom = math.max(0.0, mediaHeight - layoutInset);

    return KeyboardViewportMetrics(
      visibleTop: viewportTop,
      visibleBottom: math.min(mediaVisibleBottom, viewportBottom),
      layoutViewInsetBottom: layoutInset,
      systemKeyboardVisible: mediaInset > 0 || browserViewportShrank,
    );
  }
}

KeyboardViewportMetrics resolveKeyboardViewportMetrics(MediaQueryData media) {
  return KeyboardViewportMetrics.resolve(
    media: media,
    webViewport: readWebKeyboardViewport(),
  );
}
