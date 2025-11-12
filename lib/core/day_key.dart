// lib/core/day_key.dart
// 
// CANONICAL DAY KEY GENERATION
// This is the single source of truth for building day keys that match dayInfoMap.
//
// Why this file exists:
// - dayInfoMap uses specific month prefixes that don't always match kemetic_month_metadata.dart
// - We need consistent key generation across calendar_page.dart and day_view.dart
// - Centralizing this logic prevents future mismatches
//
// Format: "<monthKey>_<day>_<decan>"
// Example: "paophi_11_2" means Month 2 (Paophi), Day 11, Decan 2
//
// IMPORTANT CONSTRAINTS:
// - DO NOT import this file back into kemetic_month_metadata.dart (avoid import cycles)

import 'package:mobile/features/calendar/kemetic_month_metadata.dart';

// =============================================================================
// MONTH KEY OVERRIDES
// =============================================================================
// These 5 months have different prefixes in dayInfoMap vs kemetic_month_metadata.dart
// 
// Technical debt: When you normalize either the data or the metadata, remove this
// map and rely solely on getMonthById(m).key for all months.
//
// CRITICAL: Keys are CASE-SENSITIVE and must match dayInfoMap exactly.
// DO NOT change casing or "fix" capitalization - these match the data as-is.
//
// Current mismatches:
// Month  | Metadata Key  | Data Prefix | Data Lines   | Days Affected
// -------|---------------|-------------|--------------|---------------
// 2      | 'paopi'       | 'paophi'    | 1262-2247    | 30 days
// 5      | 'shefbedet'   | 'sefbedet'  | 4436-5513    | 30 days
// 10     | 'hentihet'    | 'henti'     | 7970-8461    | 30 days
// 11     | 'paipi'       | 'ipt'       | 8611-9227    | 30 days
// 12     | 'mesutra'     | 'mswtRa'    | 9252-9455    | 30 days (note capital R!)
const Map<int, String> _monthKeyOverride = {
  2:  'paophi',    // Paopi/Paophi
  5:  'sefbedet',  // Šef-Bedet/Sefbedet  
  10: 'henti',     // Ḥenti-ḥet/Henti
  11: 'ipt',       // Pa-Ipi/IPT
  12: 'mswtRa',    // Mesut-Ra/MSWT-Ra (CASE-SENSITIVE: capital R!)
};

/// Returns the month key prefix used in dayInfoMap lookups.
/// 
/// Uses override for months 2, 5, 10, 11, 12 (due to data/metadata mismatch).
/// Falls back to kemetic_month_metadata.dart key for all other months.
String monthKeyFor(int kMonth) {
  return _monthKeyOverride[kMonth] ?? getMonthById(kMonth).key;
}

/// Computes decan (1, 2, or 3) from Kemetic day number (1-30).
/// 
/// Decan calculation:
/// - Days 1-10:  Decan 1
/// - Days 11-20: Decan 2
/// - Days 21-30: Decan 3
/// 
/// Examples:
/// - decanForDay(1)  → 1
/// - decanForDay(10) → 1
/// - decanForDay(11) → 2
/// - decanForDay(30) → 3
int decanForDay(int kDay) {
  return ((kDay - 1) ~/ 10) + 1;
}

/// Builds the canonical day key format used in dayInfoMap.
/// 
/// Format: "<monthKey>_<day>_<decan>"
/// 
/// Examples:
/// - kemeticDayKey(1, 15)  → "thoth_15_2"
/// - kemeticDayKey(2, 11)  → "paophi_11_2"  (uses override)
/// - kemeticDayKey(10, 25) → "henti_25_3"   (uses override)
/// 
/// This function is used by:
/// - calendar_page.dart: Building keys for calendar grid day chips
/// - day_view.dart: Building keys for detail view long-press
String kemeticDayKey(int kMonth, int kDay) {
  final prefix = monthKeyFor(kMonth);
  final decan = decanForDay(kDay);
  return '${prefix}_${kDay}_$decan';
}

// =============================================================================
// EPAGOMENAL DAYS (Month 13) - NOT SUPPORTED IN dayInfoMap
// =============================================================================
// NOTE: Epagomenal days (Heriu Renpet - the 5-6 sacred transition days) use
// a DIFFERENT key format in the codebase:
//
//   Format: 'epagomenal_{day}_{year}'
//   Example: 'epagomenal_1_2025'
//
// These keys do NOT exist in dayInfoMap. Long-press will not show detail cards
// for epagomenal days. This is by design - these sacred days are treated as
// special transition periods outside the normal calendar structure.
//
// Location: calendar_page.dart line ~4998
//
// DO NOT change epagomenal key generation - it is intentionally separate.
// =============================================================================




