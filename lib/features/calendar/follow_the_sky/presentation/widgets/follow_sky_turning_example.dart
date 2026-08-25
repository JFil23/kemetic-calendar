import 'package:flutter/material.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FollowSkyV11Tokens.separator)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'HOW A TURNING WORKS',
                style: TextStyle(
                  color: FollowSkyV11Tokens.gold,
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2.2,
                  height: 1,
                ),
              ),
              SizedBox(width: 12),
              Expanded(child: Divider(color: Color(0x2ED4AE43), height: 1)),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            meaning.observation,
            style: const TextStyle(
              color: FollowSkyV11Tokens.silverHi,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 17,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            meaning.significanceLabel,
            style: const TextStyle(
              color: FollowSkyV11Tokens.intentionPeriwinkle,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 2.73,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meaning.personalQuestion,
            style: const TextStyle(
              color: FollowSkyV11Tokens.silverHi,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 23.5,
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            key: const ValueKey<String>('follow-sky-worked-intention'),
            controller: controller,
            onChanged: onChanged,
            scrollPadding: keyboardManagedTextFieldScrollPadding,
            cursorColor: FollowSkyV11Tokens.intentionPeriwinkle,
            style: const TextStyle(
              color: FollowSkyV11Tokens.glow,
              fontFamily: MaatFlowListTokens.fontFamily,
              fontFamilyFallback: MaatFlowListTokens.fontFallback,
              fontSize: 21,
              fontWeight: FontWeight.w300,
              fontStyle: FontStyle.italic,
              height: 1.3,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(2, 4, 2, 11),
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: FollowSkyV11Tokens.glow.withValues(alpha: 0.30),
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: FollowSkyV11Tokens.glow.withValues(alpha: 0.30),
                ),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(
                  color: FollowSkyV11Tokens.intentionPeriwinkle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
