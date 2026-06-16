import 'package:flutter/material.dart';

import 'planner_visual_tokens.dart';

class PlannerPagerDots extends StatelessWidget {
  const PlannerPagerDots({
    super.key,
    required this.count,
    required this.activeIndex,
    this.dotSize = 6,
    this.activeWidth = 16,
  });

  final int count;
  final int activeIndex;
  final double dotSize;
  final double activeWidth;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: activeIndex == i ? activeWidth : dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: activeIndex == i
                  ? PlannerVisualTokens.noteGold.withValues(
                      alpha: PlannerVisualTokens.liftedAlpha(0.70),
                    )
                  : PlannerVisualTokens.gold.withValues(
                      alpha: PlannerVisualTokens.liftedAlpha(0.15),
                    ),
              borderRadius: BorderRadius.circular(dotSize / 2),
            ),
          ),
      ],
    );
  }
}
