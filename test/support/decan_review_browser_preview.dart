// Visual reference harness. Uses the production owner with static reference data.
import 'package:flutter/material.dart';
import 'package:mobile/features/reflections/decan_review_models.dart';
import 'package:mobile/features/reflections/decan_review_views.dart';
import 'package:mobile/features/reflections/decan_review_widgets.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      backgroundColor: DecanReviewStyle.base,
      body: DecanReviewOpening(
        decanStart: DateTime(2026, 10, 1),
        moments: [
          DecanMoment(
            id: 'r',
            kind: 'response',
            sourceId: 'r',
            occurredOn: DateTime(2026, 10, 2),
            sourceLabel: 'Reading House',
            actionLabel: 'Your words',
            text: '“I can give a thought time before I answer it.”',
            isQuote: true,
          ),
          DecanMoment(
            id: 'w',
            kind: 'flow',
            sourceId: 'w',
            occurredOn: DateTime(2026, 10, 6),
            sourceLabel: 'Your flow',
            actionLabel: 'Completed',
            text: 'An evening walk',
          ),
          DecanMoment(
            id: 'l',
            kind: 'library',
            sourceId: 'l',
            occurredOn: DateTime(2026, 10, 9),
            sourceLabel: 'Library',
            actionLabel: 'Bookmarked',
            text: 'Instruction of Ptahhotep',
          ),
        ],
        question: 'What would you like to carry forward?',
        onChoose: () {},
        onWrite: () {},
        onLeave: () {},
        onOpenMoment: (_) {},
      ),
    ),
  ),
);
