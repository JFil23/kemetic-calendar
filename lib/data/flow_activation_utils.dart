import 'dart:convert';

import 'package:flutter/material.dart';

import '../features/reminders/reminder_rule.dart';

String? normalizeFlowText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

bool looksLikeRepeatingNoteMetadata(String? notes) {
  final trimmed = notes?.trim();
  if (trimmed == null || trimmed.isEmpty) return false;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return false;
    final map = Map<String, dynamic>.from(decoded);
    return map['kind']?.toString().trim().toLowerCase() == 'repeating_note';
  } catch (_) {
    return false;
  }
}

bool looksLikeReminderMetadata(
  String? notes, {
  bool isReminder = false,
  String? reminderUuid,
}) {
  if (isReminder) return true;
  if (normalizeFlowText(reminderUuid) != null) return true;
  final trimmed = notes?.trim();
  if (trimmed == null || trimmed.isEmpty) return false;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) return false;
    ReminderRule.fromJson(decoded);
    return true;
  } catch (_) {
    return false;
  }
}

({bool isReminder, bool isRepeatingNote}) classifyFlowMetadata({
  bool isReminder = false,
  bool isHidden = false,
  String? reminderUuid,
  String? notes,
}) {
  final repeatingNote = isHidden || looksLikeRepeatingNoteMetadata(notes);
  final reminder = looksLikeReminderMetadata(
    notes,
    isReminder: isReminder,
    reminderUuid: reminderUuid,
  );
  return (isReminder: reminder, isRepeatingNote: repeatingNote);
}

bool isTrackableFlowMetadata({
  bool isReminder = false,
  bool isHidden = false,
  String? reminderUuid,
  String? notes,
}) {
  final classification = classifyFlowMetadata(
    isReminder: isReminder,
    isHidden: isHidden,
    reminderUuid: reminderUuid,
    notes: notes,
  );
  return !classification.isReminder && !classification.isRepeatingNote;
}

String trimToMaxWords(String value, int maxWords) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.length <= maxWords) {
    return words.join(' ');
  }
  return words.take(maxWords).join(' ');
}

String inferFlowDomainFromTitle(String title, {String fallback = 'life'}) {
  final normalized = title.trim().toLowerCase();
  if (normalized.contains('body')) return 'body';
  if (normalized.contains('money') || normalized.contains('finance')) {
    return 'money';
  }
  if (normalized.contains('writing') || normalized.contains('write')) {
    return 'writing';
  }
  if (normalized.contains('heal')) return 'healing';
  if (normalized.contains('study') || normalized.contains('learn')) {
    return 'study';
  }
  if (normalized.contains('parent')) return 'parenting';
  if (normalized.contains('prayer') ||
      normalized.contains('spiritual') ||
      normalized.contains('ritual')) {
    return 'spiritual discipline';
  }
  return fallback;
}

String buildFlowVow({
  required String domain,
  required String intention,
  required String obstacle,
}) {
  final normalizedDomain = normalizeFlowText(domain) ?? 'life';
  final normalizedIntention = normalizeFlowText(intention) ?? 'steady practice';
  final normalizedObstacle = normalizeFlowText(obstacle);
  final clause = normalizedObstacle == null
      ? normalizedIntention
      : '$normalizedIntention despite $normalizedObstacle';
  return trimToMaxWords(
    'For 10 days, I bring $normalizedDomain into order through $clause, record, and return.',
    20,
  );
}

String buildFallbackFlowVow({
  required String title,
  String? domain,
  String? intention,
  String? obstacle,
}) {
  final resolvedDomain =
      normalizeFlowText(domain) ?? inferFlowDomainFromTitle(title);
  final resolvedIntention = normalizeFlowText(intention) ?? 'discipline';
  return buildFlowVow(
    domain: resolvedDomain,
    intention: resolvedIntention,
    obstacle: obstacle ?? 'distraction',
  );
}

DateTime? normalizeDateOnly(DateTime? value) {
  if (value == null) return null;
  final local = value.toLocal();
  return DateUtils.dateOnly(local);
}

int? inferFlowLengthDays({
  int? explicitLength,
  DateTime? startDate,
  DateTime? endDate,
  List<dynamic>? rules,
}) {
  if (explicitLength != null && explicitLength > 0) {
    return explicitLength.clamp(1, 90);
  }

  final normalizedStart = normalizeDateOnly(startDate);
  final normalizedEnd = normalizeDateOnly(endDate);
  if (normalizedStart != null && normalizedEnd != null) {
    final diff = normalizedEnd.difference(normalizedStart).inDays + 1;
    if (diff > 0) {
      return diff.clamp(1, 90);
    }
  }

  final ruleDates = <int>{};
  for (final rawRule in rules ?? const <dynamic>[]) {
    if (rawRule is! Map) continue;
    final type = rawRule['type']?.toString().trim().toLowerCase();
    if (type != 'dates') continue;
    final dates = rawRule['dates'];
    if (dates is! List) continue;
    for (final rawDate in dates) {
      final millis = switch (rawDate) {
        int value => value,
        num value => value.toInt(),
        _ => null,
      };
      if (millis != null) {
        ruleDates.add(millis);
      }
    }
  }
  if (ruleDates.isNotEmpty) {
    return ruleDates.length.clamp(1, 90);
  }

  return null;
}

String encodeFlowNotesMetadata({
  required bool kemetic,
  required bool split,
  required String overview,
  String? maatKey,
}) {
  final parts = <String>[
    kemetic ? 'mode=kemetic' : 'mode=gregorian',
    if (split) 'split=1',
    if (overview.trim().isNotEmpty)
      'ov=${Uri.encodeComponent(overview.trim())}',
    if (maatKey != null && maatKey.trim().isNotEmpty) 'maat=${maatKey.trim()}',
  ];
  return parts.join(';');
}
