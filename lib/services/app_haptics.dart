import 'package:flutter/foundation.dart';

import 'app_haptics_native.dart' if (dart.library.html) 'app_haptics_web.dart';
import 'app_haptics_result.dart';
export 'app_haptics_result.dart';

class AppHaptics {
  const AppHaptics._();

  static Future<AppHapticResult> productiveAction({String? reason}) async {
    if (kDebugMode) {
      final suffix = reason == null ? '' : ' ($reason)';
      debugPrint('[haptics] productiveAction requested$suffix');
    }
    final result = await triggerProductiveHaptic();
    if (kDebugMode) {
      debugPrint('[haptics] productiveAction result ${result.debugSummary}');
    }
    return result;
  }
}
