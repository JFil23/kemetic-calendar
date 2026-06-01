import 'package:mobile/core/day_key.dart';

/// Canonical decan metadata (names per month) used across the app.
class DecanMetadata {
  /// Short decan names keyed by Kemetic month (1–13).
  /// This is the single source of truth for decan ordering/names.
  static const Map<int, List<String>> decanNames = {
    1: ['tpy-ꜥ sbꜣw', 'ḥry-ib sbꜣw', 'sbꜣw'],
    2: ['ꜥḥꜣy', 'ḥry-ib ꜥḥꜣy', 'sbꜣ nfr'],
    3: ['sꜣḥ', 'ḥry-ib sꜣḥ', 'sbꜣ sꜣḥ'],
    4: ['msḥtjw', 'ḥry-ib msḥtjw', 'sbꜣ msḥtjw'],
    5: ['ḫnty-ḥr', 'ḥry-ib ḫnty-ḥr', 'sbꜣ ḫnty-ḥr'],
    6: ['knmw', 'ḥry-ib knmw', 'sbꜣ knmw'],
    7: ['špsswt', 'ḥry-ib špsswt', 'sbꜣ špsswt'],
    8: ['ꜥpdw', 'ḥry-ib ꜥpdw', 'sbꜣ ꜥpdw'],
    9: ['ẖry ꜥrt', 'rmn ḥry sꜣḥ', 'rmn ẖry sꜣḥ'],
    10: ['ḥr-sꜣḥ', 'ḥry-ib ḥr-sꜣḥ', 'sbꜣ ḥr-sꜣḥ'],
    11: ['sbꜣ nfr', 'ḥry-ib sbꜣ nfr', 'sbꜣ sbꜣ nfr'],
    12: ['msḥtjw ḫt', 'ḥry-ib msḥtjw ḫt', 'sbꜣ msḥtjw ḫt'],
  };

  /// Optional expanded titles (short → display).
  /// If a short name is missing here, the short name is returned.
  static const Map<String, String> decanTitles = {
    'tpy-ꜥ sbꜣw': 'tpy-ꜥ sbꜣw ("Foremost of the Stars")',
    'ḥry-ib sbꜣw': 'ḥry-ib sbꜣw ("Heart of the Stars")',
    'sbꜣw': 'sbꜣw ("The Stars")',
    'ꜥḥꜣy': 'ꜥḥꜣy ("The Riser")',
    'ḥry-ib ꜥḥꜣy': 'ḥry-ib ꜥḥꜣy ("Heart of the Riser")',
    'sbꜣ nfr': 'sbꜣ nfr ("The Beautiful Star")',
    'sꜣḥ': 'sꜣḥ ("Sah")',
    'ḥry-ib sꜣḥ': 'ḥry-ib sꜣḥ ("Heart of Sah")',
    'sbꜣ sꜣḥ': 'sbꜣ sꜣḥ ("Star of Sah")',
    'msḥtjw': 'msḥtjw ("The Foreleg")',
    'ḥry-ib msḥtjw': 'ḥry-ib msḥtjw ("Heart of the Foreleg")',
    'sbꜣ msḥtjw': 'sbꜣ msḥtjw ("Star of the Foreleg")',
    'ḫnty-ḥr': 'ḫnty-ḥr ("Foremost of the Sky")',
    'ḥry-ib ḫnty-ḥr': 'ḥry-ib ḫnty-ḥr ("Heart of the Foremost")',
    'sbꜣ ḫnty-ḥr': 'sbꜣ ḫnty-ḥr ("Star of the Foremost")',
    'knmw': 'knmw ("Khnum")',
    'ḥry-ib knmw': 'ḥry-ib knmw ("Heart of Khnum")',
    'sbꜣ knmw': 'sbꜣ knmw ("Star of Khnum")',
    'špsswt': 'špsswt ("The Noble Ones")',
    'ḥry-ib špsswt': 'ḥry-ib špsswt ("Heart of the Noble Ones")',
    'sbꜣ špsswt': 'sbꜣ špsswt ("Star of the Noble Ones")',
    'ꜥpdw': 'ꜥpdw ("The Birds")',
    'ḥry-ib ꜥpdw': 'ḥry-ib ꜥpdw ("Heart of the Birds")',
    'sbꜣ ꜥpdw': 'sbꜣ ꜥpdw ("Star of the Birds")',
    'ẖry ꜥrt': 'ẖry ꜥrt ("The One Beneath ꜥrt")',
    'rmn ḥry sꜣḥ': 'rmn ḥry sꜣḥ ("Shoulder Above Sah")',
    'rmn ẖry sꜣḥ': 'rmn ẖry sꜣḥ ("Shoulder Beneath Sah")',
    'ḥr-sꜣḥ': 'ḥr-sꜣḥ ("Heru upon Sah")',
    'ḥry-ib ḥr-sꜣḥ': 'ḥry-ib ḥr-sꜣḥ ("Heart of Heru upon Sah")',
    'sbꜣ ḥr-sꜣḥ': 'sbꜣ ḥr-sꜣḥ ("Star of Heru upon Sah")',
    'ḥry-ib sbꜣ nfr': 'ḥry-ib sbꜣ nfr ("Heart of the Beautiful Star")',
    'sbꜣ sbꜣ nfr': 'sbꜣ sbꜣ nfr ("Star of the Beautiful Star")',
    'msḥtjw ḫt': 'msḥtjw ḫt ("The Crocodiles of the Offering")',
    'ḥry-ib msḥtjw ḫt':
        'ḥry-ib msḥtjw ḫt ("Heart of the Crocodiles of the Offering")',
    'sbꜣ msḥtjw ḫt': 'sbꜣ msḥtjw ḫt ("Star of the Crocodiles of the Offering")',
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
    final short =
        (names != null && decanIndex >= 0 && decanIndex < names.length)
        ? names[decanIndex]
        : 'Decan ${decanIndex + 1}';
    if (!expanded) return short;
    return decanTitles[short] ?? short;
  }
}
