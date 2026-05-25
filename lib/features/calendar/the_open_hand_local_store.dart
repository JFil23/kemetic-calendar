import 'package:shared_preferences/shared_preferences.dart';

import 'the_open_hand_flow.dart';

class TheOpenHandLocalStore {
  const TheOpenHandLocalStore({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<String> loadPromptText(
    int flowId,
    OpenHandLocalPromptKind prompt,
  ) async {
    final prefs = await _resolvedPrefs();
    return prefs.getString(_key(flowId, 'prompt_${prompt.key}')) ?? '';
  }

  Future<void> savePromptText(
    int flowId,
    OpenHandLocalPromptKind prompt,
    String value,
  ) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, 'prompt_${prompt.key}');
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, trimmed);
    }
  }

  Future<bool> loadActCompleted(int flowId, int eventNumber) async {
    final prefs = await _resolvedPrefs();
    return prefs.getBool(_key(flowId, 'act_completed_$eventNumber')) ?? false;
  }

  Future<void> saveActCompleted(
    int flowId,
    int eventNumber,
    bool completed,
  ) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, 'act_completed_$eventNumber');
    if (completed) {
      await prefs.setBool(key, true);
    } else {
      await prefs.remove(key);
    }
  }

  Future<String> loadDeferredStrangerActDate(int flowId) async {
    final prefs = await _resolvedPrefs();
    return prefs.getString(_key(flowId, 'stranger_act_deferred_to')) ?? '';
  }

  Future<void> saveDeferredStrangerActDate(int flowId, String value) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, 'stranger_act_deferred_to');
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, trimmed);
    }
  }

  Future<Map<String, String>> exportFlowData(int flowId) async {
    final prefs = await _resolvedPrefs();
    final prefix = _prefix(flowId);
    final result = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final value = prefs.get(key);
      if (value == null) continue;
      result[key.substring(prefix.length)] = value.toString();
    }
    return result;
  }

  Future<void> deleteFlowData(int flowId) async {
    final prefs = await _resolvedPrefs();
    final prefix = _prefix(flowId);
    final keys = prefs.getKeys().where((key) => key.startsWith(prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<SharedPreferences> _resolvedPrefs() async {
    return _prefs ?? SharedPreferences.getInstance();
  }

  static String _prefix(int flowId) => 'open_hand_${flowId}_';

  static String _key(int flowId, String suffix) => '${_prefix(flowId)}$suffix';
}
