import 'dart:ui';
import 'package:flutter/material.dart';

typedef NoteJson = Map<String, dynamic>;
typedef FlowJson = Map<String, dynamic>;

String? _todToString(TimeOfDay? t) => t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
TimeOfDay? _todFromString(String? s) {
  if (s == null || s.isEmpty) return null;
  final p = s.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]) ?? 0;
  final m = int.tryParse(p[1]) ?? 0;
  return TimeOfDay(hour: h, minute: m);
}

/* ---------------- Note ---------------- */

class Note {
  final String title;
  final String? detail;
  final String? location;
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final int? flowId;

  const Note({
    required this.title,
    this.detail,
    this.location,
    required this.allDay,
    this.start,
    this.end,
    this.flowId,
  });

  NoteJson toJson() => {
    'title': title,
    'detail': detail,
    'location': location,
    'allDay': allDay,
    'start': _todToString(start),
    'end': _todToString(end),
    'flowId': flowId,
  };

  factory Note.fromJson(NoteJson j) => Note(
    title: j['title'] as String? ?? '',
    detail: j['detail'] as String?,
    location: j['location'] as String?,
    allDay: j['allDay'] as bool? ?? true,
    start: _todFromString(j['start'] as String?),
    end: _todFromString(j['end'] as String?),
    flowId: j['flowId'] as int?,
  );
}

/* ---------------- Flow rules ---------------- */

abstract class FlowRule {
  const FlowRule();
  Map<String, dynamic> toJson();

  factory FlowRule.fromJson(Map<String, dynamic> j) {
    switch (j['type']) {
      case 'week':
        return RuleWeek(
          weekdays: Set<int>.from((j['weekdays'] as List).map((e) => e as int)),
          allDay: j['allDay'] as bool? ?? true,
        );
      case 'decan':
        return RuleDecan(
          months: Set<int>.from((j['months'] as List).map((e) => e as int)),
          decans: Set<int>.from((j['decans'] as List).map((e) => e as int)),
          daysInDecan: Set<int>.from((j['daysInDecan'] as List).map((e) => e as int)),
          allDay: j['allDay'] as bool? ?? true,
        );
      case 'dates':
        return RuleDates(
          dates: (j['dates'] as List).map((e) => DateTime.parse(e as String)).toSet(),
        );
      default:
        return const RuleDates(dates: {});
    }
  }
}

class RuleWeek extends FlowRule {
  final Set<int> weekdays; // 1..7 (Mon..Sun)
  final bool allDay;
  const RuleWeek({required this.weekdays, required this.allDay});
  @override
  Map<String, dynamic> toJson() => {
    'type': 'week',
    'weekdays': weekdays.toList(),
    'allDay': allDay,
  };
}

class RuleDecan extends FlowRule {
  final Set<int> months; // 1..12
  final Set<int> decans; // 1..3
  final Set<int> daysInDecan; // 1..10
  final bool allDay;
  const RuleDecan({
    required this.months,
    required this.decans,
    required this.daysInDecan,
    required this.allDay,
  });
  @override
  Map<String, dynamic> toJson() => {
    'type': 'decan',
    'months': months.toList(),
    'decans': decans.toList(),
    'daysInDecan': daysInDecan.toList(),
    'allDay': allDay,
  };
}

class RuleDates extends FlowRule {
  final Set<DateTime> dates; // date-only (local)
  const RuleDates({required this.dates});
  @override
  Map<String, dynamic> toJson() => {
    'type': 'dates',
    'dates': dates.map((d) => DateTime(d.year, d.month, d.day).toIso8601String()).toList(),
  };
}

/* ---------------- Flow ---------------- */

class Flow {
  final int id;
  final String name;
  final Color color;
  final bool active;
  final List<FlowRule> rules;
  final DateTime? start; // date-only
  final DateTime? end;   // date-only
  final String? notes;   // packed metadata string
  final bool isReminder;

  const Flow({
    required this.id,
    required this.name,
    required this.color,
    required this.active,
    required this.rules,
    required this.start,
    required this.end,
    required this.notes,
    this.isReminder = false,
  });

  Flow copyWith({
    int? id,
    String? name,
    Color? color,
    bool? active,
    List<FlowRule>? rules,
    DateTime? start,
    DateTime? end,
    String? notes,
    bool? isReminder,
  }) {
    return Flow(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      active: active ?? this.active,
      rules: rules ?? this.rules,
      start: start ?? this.start,
      end: end ?? this.end,
      notes: notes ?? this.notes,
      isReminder: isReminder ?? this.isReminder,
    );
  }

  FlowJson toJson() => {
    'id': id,
    'name': name,
    'color': color.value,
    'active': active,
    'rules': rules.map((r) => r.toJson()).toList(),
    'start': start?.toIso8601String(),
    'end': end?.toIso8601String(),
    'notes': notes,
    'isReminder': isReminder,
  };

  factory Flow.fromJson(FlowJson j) => Flow(
    id: j['id'] as int? ?? -1,
    name: j['name'] as String? ?? '',
    color: Color(j['color'] as int? ?? 0xFF9E9E9E),
    active: j['active'] as bool? ?? true,
    rules: (j['rules'] as List? ?? const [])
        .map((e) => FlowRule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    start: (j['start'] as String?) == null ? null : DateTime.parse(j['start'] as String),
    end: (j['end'] as String?) == null ? null : DateTime.parse(j['end'] as String),
    notes: j['notes'] as String?,
    isReminder: (j['isReminder'] as bool?) ?? false,
  );
}
