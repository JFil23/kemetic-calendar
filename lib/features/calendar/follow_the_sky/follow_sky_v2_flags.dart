import 'package:flutter/foundation.dart';

/// Follow the Sky V2 routing flags.
///
/// Cut 2: [showDevEntry] exposes a debug entry beside V1.
/// Cut 3: [useV2Production] hard-switches catalog/detail to V2; then V1 is deleted.
class FollowSkyV2Flags {
  /// Production path uses V2 detail + enrollment.
  static bool useV2Production = true;

  /// Debug-only entry to open V2 while comparing (kept for tests / smoke).
  static bool get showDevEntry => kDebugMode;
}
