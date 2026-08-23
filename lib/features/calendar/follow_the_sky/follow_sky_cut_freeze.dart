/// Follow the Sky V2 cut freeze markers.
///
/// - Cut 1 original brain freeze: `7685e1373b0fd33f7b12bff14120565cbc793ff2`
/// - Cut 1.1 (eclipse-precedence observing nights): `23093cf0b7133168f1ac37f695b3c107148947c7`
/// - Cut 1.2 (Protect-attributed measurement without Connect): recorded by
///   the `cut1.2-frozen` checkpoint commit; [cut12FrozenSha] is updated to that
///   commit SHA immediately after the freeze lands.
/// - Cut 2 (real user journey: course → turning → function → choice → ritual →
///   history): same pattern, `cut2-frozen` / [cut2FrozenSha].
/// - Cut 3 (hard cutover to V2 + non-destructive migration policy): same
///   pattern, `cut3-frozen` / [cut3FrozenSha].
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
  static const String cut12FrozenSha = 'bb56665c7aba953d90d95bdc3f63735454425051';

  static const String cut12Summary =
      'CourseMeasurementService measures attributed intervals without Connect; '
      'CourseFunctionService: Measure+Turn may use Protect intervals; '
      'Reconsider+Reveal still require a concrete linked/deferred/open object.';

  /// Cut 2 — the real user journey on live calendar + catalog data.
  /// Domain catalog / observing-night brain from Cut 1.1 and the evidence rules
  /// from Cut 1.2 are unchanged. Filled by the post-freeze recording commit.
  static const String cut2FrozenSha = '20a63d0c0d44aa98b0661aeee79544f8c285f70b';

  static const String cut2Summary =
      'FollowSkyCourseAttribution owns Protect/Connect measurement attribution; '
      'Protect Time proved through the persistence codec (stamp survives edit '
      'and move, deletion stops measurement, never a Flow); '
      'five functions distinct with and without an evidence object; '
      'completed functions end in a ritual and enter session turning history; '
      'the Ma’at dock is the single primary advance path.';

  /// Temporary Cut 2 runtime stamp for proving the simulator loaded this tree.
  /// Bump the suffix whenever diagnosing stale sessions. Debug-only consumers.
  static const String cut2RuntimeStamp =
      'cut2-freeze-20260822a';

  /// Cut 3 — V2 is the only Follow the Sky. Filled by the post-freeze commit.
  static const String cut3FrozenSha = '6c72b2d3206c96cf5a4eeba379e45ccafae6ee4b';

  static const String cut3Summary =
      'V1 Track Sky detail scaffold, join sheet and category tiles deleted; '
      'FollowSkyV2Flags routing fork removed so track-the-sky reaches V2 only; '
      'stale assets/ma_at_flows pubspec entry and legacy assetPath dropped; '
      'FollowSkyMigrationApplicator stamps V2 ownership on matched legacy '
      'futures without rewriting title/time; replace/add stay deferred.';

  /// Temporary Cut 3 runtime stamp for proving the simulator loaded this tree.
  static const String cut3RuntimeStamp = 'cut3-freeze-20260822a';

  /// Cut 3 answer to the replace/add ambiguity: **do not rewrite or add**.
  /// Stamp ownership only. V1 never recorded as-generated title/time, so
  /// "untouched" cannot be proven; unmatched futures must not get a second
  /// catalog row. [FollowSkyMigrationPolicy] encodes that; the host applies
  /// [FollowSkyMigrationPlan.stamps] only.
  static const bool cut3MigrationApplyPending = false;
}
