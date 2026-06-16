import 'package:flutter/material.dart';

abstract final class PlannerVisualTokens {
  static const Color gold = Color(0xFFC8A84A);
  static const Color noteGold = Color(0xFFD4A843);
  static const Color pageTop = Color(0xFF070402);
  static const Color pageMid = Color(0xFF090501);
  static const Color pageBottom = Color(0xFF0B0600);
  static const Color textWarm = Color(0xFFE8D090);
  static const Color stoneTop = Color(0xC51C170F);
  static const Color stoneMid = Color(0xD20F0B07);
  static const Color stoneBottom = Color(0xC5140F09);

  static const double plateRadius = 6;
  static const double wallHorizontalPadding = 22;
  static const double plateGap = 38;
  static const double plateLabelGap = 14;
  static const double notesCarouselViewportFraction = 0.86;
  static const double nutritionCarouselViewportFraction = 0.88;
  static const double matteVisibilityLift = 1.25;

  static const String serifFamily = 'CormorantGaramond';
  static const List<String> serifFallback = ['GentiumPlus', 'Georgia', 'serif'];
  static const String sansFamily = 'Inter';
  static const List<String> sansFallback = ['Roboto', 'Arial', 'sans-serif'];

  static double liftedAlpha(double alpha) =>
      (alpha * matteVisibilityLift).clamp(0.0, 1.0).toDouble();

  static TextStyle get plateLabelStyle => TextStyle(
    fontFamily: sansFamily,
    fontFamilyFallback: sansFallback,
    fontSize: 11,
    letterSpacing: 4,
    color: gold.withValues(alpha: liftedAlpha(0.50)),
  );

  static TextStyle get ceremonialItalic => TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallback,
    fontStyle: FontStyle.italic,
    color: gold.withValues(alpha: liftedAlpha(0.50)),
  );

  static TextStyle get plateBody => TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallback,
    fontSize: 16,
    height: 1.35,
    color: const Color(0xFFE1CDA0).withValues(alpha: 0.90),
  );

  static TextStyle get captionItalic => ceremonialItalic.copyWith(
    fontSize: 13,
    color: gold.withValues(alpha: liftedAlpha(0.45)),
    height: 1.4,
  );

  static TextStyle get inputText => TextStyle(
    fontFamily: serifFamily,
    fontFamilyFallback: serifFallback,
    fontSize: 16,
    fontStyle: FontStyle.italic,
    color: const Color(0xFFD8C890),
  );

  static TextStyle get inputHint =>
      inputText.copyWith(color: gold.withValues(alpha: liftedAlpha(0.22)));

  static BorderSide get quietGoldBorder =>
      BorderSide(color: gold.withValues(alpha: liftedAlpha(0.15)), width: 0.5);

  static BorderSide get focusedGoldBorder =>
      BorderSide(color: gold.withValues(alpha: liftedAlpha(0.40)), width: 0.8);
}
