import 'package:flutter/material.dart';

import 'package:mobile/core/touch_targets.dart';

import 'planner_visual_tokens.dart';

class PlannerPillButton extends StatelessWidget {
  const PlannerPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.active = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final foreground = active
        ? PlannerVisualTokens.gold
        : PlannerVisualTokens.gold.withValues(
            alpha: PlannerVisualTokens.liftedAlpha(0.75),
          );
    final style = withExpandedTouchTargets(
      context,
      OutlinedButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: active
            ? PlannerVisualTokens.gold
            : PlannerVisualTokens.gold.withValues(
                alpha: PlannerVisualTokens.liftedAlpha(0.32),
              ),
        side: BorderSide(
          color: PlannerVisualTokens.gold.withValues(
            alpha: PlannerVisualTokens.liftedAlpha(active ? 0.45 : 0.30),
          ),
          width: 0.5,
        ),
        shape: const StadiumBorder(),
        padding: EdgeInsets.only(
          left: icon == null ? 16 : 12,
          right: 16,
          top: 7,
          bottom: 7,
        ),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, letterSpacing: 0.5),
      ),
    );

    if (icon == null) {
      return OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: style,
    );
  }
}
