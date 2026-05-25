import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'the_djed_flow.dart';

class SpineElement {
  final String label;
  final SpineCondition condition;
  final String? wobbleSinceNote;
  final String? oneThingToSolid;
  final PostBattleStatus? postBattleStatus;
  final bool released;

  const SpineElement({
    required this.label,
    required this.condition,
    this.wobbleSinceNote,
    this.oneThingToSolid,
    this.postBattleStatus,
    this.released = false,
  });

  factory SpineElement.fromJson(Map<String, dynamic> json) {
    return SpineElement(
      label: json['label']?.toString() ?? '',
      condition:
          _spineConditionFromKey(json['condition']?.toString()) ??
          SpineCondition.underPressure,
      wobbleSinceNote: _nullableString(json['wobble_since_note']),
      oneThingToSolid: _nullableString(json['one_thing_to_solid']),
      postBattleStatus: _postBattleStatusFromKey(
        json['post_battle_status']?.toString(),
      ),
      released: json['released'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label,
      'condition': condition.key,
      if ((wobbleSinceNote ?? '').trim().isNotEmpty)
        'wobble_since_note': wobbleSinceNote!.trim(),
      if ((oneThingToSolid ?? '').trim().isNotEmpty)
        'one_thing_to_solid': oneThingToSolid!.trim(),
      if (postBattleStatus != null) 'post_battle_status': postBattleStatus!.key,
      'released': released,
    };
  }
}

class DjedBattleCommitment {
  final String challenge;
  final String engagementAct;
  final bool completed;
  final String? outcomeSentence;

  const DjedBattleCommitment({
    required this.challenge,
    required this.engagementAct,
    this.completed = false,
    this.outcomeSentence,
  });

  factory DjedBattleCommitment.fromJson(Map<String, dynamic> json) {
    return DjedBattleCommitment(
      challenge: json['challenge']?.toString() ?? '',
      engagementAct: json['engagement_act']?.toString() ?? '',
      completed: json['completed'] == true,
      outcomeSentence: _nullableString(json['outcome_sentence']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'challenge': challenge,
      'engagement_act': engagementAct,
      'completed': completed,
      if ((outcomeSentence ?? '').trim().isNotEmpty)
        'outcome_sentence': outcomeSentence!.trim(),
    };
  }
}

class TheDjedLocalStore {
  const TheDjedLocalStore({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<String> loadPromptText(int flowId, DjedLocalPromptKind prompt) async {
    final prefs = await _resolvedPrefs();
    return prefs.getString(_key(flowId, 'prompt_${prompt.key}')) ?? '';
  }

  Future<void> savePromptText(
    int flowId,
    DjedLocalPromptKind prompt,
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

  Future<List<SpineElement>> loadSpineElements(int flowId) async {
    final prefs = await _resolvedPrefs();
    final raw = prefs.getString(_key(flowId, 'spine_elements'));
    if (raw == null || raw.trim().isEmpty) return const <SpineElement>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <SpineElement>[];
      return decoded
          .whereType<Map>()
          .map((item) => SpineElement.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.label.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <SpineElement>[];
    }
  }

  Future<void> saveSpineElements(
    int flowId,
    List<SpineElement> elements,
  ) async {
    final prefs = await _resolvedPrefs();
    final normalized = elements
        .where((item) => item.label.trim().isNotEmpty)
        .map((item) => item.toJson())
        .toList(growable: false);
    final key = _key(flowId, 'spine_elements');
    if (normalized.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(normalized));
    }
  }

  Future<DjedBattleCommitment?> loadBattleCommitment(int flowId) async {
    final prefs = await _resolvedPrefs();
    final raw = prefs.getString(_key(flowId, 'battle_commitment'));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return DjedBattleCommitment.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBattleCommitment(
    int flowId,
    DjedBattleCommitment? commitment,
  ) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, 'battle_commitment');
    if (commitment == null ||
        (commitment.challenge.trim().isEmpty &&
            commitment.engagementAct.trim().isEmpty)) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(commitment.toJson()));
    }
  }

  Future<bool> loadDirectEngagementCompleted(int flowId) async {
    final prefs = await _resolvedPrefs();
    return prefs.getBool(_key(flowId, 'direct_engagement_completed')) ?? false;
  }

  Future<void> saveDirectEngagementCompleted(int flowId, bool completed) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, 'direct_engagement_completed');
    if (completed) {
      await prefs.setBool(key, true);
    } else {
      await prefs.remove(key);
    }
  }

  Future<bool> loadRaisingCompleted(int flowId) async {
    final prefs = await _resolvedPrefs();
    return prefs.getBool(_key(flowId, 'raising_completed')) ?? false;
  }

  Future<void> saveRaisingCompleted(int flowId, bool completed) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, 'raising_completed');
    if (completed) {
      await prefs.setBool(key, true);
    } else {
      await prefs.remove(key);
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

  static String _prefix(int flowId) => 'djed_${flowId}_';

  static String _key(int flowId, String suffix) => '${_prefix(flowId)}$suffix';
}

SpineCondition? _spineConditionFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final value in SpineCondition.values) {
    if (value.key == normalized) return value;
  }
  return null;
}

PostBattleStatus? _postBattleStatusFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final value in PostBattleStatus.values) {
    if (value.key == normalized) return value;
  }
  return null;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
