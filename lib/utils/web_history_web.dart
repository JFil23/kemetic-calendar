// lib/utils/web_history_web.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void replaceUrlWithoutQuery() {
  final uri = Uri.base;
  final clean = uri.removeFragment().replace(queryParameters: const {});
  html.window.history.replaceState(null, '', clean.toString());
}

void onVisibilityChange(void Function() cb) {
  html.document.addEventListener('visibilitychange', (event) {
    if (html.document.visibilityState == 'visible') {
      cb();
      // 👇 poke localStorage to keep Safari from evicting
      try {
        html.window.localStorage['poke'] = DateTime.now().toIso8601String();
      } catch (_) {}
    }
  });
}
