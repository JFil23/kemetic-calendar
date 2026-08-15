import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_rule.dart';

class ReminderRuleStore {
  static const _prefsKey = 'reminder:rules:v1';
  static const _pendingUpsertsPrefsKey = 'reminder:pending_upserts:v1';

  Future<List<ReminderRule>> load() {
    return _loadRules(_prefsKey);
  }

  Future<void> saveAll(List<ReminderRule> rules) {
    return _saveRules(_prefsKey, rules);
  }

  Future<List<ReminderRule>> loadPendingUpserts() {
    return _loadRules(_pendingUpsertsPrefsKey);
  }

  Future<void> savePendingUpserts(List<ReminderRule> rules) {
    return _saveRules(_pendingUpsertsPrefsKey, rules);
  }

  Future<bool> hasPendingUpsertsSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pendingUpsertsPrefsKey);
  }

  Future<List<ReminderRule>> _loadRules(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return ReminderRule.decodeList(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveRules(String key, List<ReminderRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, ReminderRule.encodeList(rules));
  }
}
