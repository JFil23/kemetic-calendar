import 'package:flutter/material.dart';

const String kJournalEmptyBadgeGlyph = '𓂝';
const Color kJournalEmptyBadgeGlyphColor = Color(0x998E8A86);
const double kJournalEmptyBadgeGlyphFontSize = 52;

class JournalEmptyBadgeGlyph extends StatelessWidget {
  const JournalEmptyBadgeGlyph({
    super.key,
    this.width = 156,
    this.height = 52,
    this.fontSize = kJournalEmptyBadgeGlyphFontSize,
  });

  final double width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Text(
            kJournalEmptyBadgeGlyph,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kJournalEmptyBadgeGlyphColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w300,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
