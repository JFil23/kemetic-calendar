import 'decan_metadata.dart';
import 'kemetic_month_metadata.dart';

/// Speech-only pronunciation overrides for TTS. Keep UI labels untouched.
final Map<int, String> monthSpeechNames = Map.unmodifiable({
  for (final m in kKemeticMonths.skip(1)) m.id: m.speechName,
});

/// Decan speech ids: id = (monthIndex - 1) * 3 + decanInMonth (1..3), monthIndex 1..12.
const Map<int, String> decanSpeechNames = {
  // Month 1
  1: 'Tepi-a Sebau',      // tpy-ꜣ sbꜣw
  2: 'Hree-ib Sebau',     // ḥry-ib sbꜣw
  3: 'Sebau',             // sbꜣw

  // Month 2
  4: 'Ahai',              // ꜥḥꜣy
  5: 'Hree-ib Ahai',      // ḥry-ib ꜥḥꜣy
  6: 'Seba Nefer',        // sbꜣ nfr

  // Month 3
  7: 'Sah',               // sꜣḥ
  8: 'Hree-ib Sah',       // ḥry-ib sꜣḥ
  9: 'Seba Sah',          // sbꜣ sꜣḥ

  // Month 4
  10: 'Meshetyu',         // msḥtjw
  11: 'Hree-ib Meshetyu', // ḥry-ib msḥtjw
  12: 'Seba Meshetyu',    // sbꜣ msḥtjw

  // Month 5
  13: 'Khenty-Her',       // ḫnty-ḥr
  14: 'Hree-ib Khenty-Her', // ḥry-ib ḫnty-ḥr
  15: 'Seba Khenty-Her',  // sbꜣ ḫnty-ḥr

  // Month 6
  16: 'Khnum',            // knmw
  17: 'Hree-ib Khnum',    // ḥry-ib knmw
  18: 'Seba Khnum',       // sbꜣ knmw

  // Month 7
  19: 'Shepsesut',        // špsswt
  20: 'Hree-ib Shepsesut', // ḥry-ib špsswt
  21: 'Seba Shepsesut',   // sbꜣ špsswt

  // Month 8
  22: 'Apedu',            // ꜥpdw
  23: 'Hree-ib Apedu',    // ḥry-ib ꜥpdw
  24: 'Seba Apedu',       // sbꜣ ꜥpdw

  // Month 9
  25: 'Khery Aret',       // ẖry ꜥrt
  26: 'Remen Hree Sah',   // rmn ḥry sꜣḥ
  27: 'Remen Khery Sah',  // rmn ẖry sꜣḥ

  // Month 10
  28: 'Her-Sah',          // ḥr-sꜣḥ
  29: 'Hree-ib Her-Sah',  // ḥry-ib ḥr-sꜣḥ
  30: 'Seba Her-Sah',     // sbꜣ ḥr-sꜣḥ

  // Month 11
  31: 'Seba Nefer',       // sbꜣ nfr
  32: 'Hree-ib Seba Nefer', // ḥry-ib sbꜣ nfr
  33: 'Tepi-a Sopdet',    // tpy-ꜣ spdt

  // Month 12
  34: 'Meshetyu Khet',    // msḥtjw ḫt
  35: 'Hree-ib Meshetyu Khet', // ḥry-ib msḥtjw ḫt
  36: 'Seba Meshetyu Khet', // sbꜣ msḥtjw ḫt
};

/// Fallbacks when only generic decan labels are available.
const Map<String, String> decanSpeechFallbackLabels = {
  'Decan 1': 'Decan One',
  'Decan 2': 'Decan Two',
  'Decan 3': 'Decan Three',
};

/// Lookup by visible decan label (short transliteration) for quick speech resolution.
final Map<String, String> decanSpeechNamesByLabel = Map.unmodifiable({
  for (final entry in decanSpeechNames.entries)
    _labelForDecanId(entry.key): entry.value,
  ...decanSpeechFallbackLabels,
});

String _labelForDecanId(int decanId) {
  if (decanId < 1 || decanId > 36) return 'Decan 1';
  final monthIndex = ((decanId - 1) ~/ 3) + 1;
  final decanIndex = (decanId - 1) % 3;
  final names = DecanMetadata.decanNames[monthIndex];
  if (names != null && decanIndex < names.length) {
    return names[decanIndex];
  }
  return 'Decan ${decanIndex + 1}';
}
