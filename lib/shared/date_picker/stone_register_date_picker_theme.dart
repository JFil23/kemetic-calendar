import 'package:flutter/material.dart';

class StoneRegisterDatePickerTheme {
  static const base = Color(0xFF120F08);
  static const baseDeep = Color(0xFF0D0B07);

  static const gold = Color(0xFFD4AE43);
  static const goldSoft = Color(0xFFE8C868);

  static const gregorian = Color(0xFF6FC9E8);
  static const gregorianSoft = Color(0xFFA6E2F4);

  static const silverHigh = Color(0xFFC8C4BC);
  static const silverMid = Color(0xFF9E9A94);
  static const silverLow = Color(0xFF6A6660);

  static const rowHeight = 48.0;
  static const visibleRows = 5;
  static const wheelHeight = rowHeight * visibleRows;

  static const serifFontFamily = 'CormorantGaramond';
  static const uiFontFamily = 'Inter';

  static const plateRadius = 6.0;
  static const buttonRadius = 14.0;

  static Color accentSoftFor(Color accent) {
    if (accent == gregorian) return gregorianSoft;
    return goldSoft;
  }

  static TextStyle titleStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          color: silverHigh,
          fontFamily: serifFontFamily,
          fontSize: 23,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ) ??
        const TextStyle(
          color: silverHigh,
          fontFamily: serifFontFamily,
          fontSize: 23,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        );
  }
}
