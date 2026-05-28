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

  static String calculateGregorianDate(String dayKey, {int? kYearParam}) =>
      _calculateGregorianDate(dayKey, kYearParam: kYearParam);
}
