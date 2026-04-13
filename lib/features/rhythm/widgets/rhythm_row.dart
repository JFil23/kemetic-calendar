import 'package:flutter/material.dart';

import '../models/rhythm_models.dart';
import '../theme/rhythm_theme.dart';
import 'rhythm_chip_row.dart';
import 'rhythm_pattern_row.dart';

class RhythmRow extends StatelessWidget {
  const RhythmRow({
    super.key,
    required this.item,
    this.onTap,
    this.trailing,
  });

  final RhythmItem item;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleStyle = RhythmTheme.heading.copyWith(fontSize: 16);
    final subtitleStyle = RhythmTheme.subheading.copyWith(color: Colors.white70);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: RhythmTheme.frostSurface(),
              padding: const EdgeInsets.all(10),
              child: Icon(
                item.icon ?? Icons.auto_awesome_rounded,
                color: RhythmTheme.aurora,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: titleStyle),
                            const SizedBox(height: 4),
                            Text(item.summary, style: subtitleStyle),
                          ],
                        ),
                      ),
                      if (item.state != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: _RhythmStatePill(state: item.state!),
                        ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  if (item.pattern != null) ...[
                    const SizedBox(height: 8),
                    RhythmPatternRow(text: item.pattern!),
                  ],
                  if (item.chips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    RhythmChipRow(kinds: item.chips),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RhythmStatePill extends StatelessWidget {
  const _RhythmStatePill({required this.state});

  final RhythmItemState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      RhythmItemState.pending => ('pending', Colors.white70),
      RhythmItemState.done => ('done', RhythmTheme.aurora),
      RhythmItemState.partial => ('partial', RhythmTheme.ember),
      RhythmItemState.skipped => ('skipped', Colors.redAccent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}
