import 'package:flutter/material.dart';

import 'package:mobile/shared/glossy_text.dart';

const String kJournalEmptyBadgeGlyph = '𓂝';

class JournalEmptyBadgeGlyph extends StatelessWidget {
  const JournalEmptyBadgeGlyph({super.key, this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: KemeticGold.glyph(kJournalEmptyBadgeGlyph, size: size),
    );
  }
}
