import 'package:flutter/material.dart';

import 'planner_visual_tokens.dart';

class PlannerWarmBackground extends StatelessWidget {
  const PlannerWarmBackground({
    super.key,
    required this.percent,
    required this.child,
    this.enabled = true,
  });

  final int percent;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final warmth = (percent / 100).clamp(0.0, 1.0).toDouble();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            PlannerVisualTokens.pageTop,
            PlannerVisualTokens.pageMid,
            PlannerVisualTokens.pageBottom,
          ],
          stops: [0, 0.60, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 1.25,
                    colors: [
                      Color.lerp(
                        const Color(0x171E1405),
                        const Color(0x3338A01E),
                        warmth,
                      )!,
                      Colors.transparent,
                    ],
                    stops: const [0, 0.58],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
