import 'package:flutter/material.dart';

import '../theme/rhythm_theme.dart';

class RhythmPatternRow extends StatelessWidget {
  const RhythmPatternRow({
    super.key,
    required this.text,
    this.icon,
  });

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: RhythmTheme.frostSurface(),
          child: Icon(
            icon ?? Icons.schedule_rounded,
            size: 14,
            color: RhythmTheme.quartz,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: RhythmTheme.subheading,
        ),
      ],
    );
  }
}
