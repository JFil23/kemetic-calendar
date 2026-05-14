import 'package:flutter/material.dart';

class TimePattern {
  final List<int> daysOfWeek;
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final bool isOptional;

  const TimePattern({
    this.daysOfWeek = const [],
    this.allDay = false,
    this.start,
    this.end,
    this.isOptional = false,
  });

  TimePattern copyWith({
    List<int>? daysOfWeek,
    bool? allDay,
    TimeOfDay? start,
    TimeOfDay? end,
    bool? isOptional,
  }) {
    return TimePattern(
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      allDay: allDay ?? this.allDay,
      start: start ?? this.start,
      end: end ?? this.end,
      isOptional: isOptional ?? this.isOptional,
    );
  }
}

class RhythmDraft {
  final String? id;
  final String title;
  final String? description;
  final String category;
  final bool isTimed;
  final bool showInAlignment;
  final bool sendReminders;
  final bool trackContinuity;
  final List<TimePattern> patterns;

  const RhythmDraft({
    this.id,
    required this.title,
    this.description,
    required this.category,
    required this.isTimed,
    this.showInAlignment = true,
    this.sendReminders = false,
    this.trackContinuity = true,
    this.patterns = const [],
  });
}
