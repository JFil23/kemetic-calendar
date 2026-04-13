import 'package:flutter/material.dart';

import '../theme/rhythm_theme.dart';
import 'rhythm_section_header.dart';

class RhythmSectionCard extends StatelessWidget {
  const RhythmSectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RhythmTheme.cardSurface(),
      padding: padding ?? RhythmTheme.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            RhythmSectionHeader(
              title: title!,
              subtitle: subtitle,
              trailing: trailing,
            ),
          if (title != null) const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
