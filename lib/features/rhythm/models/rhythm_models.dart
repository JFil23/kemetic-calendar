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

class RhythmSection {
  const RhythmSection({
    required this.title,
    this.subtitle,
    this.items = const [],
  });

  final String title;
  final String? subtitle;
  final List<RhythmItem> items;
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

  RhythmNote copyWith({
    String? text,
    int? position,
  }) {
    return RhythmNote(
      id: id,
      text: text ?? this.text,
      createdAt: createdAt,
      position: position ?? this.position,
    );
  }
}

/// Static placeholder data to render the UI while backend wiring is added.
class RhythmMockData {
  RhythmMockData._();

  static List<RhythmSection> myCycleSections() => const [
        RhythmSection(
          title: 'Rhythm of Day',
          subtitle: 'Set the cadence that holds everything else.',
          items: [
            RhythmItem(
              title: 'Wake with Light',
              summary: 'Gentle rise + water',
              pattern: 'Weekdays · 6:00 AM',
              chips: [RhythmChipKind.alignment, RhythmChipKind.continuity],
              icon: Icons.wb_twilight, // fallback if font lacks twilight
              isTimed: true,
            ),
            RhythmItem(
              title: 'Wind Down',
              summary: 'Screens off, stretch, candles',
              pattern: 'Nightly · 9:30 PM',
              chips: [RhythmChipKind.reminder, RhythmChipKind.continuity],
              icon: Icons.nightlight_round,
              isTimed: true,
            ),
          ],
        ),
        RhythmSection(
          title: 'Body & Nourishment',
          items: [
            RhythmItem(
              title: 'Mineral-rich breakfast',
              summary: 'Oats, dates, cinnamon',
              pattern: 'Weekdays · 8:00 AM',
              chips: [RhythmChipKind.alignment],
              icon: Icons.bakery_dining_rounded,
            ),
            RhythmItem(
              title: 'Hydration anchor',
              summary: 'Sip mint tea between sessions',
              chips: [RhythmChipKind.continuity],
              icon: Icons.local_drink_rounded,
            ),
          ],
        ),
        RhythmSection(
          title: 'Restoration',
          items: [
            RhythmItem(
              title: 'Afternoon reset',
              summary: '10 min breath + stretch',
              pattern: 'Daily · 2:00 PM',
              chips: [RhythmChipKind.alignment, RhythmChipKind.reminder],
              icon: Icons.self_improvement_rounded,
              isTimed: true,
            ),
          ],
        ),
        RhythmSection(
          title: 'Anchors',
          items: [
            RhythmItem(
              title: 'Evening journal',
              summary: 'Three lines and one gratitude',
              pattern: 'Nightly · 9:45 PM',
              chips: [RhythmChipKind.continuity, RhythmChipKind.reminder],
              icon: Icons.edit_note_rounded,
              isTimed: true,
            ),
          ],
        ),
        RhythmSection(
          title: 'Nourishing Activities',
          items: [
            RhythmItem(
              title: 'Walk under open sky',
              summary: '15–20 minutes outside',
              chips: [RhythmChipKind.alignment],
              icon: Icons.park_rounded,
            ),
          ],
        ),
        RhythmSection(
          title: 'Custom',
          items: [
            RhythmItem(
              title: 'Create something small',
              summary: 'Sketch, poem, or melody',
              chips: [RhythmChipKind.alignment],
              icon: Icons.auto_awesome_rounded,
              isCustom: true,
            ),
          ],
        ),
      ];

  static List<RhythmItem> todaysAlignment() => const [
        RhythmItem(
          title: 'Wake with Light',
          summary: 'Completed',
          pattern: '6:05 AM',
          state: RhythmItemState.done,
          chips: [RhythmChipKind.continuity],
          icon: Icons.wb_sunny_rounded,
        ),
        RhythmItem(
          title: 'Deep work',
          summary: 'Focus block 1',
          pattern: '8:00 – 10:00 AM',
          state: RhythmItemState.partial,
          chips: [RhythmChipKind.alignment],
          icon: Icons.auto_fix_high_rounded,
        ),
        RhythmItem(
          title: 'Reset walk',
          summary: 'pending',
          pattern: '2:00 PM',
          state: RhythmItemState.pending,
          chips: [RhythmChipKind.reminder],
          icon: Icons.park_rounded,
        ),
      ];

  static List<RhythmTodo> todos() => [
        RhythmTodo(
          id: '00000000-0000-4000-8000-000000000001',
          title: 'Book acupuncture follow-up',
          notes: 'Prefer Thursday',
          dueDate: DateTime.now().add(const Duration(days: 1)),
          dueTime: const TimeOfDay(hour: 11, minute: 30),
          state: RhythmItemState.pending,
        ),
        RhythmTodo(
          id: '00000000-0000-4000-8000-000000000002',
          title: 'Restock magnesium',
          notes: 'capsules + spray',
          state: RhythmItemState.partial,
        ),
        RhythmTodo(
          id: '00000000-0000-4000-8000-000000000003',
          title: 'Share Rhythm of Day with coach',
          state: RhythmItemState.done,
        ),
      ];

  static List<ContinuitySnapshot> continuity() => const [
        ContinuitySnapshot(
          title: 'Wake with Light',
          percent: 0.86,
          completed: 6,
          planned: 7,
          blocks: [
            ContinuityBlockState.done,
            ContinuityBlockState.done,
            ContinuityBlockState.done,
            ContinuityBlockState.partial,
            ContinuityBlockState.done,
            ContinuityBlockState.done,
            ContinuityBlockState.skipped,
          ],
          icon: Icons.wb_sunny_rounded,
        ),
        ContinuitySnapshot(
          title: 'Wind Down',
          percent: 0.71,
          completed: 5,
          planned: 7,
          blocks: [
            ContinuityBlockState.done,
            ContinuityBlockState.done,
            ContinuityBlockState.partial,
            ContinuityBlockState.partial,
            ContinuityBlockState.skipped,
            ContinuityBlockState.done,
            ContinuityBlockState.unscheduled,
          ],
          icon: Icons.nightlight_round,
        ),
      ];
}
