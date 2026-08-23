/// Follow the Sky V2 cut freeze markers.
///
/// - Cut 1 original brain freeze: `7685e1373b0fd33f7b12bff14120565cbc793ff2`
/// - Cut 1.1 (eclipse-precedence observing nights): `23093cf0b7133168f1ac37f695b3c107148947c7`
/// - Cut 1.2 (Protect-attributed measurement without Connect): recorded by
///   the `cut1.2-frozen` checkpoint commit; [cut12FrozenSha] is updated to that
///   commit SHA immediately after the freeze lands.
library;

class FollowSkyCutFreeze {
  /// Original Cut 1 immutable baseline (pre eclipse-precedence).
  static const String cut1FrozenSha = '7685e1373b0fd33f7b12bff14120565cbc793ff2';

  /// Approved brain after lunar-eclipse override → Reconsider.
  static const String cut11FrozenSha = '23093cf0b7133168f1ac37f695b3c107148947c7';

  static const String cut11Summary =
      '70 canonical events → 65 observing nights; '
      'Full Moon + lunar eclipse resolves to Reconsider; '
      'companion eclipse IDs persist in track_sky_v2 ownership metadata.';

  /// Cut 1.2 — host-attributed intervals measure without Connect.
  /// Domain catalog / observing-night brain from Cut 1.1 is unchanged.
  /// Placeholder filled by the Cut 1.2 freeze commit / post-commit update.
  static const String cut12FrozenSha = 'PENDING_CUT12_FREEZE_SHA';

  static const String cut12Summary =
      'CourseMeasurementService measures attributed intervals without Connect; '
      'CourseFunctionService: Measure+Turn may use Protect intervals; '
      'Reconsider+Reveal still require a concrete linked/deferred/open object.';

  /// Temporary Cut 2 runtime stamp for proving the simulator loaded this tree.
  /// Bump the suffix whenever diagnosing stale sessions. Debug-only consumers.
  static const String cut2RuntimeStamp =
      'cut2-cut12-freeze-20260822g';
}
