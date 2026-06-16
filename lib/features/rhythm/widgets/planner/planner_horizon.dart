import 'package:flutter/material.dart';

import 'planner_visual_tokens.dart';

class PlannerHorizon extends StatelessWidget {
  const PlannerHorizon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.fromLTRB(22, 28, 22, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            PlannerVisualTokens.gold.withValues(
              alpha: PlannerVisualTokens.liftedAlpha(0.25),
            ),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
