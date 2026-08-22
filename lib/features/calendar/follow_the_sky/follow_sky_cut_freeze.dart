/// Follow the Sky V2 cut freeze markers.
///
/// - Cut 1 original brain freeze: `7685e1373b0fd33f7b12bff14120565cbc793ff2`
/// - Cut 1.1 (eclipse-precedence observing nights): recorded after the freeze
///   commit that introduces [SkyObservingNight] + companion metadata. Update
///   [cut11FrozenSha] immediately after that commit lands.
library;

class FollowSkyCutFreeze {
  /// Original Cut 1 immutable baseline (pre eclipse-precedence).
  static const String cut1FrozenSha =
      '7685e1373b0fd33f7b12bff14120565cbc793ff2';

  /// Current approved brain after lunar-eclipse override → Reconsider.
  /// Placeholder filled by freeze commit / post-commit update.
  static const String cut11FrozenSha = 'PENDING_CUT_1_1_FREEZE';

  static const String cut11Summary =
      '70 canonical events → 65 observing nights; '
      'Full Moon + lunar eclipse resolves to Reconsider; '
      'companion eclipse IDs persist in track_sky_v2 ownership metadata.';
}
