import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// The user-visible authority of the calendar's current viewport.
///
/// This value is derived from cache/catalog/coverage state. It is not a
/// monotonic startup phase: moving to an uncovered viewport can legitimately
/// move [serverCurrent] back to [cacheVisible] until that viewport is fetched.
enum CalendarViewportAuthority {
  none,
  cacheVisible,
  viewportRefreshed,
  serverCurrent,
  fullHorizon,
}

/// A half-open UTC interval used by both hydration lanes.
@immutable
class CalendarHydrationInterval {
  CalendarHydrationInterval({
    required DateTime startUtc,
    required DateTime endUtc,
  }) : startUtc = startUtc.toUtc(),
       endUtc = endUtc.toUtc() {
    if (!this.endUtc.isAfter(this.startUtc)) {
      throw ArgumentError.value(
        '$startUtc..$endUtc',
        'interval',
        'endUtc must be after startUtc',
      );
    }
  }

  /// Builds an interval from inclusive local calendar days without assuming
  /// that a local day is exactly 24 hours (DST transitions are allowed).
  factory CalendarHydrationInterval.fromInclusiveLocalDays({
    required DateTime firstLocalDay,
    required DateTime lastLocalDay,
  }) {
    final first = DateTime(
      firstLocalDay.year,
      firstLocalDay.month,
      firstLocalDay.day,
    );
    final last = DateTime(
      lastLocalDay.year,
      lastLocalDay.month,
      lastLocalDay.day,
    );
    if (last.isBefore(first)) {
      throw ArgumentError('lastLocalDay must not precede firstLocalDay');
    }
    final endExclusiveLocal = DateTime(last.year, last.month, last.day + 1);
    return CalendarHydrationInterval(
      startUtc: first.toUtc(),
      endUtc: endExclusiveLocal.toUtc(),
    );
  }

  final DateTime startUtc;
  final DateTime endUtc;

  bool containsInstant(DateTime instant) {
    final utc = instant.toUtc();
    return !utc.isBefore(startUtc) && utc.isBefore(endUtc);
  }

  bool containsInterval(CalendarHydrationInterval other) =>
      !other.startUtc.isBefore(startUtc) && !other.endUtc.isAfter(endUtc);

  bool overlaps(CalendarHydrationInterval other) =>
      startUtc.isBefore(other.endUtc) && other.startUtc.isBefore(endUtc);

  bool touches(CalendarHydrationInterval other) =>
      endUtc == other.startUtc || other.endUtc == startUtc;

  Map<String, String> toJson() => <String, String>{
    'startUtc': startUtc.toIso8601String(),
    'endUtc': endUtc.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is CalendarHydrationInterval &&
      startUtc == other.startUtc &&
      endUtc == other.endUtc;

  @override
  int get hashCode => Object.hash(startUtc, endUtc);

  @override
  String toString() =>
      '[${startUtc.toIso8601String()}, '
      '${endUtc.toIso8601String()})';
}

/// Authority-relevant catalog fields used to create a deterministic revision.
///
/// Presentation fields are included when they affect projected calendar rows.
/// Save chronology is deliberately excluded because it does not affect
/// hydration membership, visibility, reminders, or event projection.
@immutable
class CalendarCatalogFingerprintRow {
  const CalendarCatalogFingerprintRow({
    required this.id,
    required this.userId,
    required this.calendarId,
    required this.name,
    required this.color,
    required this.active,
    required this.isSaved,
    required this.startDate,
    required this.endDate,
    required this.notes,
    required this.rules,
    required this.shareId,
    required this.isHidden,
    required this.isReminder,
    required this.reminderUuid,
  });

  final int id;
  final String? userId;
  final String? calendarId;
  final String name;
  final int color;
  final bool active;
  final bool isSaved;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final Object? rules;
  final String? shareId;
  final bool isHidden;
  final bool isReminder;
  final String? reminderUuid;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'id': id,
    'userId': userId,
    'calendarId': calendarId,
    'name': name,
    'color': color,
    'active': active,
    'isSaved': isSaved,
    'startDate': _canonicalDate(startDate),
    'endDate': _canonicalDate(endDate),
    'notes': notes,
    'rules': _decodeJsonIfPossible(rules),
    'shareId': shareId,
    'isHidden': isHidden,
    'isReminder': isReminder,
    'reminderUuid': reminderUuid,
  };
}

const String calendarCatalogFingerprintVersion = 'calendar-catalog-v1';

/// Versioned SHA-256 fingerprint. Never use Dart's process-local [hashCode]
/// for a persisted authority identity.
String computeCalendarCatalogFingerprint(
  Iterable<CalendarCatalogFingerprintRow> rows,
) {
  final sorted = rows.toList(growable: false)
    ..sort((a, b) {
      final idOrder = a.id.compareTo(b.id);
      if (idOrder != 0) return idOrder;
      return (a.userId ?? '').compareTo(b.userId ?? '');
    });
  final canonicalRows = sorted
      .map((row) => _canonicalize(row.toCanonicalMap()))
      .toList(growable: false);
  final payload = jsonEncode(<String, Object?>{
    'version': calendarCatalogFingerprintVersion,
    'flows': canonicalRows,
  });
  return '$calendarCatalogFingerprintVersion:${sha256.convert(utf8.encode(payload))}';
}

String? _canonicalDate(DateTime? value) {
  if (value == null) return null;
  // Flow boundaries originate as SQL `date` values. Preserve their calendar
  // components instead of shifting them through the device timezone.
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

Object? _decodeJsonIfPossible(Object? value) {
  if (value is! String) return value;
  try {
    return jsonDecode(value);
  } on FormatException {
    return value;
  }
}

Object? _canonicalize(Object? value) {
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Set) {
    final encoded = value.map(_canonicalize).map(jsonEncode).toList()..sort();
    return encoded.map(jsonDecode).toList(growable: false);
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  if (value is num || value is bool || value is String || value == null) {
    return value;
  }
  return value.toString();
}
