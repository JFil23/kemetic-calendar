import 'dart:convert';

import '../../models/ai_flow_generation_response.dart';

final RegExp _urlPattern = RegExp(
  r'\b(?:https?:\/\/|www\.)[^\s<>()]+',
  caseSensitive: false,
);
final RegExp _genericLocationValuePattern = RegExp(
  r'^(?:study materials open|training space ready|open your budget\/docs workspace|project workspace and current deliverable visible|quiet place with your practice cue visible|desk clear and the required document open|kitchen or prep space ready|the place where this task normally happens)$',
  caseSensitive: false,
);
final RegExp _genericLocationCuePattern = RegExp(
  r'\b(?:workspace|materials?|document|deliverable|cue|prep space|training space)\b.{0,40}\b(?:open|ready|visible|clear)\b',
  caseSensitive: false,
);

List<Map<String, dynamic>> buildAiFlowImportEvents(
  AIFlowGenerationResponse response,
) {
  final notesList = _decodeNotes(response.notes);
  final events = <Map<String, dynamic>>[];

  for (final raw in notesList) {
    if (raw is! Map) continue;
    final note = Map<String, dynamic>.from(raw);
    final dayIdx = (note['day_index'] as num?)?.toInt() ?? 0;
    final title = (note['title'] as String?) ?? 'Note ${dayIdx + 1}';
    final detail = (note['details'] as String?) ?? '';
    final allDay = note['all_day'] as bool? ?? note['allDay'] as bool? ?? false;
    final startTime =
        note['start_time'] as String? ??
        note['startTime'] as String? ??
        note['startsAt'] as String?;
    final endTime =
        note['end_time'] as String? ??
        note['endTime'] as String? ??
        note['endsAt'] as String?;
    final location = _normalizeLocation(note['location'] as String?, detail);

    events.add({
      'offset_days': dayIdx,
      'title': title,
      'detail': detail,
      'location': location,
      'all_day': allDay,
      'start_time': startTime ?? '00:00',
      'end_time': endTime ?? (allDay ? '00:00' : '01:00'),
      if (note['action_id'] is String) 'action_id': note['action_id'],
      if (note['behavior_payload'] is Map)
        'behavior_payload': Map<String, dynamic>.from(
          note['behavior_payload'] as Map,
        ),
    });
  }

  return events;
}

List<dynamic> _decodeNotes(String? rawNotes) {
  if (rawNotes == null || rawNotes.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(rawNotes);
    return decoded is List ? decoded : const [];
  } catch (_) {
    return const [];
  }
}

String? _normalizeLocation(String? explicitLocation, String detail) {
  final trimmed = explicitLocation?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    final match = _urlPattern.firstMatch(trimmed);
    if (match != null) {
      var url = match.group(0)!.trim();
      while (url.isNotEmpty && RegExp(r'[),.;!?]$').hasMatch(url)) {
        url = url.substring(0, url.length - 1);
      }
      if (url.startsWith('www.')) return 'https://$url';
      return url.isEmpty ? null : url;
    }

    if (!_genericLocationValuePattern.hasMatch(trimmed) &&
        !_genericLocationCuePattern.hasMatch(trimmed)) {
      return trimmed;
    }
  }

  final match = _urlPattern.firstMatch(detail);
  if (match == null) return null;

  var url = match.group(0)!.trim();
  while (url.isNotEmpty && RegExp(r'[),.;!?]$').hasMatch(url)) {
    url = url.substring(0, url.length - 1);
  }
  if (url.isEmpty) return null;
  if (url.startsWith('www.')) return 'https://$url';
  return url;
}
