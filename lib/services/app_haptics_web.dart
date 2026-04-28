// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'app_haptic_type.dart';
import 'app_haptics_result.dart';

void _debugLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[haptics:web] $message');
}

({Object pattern, String detail}) _webHapticForType(AppHapticType type) {
  return switch (type) {
    AppHapticType.selection => (pattern: 12, detail: 'navigator.vibrate(12)'),
    AppHapticType.lightImpact => (pattern: 22, detail: 'navigator.vibrate(22)'),
    AppHapticType.mediumImpact => (
      pattern: 30,
      detail: 'navigator.vibrate(30)',
    ),
  };
}

Future<AppHapticResult> triggerAppHaptic(AppHapticType type) async {
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
      if (!hasBeenActive && !isActive) {
        return const AppHapticResult(
          backend: 'web',
          status: 'skipped',
          detail: 'user activation missing',
        );
      }
    }

    final haptic = _webHapticForType(type);
    final accepted = js_util.callMethod<Object?>(navigator, 'vibrate', <Object>[
      haptic.pattern,
    ]);
    _debugLog('navigator.vibrate returned $accepted.');
    final acceptedBool = accepted is bool ? accepted : null;
    return AppHapticResult(
      backend: 'web',
      status: acceptedBool == false ? 'rejected' : 'invoked',
      detail: haptic.detail,
      accepted: acceptedBool,
    );
  } catch (error) {
    _debugLog('Failed: $error');
    return AppHapticResult(backend: 'web', status: 'error', detail: '$error');
    // Browser support is inconsistent across mobile PWAs; fail quietly.
  }
}
