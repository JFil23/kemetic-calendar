import 'package:mobile/core/day_key.dart';

/// Canonical decan metadata (names per month) used across the app.
class DecanMetadata {
  /// Short decan names keyed by Kemetic month (1–13).
  /// This is the single source of truth for decan ordering/names.
  static const Map<int, List<String>> decanNames = {
    1: ['tpy-ꜣ sbꜣw', 'ḥry-ib sbꜣw', 'sbꜣw'],
    2: ['ꜥḥꜣy', 'ḥry-ib ꜥḥꜣy', 'sbꜣ nfr'],
    3: ['sꜣḥ', 'ḥry-ib sꜣḥ', 'sbꜣ sꜣḥ'],
    4: ['msḥtjw', 'ḥry-ib msḥtjw', 'sbꜣ msḥtjw'],
    5: ['ḫnty-ḥr', 'ḥry-ib ḫnty-ḥr', 'sbꜣ ḫnty-ḥr'],
    6: ['knmw', 'ḥry-ib knmw', 'sbꜣ knmw'],
    7: ['špsswt', 'ḥry-ib špsswt', 'sbꜣ špsswt'],
    8: ['ꜥpdw', 'ḥry-ib ꜥpdw', 'sbꜣ ꜥpdw'],
    9: ['ẖry ꜥrt', 'rmn ḥry sꜣḥ', 'rmn ẖry sꜣḥ'],
    10: ['ḥr-sꜣḥ', 'ḥry-ib ḥr-sꜣḥ', 'sbꜣ ḥr-sꜣḥ'],
    11: ['sbꜣ nfr', 'ḥry-ib sbꜣ nfr', 'tpy-ꜣ spdt'],
    12: ['msḥtjw ḫt', 'ḥry-ib msḥtjw ḫt', 'sbꜣ msḥtjw ḫt'],
  };

  /// Optional expanded titles (short → display).
  /// If a short name is missing here, the short name is returned.
  static const Map<String, String> decanTitles = {
    'tpy-ꜣ sbꜣw': 'tpy-ꜣ sbꜣw ("Foremost of the Stars")',
    'ḥry-ib sbꜣw': 'ḥry-ib sbꜣw ("Heart of the Stars")',
    'sbꜣw': 'sbꜣw ("The Stars")',
    'msḥtjw ḫt': 'msḥtjw ḫt ("The Sacred Foreleg")',
    'ḥry-ib msḥtjw ḫt': 'ḥry-ib msḥtjw ḫt ("Heart of the Sacred Foreleg")',
    'sbꜣ msḥtjw ḫt': 'sbꜣ msḥtjw ḫt ("Star of the Sacred Foreleg")',
  };

  /// Resolve the decan name for a given month/day.
  /// [expanded] toggles using [decanTitles] when available.
  static String decanNameFor({
    required int kMonth,
    required int kDay,
    bool expanded = false,
  }) {
    final decanIndex = decanForDay(kDay) - 1;
    final names = decanNames[kMonth];
    final short = (names != null && decanIndex >= 0 && decanIndex < names.length)
        ? names[decanIndex]
        : 'Decan ${decanIndex + 1}';
    if (!expanded) return short;
    return decanTitles[short] ?? short;
  }
}
