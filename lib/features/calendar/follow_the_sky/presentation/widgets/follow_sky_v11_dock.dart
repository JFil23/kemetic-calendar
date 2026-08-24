import 'package:flutter/material.dart';

import '../../../maat_flow_visual_tokens.dart';
import 'follow_sky_v11_tokens.dart';

class FollowSkyV11Dock extends StatelessWidget {
  const FollowSkyV11Dock({
    super.key,
    required this.joined,
    required this.joining,
    required this.onCarry,
  });

  final bool joined;
  final bool joining;
  final VoidCallback? onCarry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FollowSkyV11Tokens.pageBg.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: Color(0xFF2A2518))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: joined
              ? _joinedDock()
              : _carryDock(),
        ),
      ),
    );
  }

  Widget _carryDock() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: FollowSkyV11Tokens.pageBg,
          foregroundColor: FollowSkyV11Tokens.gold,
          disabledBackgroundColor: FollowSkyV11Tokens.pageBg,
          disabledForegroundColor: FollowSkyV11Tokens.silverMid,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: const BorderSide(color: FollowSkyV11Tokens.gold, width: 1.15),
          ),
          elevation: 0,
        ),
        onPressed: joining ? null : onCarry,
        child: joining
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FollowSkyV11Tokens.gold,
                ),
              )
            : const Text(
                'Carry',
                style: TextStyle(
                  fontFamily: MaatFlowListTokens.fontFamily,
                  fontFamilyFallback: MaatFlowListTokens.fontFallback,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _joinedDock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FollowSkyV11Tokens.pageBg,
              foregroundColor: FollowSkyV11Tokens.silverMid,
              disabledBackgroundColor: FollowSkyV11Tokens.pageBg,
              disabledForegroundColor: FollowSkyV11Tokens.silverMid,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: FollowSkyV11Tokens.silverMid.withValues(alpha: 0.5),
                ),
              ),
              elevation: 0,
            ),
            onPressed: null,
            child: const Text(
              'In your calendar',
              style: TextStyle(
                fontFamily: MaatFlowListTokens.fontFamily,
                fontFamilyFallback: MaatFlowListTokens.fontFallback,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'The sky will find you. Change anything later.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: FollowSkyV11Tokens.silverMid,
            fontSize: 14,
            fontStyle: FontStyle.italic,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
