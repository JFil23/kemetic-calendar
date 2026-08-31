// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class BrowserViewportSnapshot {
  const BrowserViewportSnapshot({
    required this.innerHeight,
    required this.visualViewportHeight,
    required this.visualViewportOffsetTop,
    required this.visualViewportPageTop,
  });

  final double? innerHeight;
  final double? visualViewportHeight;
  final double? visualViewportOffsetTop;
  final double? visualViewportPageTop;
}

typedef BrowserViewportListener =
    void Function(String event, BrowserViewportSnapshot snapshot);

class BrowserViewportSubscription {
  BrowserViewportSubscription(this._dispose);

  final void Function() _dispose;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _dispose();
  }
}

BrowserViewportSnapshot _snapshot() {
  final viewport = web.window.visualViewport;
  return BrowserViewportSnapshot(
    innerHeight: web.window.innerHeight.toDouble(),
    visualViewportHeight: viewport?.height.toDouble(),
    visualViewportOffsetTop: viewport?.offsetTop.toDouble(),
    visualViewportPageTop: viewport?.pageTop.toDouble(),
  );
}

BrowserViewportSubscription observeBrowserViewport(
  BrowserViewportListener listener,
) {
  final viewport = web.window.visualViewport;
  if (viewport == null) {
    scheduleMicrotask(
      () => listener('visualViewport.unavailable', _snapshot()),
    );
    return BrowserViewportSubscription(() {});
  }

  late final JSFunction resizeListener;
  late final JSFunction scrollListener;
  resizeListener = ((web.Event _) {
    listener('visualViewport.resize', _snapshot());
  }).toJS;
  scrollListener = ((web.Event _) {
    listener('visualViewport.scroll', _snapshot());
  }).toJS;

  viewport.addEventListener('resize', resizeListener);
  viewport.addEventListener('scroll', scrollListener);
  scheduleMicrotask(() => listener('visualViewport.initial', _snapshot()));

  return BrowserViewportSubscription(() {
    viewport.removeEventListener('resize', resizeListener);
    viewport.removeEventListener('scroll', scrollListener);
  });
}
