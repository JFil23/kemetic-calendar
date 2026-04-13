import 'package:flutter/material.dart';

import '../models/rhythm_models.dart';
import '../theme/rhythm_theme.dart';

class RhythmChipRow extends StatelessWidget {
  const RhythmChipRow({
    super.key,
    required this.kinds,
  });

  final List<RhythmChipKind> kinds;

  @override
  Widget build(BuildContext context) {
    if (kinds.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: kinds.map((kind) => _RhythmChip(kind: kind)).toList(),
    );
  }
}

class _RhythmChip extends StatelessWidget {
  const _RhythmChip({required this.kind});

  final RhythmChipKind kind;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (kind) {
      RhythmChipKind.alignment => ('Alignment', RhythmTheme.aurora),
      RhythmChipKind.reminder => ('Reminder', RhythmTheme.ember),
      RhythmChipKind.continuity => ('Continuity', Colors.white70),
    };

    final icon = switch (kind) {
      RhythmChipKind.alignment => Icons.auto_fix_high_rounded,
      RhythmChipKind.reminder => Icons.notifications_active_rounded,
      RhythmChipKind.continuity => Icons.timeline_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
