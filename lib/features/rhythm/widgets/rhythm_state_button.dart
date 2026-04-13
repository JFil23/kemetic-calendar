import 'package:flutter/material.dart';

import '../models/rhythm_models.dart';
import '../theme/rhythm_theme.dart';

class RhythmStateButtonGroup extends StatelessWidget {
  const RhythmStateButtonGroup({
    super.key,
    required this.current,
    this.onChanged,
  });

  final RhythmItemState current;
  final ValueChanged<RhythmItemState>? onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (RhythmItemState.done, Icons.check_circle_rounded),
      (RhythmItemState.partial, Icons.adjust_rounded),
      (RhythmItemState.skipped, Icons.remove_circle_outline_rounded),
    ];

    return Wrap(
      spacing: 8,
      children: [
        for (final option in options)
          _StateDot(
            state: option.$1,
            icon: option.$2,
            isActive: current == option.$1,
            onTap: onChanged != null ? () => onChanged!(option.$1) : null,
          ),
      ],
    );
  }
}

class _StateDot extends StatelessWidget {
  const _StateDot({
    required this.state,
    required this.icon,
    required this.isActive,
    this.onTap,
  });

  final RhythmItemState state;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (state) {
      RhythmItemState.done => (RhythmTheme.aurora, RhythmTheme.aurora.withValues(alpha: 0.14)),
      RhythmItemState.partial => (RhythmTheme.ember, RhythmTheme.ember.withValues(alpha: 0.14)),
      RhythmItemState.skipped => (Colors.redAccent, Colors.redAccent.withValues(alpha: 0.12)),
      RhythmItemState.pending => (Colors.white54, Colors.white12),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? background : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? color.withValues(alpha: 0.6) : Colors.white12),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
