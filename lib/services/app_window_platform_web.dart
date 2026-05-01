import 'dart:async';
import 'dart:js_interop';

import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

typedef WebLifecycleLogger =
    void Function(String event, Map<String, Object?> detail);

const String _windowIdPrefix = 'kemetic_window:';
const String _windowIdStorageKey = 'kemetic.window_id.v1';

bool _lifecycleLoggingInstalled = false;

bool _isUsableWindowId(String? raw) {
  final value = raw?.trim();
  return value != null && value.length >= 8;
}

String _generateWindowId() => const Uuid().v4();

String? _readSessionStorageWindowId() {
  try {
    return web.window.sessionStorage.getItem(_windowIdStorageKey)?.trim();
  } catch (_) {
    return null;
  }
}

void _writeSessionStorageWindowId(String windowId) {
  try {
    web.window.sessionStorage.setItem(_windowIdStorageKey, windowId);
  } catch (_) {
    // Best-effort only on web.
  }
}

String? _readWindowNameWindowId() {
  try {
    final raw = web.window.name.trim();
    if (!raw.startsWith(_windowIdPrefix)) {
      return null;
    }
    return raw.substring(_windowIdPrefix.length).trim();
  } catch (_) {
    return null;
  }
}

void _mirrorWindowIdIntoWindowName(String windowId) {
  try {
    final currentName = web.window.name.trim();
    if (currentName.isEmpty || currentName.startsWith(_windowIdPrefix)) {
      web.window.name = '$_windowIdPrefix$windowId';
    }
  } catch (_) {
    // Best-effort only on web.
  }
}

Future<String> resolvePlatformWindowId() async {
  final sessionWindowId = _readSessionStorageWindowId();
  if (_isUsableWindowId(sessionWindowId)) {
    final normalized = sessionWindowId!.trim();
    _mirrorWindowIdIntoWindowName(normalized);
    return normalized;
  }

  final namedWindowId = _readWindowNameWindowId();
  if (_isUsableWindowId(namedWindowId)) {
    final normalized = namedWindowId!.trim();
    _writeSessionStorageWindowId(normalized);
    _mirrorWindowIdIntoWindowName(normalized);
    return normalized;
  }

  final generated = _generateWindowId();
  _writeSessionStorageWindowId(generated);
  _mirrorWindowIdIntoWindowName(generated);
  return generated;
}

void installWebLifecycleLogging(WebLifecycleLogger onEvent) {
  if (_lifecycleLoggingInstalled) {
    return;
  }
  _lifecycleLoggingInstalled = true;

  web.window.addEventListener(
    'pageshow',
    ((web.Event event) {
      final persisted = (event as web.PageTransitionEvent).persisted;
      onEvent('pageshow', <String, Object?>{'persisted': persisted});
    }).toJS,
  );

  web.document.addEventListener(
    'visibilitychange',
    ((web.Event _) {
      onEvent('visibilitychange', <String, Object?>{
        'state': web.document.visibilityState,
      });
    }).toJS,
  );
}
