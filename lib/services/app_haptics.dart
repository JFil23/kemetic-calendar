import 'package:flutter/foundation.dart';

import 'app_haptics_native.dart' if (dart.library.html) 'app_haptics_web.dart';
import 'app_haptic_type.dart';
import 'app_haptics_result.dart';
export 'app_haptics_result.dart';

class AppHaptics {
  const AppHaptics._();

  static Future<AppHapticResult> selection({String? reason}) {
    return _trigger(AppHapticType.selection, reason: reason);
  }

  static Future<AppHapticResult> lightImpact({String? reason}) {
    return _trigger(AppHapticType.lightImpact, reason: reason);
  }

  static Future<AppHapticResult> mediumImpact({String? reason}) {
    return _trigger(AppHapticType.mediumImpact, reason: reason);
  }

  static Future<AppHapticResult> productiveAction({String? reason}) async {
    return lightImpact(reason: reason);
  }

  static Future<AppHapticResult> _trigger(
    AppHapticType type, {
    String? reason,
  }) async {
    if (kDebugMode) {
      final suffix = reason == null ? '' : ' ($reason)';
      debugPrint('[haptics] ${_debugLabelForType(type)} requested$suffix');
    }
    final result = await triggerAppHaptic(type);
    if (kDebugMode) {
      debugPrint(
        '[haptics] ${_debugLabelForType(type)} result ${result.debugSummary}',
      );
    }
    return result;
  }

  static String _debugLabelForType(AppHapticType type) {
    return switch (type) {
      AppHapticType.selection => 'selection',
      AppHapticType.lightImpact => 'lightImpact',
      AppHapticType.mediumImpact => 'mediumImpact',
    };
  }
}
