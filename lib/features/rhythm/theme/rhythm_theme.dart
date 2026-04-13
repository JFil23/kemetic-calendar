import 'package:flutter/material.dart';

import 'package:mobile/shared/glossy_text.dart' show gold, goldGloss;

/// Surfaces and typography for Rhythm — aligned with app black / 0x0D0D0F cards and Kemetic gold accents.
class RhythmTheme {
  RhythmTheme._();

  /// Primary accent (Kemetic gold); replaces the old teal.
  static const Color aurora = gold;

  /// Secondary accent for partial / warm highlights.
  static const Color ember = Color(0xFFE8C078);

  /// Muted body / support text.
  static const Color quartz = Color(0xFFB0B0B0);

  static Gradient get accentGradient => goldGloss;

  /// Cards: same language as Kemetic node list — subtle lift on black.
  static BoxDecoration cardSurface() => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      );

  static BoxDecoration frostSurface() => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      );

  /// Section / row titles (item rows); section card titles use gold via [RhythmSectionHeader].
  static TextStyle get heading =>
      const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white);

  static TextStyle get subheading =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: quartz);

  static TextStyle get label =>
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70);

  static EdgeInsets get cardPadding => const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
}
