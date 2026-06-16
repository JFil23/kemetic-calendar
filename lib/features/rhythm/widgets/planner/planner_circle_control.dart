import 'package:flutter/material.dart';

import 'planner_visual_tokens.dart';

class PlannerCircleControl extends StatelessWidget {
  const PlannerCircleControl({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.heroTag,
    this.size = 30,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Object? heroTag;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? PlannerVisualTokens.gold.withValues(
            alpha: PlannerVisualTokens.liftedAlpha(0.22),
          )
        : PlannerVisualTokens.gold;
    final button = IconButton(
      constraints: const BoxConstraints.tightFor(
        width: kMinInteractiveDimension,
        height: kMinInteractiveDimension,
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.standard,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: PlannerVisualTokens.gold.withValues(
              alpha: PlannerVisualTokens.liftedAlpha(0.35),
            ),
            width: 0.5,
          ),
        ),
        child: Icon(icon, size: size * 0.58, color: color),
      ),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.padded,
        backgroundColor: Colors.transparent,
        shape: const CircleBorder(),
      ),
    );

    if (heroTag == null) return button;

    return Hero(tag: heroTag!, child: button);
  }
}
