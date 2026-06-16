import 'package:flutter/material.dart';

import 'planner_visual_tokens.dart';

class PlannerPlate extends StatelessWidget {
  const PlannerPlate({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            label.toUpperCase(),
            style: PlannerVisualTokens.plateLabelStyle,
          ),
        ),
        const SizedBox(height: PlannerVisualTokens.plateLabelGap),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              PlannerVisualTokens.plateRadius,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PlannerVisualTokens.stoneTop,
                PlannerVisualTokens.stoneMid,
                PlannerVisualTokens.stoneBottom,
              ],
              stops: [0, 0.55, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: PlannerVisualTokens.gold.withValues(
                            alpha: PlannerVisualTokens.liftedAlpha(0.18),
                          ),
                          width: 0.5,
                        ),
                      ),
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.05,
                        colors: [
                          PlannerVisualTokens.gold.withValues(
                            alpha: PlannerVisualTokens.liftedAlpha(0.06),
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.70],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        PlannerVisualTokens.plateRadius,
                      ),
                      border: Border.all(
                        color: PlannerVisualTokens.gold.withValues(
                          alpha: PlannerVisualTokens.liftedAlpha(0.07),
                        ),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ],
    );
  }
}
