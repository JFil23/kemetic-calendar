import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'maat_flow_response_models.dart';
import 'the_reading_house_flow.dart';

class ReadingHousePrivateMarginStore {
  const ReadingHousePrivateMarginStore({SharedPreferences? prefs})
    : _prefs = prefs;

  final SharedPreferences? _prefs;

  Future<Map<String, MaatFlowResponseValue>> loadValues({
    required int flowId,
    required int? eventNumber,
  }) async {
    final prefs = await _resolvedPrefs();
    final raw = prefs.getString(_key(flowId, eventNumber));
    if (raw == null || raw.trim().isEmpty) {
      return const <String, MaatFlowResponseValue>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <String, MaatFlowResponseValue>{};
      return readingHousePrivateMarginValuesFromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return const <String, MaatFlowResponseValue>{};
    }
  }

  Future<void> saveValues({
    required int flowId,
    required int? eventNumber,
    required Map<String, MaatFlowResponseValue> values,
  }) async {
    final prefs = await _resolvedPrefs();
    final key = _key(flowId, eventNumber);
    final payload = readingHousePrivateMarginValuesToJson(values);
    if (payload.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(payload));
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

  Future<SharedPreferences> _resolvedPrefs() async {
    return _prefs ?? SharedPreferences.getInstance();
  }

  static String _prefix(int flowId) => 'reading_house_${flowId}_';

  static String _key(int flowId, int? eventNumber) {
    final number = eventNumber == null || eventNumber < 1
        ? 'event_unknown'
        : 'event_$eventNumber';
    return '${_prefix(flowId)}private_margin_$number';
  }
}

Map<String, dynamic> readingHousePrivateMarginValuesToJson(
  Map<String, MaatFlowResponseValue> values,
) {
  final reflection = _text(values, kReadingHousePrivateReflectionSpecId);
  final shortNote = _text(values, kReadingHouseShortNoteSpecId);
  final sitWithoutWriting =
      values[kReadingHouseSitWithoutWritingSpecId]?.checked == true;
  final position = readingHousePositionFromResponseValues(values);
  return <String, dynamic>{
    if (reflection != null) kReadingHousePrivateReflectionSpecId: reflection,
    if (shortNote != null) kReadingHouseShortNoteSpecId: shortNote,
    if (sitWithoutWriting)
      kReadingHouseSitWithoutWritingSpecId: sitWithoutWriting,
    if (position != null) kReadingHousePositionSpecId: position,
  };
}

Map<String, MaatFlowResponseValue> readingHousePrivateMarginValuesFromJson(
  Map<String, dynamic> json,
) {
  final reflection = _string(json[kReadingHousePrivateReflectionSpecId]);
  final shortNote = _string(json[kReadingHouseShortNoteSpecId]);
  final sitWithoutWriting = json[kReadingHouseSitWithoutWritingSpecId] == true;
  final position = _normalizeReadingHousePosition(
    _string(json[kReadingHousePositionSpecId]),
  );
  return <String, MaatFlowResponseValue>{
    if (reflection != null)
      kReadingHousePrivateReflectionSpecId: MaatFlowResponseValue.text(
        specId: kReadingHousePrivateReflectionSpecId,
        text: reflection,
        multiline: true,
      ),
    if (shortNote != null)
      kReadingHouseShortNoteSpecId: MaatFlowResponseValue.text(
        specId: kReadingHouseShortNoteSpecId,
        text: shortNote,
      ),
    if (sitWithoutWriting)
      kReadingHouseSitWithoutWritingSpecId: MaatFlowResponseValue.checkbox(
        specId: kReadingHouseSitWithoutWritingSpecId,
        checked: true,
      ),
    if (position != null)
      kReadingHousePositionSpecId: MaatFlowResponseValue.choice(
        specId: kReadingHousePositionSpecId,
        optionId: position,
      ),
  };
}

String? readingHousePositionFromResponseValues(
  Map<String, MaatFlowResponseValue> values,
) {
  final options =
      values[kReadingHousePositionSpecId]?.optionIds ?? const <String>[];
  if (options.isEmpty) return null;
  return _normalizeReadingHousePosition(options.first);
}

Map<String, dynamic> readingHousePrivateMarginCompletionMetadata(
  Map<String, MaatFlowResponseValue> values,
) {
  final reflection = _text(values, kReadingHousePrivateReflectionSpecId);
  final shortNote = _text(values, kReadingHouseShortNoteSpecId);
  final sitWithoutWriting =
      values[kReadingHouseSitWithoutWritingSpecId]?.checked == true;
  final position = readingHousePositionFromResponseValues(values);
  return <String, dynamic>{
    'reader_sitting_phase': 'enabled',
    'position_required': true,
    'writing_required': false,
    if (position != null) 'reading_position': position,
    'private_margin': <String, dynamic>{
      'phase': 'enabled',
      'storage': 'local_only',
      'private_reflection_recorded': reflection != null,
      'short_note_recorded': shortNote != null,
      'sit_without_writing': sitWithoutWriting,
    },
    'shared_fragments_phase': 'future',
    'company_surfaces': 'disabled',
  };
}

String? _text(Map<String, MaatFlowResponseValue> values, String specId) {
  return _string(values[specId]?.text);
}

String? _string(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

String? _normalizeReadingHousePosition(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == kReadingHousePositionCarrying) {
    return kReadingHousePositionCarrying;
  }
  if (normalized == kReadingHousePositionNotYet) {
    return kReadingHousePositionNotYet;
  }
  return null;
}
