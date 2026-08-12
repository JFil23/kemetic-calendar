import 'package:shared_preferences/shared_preferences.dart';

/// User-scoped SharedPreferences keys with copy-never-drop migration.
///
/// Legacy global keys stay intact for at least one release so a code rollback
/// can still read them. Read path: user-scoped first, then global fallback.
class CalendarUserScopedPrefs {
  CalendarUserScopedPrefs._();

  static const String legacyManualDeleteTombstonesKey =
      'calendar:manual_delete_tombstones';
  static const String legacyEndedReminderIdsKey = 'reminder:ended_ids';

  static const String _userScopedMigrationDonePrefix =
      'calendar:user_scoped_prefs_v1';

  static String manualDeleteTombstonesKey(String userId) =>
      '$legacyManualDeleteTombstonesKey:$userId';

  static String endedReminderIdsKey(String userId) =>
      '$legacyEndedReminderIdsKey:$userId';

  static String userScopedMigrationDoneKey(String userId) =>
      '$_userScopedMigrationDonePrefix:$userId';

  /// Copy global lists into user-scoped keys if missing. Never deletes globals.
  static Future<void> ensureMigrated({
    required SharedPreferences prefs,
    required String userId,
  }) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return;

    final doneKey = userScopedMigrationDoneKey(trimmed);
    if (prefs.getBool(doneKey) == true) return;

    await _copyStringListIfAbsent(
      prefs: prefs,
      userKey: manualDeleteTombstonesKey(trimmed),
      legacyKey: legacyManualDeleteTombstonesKey,
    );
    await _copyStringListIfAbsent(
      prefs: prefs,
      userKey: endedReminderIdsKey(trimmed),
      legacyKey: legacyEndedReminderIdsKey,
    );
    await prefs.setBool(doneKey, true);
  }

  static Future<List<String>> readStringList({
    required SharedPreferences prefs,
    required String? userId,
    required String Function(String userId) userKey,
    required String legacyKey,
  }) async {
    final trimmed = userId?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      await ensureMigrated(prefs: prefs, userId: trimmed);
      final scoped = prefs.getStringList(userKey(trimmed));
      if (scoped != null) return List<String>.from(scoped);
    }
    return List<String>.from(
      prefs.getStringList(legacyKey) ?? const <String>[],
    );
  }

  static Future<void> writeStringList({
    required SharedPreferences prefs,
    required String? userId,
    required String Function(String userId) userKey,
    required String legacyKey,
    required List<String> values,
  }) async {
    final trimmed = userId?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      await ensureMigrated(prefs: prefs, userId: trimmed);
      await prefs.setStringList(userKey(trimmed), values);
      return;
    }
    await prefs.setStringList(legacyKey, values);
  }

  static Future<void> _copyStringListIfAbsent({
    required SharedPreferences prefs,
    required String userKey,
    required String legacyKey,
  }) async {
    if (prefs.containsKey(userKey)) return;
    final legacy = prefs.getStringList(legacyKey);
    if (legacy == null) return;
    await prefs.setStringList(userKey, List<String>.from(legacy));
  }
}
