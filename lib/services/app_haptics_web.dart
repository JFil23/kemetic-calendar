// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'app_haptics_result.dart';

void _debugLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[haptics:web] $message');
}

Future<AppHapticResult> triggerProductiveHaptic() async {
  try {
    if (!web.window.isSecureContext) {
      _debugLog('Skipped: not in a secure context.');
      return const AppHapticResult(
        backend: 'web',
        status: 'skipped',
        detail: 'not in a secure context',
      );
    }
    final navigator = web.window.navigator;
    if (!js_util.hasProperty(navigator, 'vibrate')) {
      _debugLog('Skipped: navigator.vibrate is unavailable.');
      return const AppHapticResult(
        backend: 'web',
        status: 'skipped',
        detail: 'navigator.vibrate is unavailable',
      );
    }

    final userActivation = js_util.getProperty<Object?>(
      navigator,
      'userActivation',
    );
    if (userActivation != null) {
      final hasBeenActive =
          js_util.getProperty<bool?>(userActivation, 'hasBeenActive') ?? false;
      final isActive =
          js_util.getProperty<bool?>(userActivation, 'isActive') ?? false;
      _debugLog(
        'userActivation hasBeenActive=$hasBeenActive isActive=$isActive.',
      );
    }

    // Slightly longer than the first pass so Android PWAs can actually feel it.
    final accepted = js_util.callMethod<Object?>(navigator, 'vibrate', <Object>[
      22,
    ]);
    _debugLog('navigator.vibrate returned $accepted.');
    final acceptedBool = accepted is bool ? accepted : null;
    return AppHapticResult(
      backend: 'web',
      status: 'invoked',
      detail: 'navigator.vibrate(22)',
      accepted: acceptedBool,
    );
  } catch (error) {
    _debugLog('Failed: $error');
    return AppHapticResult(backend: 'web', status: 'error', detail: '$error');
    // Browser support is inconsistent across mobile PWAs; fail quietly.
  }
}
