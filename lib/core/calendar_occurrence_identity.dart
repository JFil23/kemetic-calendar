import 'package:flutter/foundation.dart';

enum CalendarOccurrenceKind { reminder }

/// Semantic identity for one generated calendar occurrence.
///
/// Database row ids are deliberately not part of this value. A materialized
/// row can be deleted and recreated without changing which occurrence it is.
@immutable
class CalendarOccurrenceIdentity {
  CalendarOccurrenceIdentity._({
    required this.kind,
    required String sourceId,
    required DateTime localDate,
  }) : sourceId = sourceId.trim(),
       localDate = DateTime(localDate.year, localDate.month, localDate.day) {
    if (this.sourceId.isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'must not be empty');
    }
  }

  factory CalendarOccurrenceIdentity.reminder({
    required String reminderId,
    required DateTime localDate,
  }) {
    return CalendarOccurrenceIdentity._(
      kind: CalendarOccurrenceKind.reminder,
      sourceId: reminderId,
      localDate: localDate,
    );
  }

  final CalendarOccurrenceKind kind;
  final String sourceId;
  final DateTime localDate;

  String get localDateKey => formatCalendarOccurrenceLocalDate(localDate);

  /// Matches the existing reminder occurrence CID so adoption requires no
  /// rewrite of user_events, completions, notifications, or deletion trash.
  String get canonicalKey => switch (kind) {
    CalendarOccurrenceKind.reminder => 'reminder:$sourceId:$localDateKey',
  };

  static CalendarOccurrenceIdentity? tryParse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    const reminderPrefix = 'reminder:';
    if (!value.startsWith(reminderPrefix)) return null;
    final dateSeparator = value.lastIndexOf(':');
    if (dateSeparator <= reminderPrefix.length) return null;
    final reminderId = value.substring(reminderPrefix.length, dateSeparator);
    final date = tryParseCalendarOccurrenceLocalDate(
      value.substring(dateSeparator + 1),
    );
    if (reminderId.trim().isEmpty || date == null) return null;
    return CalendarOccurrenceIdentity.reminder(
      reminderId: reminderId,
      localDate: date,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CalendarOccurrenceIdentity &&
        other.kind == kind &&
        other.sourceId == sourceId &&
        other.localDate == localDate;
  }

  @override
  int get hashCode => Object.hash(kind, sourceId, localDate);

  @override
  String toString() => canonicalKey;
}

String formatCalendarOccurrenceLocalDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? tryParseCalendarOccurrenceLocalDate(String raw) {
  final value = raw.trim();
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}
