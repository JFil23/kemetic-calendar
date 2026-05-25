import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'the_kept_word_flow.dart';

class KeptWordAgreementEntry {
  final String personLabel;
  final String agreementText;
  final String status;

  const KeptWordAgreementEntry({
    required this.personLabel,
    required this.agreementText,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'person_label': personLabel,
      'agreement_text': agreementText,
      'status': status,
    };
  }

  static KeptWordAgreementEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final personLabel = value['person_label']?.toString().trim() ?? '';
    final agreementText = value['agreement_text']?.toString().trim() ?? '';
    final status = value['status']?.toString().trim() ?? '';
    if (personLabel.isEmpty && agreementText.isEmpty) return null;
    return KeptWordAgreementEntry(
      personLabel: personLabel,
      agreementText: agreementText,
      status: _normalizeStatus(status),
    );
  }

  static String _normalizeStatus(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
    if (normalized == 'kept' ||
        normalized == 'drifted' ||
        normalized == 'broken') {
      return normalized;
    }
    return 'drifted';
  }
}

class TheKeptWordLocalStore {
  const TheKeptWordLocalStore({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<List<KeptWordAgreementEntry>> loadAgreementInventory(
    int flowId,
  ) async {
    final prefs = await _resolvedPrefs();
    final raw = prefs.getString(_key(flowId, 'agreement_inventory'));
    if (raw == null || raw.trim().isEmpty) {
      return const <KeptWordAgreementEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <KeptWordAgreementEntry>[];
      return decoded
          .map(KeptWordAgreementEntry.fromJson)
          .whereType<KeptWordAgreementEntry>()
          .toList(growable: false);
    } catch (_) {
      return const <KeptWordAgreementEntry>[];
    }
  }

  Future<void> saveAgreementInventory(
    int flowId,
    List<KeptWordAgreementEntry> entries,
  ) async {
    final prefs = await _resolvedPrefs();
    await prefs.setString(
      _key(flowId, 'agreement_inventory'),
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<String> loadPromptText(
    int flowId,
    KeptWordLocalPromptKind prompt,
  ) async {
    final prefs = await _resolvedPrefs();
    return prefs.getString(_key(flowId, 'prompt_${prompt.key}')) ?? '';
  }

  Future<void> savePromptText(
    int flowId,
    KeptWordLocalPromptKind prompt,
    String value,
  ) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, 'prompt_${prompt.key}');
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
      if (prompt == KeptWordLocalPromptKind.agreementInventory) {
        await prefs.remove(_key(flowId, 'agreement_inventory'));
      }
      return;
    }
    await prefs.setString(key, trimmed);
    if (prompt == KeptWordLocalPromptKind.agreementInventory) {
      await saveAgreementInventory(flowId, parseAgreementInventory(trimmed));
    }
  }

  Future<bool> loadConversationCompleted(int flowId) async {
    final prefs = await _resolvedPrefs();
    return prefs.getBool(_key(flowId, 'conversation_completed')) ?? false;
  }

  Future<void> saveConversationCompleted(int flowId, bool value) async {
    final prefs = await _resolvedPrefs();
    await prefs.setBool(_key(flowId, 'conversation_completed'), value);
  }

  Future<bool> loadConversationPaused(int flowId) async {
    final prefs = await _resolvedPrefs();
    return prefs.getBool(_key(flowId, 'conversation_paused')) ?? false;
  }

  Future<void> saveConversationPaused(int flowId, bool value) async {
    final prefs = await _resolvedPrefs();
    await prefs.setBool(_key(flowId, 'conversation_paused'), value);
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

  static List<KeptWordAgreementEntry> parseAgreementInventory(String value) {
    final entries = <KeptWordAgreementEntry>[];
    for (final rawLine in value.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final parts = line.split(RegExp(r'\s+[-:]\s+'));
      final person = parts.isNotEmpty ? parts.first.trim() : '';
      final statusRaw = parts.length >= 3 ? parts.last.trim() : '';
      final agreement = parts.length >= 3
          ? parts.sublist(1, parts.length - 1).join(' - ').trim()
          : parts.length == 2
          ? parts.last.trim()
          : '';
      entries.add(
        KeptWordAgreementEntry(
          personLabel: person,
          agreementText: agreement,
          status: KeptWordAgreementEntry._normalizeStatus(statusRaw),
        ),
      );
    }
    return entries;
  }

  Future<SharedPreferences> _resolvedPrefs() async {
    return _prefs ?? SharedPreferences.getInstance();
  }

  static String _prefix(int flowId) => 'kept_word_${flowId}_';

  static String _key(int flowId, String suffix) => '${_prefix(flowId)}$suffix';
}
