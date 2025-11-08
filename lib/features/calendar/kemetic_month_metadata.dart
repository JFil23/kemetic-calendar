import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// KEMETIC MONTH METADATA - SINGLE SOURCE OF TRUTH
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// ⚠️ API STABILITY RULES:
/// - Month IDs (1-13) are STABLE and NEVER change
/// - Display text (labels, transliterations) MAY change for accuracy
/// - Always store/query by ID, never by text
/// - All logic MUST use IDs or enum values, NEVER strings
///
/// This file centralizes all month data to prevent the historical bug where
/// Month 2's transliteration was incorrectly shown as 'Pȝ ỉp.t' (which belongs
/// to Month 11). The fix: Month 2 = 'Mnḫt', Month 11 = 'ỉpt-ḥmt'.
/// ═══════════════════════════════════════════════════════════════════════════

/// Kemetic calendar seasons
/// 
/// ⚠️ NEVER store season.name in database - store monthId only.
/// Season can be derived from monthId via getMonthById(id).season
enum KemeticSeason {
  akhet('Akhet', 'Inundation'),
  peret('Peret', 'Emergence'),
  shemu('Shemu', 'Harvest'),
  transition('Transition', 'Days upon the Year');

  final String label;
  final String meaning;
  const KemeticSeason(this.label, this.meaning);
}

/// Immutable month data container
@immutable
class KemeticMonth {
  final int id; // 1-13, STABLE identifier
  final String key; // Lowercase stable key for routing/deep links
  final String displayShort; // UI: Short name
  final String displayTransliteration; // UI: Egyptological transliteration
  final String transliterationFull; // UI: Full readable form
  final String hellenized; // UI: Greek/Coptic form
  final KemeticSeason season; // Derived enum
  final List<String> searchAliases; // All known variants for search/migration

  const KemeticMonth({
    required this.id,
    required this.key,
    required this.displayShort,
    required this.displayTransliteration,
    required this.transliterationFull,
    required this.hellenized,
    required this.season,
    required this.searchAliases,
  });

  String get displayFull => '$displayShort ($displayTransliteration)';

  bool matches(String query) {
    final normalized = normalizeForMatch(query);
    if (normalized.isEmpty) return false;
    return searchAliases.any((a) => normalizeForMatch(a) == normalized);
  }
  
  /// Get normalized aliases for this month (cached per instance)
  Set<String> get _normalizedAliases => 
      searchAliases.map(normalizeForMatch).toSet();

  @override
  String toString() => 'KemeticMonth($id: $displayShort)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is KemeticMonth && id == other.id);

  @override
  int get hashCode => id.hashCode;
}

