import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

// #region agent log
@JS('fetch')
external JSPromise<JSAny?> _jsFetch(JSString url, JSAny init);

void agentPlatformIngest(String jsonBody) {
  const url =
      'http://127.0.0.1:7754/ingest/55b4db24-649f-4229-be73-6a2b8bba0263';
  try {
    web.window.navigator.sendBeacon(url, jsonBody.toJS);
  } catch (_) {}
  try {
    final headers = JSObject();
    headers.setProperty('Content-Type'.toJS, 'text/plain'.toJS);
    final init = JSObject();
    init.setProperty('method'.toJS, 'POST'.toJS);
    init.setProperty('headers'.toJS, headers);
    init.setProperty('body'.toJS, jsonBody.toJS);
    init.setProperty('mode'.toJS, 'cors'.toJS);
    init.setProperty('keepalive'.toJS, true.toJS);
    _jsFetch(url.toJS, init);
  } catch (_) {}
  try {
    final headers = JSObject();
    headers.setProperty('Content-Type'.toJS, 'application/json'.toJS);
    headers.setProperty('X-Debug-Session-Id'.toJS, 'bdbad5'.toJS);
    final init = JSObject();
    init.setProperty('method'.toJS, 'POST'.toJS);
    init.setProperty('headers'.toJS, headers);
    init.setProperty('body'.toJS, jsonBody.toJS);
    _jsFetch(url.toJS, init);
  } catch (_) {}
}
// #endregion
