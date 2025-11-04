import 'package:flutter/material.dart';

/// Guaranteed font rendering for Egyptological transliteration
/// 
/// ALL month name displays MUST use this widget to ensure:
/// - Diacritics render correctly (ḫ, ḥ, ꜥ, ȝ, etc.)
/// - Font family is consistent
/// - Accessibility scaling works
/// 
/// CI will enforce this via architecture guard tests.
class MonthNameText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;

  const MonthNameText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
  });

  @override
  Widget build(BuildContext context) {
    // Merge with provided style but enforce font family
    final effectiveStyle = (style ?? const TextStyle()).copyWith(
      fontFamily: 'GentiumPlus',
      fontFamilyFallback: const ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
    );
    
    return Text(
      text,
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? (maxLines != null ? TextOverflow.ellipsis : null),
      softWrap: softWrap,
    );
  }
}

