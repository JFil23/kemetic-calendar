import 'package:flutter/material.dart';
import 'package:mobile/core/touch_targets.dart';

import '../models/rhythm_models.dart';
import '../theme/rhythm_theme.dart';

class RhythmStateButtonGroup extends StatelessWidget {
  const RhythmStateButtonGroup({
    super.key,
    required this.current,
    this.onChanged,
    this.onDelete,
  });

  final RhythmItemState current;
  final ValueChanged<RhythmItemState>? onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final options =
        <
          ({
            RhythmItemState state,
            IconData icon,
            bool isActive,
            VoidCallback? onTap,
          })
        >[
          (
            state: RhythmItemState.done,
            icon: Icons.check_circle_rounded,
            isActive: current == RhythmItemState.done,
            onTap: onChanged != null
                ? () => onChanged!(
                    current == RhythmItemState.done
                        ? RhythmItemState.pending
                        : RhythmItemState.done,
                  )
                : null,
          ),
          (
            state: RhythmItemState.partial,
            icon: Icons.adjust_rounded,
            isActive: current == RhythmItemState.partial,
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
              onTap: onDelete,
            )
          else
            (
              state: RhythmItemState.skipped,
              icon: Icons.remove_circle_outline_rounded,
              isActive: current == RhythmItemState.skipped,
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
    this.onTap,
    this.padding = const EdgeInsets.all(8),
    this.iconSize = 18,
    this.borderRadius = 12,
  });

  final RhythmItemState state;
  final IconData? icon;
  final bool isActive;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double iconSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (state) {
      RhythmItemState.done => (
        RhythmTheme.aurora,
        RhythmTheme.aurora.withValues(alpha: 0.14),
      ),
      RhythmItemState.partial => (
        RhythmTheme.ember,
        RhythmTheme.ember.withValues(alpha: 0.14),
      ),
      RhythmItemState.skipped => (
        Colors.redAccent,
        Colors.redAccent.withValues(alpha: 0.12),
      ),
      RhythmItemState.pending => (Colors.white54, Colors.white12),
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

    return GestureDetector(
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
                color: isActive ? color.withValues(alpha: 0.6) : Colors.white12,
              ),
            ),
            child: Icon(resolvedIcon, size: iconSize, color: color),
          ),
        ),
      ),
    );
  }
}
