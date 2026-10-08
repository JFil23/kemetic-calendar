/*
 * ═══════════════════════════════════════════════════════════════
 *   KEMETIC DAY CARD DATA
 * ═══════════════════════════════════════════════════════════════
 *
 * Day cards are keyed by Kemetic month/day/decan and reused every year.
 *
 * Gregorian labels in the UI come from [KemeticDayData.calculateGregorianDate]
 * (day key + Kemetic year), not from static strings on each card.
 *
 * Heriu Renpet is the exception: leap years expose a sixth threshold day.
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

  /// Flow rows use the absolute month day (1–30), including later decans.
  static DecanDayInfo? getFlowForDay(String dayKey) {
    final day = _parseDayKey(dayKey)?.day;
    final info = getInfoForDay(dayKey);
    if (day == null || info == null) return null;
    for (final row in info.decanFlow) {
      if (row.day == day) return row;
    }
    return null;
  }

  static String calculateGregorianDate(String dayKey, {int? kYearParam}) =>
      _calculateGregorianDate(dayKey, kYearParam: kYearParam);
}
