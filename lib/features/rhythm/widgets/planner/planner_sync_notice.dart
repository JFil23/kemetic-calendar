import 'package:flutter/material.dart';
import '../../theme/rhythm_theme.dart';
import 'planner_visual_tokens.dart';

/// Uses the existing Planner notice geometry for durable-save status.
class PlannerSyncNotice extends StatelessWidget {
  const PlannerSyncNotice({super.key, required this.message, this.onReview});
  final String message;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orangeAccent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(PlannerVisualTokens.plateRadius),
      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_sync, color: Colors.orangeAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: RhythmTheme.subheading.copyWith(
                  color: Colors.orangeAccent,
                ),
              ),
            ),
          ],
        ),
        if (onReview != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onReview,
              child: const Text('Review changes'),
            ),
          ),
      ],
    ),
  );
}
