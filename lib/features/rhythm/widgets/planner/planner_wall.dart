import 'package:flutter/material.dart';

import 'planner_visual_tokens.dart';

class PlannerWall extends StatelessWidget {
  const PlannerWall({
    super.key,
    required this.children,
    this.topPadding = 8,
    this.bottomPadding = 56,
  });

  final List<Widget> children;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        PlannerVisualTokens.wallHorizontalPadding,
        topPadding,
        PlannerVisualTokens.wallHorizontalPadding,
        bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: PlannerVisualTokens.plateGap),
            children[i],
          ],
        ],
      ),
    );
  }
}
