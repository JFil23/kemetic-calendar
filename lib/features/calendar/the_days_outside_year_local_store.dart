import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'the_days_outside_year_flow.dart';

class DaysOutsideYearLocalStore {
  const DaysOutsideYearLocalStore({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<String> loadPromptText(
    int flowId,
    DaysOutsideLocalPromptKind prompt,
  ) async {
    final prefs = await _resolvedPrefs();
    return prefs.getString(_key(flowId, 'prompt_${prompt.key}')) ?? '';
  }

  Future<void> savePromptText(
    int flowId,
    DaysOutsideLocalPromptKind prompt,
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

  Future<Map<String, String>> loadReceipts(int flowId) async {
    final prefs = await _resolvedPrefs();
    final raw = prefs.getString(_key(flowId, 'wep_receipts'));
    if (raw == null || raw.trim().isEmpty) return const <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <String, String>{};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<void> saveReceipts(int flowId, Map<String, String> receipts) async {
    final prefs = await _resolvedPrefs();
    final normalized = <String, String>{};
    for (final entry in receipts.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) continue;
      normalized[entry.key] = value;
    }
    final key = _key(flowId, 'wep_receipts');
    if (normalized.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(normalized));
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

  static String _prefix(int flowId) => 'days_outside_${flowId}_';

  static String _key(int flowId, String suffix) => '${_prefix(flowId)}$suffix';
}
