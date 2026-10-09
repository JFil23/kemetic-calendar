import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPrefs {
  SettingsPrefs._();

  static const realTimeAlertsKey = 'settings:realTimeAlerts';
  static const usHolidaysEnabledKey = 'settings:usHolidaysEnabled';
  static const dailyCosmicContextBadgeEnabledKey =
      'settings:dailyCosmicContextBadgeEnabled';

  static final _dailyCosmicContextBadgeChanges = ValueNotifier<int>(0);
  static ValueListenable<int> get dailyCosmicContextBadgeChanges =>
      _dailyCosmicContextBadgeChanges;
  static Future<void>? _dailyCosmicContextWrite;

  /// Both surfaces share the deployed device preference and publish only
  /// acknowledged changes. Keep this outside bulk saves and warm-cache cleanup.
  static Future<void> setDailyCosmicContextBadgeEnabled(
    bool enabled, {
    SharedPreferences? prefs,
  }) {
    final previousWrite = _dailyCosmicContextWrite;
    final write = () async {
      if (previousWrite != null) await previousWrite;
      final store = prefs ?? await SharedPreferences.getInstance();
      final previous = dailyCosmicContextBadgeEnabledFrom(store);
      try {
        if (!await store.setBool(dailyCosmicContextBadgeEnabledKey, enabled)) {
          throw StateError('Day’s Rhythm preference was not saved');
        }
      } catch (_) {
        // SharedPreferences updates its in-memory cache before persistence.
        await store.reload();
        rethrow;
      }
      if (previous != enabled) _dailyCosmicContextBadgeChanges.value++;
    }();
    late final Future<void> tail;
    void release() {
      if (identical(_dailyCosmicContextWrite, tail)) {
        _dailyCosmicContextWrite = null;
      }
    }

    tail = write.then<void>(
      (_) => release(),
      onError: (Object _, StackTrace _) => release(),
    );
    _dailyCosmicContextWrite = tail;
    return write;
  }

  static const legacyCatchUpRemindersKey = 'settings:catchUpReminders';
  static const legacyMissedOnOpenKey = 'settings:missedOnOpen';
  static const legacyEndOfDaySummaryKey = 'settings:endOfDaySummary';

  static bool realTimeAlertsEnabledFrom(SharedPreferences prefs) {
    return prefs.getBool(realTimeAlertsKey) ?? false;
  }

  static bool usHolidaysEnabledFrom(SharedPreferences prefs) {
    return prefs.getBool(usHolidaysEnabledKey) ?? false;
  }

  static bool dailyCosmicContextBadgeEnabledFrom(SharedPreferences prefs) {
    return prefs.getBool(dailyCosmicContextBadgeEnabledKey) ?? true;
  }

  static Future<bool> realTimeAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return realTimeAlertsEnabledFrom(prefs);
  }

  static Future<bool> dailyCosmicContextBadgeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return dailyCosmicContextBadgeEnabledFrom(prefs);
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
