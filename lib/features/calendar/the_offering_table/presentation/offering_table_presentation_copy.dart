import 'package:flutter/foundation.dart';

import 'package:mobile/features/calendar/the_offering_table_flow.dart';

@immutable
class OfferingTablePracticePresentation {
  const OfferingTablePracticePresentation({
    required this.previewSummary,
    required this.why,
    required this.instruction,
    required this.steps,
  });

  final String previewSummary;
  final String why;
  final String instruction;
  final List<String> steps;
}

const _firstFivePracticePresentations = <int, OfferingTablePracticePresentation>{
  1: OfferingTablePracticePresentation(
    previewSummary:
        'Start with your most basic need before the day starts asking.',
    why:
        'Provision begins with the most basic need. Today you practice noticing yours before the day takes over.',
    instruction:
        'Start with water, then name one need you have been putting off.',
    steps: <String>[
      'Fill a cup of water.',
      'Name one basic need that has been unmet for a few days.',
      'Do the smallest thing that begins to meet it.',
    ],
  ),
  2: OfferingTablePracticePresentation(
    previewSummary: 'Choose what reaches you before messages and tasks do.',
    why:
        'The day starts competing for your attention immediately. This practice lets you choose your first input.',
    instruction:
        'Give your body something before your feeds, messages, or task list.',
    steps: <String>[
      'Drink water before opening a feed or message thread.',
      'Name what you want your first real input to be today.',
      'Protect one quiet minute for it.',
    ],
  ),
  3: OfferingTablePracticePresentation(
    previewSummary: 'Turn one meal from fuel into actual provision.',
    why:
        'Food can become something you rush through. Today you treat one meal as actual provision.',
    instruction: 'Make your first real food deliberate instead of accidental.',
    steps: <String>[
      'Name your first real food for the day.',
      'If it is not planned, choose one reachable option now.',
      'Prepare or place one part of it where you will see it.',
    ],
  ),
  4: OfferingTablePracticePresentation(
    previewSummary:
        'Correct one small act of body-care you have been deferring.',
    why:
        'Small acts of neglect build quietly. Today you correct one before it becomes normal.',
    instruction: 'Give your body one piece of care you have been postponing.',
    steps: <String>[
      'Wash your face, hands, or mouth with attention.',
      'Name one body-care task you have delayed.',
      'Do its smallest useful version today.',
    ],
  ),
  5: OfferingTablePracticePresentation(
    previewSummary:
        'Treat rest as something that must be provided, not hoped for.',
    why:
        'Rest is not leftover time. It is something that has to be provided for on purpose.',
    instruction: 'Look at tonight before the day fills it for you.',
    steps: <String>[
      'Name how many hours you slept last night.',
      "Name one thing likely to shorten tonight's sleep.",
      'Reduce that thing by one small amount.',
    ],
  ),
};

OfferingTablePracticePresentation offeringTablePracticePresentation(
  OfferingTableDay day,
) {
  final approved = _firstFivePracticePresentations[day.dayNumber];
  if (approved != null) return approved;

  return OfferingTablePracticePresentation(
    previewSummary: _firstSentence(day.provisionAct),
    why: day.purpose,
    instruction: day.provisionAct,
    steps: day.optionalSteps,
  );
}

String _firstSentence(String value) {
  final normalized = value.trim();
  final firstSentence = RegExp(r'^.*?[.!?](?:\s|$)').firstMatch(normalized);
  return firstSentence?.group(0)?.trim() ?? normalized;
}
