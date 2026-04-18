import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> showForegroundPushAlert({
  required String title,
  String? body,
}) async {
  try {
    if (web.Notification.permission != 'granted') return;
    final notification = web.Notification(
      title,
      web.NotificationOptions(
        body: body ?? '',
        icon: 'icons/Icon-192.png',
        badge: 'icons/Icon-maskable-192.png',
        tag: 'kemetic-calendar-foreground',
      ),
    );
    web.window.setTimeout(
      (() {
        notification.close();
      }).toJS,
      8000.toJS,
    );
  } catch (_) {
    // Browser notification APIs vary across PWAs; fail quietly.
  }
}
