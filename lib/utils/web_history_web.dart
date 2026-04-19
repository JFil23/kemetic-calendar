// lib/utils/web_history_web.dart
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_util' as js_util;
import 'dart:math' as math;

import 'package:web/web.dart' as web;

final List<JSFunction> _visibilityListeners = <JSFunction>[];

bool _navigatorStandalone() {
  try {
    return js_util.getProperty<bool?>(web.window.navigator, 'standalone') ==
        true;
  } catch (_) {
    return false;
  }
}

String _navigatorPlatform() {
  try {
    return js_util.getProperty<String?>(web.window.navigator, 'platform') ?? '';
  } catch (_) {
    return '';
  }
}

int _navigatorMaxTouchPoints() {
  try {
    return js_util
            .getProperty<num?>(web.window.navigator, 'maxTouchPoints')
            ?.toInt() ??
        0;
  } catch (_) {
    return 0;
  }
}

bool _isIOSFamilyStandalonePwa() {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  final isAppleMobile =
      userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('ipod');
  final isTouchMac =
      _navigatorPlatform() == 'MacIntel' && _navigatorMaxTouchPoints() > 1;
  final isIOSFamily = isAppleMobile || isTouchMac;
  final isStandalone =
      web.window.matchMedia('(display-mode: standalone)').matches ||
      _navigatorStandalone();

  return isIOSFamily && isStandalone;
}

bool _isIOSFamilyStandaloneTabletPwa() {
  if (!_isIOSFamilyStandalonePwa()) {
    return false;
  }

  final shortestScreenSide = math.min(
    web.window.screen.width.toDouble(),
    web.window.screen.height.toDouble(),
  );

  return shortestScreenSide >= 768;
}

void replaceUrlWithoutQuery() {
  final uri = Uri.base;
  final clean = uri.removeFragment().replace(queryParameters: const {});
  web.window.history.replaceState(null, '', clean.toString());
}

void nudgeStandaloneWebView() {
  if (!_isIOSFamilyStandalonePwa()) {
    return;
  }

  void dispatchResize() {
    web.window.dispatchEvent(web.Event('resize'));
  }

  dispatchResize();
  Future<void>.microtask(() {
    dispatchResize();
  });
  Timer(const Duration(milliseconds: 60), dispatchResize);
  if (_isIOSFamilyStandaloneTabletPwa()) {
    Timer(const Duration(milliseconds: 220), dispatchResize);
  }
}

void onVisibilityChange(void Function() cb) {
  final listener = ((web.Event _) {
    if (web.document.visibilityState == 'visible') {
      cb();
      // Poke localStorage to keep Safari from evicting state too aggressively.
      try {
        web.window.localStorage.setItem(
          'poke',
          DateTime.now().toIso8601String(),
        );
      } catch (_) {}
    }
  }).toJS;
  _visibilityListeners.add(listener);
  web.document.addEventListener('visibilitychange', listener);
}
