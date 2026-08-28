import 'package:shared_preferences/shared_preferences.dart';

class OfferingTableLocalStore {
  const OfferingTableLocalStore({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<String> loadNeed(int flowId) async {
    final prefs = await _resolvedPrefs();
    return prefs.getString(_key(flowId, 'initial_need'))?.trim() ?? '';
  }

  Future<void> saveNeed(int flowId, String value) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, 'initial_need');
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, trimmed);
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

  static String _prefix(int flowId) => 'offering_table_${flowId}_';

  static String _key(int flowId, String suffix) => '${_prefix(flowId)}$suffix';
}
