import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'the_wag_flow.dart';

class AncestorNameEntry {
  final String display;
  final bool isBlood;
  final bool isPracticeAncestor;
  final String? note;

  const AncestorNameEntry({
    required this.display,
    this.isBlood = true,
    this.isPracticeAncestor = false,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'display': display,
      'is_blood': isBlood,
      'is_practice_ancestor': isPracticeAncestor,
      if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
    };
  }

  static AncestorNameEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final display = value['display']?.toString().trim() ?? '';
    if (display.isEmpty) return null;
    return AncestorNameEntry(
      display: display,
      isBlood: value['is_blood'] != false,
      isPracticeAncestor: value['is_practice_ancestor'] == true,
      note: value['note']?.toString().trim(),
    );
  }
}

class TheWagLocalStore {
  const TheWagLocalStore({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<List<AncestorNameEntry>> loadAncestorNames(int flowId) async {
    final prefs = await _resolvedPrefs();
    final raw = prefs.getString(_key(flowId, 'ancestor_names'));
    if (raw == null || raw.trim().isEmpty) return const <AncestorNameEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <AncestorNameEntry>[];
      return decoded
          .map(AncestorNameEntry.fromJson)
          .whereType<AncestorNameEntry>()
          .toList(growable: false);
    } catch (_) {
      return const <AncestorNameEntry>[];
    }
  }

  Future<void> saveAncestorNames(
    int flowId,
    List<AncestorNameEntry> entries,
  ) async {
    final prefs = await _resolvedPrefs();
    await prefs.setString(
      _key(flowId, 'ancestor_names'),
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<String> loadPromptText(int flowId, WagLocalPromptKind prompt) async {
    final prefs = await _resolvedPrefs();
    return prefs.getString(_key(flowId, 'prompt_${prompt.key}')) ?? '';
  }

  Future<void> savePromptText(
    int flowId,
    WagLocalPromptKind prompt,
    String value,
  ) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, 'prompt_${prompt.key}');
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
      if (prompt == WagLocalPromptKind.ancestorNames ||
          prompt == WagLocalPromptKind.extendedNames) {
        await prefs.remove(_key(flowId, 'ancestor_names'));
      }
      return;
    }
    await prefs.setString(key, trimmed);
    if (prompt == WagLocalPromptKind.ancestorNames ||
        prompt == WagLocalPromptKind.extendedNames) {
      await saveAncestorNames(flowId, parseAncestorNames(trimmed));
    }
  }

  Future<String> loadWagFocusName(int flowId) async {
    final prefs = await _resolvedPrefs();
    return prefs.getString(_key(flowId, 'wag_focus_name')) ?? '';
  }

  Future<void> saveWagFocusName(int flowId, String value) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, 'wag_focus_name');
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, trimmed);
    }
  }

  Future<String> loadNextWagDateIso(int flowId) async {
    final prefs = await _resolvedPrefs();
    return prefs.getString(_key(flowId, 'next_wag_date_iso')) ?? '';
  }

  Future<void> saveNextWagDateIso(int flowId, String value) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, 'next_wag_date_iso');
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

  static List<AncestorNameEntry> parseAncestorNames(String value) {
    final entries = <AncestorNameEntry>[];
    for (final rawLine in value.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final practice =
          line.toLowerCase().contains('practice ancestor') ||
          line.toLowerCase().contains('mentor') ||
          line.toLowerCase().contains('elder');
      entries.add(
        AncestorNameEntry(
          display: line,
          isBlood: !practice,
          isPracticeAncestor: practice,
        ),
      );
    }
    return entries;
  }

  Future<SharedPreferences> _resolvedPrefs() async {
    return _prefs ?? SharedPreferences.getInstance();
  }

  static String _prefix(int flowId) => 'the_wag_${flowId}_';

  static String _key(int flowId, String suffix) => '${_prefix(flowId)}$suffix';
}
