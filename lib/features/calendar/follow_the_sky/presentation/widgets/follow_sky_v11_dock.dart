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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, FollowSkyV11Tokens.pageBg],
          stops: [0.0, 0.34],
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
          child: joined ? _joinedDock() : _carryDock(),
        ),
      ),
    );
  }

  Widget _carryDock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey<String>('follow-sky-carry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FollowSkyV11Tokens.pageBg,
              foregroundColor: FollowSkyV11Tokens.gold,
              disabledBackgroundColor: FollowSkyV11Tokens.pageBg,
              disabledForegroundColor: FollowSkyV11Tokens.silverMid,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: const BorderSide(
                  color: FollowSkyV11Tokens.gold,
                  width: 1.5,
                ),
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
                    'Carry this course',
                    style: TextStyle(
                      fontFamily: MaatFlowListTokens.fontFamily,
                      fontFamilyFallback: MaatFlowListTokens.fontFallback,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 11),
        const Text(
          'Nothing is added until you carry it.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: FollowSkyV11Tokens.contentMuted,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 10.5,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _joinedDock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey<String>('follow-sky-carried'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FollowSkyV11Tokens.pageBg,
              foregroundColor: FollowSkyV11Tokens.contentSecondary,
              disabledBackgroundColor: FollowSkyV11Tokens.pageBg,
              disabledForegroundColor: FollowSkyV11Tokens.contentSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: FollowSkyV11Tokens.gold.withValues(alpha: 0.22),
                  width: 1.5,
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
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 11),
        const Text(
          'The sky will find you. Change anything later.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: FollowSkyV11Tokens.contentMuted,
            fontFamily: MaatFlowListTokens.fontFamily,
            fontFamilyFallback: MaatFlowListTokens.fontFallback,
            fontSize: 10.5,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}
