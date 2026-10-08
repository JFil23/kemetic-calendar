import 'package:flutter/material.dart';
import '../reflections/decan_review_controller.dart';
import '../reflections/decan_review_widgets.dart';

const decanReflectionLowerThirdBadgeKey = ValueKey<String>(
  'decan-reflection-lower-third-badge',
);

@immutable
class CalendarDecanReflectionPrompt {
  const CalendarDecanReflectionPrompt({
    required this.id,
    required this.reviewWindow,
  });
  final String? id;
  final DecanReviewWindow reviewWindow;
  DateTime get decanStart => reviewWindow.start;
  DateTime get decanEnd => reviewWindow.end;
}

class DecanReflectionLowerThirdBadge extends StatelessWidget {
  const DecanReflectionLowerThirdBadge({
    super.key = decanReflectionLowerThirdBadgeKey,
    required this.prompt,
    required this.maxWidth,
    required this.onTap,
  });
  final CalendarDecanReflectionPrompt prompt;
  final double maxWidth;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 13, 20, 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0x66D4AE43)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B140D), Color(0xFF120E0A)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xAA000000),
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DecanReviewSeal(),
                const SizedBox(width: 15),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'These ten days',
                        style: DecanReviewStyle.serif(23, height: 1),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Your decan reflection',
                        style: DecanReviewStyle.ui(11, height: 1, spacing: .22),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: DecanReviewStyle.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
