import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/rhythm_models.dart';
import 'planner/planner_visual_tokens.dart';
import 'rhythm_state_button.dart';

class RhythmTodoRow extends StatelessWidget {
  const RhythmTodoRow({
    super.key,
    required this.todo,
    this.onStateChanged,
    this.onMoveToTomorrow,
    this.onDelete,
    this.dueTextOverride,
    this.dueTextColor,
  });

  final RhythmTodo todo;
  final ValueChanged<RhythmItemState>? onStateChanged;
  final VoidCallback? onMoveToTomorrow;
  final VoidCallback? onDelete;
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
        dueTextColor ??
        PlannerVisualTokens.gold.withValues(
          alpha: PlannerVisualTokens.liftedAlpha(0.50),
        );
    final isDone = todo.state == RhythmItemState.done;
    final bodyColor = const Color(
      0xFFE0C897,
    ).withValues(alpha: PlannerVisualTokens.liftedAlpha(isDone ? 0.38 : 0.82));
    final titleStyle = PlannerVisualTokens.plateBody.copyWith(
      color: bodyColor,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
      decorationColor: PlannerVisualTokens.gold.withValues(
        alpha: PlannerVisualTokens.liftedAlpha(0.36),
      ),
      decorationThickness: 1.0,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: PlannerVisualTokens.gold.withValues(
                  alpha: PlannerVisualTokens.liftedAlpha(isDone ? 0.44 : 0.22),
                ),
                width: 0.7,
              ),
              color: isDone
                  ? PlannerVisualTokens.gold.withValues(
                      alpha: PlannerVisualTokens.liftedAlpha(0.12),
                    )
                  : Colors.transparent,
            ),
            child: Icon(
              isDone
                  ? Icons.check_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: PlannerVisualTokens.gold.withValues(
                alpha: PlannerVisualTokens.liftedAlpha(isDone ? 0.72 : 0.26),
              ),
              size: isDone ? 12 : 9,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(todo.title, style: titleStyle),
                if (todo.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    todo.notes!,
                    style: PlannerVisualTokens.captionItalic.copyWith(
                      fontStyle: FontStyle.normal,
                      color: PlannerVisualTokens.gold.withValues(
                        alpha: PlannerVisualTokens.liftedAlpha(0.42),
                      ),
                    ),
                  ),
                ],
                if (dueText != null) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: PlannerVisualTokens.gold.withValues(
                          alpha: PlannerVisualTokens.liftedAlpha(0.35),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dueText,
                        style: PlannerVisualTokens.captionItalic.copyWith(
                          color: baseDueColor.withValues(
                            alpha: PlannerVisualTokens.liftedAlpha(0.64),
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                RhythmStateButtonGroup(
                  current: todo.state,
                  onChanged: onStateChanged,
                  onMoveToTomorrow: onMoveToTomorrow,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
