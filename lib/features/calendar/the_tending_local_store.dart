import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'the_tending_flow.dart';

class CareListEntry {
  final String name;
  final String perceivedNeed;
  final String? statusTag;
  final String? note;

  const CareListEntry({
    required this.name,
    required this.perceivedNeed,
    this.statusTag,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'perceived_need': perceivedNeed,
      if ((statusTag ?? '').trim().isNotEmpty) 'status_tag': statusTag!.trim(),
      if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
    };
  }

  static CareListEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final name = value['name']?.toString().trim() ?? '';
    final perceivedNeed = value['perceived_need']?.toString().trim() ?? '';
    if (name.isEmpty && perceivedNeed.isEmpty) return null;
    return CareListEntry(
      name: name,
      perceivedNeed: perceivedNeed,
      statusTag: value['status_tag']?.toString().trim(),
      note: value['note']?.toString().trim(),
    );
  }
}

class TheTendingLocalStore {
  const TheTendingLocalStore({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<List<CareListEntry>> loadCareList(int flowId) async {
    final prefs = await _resolvedPrefs();
    final raw = prefs.getString(_key(flowId, 'care_list'));
    if (raw == null || raw.trim().isEmpty) return const <CareListEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <CareListEntry>[];
      return decoded
          .map(CareListEntry.fromJson)
          .whereType<CareListEntry>()
          .toList(growable: false);
    } catch (_) {
      return const <CareListEntry>[];
    }
  }

  Future<void> saveCareList(int flowId, List<CareListEntry> entries) async {
    final prefs = await _resolvedPrefs();
    await prefs.setString(
      _key(flowId, 'care_list'),
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<String> loadPromptText(
    int flowId,
    TheTendingLocalPromptKind prompt,
  ) async {
    final prefs = await _resolvedPrefs();
    return prefs.getString(_key(flowId, 'prompt_${prompt.key}')) ?? '';
  }

  Future<void> savePromptText(
    int flowId,
    TheTendingLocalPromptKind prompt,
    String value,
  ) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, 'prompt_${prompt.key}');
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, trimmed);
    if (prompt == TheTendingLocalPromptKind.careInventory) {
      await saveCareList(flowId, parseCareInventory(trimmed));
    }
  }

  Future<Map<String, String>> exportFlowData(int flowId) async {
    final prefs = await _resolvedPrefs();
    final prefix = _prefix(flowId);
    final result = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final value = prefs.getString(key);
      if (value == null) continue;
      result[key.substring(prefix.length)] = value;
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

  static List<CareListEntry> parseCareInventory(String value) {
    final entries = <CareListEntry>[];
    for (final rawLine in value.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final parts = line.split(RegExp(r'\s+[-:]\s+'));
      if (parts.length >= 2) {
        entries.add(
          CareListEntry(
            name: parts.first.trim(),
            perceivedNeed: parts.sublist(1).join(' - ').trim(),
          ),
        );
      } else {
        entries.add(CareListEntry(name: line, perceivedNeed: ''));
      }
    }
    return entries;
  }

  Future<SharedPreferences> _resolvedPrefs() async {
    return _prefs ?? SharedPreferences.getInstance();
  }

  static String _prefix(int flowId) => 'tending_${flowId}_';

  static String _key(int flowId, String suffix) => '${_prefix(flowId)}$suffix';
}
