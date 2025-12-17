import 'dart:convert';

import 'package:flutter/material.dart';

enum ReminderRepeatKind {
  none,
  everyNDays,
  weekly,
  monthlyDay,
  kemeticEveryNDecans,
  kemeticDecanDay,
  kemeticMonthDay,
}

@immutable
class ReminderRepeat {
  final ReminderRepeatKind kind;
  final int interval; // Used for everyNDays / kemeticEveryNDecans
  final Set<int> weekdays; // 1=Mon..7=Sun
  final int? monthDay; // Gregorian day-of-month (1-31)
  final int? decanDay; // 1-10
  final int? kemeticMonthDay; // 1-30

  const ReminderRepeat({
    this.kind = ReminderRepeatKind.none,
    this.interval = 1,
    this.weekdays = const {},
    this.monthDay,
    this.decanDay,
    this.kemeticMonthDay,
  });

  Map<String, dynamic> toJson() {
    return {
      'kind': kind.name,
      'interval': interval,
      'weekdays': weekdays.toList(),
      'monthDay': monthDay,
      'decanDay': decanDay,
      'kemeticMonthDay': kemeticMonthDay,
    };
  }

  factory ReminderRepeat.fromJson(Map<String, dynamic> json) {
    ReminderRepeatKind _kindFrom(String? raw) {
      return ReminderRepeatKind.values.firstWhere(
        (k) => k.name == raw,
        orElse: () => ReminderRepeatKind.none,
      );
    }

    return ReminderRepeat(
      kind: _kindFrom(json['kind'] as String?),
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      weekdays: {
        for (final n in (json['weekdays'] as List? ?? const []))
          (n as num).toInt(),
      },
      monthDay: (json['monthDay'] as num?)?.toInt(),
      decanDay: (json['decanDay'] as num?)?.toInt(),
      kemeticMonthDay: (json['kemeticMonthDay'] as num?)?.toInt(),
    );
  }

  ReminderRepeat copyWith({
    ReminderRepeatKind? kind,
    int? interval,
    Set<int>? weekdays,
    int? monthDay,
    int? decanDay,
    int? kemeticMonthDay,
  }) {
    return ReminderRepeat(
      kind: kind ?? this.kind,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      monthDay: monthDay ?? this.monthDay,
      decanDay: decanDay ?? this.decanDay,
      kemeticMonthDay: kemeticMonthDay ?? this.kemeticMonthDay,
    );
  }
}

@immutable
class ReminderRule {
  final String id;
  final String title;
  final DateTime startLocal;
  final bool allDay;
  final Color color;
  final String? category;
  final bool active;
  final ReminderRepeat repeat;

  const ReminderRule({
    required this.id,
    required this.title,
    required this.startLocal,
    this.allDay = false,
    required this.color,
    this.category,
    this.active = true,
    this.repeat = const ReminderRepeat(),
  });

  ReminderRule copyWith({
    String? id,
    String? title,
    DateTime? startLocal,
    bool? allDay,
    Color? color,
    String? category,
    bool? active,
    ReminderRepeat? repeat,
  }) {
    return ReminderRule(
      id: id ?? this.id,
      title: title ?? this.title,
      startLocal: startLocal ?? this.startLocal,
      allDay: allDay ?? this.allDay,
      color: color ?? this.color,
      category: category ?? this.category,
      active: active ?? this.active,
      repeat: repeat ?? this.repeat,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startLocal': startLocal.toIso8601String(),
      'allDay': allDay,
      'color': color.value,
      'category': category,
      'active': active,
      'repeat': repeat.toJson(),
    };
  }

  factory ReminderRule.fromJson(Map<String, dynamic> json) {
    return ReminderRule(
      id: json['id'] as String,
      title: json['title'] as String,
      startLocal: DateTime.parse(json['startLocal'] as String),
      allDay: (json['allDay'] as bool?) ?? false,
      color: Color((json['color'] as num?)?.toInt() ?? Colors.blue.value),
      category: json['category'] as String?,
      active: (json['active'] as bool?) ?? true,
      repeat: ReminderRepeat.fromJson(
        Map<String, dynamic>.from(
          (json['repeat'] as Map?) ?? const {},
        ),
      ),
    );
  }

  static String encodeList(List<ReminderRule> rules) {
    // Deduplicate by id before encoding
    final seen = <String>{};
    final deduped = <ReminderRule>[];
    for (final r in rules) {
      if (seen.add(r.id)) {
        deduped.add(r);
      }
    }
    return jsonEncode(deduped.map((r) => r.toJson()).toList());
  }

  static List<ReminderRule> decodeList(String raw) {
    final data = jsonDecode(raw) as List;
    final seen = <String>{};
    final out = <ReminderRule>[];
    for (final e in data) {
      final rule = ReminderRule.fromJson(Map<String, dynamic>.from(e as Map));
      if (seen.add(rule.id)) {
        out.add(rule);
      }
    }
    return out;
  }
}
