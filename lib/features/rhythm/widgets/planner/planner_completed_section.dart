import 'package:flutter/material.dart';

import 'package:mobile/features/rhythm/models/rhythm_models.dart';

import 'planner_plate.dart';
import 'planner_visual_tokens.dart';

class PlannerCompletedSection extends StatelessWidget {
  const PlannerCompletedSection({
    super.key,
    required this.plannerLoading,
    required this.loadingSlot,
    required this.completedItems,
  });

  final bool plannerLoading;
  final Widget loadingSlot;
  final List<RhythmItem> completedItems;

  @override
  Widget build(BuildContext context) {
    return PlannerPlate(
      label: 'Completed',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: plannerLoading
            ? loadingSlot
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: completedItems.isEmpty
                    ? [
                        Text(
                          'Nothing placed on the scale yet. One honored step begins the weighing.',
                          style: PlannerVisualTokens.captionItalic.copyWith(
                            fontSize: 15,
                            color: PlannerVisualTokens.gold.withValues(
                              alpha: PlannerVisualTokens.liftedAlpha(0.30),
                            ),
                          ),
                        ),
                      ]
                    : [
                        for (int i = 0; i < completedItems.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 24,
                              thickness: 0.5,
                              color: PlannerVisualTokens.gold.withValues(
                                alpha: PlannerVisualTokens.liftedAlpha(0.06),
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                  width: 12,
                                  height: 0.5,
                                  color: PlannerVisualTokens.gold.withValues(
                                    alpha: PlannerVisualTokens.liftedAlpha(
                                      0.40,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  completedItems[i].title,
                                  style: PlannerVisualTokens.plateBody.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: const Color(0xFFDCC8A0).withValues(
                                      alpha: PlannerVisualTokens.liftedAlpha(
                                        0.60,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
              ),
      ),
    );
  }
}
