import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_rule.dart';

class ReminderRuleStore {
  static const _prefsKey = 'reminder:rules:v1';

  Future<List<ReminderRule>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return ReminderRule.decodeList(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAll(List<ReminderRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, ReminderRule.encodeList(rules));
  }
}
