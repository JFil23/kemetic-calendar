import 'package:flutter/material.dart';
import '../../../../shared/glossy_text.dart';
import 'planner_visual_tokens.dart';

/// The same gold note lettering in the Planner and its Pages preview.
class PlannerNoteText extends StatelessWidget {
  const PlannerNoteText(
    this.text, {
    super.key,
    this.fontSize = 24,
    this.maxLines = 6,
  });
  final String text;
  final double fontSize;
  final int maxLines;
  @override
  Widget build(BuildContext context) => KemeticGold.text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      fontFamily: PlannerVisualTokens.serifFamily,
      fontFamilyFallback: PlannerVisualTokens.serifFallback,
      height: 1.15,
    ),
    maxLines: maxLines,
    softWrap: true,
  );
}
