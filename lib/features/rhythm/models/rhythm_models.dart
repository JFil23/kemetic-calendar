import 'package:flutter/material.dart';

enum RhythmChipKind { alignment, reminder, continuity }

enum RhythmItemState { pending, done, partial, skipped }

enum ContinuityBlockState { done, partial, skipped, unscheduled }

class RhythmItem {
  const RhythmItem({
    required this.title,
    required this.summary,
    this.pattern,
    this.chips = const [],
    this.state,
    this.icon,
    this.isCustom = false,
    this.isTimed = false,
  });

  final String title;
  final String summary;
  final String? pattern;
  final List<RhythmChipKind> chips;
  final RhythmItemState? state;
  final IconData? icon;
  final bool isCustom;
  final bool isTimed;

  RhythmItem copyWith({
    String? title,
    String? summary,
    String? pattern,
    List<RhythmChipKind>? chips,
    RhythmItemState? state,
    IconData? icon,
    bool? isCustom,
    bool? isTimed,
  }) {
    return RhythmItem(
      title: title ?? this.title,
      summary: summary ?? this.summary,
      pattern: pattern ?? this.pattern,
      chips: chips ?? this.chips,
      state: state ?? this.state,
      icon: icon ?? this.icon,
      isCustom: isCustom ?? this.isCustom,
      isTimed: isTimed ?? this.isTimed,
    );
  }
}

class ContinuitySnapshot {
  const ContinuitySnapshot({
    required this.title,
    required this.percent,
    required this.completed,
    required this.planned,
    this.blocks = const [],
    this.icon,
  });

  final String title;
  final double percent;
  final int completed;
  final int planned;
  final List<ContinuityBlockState> blocks;
  final IconData? icon;
}

class RhythmTodo {
  const RhythmTodo({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    this.dueTime,
    this.isChecklist = true,
    this.isCalendar = true,
    this.state = RhythmItemState.pending,
  });

  final String id;
  final String title;
  final String? notes;
  final DateTime? dueDate;
  final TimeOfDay? dueTime;
  final bool isChecklist;
  final bool isCalendar;
  final RhythmItemState state;
}

class RhythmTodoDraft {
  const RhythmTodoDraft({
    required this.title,
    this.notes,
    this.dueDate,
    this.dueTime,
    this.metadata = const <String, dynamic>{},
  });

  final String title;
  final String? notes;
  final DateTime? dueDate;
  final TimeOfDay? dueTime;
  final Map<String, dynamic> metadata;

  RhythmTodoDraft copyWith({
    String? title,
    String? notes,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    Map<String, dynamic>? metadata,
  }) {
    return RhythmTodoDraft(
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      metadata: metadata ?? this.metadata,
    );
  }
}

class RhythmNote {
  const RhythmNote({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.position,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final int position;

  RhythmNote copyWith({String? text, int? position}) {
    return RhythmNote(
      id: id,
      text: text ?? this.text,
      createdAt: createdAt,
      position: position ?? this.position,
    );
  }
}
