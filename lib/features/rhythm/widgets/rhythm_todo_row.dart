import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/rhythm_models.dart';
import '../theme/rhythm_theme.dart';
import 'rhythm_state_button.dart';

class RhythmTodoRow extends StatelessWidget {
  const RhythmTodoRow({
    super.key,
    required this.todo,
    this.onStateChanged,
    this.dueTextOverride,
    this.dueTextColor,
  });

  final RhythmTodo todo;
  final ValueChanged<RhythmItemState>? onStateChanged;
  final String? dueTextOverride;
  final Color? dueTextColor;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d');
    final timeFormatter = DateFormat('h:mm a');

    String? dueText = dueTextOverride;
    if (dueText == null) {
      if (todo.dueDate != null) {
        dueText = formatter.format(todo.dueDate!);
        if (todo.dueTime != null) {
          final dateTime = DateTime(
            todo.dueDate!.year,
            todo.dueDate!.month,
            todo.dueDate!.day,
            todo.dueTime!.hour,
            todo.dueTime!.minute,
          );
          dueText = '$dueText · ${timeFormatter.format(dateTime)}';
        }
      } else if (todo.dueTime != null) {
        final now = DateTime.now();
        dueText = timeFormatter.format(
          DateTime(
            now.year,
            now.month,
            now.day,
            todo.dueTime!.hour,
            todo.dueTime!.minute,
          ),
        );
      }
    }

    final baseDueColor =
        dueTextColor ?? RhythmTheme.subheading.color ?? Colors.white70;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: RhythmTheme.frostSurface(),
          child: Icon(
            Icons.checklist_rounded,
            color: RhythmTheme.aurora,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(todo.title, style: RhythmTheme.heading.copyWith(fontSize: 16)),
              if (todo.notes != null) ...[
                const SizedBox(height: 4),
                Text(todo.notes!, style: RhythmTheme.subheading),
              ],
              if (dueText != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text(
                      dueText,
                      style: RhythmTheme.subheading.copyWith(
                        color: baseDueColor,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              RhythmStateButtonGroup(
                current: todo.state,
                onChanged: onStateChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