/// Public normalization function for matching
/// Strips diacritics, collapses separators, handles precomposed characters
@visibleForTesting
String normalizeForMatch(String s) {
  final t = s.toLowerCase().trim();
  
  // Strip combining marks (U+0300-U+036F)
  final noCombining = t.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  
  // Replace common Egyptological precomposed characters with ASCII
  final asciiMapped = noCombining
      .replaceAll('ḫ', 'kh').replaceAll('Ḫ', 'kh')
      .replaceAll('ḥ', 'h').replaceAll('Ḥ', 'h')
      .replaceAll('ḏ', 'dj').replaceAll('Ḏ', 'dj')
      .replaceAll('ȝ', 'a').replaceAll('Ȝ', 'a')
      .replaceAll('ꜥ', 'a').replaceAll('Ꜥ', 'a')
      .replaceAll('š', 's').replaceAll('Š', 's')
      .replaceAll('ṯ', 't').replaceAll('Ṯ', 't');
  
  // Remove zero-width characters
  final noZeroWidth = asciiMapped.replaceAll(
    RegExp(r'[\u200B-\u200D\uFEFF]'), ''
  );
  
  // Normalize smart quotes and dashes
  final smartFold = noZeroWidth
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'")
      .replaceAll('\u201C', '"')
      .replaceAll('\u201D', '"')
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-')
      .replaceAll('\u2032', "'")
      .replaceAll('\u2033', '"');
  
  // Remove ALL non-alphanumeric characters (including parentheses, brackets, etc.)
  return smartFold.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

/// Canonical month data - SINGLE SOURCE OF TRUTH
/// Index 0 is sentinel; months are 1-indexed (DO NOT reorder)
const List<KemeticMonth> kKemeticMonths = [
  // Sentinel (index 0) - never used
  KemeticMonth(
    id: 0,
    key: 'none',
    displayShort: '',
    displayTransliteration: '',
    transliterationFull: '',
    hellenized: '',
    season: KemeticSeason.transition,
    searchAliases: [],
  ),
  
  // Month 1: Thoth
  KemeticMonth(
    id: 1,
    key: 'thoth',
    displayShort: 'Thoth',
    displayTransliteration: 'Ḏḥwty',
    transliterationFull: 'Djehuty',
    hellenized: 'Thoth',
    season: KemeticSeason.akhet,
    searchAliases: [
      'Thoth', 'Ḏḥwty', 'Djehuty', 'Tekh', 'Tḫy',
      'Dhwty', 'Thout', 'Thōth',
    ],
  ),
  
  // Month 2: Paopi - 🔥 THE PRIMARY FIX
  KemeticMonth(
    id: 2,
    key: 'paopi',
    displayShort: 'Paopi',
    displayTransliteration: 'Mnḫt', // ✅ CORRECTED from 'Pȝ ỉp.t'
    transliterationFull: 'Menkhet',
    hellenized: 'Phaophi',
    season: KemeticSeason.akhet,
    searchAliases: [
      'Paopi', 'Mnḫt', 'Menkhet', 'Phaophi',
      'Pa-en-Mekh', 'Paenmekh', 'Mnkht', 'Menkhet',
    ],
  ),
  
  // Month 3: Hathor
  KemeticMonth(
    id: 3,
    key: 'hathor',
    displayShort: 'Hathor',
    displayTransliteration: 'Ḥwt-Ḥr',
    transliterationFull: 'Hwt-Hr',
    hellenized: 'Athyr',
    season: KemeticSeason.akhet,
    searchAliases: [
      'Hathor', 'Ḥwt-Ḥr', 'Hwt-Hr', 'Athyr', 'Hwthr',
    ],
  ),
  
  // Month 4: Ka-ḥer-Ka
  KemeticMonth(
    id: 4,
    key: 'kaherka',
    displayShort: 'Ka-ḥer-Ka',
    displayTransliteration: 'Kȝ-ḥr-Kȝ',
    transliterationFull: 'Ka-her-Ka',
    hellenized: 'Choiak',
    season: KemeticSeason.akhet,
    searchAliases: [
      'Ka-ḥer-Ka', 'Ka-her-Ka', 'Kȝ-ḥr-Kȝ', 'Choiak', 'Kaherka',
    ],
  ),
  
  // Month 5: Šef-Bedet
  KemeticMonth(
    id: 5,
    key: 'shefbedet',
    displayShort: 'Šef-Bedet',
    displayTransliteration: 'Šf-bdt',
    transliterationFull: 'Shef-Bedet',
    hellenized: 'Tybi',
    season: KemeticSeason.peret,
    searchAliases: [
      'Šef-Bedet', 'Shef-Bedet', 'Šf-bdt', 'Tybi', 'Shefbedet',
    ],
  ),
  
  // Month 6: Rekh-Wer
  KemeticMonth(
    id: 6,
    key: 'rekhwer',
    displayShort: 'Rekh-Wer',
    displayTransliteration: 'Rḫ-wr',
    transliterationFull: 'Rekh-Wer',
    hellenized: 'Mechir',
    season: KemeticSeason.peret,
    searchAliases: [
      'Rekh-Wer', 'Rekhwer', 'Rḫ-wr', 'Mechir',
    ],
  ),
  
  // Month 7: Rekh-Nedjes
  KemeticMonth(
    id: 7,
    key: 'rekhnedjes',
    displayShort: 'Rekh-Nedjes',
    displayTransliteration: 'Rḫ-nḏs',
    transliterationFull: 'Rekh-Nedjes',
    hellenized: 'Phamenoth',
    season: KemeticSeason.peret,
    searchAliases: [
      'Rekh-Nedjes', 'Rekhnedjes', 'Rekhndjes', 
      'Rḫ-nḏs', 'Phamenoth',
    ],
  ),
  
  // Month 8: Renwet
  KemeticMonth(
    id: 8,
    key: 'renwet',
    displayShort: 'Renwet',
    displayTransliteration: 'Rnnwt',
    transliterationFull: 'Renenutet',
    hellenized: 'Pharmuthi',
    season: KemeticSeason.peret,
    searchAliases: [
      'Renwet', 'Rnnwt', 'Renenutet', 'Pharmuthi',
    ],
  ),
  
  // Month 9: Hnsw
  KemeticMonth(
    id: 9,
    key: 'hnsw',
    displayShort: 'Hnsw',
    displayTransliteration: 'Ḥnsw',
    transliterationFull: 'Khonsu',
    hellenized: 'Pachons',
    season: KemeticSeason.shemu,
    searchAliases: [
      'Hnsw', 'Ḥnsw', 'Khonsu', 'Pachons',
    ],
  ),
  
  // Month 10: Ḥenti-ḥet
  KemeticMonth(
    id: 10,
    key: 'hentihet',
    displayShort: 'Ḥenti-ḥet',
    displayTransliteration: 'Ḥnt-ḥtj',
    transliterationFull: 'Henti-het',
    hellenized: 'Payni',
    season: KemeticSeason.shemu,
    searchAliases: [
      'Ḥenti-ḥet', 'Henti-het', 'Ḥnt-ḥtj', 'Payni', 'Hentihet',
    ],
  ),
  
  // Month 11: Pa-Ipi
  // ⚠️ CRITICAL: Pȝ ỉp.t belongs HERE (was incorrectly in Month 2)
  KemeticMonth(
    id: 11,
    key: 'paipi',
    displayShort: 'Pa-Ipi',
    displayTransliteration: 'ỉpt-ḥmt',
    transliterationFull: 'Ipet-hemet',
    hellenized: 'Epiphi',
    season: KemeticSeason.shemu,
    searchAliases: [
      'Pa-Ipi', 'Paipi', 'ỉpt-ḥmt', 'Ipet-hemet', 'Epiphi',
      'Pȝ ỉp.t', 'Pa ip.t', 'Pa-ipt', 'Paipt', 'ipt',
    ],
  ),
  
  // Month 12: Mesut-Ra
  KemeticMonth(
    id: 12,
    key: 'mesutra',
    displayShort: 'Mesut-Ra',
    displayTransliteration: 'Mswt-Rꜥ',
    transliterationFull: 'Mesut-Ra',
    hellenized: 'Mesore',
    season: KemeticSeason.shemu,
    searchAliases: [
      'Mesut-Ra', 'Mesutra', 'Mswt-Rꜥ', 'Mesore',
    ],
  ),
  
  // Month 13: Epagomenal Days
  KemeticMonth(
    id: 13,
    key: 'epagomenal',
    displayShort: 'Heriu Renpet',  // ✅ FIX 3: Changed from 'Epagomenal'
    displayTransliteration: 'ḥr.w rnpt',
    transliterationFull: 'Heriu Renpet',
    hellenized: 'Epagomenai',
    season: KemeticSeason.transition,
    searchAliases: [
      'Epagomenal', 'ḥr.w rnpt', 'Heriu Renpet', 'Epagomenai',
      'Days upon the Year', 'Heriu-Renpet',
    ],
  ),
];

/// Build alias lookup map with collision detection
/// Throws in ALL build modes (not just debug) to prevent silent data loss
Map<String, int> _buildAliasMap() {
  final tmp = <String, int>{};
  
  for (final m in kKemeticMonths.skip(1)) {
    for (final alias in m.searchAliases) {
      final key = normalizeForMatch(alias);
      
      if (tmp.containsKey(key)) {
        // ✅ THROWS in release too - critical data integrity
        throw StateError(
          'ALIAS COLLISION: "$alias" (normalized: "$key") '
          'maps to both Month ${tmp[key]} and Month ${m.id}. '
          'Fix searchAliases in kemetic_month_metadata.dart'
        );
      }
      
      tmp[key] = m.id;
    }
  }
  
  return Map.unmodifiable(tmp);
}

/// Cached alias lookup - built once at app start
final Map<String, int> _aliasToId = _buildAliasMap();

/// Legacy key redirects (for old deep links/storage)
const Map<String, String> _legacyKeyRedirects = {
  'rekhned jes': 'rekhnedjes', // Fixed space in key
};

/// Test helper - exposes map size without exposing map itself
@visibleForTesting
int aliasIndexSize() => _aliasToId.length;

/// Test helper - rebuild alias map for performance testing
@visibleForTesting
Map<String, int> rebuildAliasMapForTest() => _buildAliasMap();

/// PRIMARY API: Get month by ID (1-13)
/// Throws RangeError if invalid
KemeticMonth getMonthById(int id) {
  if (id < 1 || id > 13) {
    throw RangeError.range(id, 1, 13, 'monthId', 'Month ID must be 1-13');
  }
  assert(kKemeticMonths[id].id == id, 'Array misalignment at index $id');
  return kKemeticMonths[id];
}

/// Get month by stable key (for deep links/routing)
/// Returns null if not found
KemeticMonth? getMonthByKey(String key) {
  final normalized = normalizeForMatch(key);
  final redirected = _legacyKeyRedirects[normalized] ?? normalized;
  
  try {
    return kKemeticMonths.firstWhere((m) => m.key == redirected);
  } catch (_) {
    if (kDebugMode) print('⚠️ Unknown month key: "$key"');
    return null;
  }
}

/// Resolve month ID from any alias (for search/migration)
/// Returns null if not found, logs in debug mode
int? monthIdFromAlias(String alias) {
  final id = _aliasToId[normalizeForMatch(alias)];
  if (id == null && kDebugMode) {
    print('⚠️ Unknown month alias: "$alias"');
  }
  return id;
}

/// Search months with intelligent ranking
/// Priority: exact > prefix > contains
/// Results are deterministic (sorted by ID within each tier)
List<KemeticMonth> searchMonths(String query, {int maxResults = 5}) {
  final normalized = normalizeForMatch(query);
  if (normalized.isEmpty) return [];
  
  // Tier 1: Exact match
  final exactId = _aliasToId[normalized];
  if (exactId != null) return [getMonthById(exactId)];
  
  // Tier 2: Prefix matches (sorted by ID)
  final prefixMatches = kKemeticMonths
      .skip(1)
      .where((m) => m._normalizedAliases.any((a) => a.startsWith(normalized)))
      .toList()
    ..sort((a, b) {
      final idCmp = a.id.compareTo(b.id);
      return idCmp != 0 ? idCmp : a.key.compareTo(b.key);
    });
  
  if (prefixMatches.isNotEmpty) {
    return prefixMatches.take(maxResults).toList();
  }
  
  // Tier 3: Contains matches (sorted by ID)
  final containsMatches = kKemeticMonths
      .skip(1)
      .where((m) => m._normalizedAliases.any((a) => a.contains(normalized)))
      .toList()
    ..sort((a, b) {
      final idCmp = a.id.compareTo(b.id);
      return idCmp != 0 ? idCmp : a.key.compareTo(b.key);
    });
  
  return containsMatches.take(maxResults).toList();
}

/// Season helper functions - use these instead of string comparisons
bool isAkhet(int monthId) => getMonthById(monthId).season == KemeticSeason.akhet;
bool isPeret(int monthId) => getMonthById(monthId).season == KemeticSeason.peret;
bool isShemu(int monthId) => getMonthById(monthId).season == KemeticSeason.shemu;
bool isEpagomenal(int monthId) => monthId == 13;

/// Get season name for display (use this instead of accessing enum directly)
String getSeasonName(int monthId) => getMonthById(monthId).season.label;

/// DEPRECATED: Old compatibility shims (removed in next major release)
@Deprecated('Use getMonthById(id).hellenized - removes in v3.0')
Map<int, String> get kemeticMonthsHellenized => {
  for (var m in kKemeticMonths.skip(1)) m.id: m.hellenized,
};

@Deprecated('Use getMonthById(id).displayFull - removes in v3.0')
List<String> get monthNamesCompat => [
  '',
  ...kKemeticMonths.skip(1).map((m) => m.displayFull),
];

