import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_window_platform_stub.dart'
    if (dart.library.html) 'app_window_platform_web.dart'
    as app_window_platform;

class AppWindowService {
  AppWindowService._();

  static final AppWindowService instance = AppWindowService._();

  static Future<String> Function()? debugWindowIdResolver;

  String? _windowId;
  Future<String>? _windowIdFuture;
  bool _webLifecycleLoggingInstalled = false;

  String? get currentWindowId => _windowId;

  String get restorationScopeId {
    final raw = _windowId ?? 'primary';
    final normalized = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'kemetic_app_$normalized';
  }

  void resetForTesting() {
    _windowId = null;
    _windowIdFuture = null;
    _webLifecycleLoggingInstalled = false;
  }

  Future<String> ensureInitialized() {
    final cached = _windowId;
    if (cached != null && cached.isNotEmpty) {
      return Future<String>.value(cached);
    }

    final inFlight = _windowIdFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final debugResolver = debugWindowIdResolver;
    _windowIdFuture = () async {
      final resolved = debugResolver != null
          ? await debugResolver()
          : await app_window_platform.resolvePlatformWindowId();
      final normalized = resolved.trim().isEmpty ? 'primary' : resolved.trim();
      _windowId = normalized;
      return normalized;
    }();
    return _windowIdFuture!;
  }

  void installWebLifecycleLogging() {
    if (_webLifecycleLoggingInstalled) {
      return;
    }
    _webLifecycleLoggingInstalled = true;

    app_window_platform.installWebLifecycleLogging((event, detail) {
      if (!kDebugMode) {
        return;
      }
      debugPrint('[web-lifecycle] $event $detail');
    });
  }
}
