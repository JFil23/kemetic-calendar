import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_haptics_result.dart';

Future<AppHapticResult> triggerProductiveHaptic() async {
  try {
    if (kDebugMode) {
      debugPrint('[haptics:native] invoking HapticFeedback.lightImpact().');
    }
    await HapticFeedback.lightImpact();
    if (kDebugMode) {
      debugPrint('[haptics:native] HapticFeedback.lightImpact() completed.');
    }
    return const AppHapticResult(
      backend: 'native',
      status: 'invoked',
      detail: 'HapticFeedback.lightImpact()',
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
