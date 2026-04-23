// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const String _legacyWorkerScopeSegment = 'firebase-cloud-messaging-push-scope';

String _workerUrl() {
  return Uri.base.resolve('firebase-messaging-sw.js').toString();
}

String _workerScopeUrl() {
  return Uri.base.resolve('/').toString();
}

String _workerScopePath() {
  return Uri.base.resolve('/').path;
}

String _legacyWorkerScopeUrl() {
  return Uri.base.resolve(_legacyWorkerScopeSegment).toString();
}

Future<void> _clearLegacyRegistration(
  web.ServiceWorkerContainer container,
) async {
  final legacy = await container
      .getRegistration(_legacyWorkerScopeUrl())
      .toDart;
  if (legacy == null) {
    return;
  }

  try {
    final subscription = await legacy.pushManager.getSubscription().toDart;
    await subscription?.unsubscribe().toDart;
  } catch (_) {
    // Best effort only.
  }

  try {
    await legacy.unregister().toDart;
  } catch (_) {
    // Best effort only.
  }
}

Future<web.ServiceWorkerRegistration?> _ensureRegistration() async {
  if (!web.window.isSecureContext) {
    return null;
  }
  if (!js_util.hasProperty(web.window.navigator, 'serviceWorker')) {
    return null;
  }

  final container = web.window.navigator.serviceWorker;
  var registration = await container.getRegistration(_workerScopeUrl()).toDart;
  registration ??= await container
      .register(
        _workerUrl(),
        web.RegistrationOptions(scope: _workerScopePath()),
      )
      .toDart;
  return registration;
}

Uint8List _base64UrlDecode(String value) {
  var normalized = value.replaceAll('-', '+').replaceAll('_', '/');
  while (normalized.length % 4 != 0) {
    normalized += '=';
  }
  return Uint8List.fromList(base64Decode(normalized));
}

String? _subscriptionToJson(web.PushSubscription? subscription) {
  if (subscription == null) return null;
  final json = js_util.dartify(subscription.toJSON());
  if (json is Map) {
    return jsonEncode(Map<String, dynamic>.from(json));
  }
  return null;
}

Future<String> browserNotificationPermissionStatus() async {
  return web.Notification.permission;
}

Future<String> requestBrowserNotificationPermission() async {
  return (await web.Notification.requestPermission().toDart).toString();
}

Future<String?> getExistingBrowserPushSubscriptionJson() async {
  final registration = await _ensureRegistration();
  if (registration == null) {
    return null;
  }
  final subscription = await registration.pushManager.getSubscription().toDart;
  return _subscriptionToJson(subscription);
}

Future<String?> subscribeBrowserPush(String publicKey) async {
  final registration = await _ensureRegistration();
  if (registration == null) {
    return null;
  }

  var subscription = await registration.pushManager.getSubscription().toDart;
  subscription ??= await registration.pushManager
      .subscribe(
        web.PushSubscriptionOptionsInit(
          userVisibleOnly: true,
          applicationServerKey: _base64UrlDecode(publicKey).toJS,
        ),
      )
      .toDart;

  final container = web.window.navigator.serviceWorker;
  await _clearLegacyRegistration(container);
  return _subscriptionToJson(subscription);
}

Future<void> unsubscribeBrowserPush() async {
  final registration = await _ensureRegistration();
  if (registration != null) {
    final subscription = await registration.pushManager
        .getSubscription()
        .toDart;
    await subscription?.unsubscribe().toDart;
  }

  final container = web.window.navigator.serviceWorker;
  await _clearLegacyRegistration(container);
}
