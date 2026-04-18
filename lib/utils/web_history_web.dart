// lib/utils/web_history_web.dart
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

final List<JSFunction> _visibilityListeners = <JSFunction>[];

void replaceUrlWithoutQuery() {
  final uri = Uri.base;
  final clean = uri.removeFragment().replace(queryParameters: const {});
  web.window.history.replaceState(null, '', clean.toString());
}

void nudgeStandaloneWebView() {
  void dispatchResize() {
    web.window.dispatchEvent(web.Event('resize'));
  }

  dispatchResize();
  Future<void>.microtask(() {
    dispatchResize();
  });
  Timer(const Duration(milliseconds: 60), dispatchResize);
  Timer(const Duration(milliseconds: 220), dispatchResize);
}

void onVisibilityChange(void Function() cb) {
  final listener = ((web.Event _) {
    if (web.document.visibilityState == 'visible') {
      cb();
      // Poke localStorage to keep Safari from evicting state too aggressively.
      try {
        web.window.localStorage.setItem('poke', DateTime.now().toIso8601String());
      } catch (_) {}
    }
  }).toJS;
  _visibilityListeners.add(listener);
  web.document.addEventListener('visibilitychange', listener);
}
