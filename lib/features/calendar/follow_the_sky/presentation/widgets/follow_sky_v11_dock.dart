import 'package:flutter/material.dart';

import '../../../presentation/maat_flow_detail_shell.dart';
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
    return MaatFlowDetailDock(
      theme: FollowSkyV11Tokens.detailTheme,
      joined: joined,
      busy: joining,
      onPressed: onCarry,
      actionLabel: 'Carry this course',
      actionNote: 'Nothing is added until you carry it.',
      joinedLabel: 'In your calendar',
      joinedNote: 'The sky will find you. Change anything later.',
      actionKey: const ValueKey<String>('follow-sky-carry'),
      joinedKey: const ValueKey<String>('follow-sky-carried'),
    );
  }
}
