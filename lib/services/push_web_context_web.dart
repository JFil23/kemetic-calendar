// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_util' as js_util;

import 'package:web/web.dart' as web;

class WebPushContext {
  const WebPushContext({
    required this.secureContext,
    required this.notificationApiAvailable,
    required this.serviceWorkerApiAvailable,
    required this.pushManagerApiAvailable,
    required this.appleMobile,
    required this.standalone,
    required this.serviceWorkerScriptReachable,
  });

  final bool secureContext;
  final bool notificationApiAvailable;
  final bool serviceWorkerApiAvailable;
  final bool pushManagerApiAvailable;
  final bool appleMobile;
  final bool standalone;
  final bool serviceWorkerScriptReachable;

  String? get blockerMessage {
    if (!secureContext) {
      return 'Web push requires HTTPS (or localhost during development).';
    }
    if (appleMobile && !standalone) {
      return 'On iPhone and iPad, web push only works from the installed Home Screen app.';
    }
    if (!notificationApiAvailable ||
        !serviceWorkerApiAvailable ||
        !pushManagerApiAvailable) {
      return 'This browser does not expose the APIs required for web push.';
    }
    if (!serviceWorkerScriptReachable) {
      return 'The web push service worker is missing from this web build.';
    }
    return null;
  }
}

bool _hasProperty(JSAny target, String name) {
  return js_util.hasProperty(target, name);
}

bool _navigatorStandalone() {
  try {
    return js_util.getProperty<bool?>(
          web.window.navigator,
          'standalone',
        ) ==
        true;
  } catch (_) {
    return false;
  }
}

String _messagingWorkerUrl() {
  return Uri.base.resolve('firebase-messaging-sw.js').toString();
}

String _messagingScopeUrl() {
  return Uri.base.resolve('firebase-cloud-messaging-push-scope').toString();
}

String _messagingScopePath() {
  return Uri.base.resolve('firebase-cloud-messaging-push-scope').path;
}

Future<bool> _hasMessagingServiceWorkerRegistration() async {
  try {
    final registration = await web.window.navigator.serviceWorker
        .getRegistration(_messagingScopeUrl())
        .toDart;
    return registration != null;
  } catch (_) {
    return false;
  }
}

Future<bool> ensureWebPushServiceWorkerReady() async {
  if (!web.window.isSecureContext) {
    return false;
  }
  if (!_hasProperty(web.window.navigator, 'serviceWorker')) {
    return false;
  }

  try {
    final container = web.window.navigator.serviceWorker;
    var registration = await container.getRegistration(_messagingScopeUrl()).toDart;
    registration ??= await container
        .register(
          _messagingWorkerUrl(),
          web.RegistrationOptions(scope: _messagingScopePath()),
        )
        .toDart;

    if (registration.active != null || registration.waiting != null) {
      return true;
    }

    for (var attempt = 0; attempt < 10; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final refreshed = await container.getRegistration(_messagingScopeUrl()).toDart;
      if (refreshed?.active != null || refreshed?.waiting != null) {
        return true;
      }
    }

    return registration.installing != null;
  } catch (_) {
    return false;
  }
}

Future<WebPushContext> inspectWebPushContext() async {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  final appleMobile =
      userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('ipod');
  final standalone =
      web.window.matchMedia('(display-mode: standalone)').matches ||
      _navigatorStandalone();

  return WebPushContext(
    secureContext: web.window.isSecureContext,
    notificationApiAvailable: _hasProperty(web.window, 'Notification'),
    serviceWorkerApiAvailable: _hasProperty(
      web.window.navigator,
      'serviceWorker',
    ),
    pushManagerApiAvailable: _hasProperty(web.window, 'PushManager'),
    appleMobile: appleMobile,
    standalone: standalone,
    serviceWorkerScriptReachable:
        await _hasMessagingServiceWorkerRegistration(),
  );
}
