import 'package:flutter/material.dart';

import '../../planner/planner_scale_math.dart';
import 'maat_scale.dart';
import 'planner_visual_tokens.dart';

class PlannerWeighingHeader extends StatelessWidget {
  const PlannerWeighingHeader({
    super.key,
    required this.percent,
    required this.dateLabel,
    this.question,
    this.showProgressStatus = true,
  });

  final int percent;
  final String dateLabel;
  final Widget? question;
  final bool showProgressStatus;

  @override
  Widget build(BuildContext context) {
    final progress = (percent / 100.0).clamp(0.0, 1.0).toDouble();
    final tiltDegrees = plannerScaleTiltDegrees(percent);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
      child: Column(
        children: [
          Text(
            dateLabel,
            textAlign: TextAlign.center,
            style: PlannerVisualTokens.ceremonialItalic.copyWith(
              fontSize: 13,
              letterSpacing: 0.4,
              color: PlannerVisualTokens.gold.withValues(
                alpha: PlannerVisualTokens.liftedAlpha(0.50),
              ),
            ),
          ),
          const SizedBox(height: 10),
          MaatScale(tiltDegrees: tiltDegrees, progress: progress),
          if (showProgressStatus) ...[
            Text(
              '$percent%',
              style: const TextStyle(
                color: PlannerVisualTokens.textWarm,
                fontSize: 54,
                fontWeight: FontWeight.w600,
                fontFamily: PlannerVisualTokens.serifFamily,
                fontFamilyFallback: PlannerVisualTokens.serifFallback,
                height: 1,
                shadows: [Shadow(color: Color(0x33C8A84A), blurRadius: 24)],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'ALIGNED',
              style: TextStyle(
                color: const Color(
                  0xFFC8A84A,
                ).withValues(alpha: PlannerVisualTokens.liftedAlpha(0.48)),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ] else
            const SizedBox(height: 58),
          if (question != null) ...[
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: question!,
            ),
          ],
        ],
      ),
    );
  }
}
