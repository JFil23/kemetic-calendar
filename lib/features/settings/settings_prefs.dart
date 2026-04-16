import 'package:shared_preferences/shared_preferences.dart';

class SettingsPrefs {
  SettingsPrefs._();

  static const realTimeAlertsKey = 'settings:realTimeAlerts';
  static const autoCalendarSyncKey = 'settings:autoCalendarSync';
  static const usHolidaysEnabledKey = 'settings:usHolidaysEnabled';

  static const legacyCatchUpRemindersKey = 'settings:catchUpReminders';
  static const legacyMissedOnOpenKey = 'settings:missedOnOpen';
  static const legacyEndOfDaySummaryKey = 'settings:endOfDaySummary';

  static bool realTimeAlertsEnabledFrom(SharedPreferences prefs) {
    return prefs.getBool(realTimeAlertsKey) ?? false;
  }

  static bool autoCalendarSyncEnabledFrom(SharedPreferences prefs) {
    return prefs.getBool(autoCalendarSyncKey) ?? true;
  }

  static bool usHolidaysEnabledFrom(SharedPreferences prefs) {
    return prefs.getBool(usHolidaysEnabledKey) ?? false;
  }

  static Future<bool> realTimeAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return realTimeAlertsEnabledFrom(prefs);
  }

  static Future<bool> autoCalendarSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return autoCalendarSyncEnabledFrom(prefs);
  }

  static Future<void> clearLegacyReminderPrefs([
    SharedPreferences? prefs,
  ]) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.remove(legacyCatchUpRemindersKey);
    await store.remove(legacyMissedOnOpenKey);
    await store.remove(legacyEndOfDaySummaryKey);
  }
}
