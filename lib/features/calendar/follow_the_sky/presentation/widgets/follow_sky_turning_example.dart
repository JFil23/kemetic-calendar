import 'package:flutter/material.dart';
import 'package:mobile/widgets/day_sheet_components.dart';

import '../../../maat_flow_visual_tokens.dart';
import '../turning_meaning.dart';
import 'follow_sky_v11_tokens.dart';

class FollowSkyTurningExample extends StatelessWidget {
  const FollowSkyTurningExample({
    super.key,
    required this.meaning,
    required this.controller,
    required this.onChanged,
  });

  final TurningMeaning meaning;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How a turning works',
          style: TextStyle(
            color: FollowSkyV11Tokens.gold,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          meaning.observation,
          style: const TextStyle(
            color: FollowSkyV11Tokens.silverHi,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 16,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          meaning.significanceLabel,
          style: const TextStyle(
            color: FollowSkyV11Tokens.gold,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          meaning.personalQuestion,
          style: const TextStyle(
            color: FollowSkyV11Tokens.silverHi,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 16,
            fontStyle: FontStyle.italic,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        DaySheetTextField(
          controller: controller,
          hint: 'Your intention…',
        ),
      ],
    );
  }
}
