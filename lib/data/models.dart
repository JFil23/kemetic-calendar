import 'dart:convert';
import 'package:flutter/material.dart';

/// Simple categories for notes.
enum EventCategory { personal, ritual, work, other }

const Map<EventCategory, String> kCategoryLabels = {
  EventCategory.personal: 'Personal',
  EventCategory.ritual:   'Ritual',
  EventCategory.work:     'Work',
  EventCategory.other:    'Other',
};

/// Tiny helper used by UI to paint category bullets.
Color categoryColor(EventCategory c, BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  switch (c) {
    case EventCategory.personal: return scheme.tertiary;
    case EventCategory.ritual:   return scheme.primary;
    case EventCategory.work:     return scheme.secondary;
    case EventCategory.other:    return scheme.outline;
  }
}

/// One saved note/event (all-day).
class Event {
  final String id;
  final DateTime startUtc;             // midnight in UTC for Gregorian anchor
  final int kYear;
  final int kMonth;                    // 1..12, or 0 for epagomenal bucket
  final int kDay;                      // 1..30 on normal months, 1..5(6) for epagomenal
  final String title;                  // non-null for simpler UI wiring
  final String? notes;
  final bool allDay;
  final EventCategory category;
  final bool isEpagomenal;             // true when this is one of the 5/6 days

  const Event({
    required this.id,
    required this.startUtc,
    required this.kYear,
    required this.kMonth,
    required this.kDay,
    required this.title,
    required this.notes,
    required this.allDay,
    required this.category,
    required this.isEpagomenal,
  });

  Event copyWith({
    String? id,
    DateTime? startUtc,
    int? kYear,
    int? kMonth,
    int? kDay,
    String? title,
    String? notes,
    bool? allDay,
    EventCategory? category,
    bool? isEpagomenal,
  }) {
    return Event(
      id: id ?? this.id,
      startUtc: startUtc ?? this.startUtc,
      kYear: kYear ?? this.kYear,
      kMonth: kMonth ?? this.kMonth,
      kDay: kDay ?? this.kDay,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      allDay: allDay ?? this.allDay,
      category: category ?? this.category,
      isEpagomenal: isEpagomenal ?? this.isEpagomenal,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'startUtc': startUtc.toIso8601String(),
    'kYear': kYear,
    'kMonth': kMonth,
    'kDay': kDay,
    'title': title,
    'notes': notes,
    'allDay': allDay,
    'category': category.index,
    'isEpagomenal': isEpagomenal,
  };

  static Event fromMap(Map<String, Object?> m) => Event(
    id: (m['id'] as String?) ?? '',
    startUtc: DateTime.parse(m['startUtc'] as String),
    kYear: m['kYear'] as int,
    kMonth: m['kMonth'] as int,
    kDay: m['kDay'] as int,
    title: (m['title'] as String?) ?? '',
    notes: m['notes'] as String?,
    allDay: (m['allDay'] as bool?) ?? true,
    category: EventCategory.values[(m['category'] as int?) ?? 0],
    isEpagomenal: (m['isEpagomenal'] as bool?) ?? false,
  );

  String toJson() => jsonEncode(toMap());
  static Event fromJson(String s) => fromMap(jsonDecode(s) as Map<String, Object?>);
}
