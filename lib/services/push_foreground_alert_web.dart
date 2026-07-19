import 'dart:js_interop';

import '../shared/kemetic_text.dart';
import 'package:web/web.dart' as web;

Future<void> showForegroundPushAlert({
  required String title,
  String? body,
}) async {
  try {
    if (web.Notification.permission != 'granted') return;
    final safeTitle = KemeticExternalText.asciiSafe(title);
    final safeBody = body == null ? null : KemeticExternalText.asciiSafe(body);
    final notification = web.Notification(
      safeTitle.isEmpty ? 'Kemetic Calendar' : safeTitle,
      web.NotificationOptions(
        body: safeBody ?? '',
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
