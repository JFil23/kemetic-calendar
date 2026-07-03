import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';

import '../models/rhythm_models.dart';
import 'planner/planner_visual_tokens.dart';

class RhythmStateButtonGroup extends StatelessWidget {
  const RhythmStateButtonGroup({
    super.key,
    required this.current,
    this.onChanged,
    this.onMoveToTomorrow,
    this.onDelete,
  });

  final RhythmItemState current;
  final ValueChanged<RhythmItemState>? onChanged;
  final VoidCallback? onMoveToTomorrow;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final options =
        <
          ({
            RhythmItemState state,
            IconData icon,
            bool isActive,
            String tooltip,
            VoidCallback? onTap,
          })
        >[
          (
            state: RhythmItemState.done,
            icon: Icons.check_circle_rounded,
            isActive: current == RhythmItemState.done,
            tooltip: 'Done',
            onTap: onChanged != null
                ? () => onChanged!(
                    current == RhythmItemState.done
                        ? RhythmItemState.pending
                        : RhythmItemState.done,
                  )
                : null,
          ),
          if (onMoveToTomorrow != null && current != RhythmItemState.done)
            (
              state: RhythmItemState.partial,
              icon: Icons.arrow_forward_rounded,
              isActive: false,
              tooltip: 'Move to tomorrow',
              onTap: onMoveToTomorrow,
            )
          else if (onMoveToTomorrow == null)
            (
              state: RhythmItemState.partial,
              icon: Icons.adjust_rounded,
              isActive: current == RhythmItemState.partial,
              tooltip: 'Partial',
              onTap: onChanged != null
                  ? () => onChanged!(
                      current == RhythmItemState.partial
                          ? RhythmItemState.pending
                          : RhythmItemState.partial,
                    )
                  : null,
            ),
          if (onDelete != null)
            (
              state: RhythmItemState.skipped,
              icon: Icons.delete_outline_rounded,
              isActive: false,
              tooltip: 'Delete',
              onTap: onDelete,
            )
          else
            (
              state: RhythmItemState.skipped,
              icon: Icons.remove_circle_outline_rounded,
              isActive: current == RhythmItemState.skipped,
              tooltip: 'Skipped',
              onTap: onChanged != null
                  ? () => onChanged!(
                      current == RhythmItemState.skipped
                          ? RhythmItemState.pending
                          : RhythmItemState.skipped,
                    )
                  : null,
            ),
        ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            RhythmStateDot(
              state: options[i].state,
              isActive: options[i].isActive,
              icon: options[i].icon,
              tooltip: options[i].tooltip,
              onTap: options[i].onTap,
            ),
          ],
        ],
      ),
    );
  }
}

class RhythmStateDot extends StatelessWidget {
  const RhythmStateDot({
    super.key,
    required this.state,
    required this.isActive,
    this.icon,
    this.tooltip,
    this.onTap,
    this.padding = const EdgeInsets.all(8),
    this.iconSize = 18,
    this.borderRadius = 12,
  });

  final RhythmItemState state;
  final IconData? icon;
  final String? tooltip;
  final bool isActive;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double iconSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (state) {
      RhythmItemState.done => (
        PlannerVisualTokens.gold,
        PlannerVisualTokens.gold.withValues(
          alpha: PlannerVisualTokens.liftedAlpha(0.15),
        ),
      ),
      RhythmItemState.partial => (
        PlannerVisualTokens.noteGold.withValues(
          alpha: PlannerVisualTokens.liftedAlpha(0.82),
        ),
        PlannerVisualTokens.noteGold.withValues(
          alpha: PlannerVisualTokens.liftedAlpha(0.10),
        ),
      ),
      RhythmItemState.skipped => (
        Colors.redAccent.withValues(
          alpha: PlannerVisualTokens.liftedAlpha(0.76),
        ),
        Colors.redAccent.withValues(
          alpha: PlannerVisualTokens.liftedAlpha(0.10),
        ),
      ),
      RhythmItemState.pending => (
        PlannerVisualTokens.gold.withValues(
          alpha: PlannerVisualTokens.liftedAlpha(0.34),
        ),
        Colors.transparent,
      ),
    };
    final resolvedIcon =
        icon ??
        switch (state) {
          RhythmItemState.done => Icons.check_circle_rounded,
          RhythmItemState.partial => Icons.adjust_rounded,
          RhythmItemState.skipped => Icons.remove_circle_outline_rounded,
          RhythmItemState.pending => Icons.radio_button_unchecked_rounded,
        };

    final minTouchSize = useExpandedTouchTargets(context)
        ? kMinInteractiveDimension
        : 0.0;

    final dot = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minTouchSize,
          minHeight: minTouchSize,
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: padding,
            decoration: BoxDecoration(
              color: isActive ? background : Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isActive
                    ? color.withValues(
                        alpha: PlannerVisualTokens.liftedAlpha(0.58),
                      )
                    : PlannerVisualTokens.gold.withValues(
                        alpha: PlannerVisualTokens.liftedAlpha(0.14),
                      ),
                width: 0.7,
              ),
            ),
            child: Icon(resolvedIcon, size: iconSize, color: color),
          ),
        ),
      ),
    );
    if (tooltip == null || tooltip!.trim().isEmpty) return dot;
    return Tooltip(message: tooltip!, child: dot);
  }
}
