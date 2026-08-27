import 'package:flutter/material.dart';

import '../../../presentation/maat_flow_detail_shell.dart';

/// V11 reference geometry for Follow the Sky detail at ~390 logical px width.
abstract final class FollowSkyV11Tokens {
  static const double referenceWidth = MaatFlowDetailGeometry.referenceWidth;
  static const double referenceHeight = MaatFlowDetailGeometry.referenceHeight;
  static const double heroHeight = MaatFlowDetailGeometry.heroHeight;
  static const double sheetOverlap = MaatFlowDetailGeometry.sheetOverlap;
  static const double heroParallaxFactor =
      MaatFlowDetailGeometry.heroParallaxFactor;
  static const double heroFadeScrollDistance =
      MaatFlowDetailGeometry.heroFadeScrollDistance;
  static const double heroImageAlignmentY = 0.48;
  static const double bottomContentClearance =
      MaatFlowDetailGeometry.bottomContentClearance;

  static const Color pageBg = Color(0xFF050504);
  static const Color sheetBg = Color(0xFF080706);
  static const Color turningSheetBg = Color(0xFF0D0B07);
  static const Color gold = Color(0xFFD4AE43);
  static const Color goldDim = Color(0xFF8A7030);
  static const Color silverHi = Color(0xFFC8C4BC);
  static const Color silverMid = Color(0xFF9E9A94);
  static const Color silverLo = Color(0xFF6A6660);
  static const Color separator = Color(0xFF2A2415);
  static const Color intentionPeriwinkle = Color(0xFF6876D8);
  static const Color glow = Color(0xFFA4B1FF);
  static const Color previewDash = Color(0x66D4AE43);
  static const Color calendarPreview = Color(0xFF120F08);
  static const Color calendarAntique = Color(0xFFD0B253);
  static const Color calendarDay = Color(0xFFB99C58);
  static const Color calendarWeekday = Color(0xFF9D8654);
  static const Color calendarDecan = Color(0xFFAA8F55);
  static const Color calendarGregorian = Color(0xFF4DA3FF);
  static const Color calendarTransliteration = Color(0xFFB09355);
  static const Color calendarMuted = Color(0xFFB3A596);

  static const MaatFlowDetailTheme detailTheme = MaatFlowDetailTheme(
    pageBackground: pageBg,
    sheetBackground: sheetBg,
    sheetBorder: Color(0x2ED4AE43),
    accent: gold,
    primaryText: silverHi,
    secondaryText: silverMid,
    mutedText: silverLo,
    separator: separator,
    glow: glow,
  );

  static const double decanRowHeight = 80;
  static const double dayNumberAreaHeight = 42;
  static const double todayRingDiameter = 40;
  static const double skyRingDiameter = 36;
  static const double ringDotGap = 6;
  static const double todayLabelFontSize = 10.5;
  static const double dayNumberFontSize = 21;

  static const String heroAsset = 'assets/follow_the_sky/hero.png';
  static const String heroSubtitle =
      "Sky · the year's turnings, in Kemetic time";
}
