import 'package:flutter/foundation.dart';

/// Shared UI typography. Web uses the equivalent static face to avoid the
/// variable-font rendering path; native keeps its approved font registration.
abstract final class AppFonts {
  static const nativeUi = 'Inter';
  static const webUi = 'InterWeb';
  static const ui = kIsWeb ? webUi : nativeUi;
}
