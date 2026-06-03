import 'package:flutter/foundation.dart';

const bool restorationTraceEnabled = bool.fromEnvironment(
  'RESTORATION_TRACE',
  defaultValue: false,
);

void traceRestoration(String message) {
  if (!kDebugMode || !restorationTraceEnabled) return;
  debugPrint('[restoration] $message');
}
