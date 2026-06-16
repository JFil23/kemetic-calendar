import 'package:flutter/material.dart';

import 'planner_visual_tokens.dart';

class PlannerHairlineRule extends StatelessWidget {
  const PlannerHairlineRule({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 18),
      color: PlannerVisualTokens.gold.withValues(
        alpha: PlannerVisualTokens.liftedAlpha(0.08),
      ),
    );
  }
}
