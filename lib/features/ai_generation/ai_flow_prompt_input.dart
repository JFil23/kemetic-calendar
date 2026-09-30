import 'package:flutter/material.dart' show Color;

String buildCanonicalAiFlowPromptText({
  String? description,
  String? sourceText,
  String? pastedPromptBody,
}) {
  final seen = <String>{};
  final parts = <String>[];
  for (final raw in [description, sourceText, pastedPromptBody]) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) continue;
    final key = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (seen.add(key)) parts.add(trimmed);
  }
  return parts.join('\n\n');
}

String aiFlowColorHexFromColor(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}

String aiFlowIanaTimezoneForLocal(DateTime nowLocal) {
  final offsetHours = nowLocal.timeZoneOffset.inHours;
  final timezoneMap = {
    -10: 'Pacific/Honolulu',
    -9: 'America/Anchorage',
    -8: 'America/Los_Angeles',
    -7: 'America/Los_Angeles',
    -6: 'America/Denver',
    -5: 'America/Chicago',
    -4: 'America/New_York',
    0: 'Europe/London',
    1: 'Europe/Paris',
    8: 'Asia/Singapore',
    9: 'Asia/Tokyo',
    10: 'Australia/Sydney',
  };
  return timezoneMap[offsetHours] ?? 'America/Los_Angeles';
}

bool _aiFlowLooksLikeTelemetryBlock(String block) {
  final compact = block.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return false;
  final jsonKeys = RegExp(r'"[\w.-]+":').allMatches(compact).length;
  final telemetryHits = RegExp(
    r'(event_message|deployment_id|execution_id|function_id|project_ref|served_by|booted|shutdown|WallClockTime|cpu_time_used|memory_used|timestamp|version|region)',
    caseSensitive: false,
  ).allMatches(compact).length;
  return telemetryHits >= 2 ||
      (compact.startsWith('{') && compact.endsWith('}') && jsonKeys >= 4);
}

String _aiFlowExtractLongPasteIntent(String raw) {
  final blocks = raw
      .split(RegExp(r'\n\s*\n'))
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();
  final proseBlocks = blocks
      .where((b) => !_aiFlowLooksLikeTelemetryBlock(b))
      .toList();
  if (proseBlocks.isEmpty) {
    return raw.length > 1800 ? '${raw.substring(0, 1800)}...' : raw;
  }

  final requestCue = RegExp(
    r'(turn|make|convert|transform|create|build|organize|map).{0,40}(flow|\d{1,3}\s*day)',
    caseSensitive: false,
    dotAll: true,
  );
  final requestBlocks = proseBlocks
      .where((b) => requestCue.hasMatch(b))
      .toList();

  final candidates = <String>[
    if (requestBlocks.isNotEmpty) requestBlocks.first,
    proseBlocks.first,
    if (proseBlocks.length > 1) proseBlocks.last,
  ];

  final seen = <String>{};
  final chosen = <String>[];
  for (final block in candidates) {
    final key = block.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    chosen.add(block);
  }

  final summary = chosen.join('\n\n');
  return summary.length > 1800 ? '${summary.substring(0, 1800)}...' : summary;
}

bool _aiFlowShouldSendAsSourceMaterial(String raw) {
  final trimmed = raw.trim();
  if (trimmed.length > 2200) return true;
  final blocks = trimmed
      .split(RegExp(r'\n\s*\n'))
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();
  return blocks.length >= 4;
}

/// Long pastes go to `source_text` on the edge function so the model treats
/// them as authoritative material while keeping dictation heuristics off.
({String description, String? sourceText}) splitAiFlowPromptForApi(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return (description: '', sourceText: null);
  }
  if (!_aiFlowShouldSendAsSourceMaterial(trimmed)) {
    return (description: trimmed, sourceText: null);
  }
  final intent = _aiFlowExtractLongPasteIntent(trimmed);
  return (
    description:
        'USER_INTENT_SUMMARY:\n$intent\n\nTransform SOURCE_TEXT into a flow for the selected date range. Preserve concrete initiatives, constraints, milestones, numbers, sequence, and voice from SOURCE_TEXT. Organize it into a clear progression instead of generic summaries.',
    sourceText: trimmed,
  );
}
