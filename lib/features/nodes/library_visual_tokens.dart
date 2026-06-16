import 'package:flutter/material.dart';

class LibraryVisualTokens {
  const LibraryVisualTokens._();

  static const Color base = Color(0xFF181818);
  static const Color base2 = Color(0xFF181818);
  static const Color card = Color(0xFF1A160D);
  static const Color cardEnd = Color(0xFF100E08);
  static const Color cardEdge = Color(0xFF2A2214);
  static const Color gold = Color(0xFFD4AE43);
  static const Color goldDim = Color(0xFFB8965A);
  static const Color brass = Color(0xFF8A744A);
  static const Color highlightText = Color(0xFFC8C4BC);
  static const Color midText = Color(0xFF9E9A94);
  static const Color lowText = Color(0xFF6A6660);
  static const Color spine = Color(0xFF5A4A2C);
  static const Color spineLit = Color(0xFFC7A24E);
  static const Color glow = Color(0xFFF5E8CB);
  static const Color iconBox = Color(0xFF0B0C08);
  static const Color transparent = Color(0x00000000);

  static const String serifFont = 'CormorantGaramond';
  static const String glyphFont = 'Noto Sans Egyptian Hieroglyphs';
  static const List<String> glyphFontFallback = [
    'NotoSansEgyptianHieroglyphs',
    'GentiumPlus',
    'NotoSans',
    'Roboto',
    'Arial',
    'sans-serif',
  ];
  static const List<String> sansFontFallback = [
    'NotoSans',
    'Roboto',
    'Arial',
    'sans-serif',
  ];

  static const Gradient flatGold = LinearGradient(colors: [gold, gold]);

  static const Gradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [base, base2],
  );

  static const Gradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [card, cardEnd],
  );

  static const Gradient accentStripeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x8CB8965A), Color(0x8C8A744A)],
  );

  static const Gradient crownBloomGradient = RadialGradient(
    center: Alignment.topCenter,
    radius: 0.88,
    colors: [Color(0x12F5E8CB), transparent],
  );

  static const Gradient nodeBackgroundGradient = RadialGradient(
    center: Alignment(0, -0.3),
    radius: 0.85,
    colors: [Color(0xFF181713), Color(0xFF10100C)],
  );

  static const Gradient currentNodeBackgroundGradient = RadialGradient(
    center: Alignment(0, -0.2),
    radius: 0.86,
    colors: [Color(0xFF20180D), Color(0xFF11110D)],
  );

  static TextStyle chromeTitleStyle() => const TextStyle(
    color: gold,
    fontFamily: serifFont,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: 1,
    letterSpacing: 0.6,
  );

  static TextStyle chromeGlyphStyle() => const TextStyle(
    color: goldDim,
    fontFamily: glyphFont,
    fontFamilyFallback: glyphFontFallback,
    fontWeight: FontWeight.w400,
    fontSize: 27,
    height: 1,
    letterSpacing: 3.75,
  );

  static TextStyle eyebrowStyle() => const TextStyle(
    color: brass,
    fontFamily: serifFont,
    fontWeight: FontWeight.w600,
    fontSize: 15.5,
    height: 1.2,
    letterSpacing: 5,
  );

  static TextStyle canonSubtitleStyle() => const TextStyle(
    color: midText,
    fontFamily: serifFont,
    fontStyle: FontStyle.italic,
    fontSize: 20,
    height: 1.35,
    letterSpacing: 0,
  );

  static TextStyle cardTitleStyle() => const TextStyle(
    color: gold,
    fontFamily: serifFont,
    fontWeight: FontWeight.w600,
    fontSize: 24,
    height: 1.05,
    letterSpacing: 0,
  );

  static TextStyle themeStyle() => const TextStyle(
    color: midText,
    fontFamily: serifFont,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.25,
    letterSpacing: 0,
  );

  static TextStyle openingStyle() => const TextStyle(
    color: highlightText,
    fontFamily: serifFont,
    fontWeight: FontWeight.w400,
    fontSize: 18.5,
    height: 1.48,
    letterSpacing: 0,
  );

  static TextStyle metaStyle() => const TextStyle(
    color: lowText,
    fontWeight: FontWeight.w500,
    fontSize: 12.5,
    height: 1.2,
    letterSpacing: 1.7,
    fontFamilyFallback: sansFontFallback,
  );
}
