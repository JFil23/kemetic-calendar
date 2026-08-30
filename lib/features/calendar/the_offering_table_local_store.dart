import 'package:shared_preferences/shared_preferences.dart';

class OfferingTableLocalStore {
  const OfferingTableLocalStore({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<String> loadIntention(int flowId, int dayNumber) async {
    _validateDayNumber(dayNumber);
    final prefs = await _resolvedPrefs();
    final intentionKey = _intentionKey(flowId, dayNumber);
    if (prefs.containsKey(intentionKey)) {
      return prefs.getString(intentionKey)?.trim() ?? '';
    }
    if (dayNumber != 1) return '';

    final legacyKey = _key(flowId, 'initial_need');
    if (!prefs.containsKey(legacyKey)) return '';
    final legacyValue = prefs.getString(legacyKey)?.trim() ?? '';
    if (legacyValue.isNotEmpty) {
      await prefs.setString(intentionKey, legacyValue);
    }
    await prefs.remove(legacyKey);
    return legacyValue;
  }

  Future<void> saveIntention(int flowId, int dayNumber, String value) async {
    _validateDayNumber(dayNumber);
    final prefs = await _resolvedPrefs();
    final key = _intentionKey(flowId, dayNumber);
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, trimmed);
    }
    if (dayNumber == 1) {
      await prefs.remove(_key(flowId, 'initial_need'));
    }
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

  static String _intentionKey(int flowId, int dayNumber) =>
      _key(flowId, 'day_${dayNumber.toString().padLeft(2, '0')}_intention');

  static void _validateDayNumber(int dayNumber) {
    if (dayNumber < 1 || dayNumber > 30) {
      throw ArgumentError.value(dayNumber, 'dayNumber', 'must be 1 through 30');
    }
  }
}
