import 'package:flutter/material.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';

const Color kCalendarReflectionBadgeColor = Color(0xFF8FD7E8);

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
    );
  }

  String buildJournalPrefillText() {
    final displayTitle = title.trim().isEmpty ? 'this calendar item' : title;
    final description = <String>[
      'Reflection linked from ${sourceType.wireName}.',
      'Source id: $sourceId.',
      if ((occurrenceId?.trim().isNotEmpty ?? false))
        'Occurrence id: ${occurrenceId!.trim()}.',
      if ((eventId?.trim().isNotEmpty ?? false))
        'Event id: ${eventId!.trim()}.',
      if (flowId != null) 'Flow id: $flowId.',
      'Calendar date: $calendarDateKey.',
      if (completionStatus != CompletionStatus.none)
        'Completion: ${completionStatus.wireName}.',
    ].join(' ');
    final token = EventBadgeToken.buildToken(
      id: 'calendar_reflection:${sourceType.wireName}:$sourceId',
      eventId: eventId ?? occurrenceId ?? sourceId,
      title: displayTitle,
      start: start,
      end: end,
      color: color,
      description: description,
      completionStatus: completionStatus,
      reflectionStatus: ReflectionStatus.userWritten,
      sourceType: sourceType,
    );
    return '$token\nReflection on $displayTitle\n\n';
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
