/*
 * ═══════════════════════════════════════════════════════════════
 *   ⚠️  KEMETIC YEAR 1 ONLY - HARDCODED DATES
 * ═══════════════════════════════════════════════════════════════
 *
 * Valid Period: March 20, 2025 - March 19, 2026 (Gregorian)
 *
 * Gregorian labels in the UI come from [KemeticDayData.calculateGregorianDate]
 * (day key + Kemetic year), not from static strings on each card.
 *
 * For multi-year support, see: docs/MULTI_YEAR_MIGRATION.md
 *
 * ═══════════════════════════════════════════════════════════════
 */

part of 'kemetic_day_info.dart';

/// Public facade for Kemetic day reference data.
class KemeticDayData {
  KemeticDayData._();

  static final Map<String, KemeticDayInfo> dayInfoMap = _dayInfoMap;

  static String? resolveDecanNameFromKey(
    String dayKey, {
    bool expanded = false,
  }) => _resolveDecanNameFromKey(dayKey, expanded: expanded);

  static KemeticDayInfo? getInfoForDay(String dayKey) => _getInfoForDay(dayKey);

  static String calculateGregorianDate(String dayKey, {int? kYearParam}) =>
      _calculateGregorianDate(dayKey, kYearParam: kYearParam);
}
