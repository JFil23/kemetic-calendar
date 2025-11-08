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
    final s = style ?? const TextStyle();
    final double fs = (s.fontSize ?? 20.0);

    // Canonical crisp stack for month names
    final TextStyle base = const TextStyle(
      fontFamily: 'GentiumPlus',
      fontFamilyFallback: ['NotoSans', 'Roboto', 'Arial', 'sans-serif'],
    );

    final TextStyle crisp = base.merge(s).copyWith(
      // snap to whole pixels
      fontSize: fs.roundToDouble(),
      // kill subpixel spacing (CanvasKit blur)
      letterSpacing: 0,
      // do NOT force a fractional line height
      height: s.height,
    );

    return Text(
      text,
      textAlign: textAlign,
      style: crisp,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow ?? (maxLines != null ? TextOverflow.ellipsis : null),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );
  }
}

