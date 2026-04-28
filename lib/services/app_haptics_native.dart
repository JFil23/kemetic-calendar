import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_haptic_type.dart';
import 'app_haptics_result.dart';

({Future<void> Function() invoke, String detail}) _nativeHapticForType(
  AppHapticType type,
) {
  return switch (type) {
    AppHapticType.selection => (
      invoke: HapticFeedback.selectionClick,
      detail: 'HapticFeedback.selectionClick()',
    ),
    AppHapticType.lightImpact => (
      invoke: HapticFeedback.lightImpact,
      detail: 'HapticFeedback.lightImpact()',
    ),
    AppHapticType.mediumImpact => (
      invoke: HapticFeedback.mediumImpact,
      detail: 'HapticFeedback.mediumImpact()',
    ),
  };
}

Future<AppHapticResult> triggerAppHaptic(AppHapticType type) async {
  final target = _nativeHapticForType(type);
  try {
    if (kDebugMode) {
      debugPrint('[haptics:native] invoking ${target.detail}.');
    }
    await target.invoke();
    if (kDebugMode) {
      debugPrint('[haptics:native] ${target.detail} completed.');
    }
    return AppHapticResult(
      backend: 'native',
      status: 'invoked',
      detail: target.detail,
    );
  } catch (error) {
    if (kDebugMode) {
      debugPrint('[haptics:native] Failed: $error');
    }
    return AppHapticResult(
      backend: 'native',
      status: 'error',
      detail: '$error',
    );
    // Some platforms silently ignore haptics; keep the interaction flowing.
  }
}
