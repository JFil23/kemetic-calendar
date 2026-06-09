import 'package:flutter/material.dart';
import 'package:mobile/core/completion_status.dart';

const Color kCalendarReflectionBadgeColor = Color(0xFF8FD7E8);
const String kCalendarReflectionFallbackPrompt =
    'What do you want to remember from this?';
const String kCalendarReflectionSourcePrompt = 'What did this help you notice?';

class CalendarReflectionContext {
  const CalendarReflectionContext({
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.calendarDate,
    this.occurrenceId,
    this.eventId,
    this.flowId,
    this.start,
    this.end,
    this.color = kCalendarReflectionBadgeColor,
    this.completionStatus = CompletionStatus.none,
    this.reflectionPrompt,
  });

  final CompletionSourceType sourceType;
  final String sourceId;
  final String title;
  final DateTime calendarDate;
  final String? occurrenceId;
  final String? eventId;
  final int? flowId;
  final DateTime? start;
  final DateTime? end;
  final Color color;
  final CompletionStatus completionStatus;
  final String? reflectionPrompt;

  String get calendarDateKey => _dateKey(calendarDate);

  String get journalRouteLocation => '/journal';

  Map<String, String> toQueryParameters() {
    final params = <String, String>{
      'reflection': 'calendar_item',
      'date': calendarDateKey,
      'sourceType': sourceType.wireName,
      'sourceId': sourceId,
      'title': title.trim().isEmpty ? 'Calendar item' : title.trim(),
      'completionStatus': completionStatus.wireName,
      'color': color.toARGB32().toRadixString(16).padLeft(8, '0'),
    };
    final occurrence = occurrenceId?.trim();
    if (occurrence != null && occurrence.isNotEmpty) {
      params['occurrenceId'] = occurrence;
    }
    final event = eventId?.trim();
    if (event != null && event.isNotEmpty) {
      params['eventId'] = event;
    }
    final flow = flowId;
    if (flow != null) {
      params['flowId'] = '$flow';
    }
    final prompt = _cleanUserFacingPrompt(reflectionPrompt);
    if (prompt != null) {
      params['reflectionPrompt'] = prompt;
    }
    final startIso = start?.toUtc().toIso8601String();
    if (startIso != null && startIso.isNotEmpty) {
      params['start'] = startIso;
    }
    final endIso = end?.toUtc().toIso8601String();
    if (endIso != null && endIso.isNotEmpty) {
      params['end'] = endIso;
    }
    return params;
  }

  static CalendarReflectionContext? fromQueryParameters(
    Map<String, String> query,
  ) {
    if (query['reflection'] != 'calendar_item') return null;
    final sourceType = _sourceTypeFromWireName(query['sourceType']);
    final sourceId = query['sourceId']?.trim();
    final title = query['title']?.trim();
    final date = _parseDateKey(query['date']);
    if (sourceType == null ||
        sourceId == null ||
        sourceId.isEmpty ||
        title == null ||
        title.isEmpty ||
        date == null) {
      return null;
    }
    return CalendarReflectionContext(
      sourceType: sourceType,
      sourceId: sourceId,
      title: title,
      calendarDate: date,
      occurrenceId: query['occurrenceId'],
      eventId: query['eventId'],
      flowId: int.tryParse(query['flowId'] ?? ''),
      start: _parseDateTime(query['start']),
      end: _parseDateTime(query['end']),
      color: _parseColor(query['color']),
      completionStatus: CompletionStatusX.fromWireName(
        query['completionStatus'],
      ),
      reflectionPrompt: query['reflectionPrompt'],
    );
  }

  String buildJournalPlaceholderText() {
    return _cleanUserFacingPrompt(reflectionPrompt) ??
        _fallbackPromptFor(sourceType: sourceType, title: title);
  }

  static CompletionSourceType? _sourceTypeFromWireName(String? raw) {
    final value = raw?.trim();
    for (final type in CompletionSourceType.values) {
      if (type.wireName == value) return type;
    }
    return null;
  }

  static DateTime? _parseDateKey(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime? _parseDateTime(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  static Color _parseColor(String? raw) {
    var value = raw?.trim().replaceFirst('#', '') ?? '';
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return kCalendarReflectionBadgeColor;
    return Color(parsed);
  }
}

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String resolveCalendarReflectionPrompt({
  required CompletionSourceType sourceType,
  String? title,
  String? detail,
  Map<String, dynamic>? behaviorPayload,
}) {
  return _cleanUserFacingPrompt(_promptFromPayload(behaviorPayload)) ??
      _cleanUserFacingPrompt(_promptFromDetail(detail)) ??
      _fallbackPromptFor(sourceType: sourceType, title: title);
}

String _fallbackPromptFor({
  required CompletionSourceType sourceType,
  String? title,
}) {
  switch (sourceType) {
    case CompletionSourceType.note:
    case CompletionSourceType.reminder:
      return kCalendarReflectionFallbackPrompt;
    case CompletionSourceType.maatFlow:
    case CompletionSourceType.userFlow:
    case CompletionSourceType.itinerary:
    case CompletionSourceType.calendarEvent:
      return (title?.trim().isNotEmpty ?? false)
          ? kCalendarReflectionSourcePrompt
          : kCalendarReflectionFallbackPrompt;
  }
}

String? _promptFromPayload(Map<String, dynamic>? payload) {
  if (payload == null) return null;
  for (final key in const <String>[
    'reflectionPrompt',
    'reflection_prompt',
    'reflectionQuestion',
    'reflection_question',
  ]) {
    final prompt = _cleanUserFacingPrompt(payload[key]?.toString());
    if (prompt != null) return prompt;
  }

  final guidance = payload['reflection_guidance'];
  if (guidance is Map) {
    for (final key in const <String>[
      'reflectionPrompt',
      'reflectionQuestion',
      'prompt',
      'question',
      'reflectionIntent',
    ]) {
      final prompt = _cleanUserFacingPrompt(guidance[key]?.toString());
      if (prompt != null) return prompt;
    }
  }
  return null;
}

String? _promptFromDetail(String? detail) {
  final text = detail?.trim();
  if (text == null || text.isEmpty) return null;
  final match = RegExp(
    r'\bReflection\s*:\s*(.+)$',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(text);
  if (match == null) return null;
  final segment = match.group(1)?.trim();
  if (segment == null || segment.isEmpty) return null;

  final quotedQuestion = RegExp(
    r'["“]([^"”]*\?)[”"]',
    dotAll: true,
  ).firstMatch(segment);
  final quotedPrompt = _cleanUserFacingPrompt(quotedQuestion?.group(1));
  if (quotedPrompt != null) return quotedPrompt;

  final question = RegExp(r'([^.!?\n]*\?)', dotAll: true).firstMatch(segment);
  final questionPrompt = _cleanUserFacingPrompt(question?.group(1));
  if (questionPrompt != null) return questionPrompt;

  return _cleanUserFacingPrompt(segment);
}

String? _cleanUserFacingPrompt(String? raw) {
  var value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  value = value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\-:;\s]+'), '')
      .replaceAll(RegExp(r'[\s]+$'), '');
  if (value.isEmpty) return null;

  final lower = value.toLowerCase();
  const blockedMarkers = <String>[
    'source id:',
    'occurrence id:',
    'event id:',
    'flow id:',
    'source:',
    'completion:',
    'source_type',
    'user_flow',
    'maat_flow',
    'calendar_event',
    'event_badge',
    '⟦',
  ];
  if (blockedMarkers.any(lower.contains)) return null;

  return value;
}
