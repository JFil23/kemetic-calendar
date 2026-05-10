// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js_util' as js_util;

import 'package:web/web.dart' as web;

Future<void> publishDailyReflectionWidgetData({
  required String date,
  required String dateLabel,
  required String dayKey,
  required int kYear,
  required String question,
}) async {
  try {
    if (!js_util.hasProperty(web.window.navigator, 'serviceWorker')) return;
    final container = js_util.getProperty<Object?>(
      web.window.navigator,
      'serviceWorker',
    );
    if (container == null) return;

    final message = js_util.jsify(<String, Object?>{
      'type': 'kemetic-daily-reflection-widget-data',
      'payload': <String, Object?>{
        'date': date,
        'dateLabel': dateLabel,
        'dayKey': dayKey,
        'kYear': kYear,
        'question': question,
      },
    });

    void postTo(Object? worker) {
      if (worker == null) return;
      js_util.callMethod<void>(worker, 'postMessage', [message]);
    }

    postTo(js_util.getProperty<Object?>(container, 'controller'));

    final ready = js_util.getProperty<Object?>(container, 'ready');
    if (ready == null) return;
    final registration = await js_util.promiseToFuture<Object?>(ready);
    if (registration == null) return;
    postTo(js_util.getProperty<Object?>(registration, 'active'));
    postTo(js_util.getProperty<Object?>(registration, 'waiting'));
  } catch (_) {
    // Widget sync is an optional PWA enhancement; never fail app rendering.
  }
}
