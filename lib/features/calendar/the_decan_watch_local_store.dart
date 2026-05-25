import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DecanWatchRecord {
  final String? skyNote;
  final String? decanIntention;
  final bool observedFromInside;

  const DecanWatchRecord({
    this.skyNote,
    this.decanIntention,
    this.observedFromInside = false,
  });

  bool get isEmpty {
    return (skyNote ?? '').trim().isEmpty &&
        (decanIntention ?? '').trim().isEmpty &&
        !observedFromInside;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if ((skyNote ?? '').trim().isNotEmpty) 'sky_note': skyNote!.trim(),
      if ((decanIntention ?? '').trim().isNotEmpty)
        'decan_intention': decanIntention!.trim(),
      'observed_from_inside': observedFromInside,
    };
  }

  static DecanWatchRecord fromJson(Object? value) {
    if (value is! Map) return const DecanWatchRecord();
    return DecanWatchRecord(
      skyNote: value['sky_note']?.toString(),
      decanIntention: value['decan_intention']?.toString(),
      observedFromInside: value['observed_from_inside'] == true,
    );
  }

  DecanWatchRecord copyWith({
    String? skyNote,
    String? decanIntention,
    bool? observedFromInside,
  }) {
    return DecanWatchRecord(
      skyNote: skyNote ?? this.skyNote,
      decanIntention: decanIntention ?? this.decanIntention,
      observedFromInside: observedFromInside ?? this.observedFromInside,
    );
  }
}

class DecanWatchLocalStore {
  const DecanWatchLocalStore({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<DecanWatchRecord> loadRecord({
    required int flowId,
    required int kYear,
    required int globalDecanId,
  }) async {
    final prefs = await _resolvedPrefs();
    final raw = prefs.getString(_recordKey(flowId, kYear, globalDecanId));
    if (raw == null || raw.trim().isEmpty) {
      return const DecanWatchRecord();
    }
    try {
      return DecanWatchRecord.fromJson(jsonDecode(raw));
    } catch (_) {
      return const DecanWatchRecord();
    }
  }

  Future<void> saveRecord({
    required int flowId,
    required int kYear,
    required int globalDecanId,
    required DecanWatchRecord record,
  }) async {
    final prefs = await _resolvedPrefs();
    final key = _recordKey(flowId, kYear, globalDecanId);
    if (record.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(record.toJson()));
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

  static String _recordKey(int flowId, int kYear, int globalDecanId) {
    return '${_prefix(flowId)}${kYear}_$globalDecanId';
  }

  static String _prefix(int flowId) => 'decan_watch_${flowId}_';
}
