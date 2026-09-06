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
    previewSummary: 'Check one supply before it becomes an emergency.',
    why:
        'The supplies that run out do so silently. This rite checks them while they can still be replenished easily.',
    instruction:
        'Check one thing you rely on: medication, water bottle, groceries, soap, clean clothes, or transit fare. Refill it, or write down the next concrete step.',
    steps: <String>[
      'Name one supply running low.',
      'Refill it, or write down the next step.',
      'Put it in sight or set one reminder.',
    ],
  ),
  2: OfferingTablePracticePresentation(
    previewSummary: 'Choose what reaches you before the noise does.',
    why:
        'The day starts competing for your attention immediately. This practice lets you choose your first input.',
    instruction:
        'Choose the first thing you want to give your attention to. Then give your body water before feeds, messages, or tasks get first claim.',
    steps: <String>[
      'Name the first thing you want to give your attention to today.',
      'Drink a glass of water before you open feeds, messages, or tasks.',
      'Give that first thing one quiet minute.',
    ],
  ),
  3: OfferingTablePracticePresentation(
    previewSummary: 'Make sure real food has a place in your day.',
    why:
        'Food can become something you rush through. Today you treat one meal as actual provision.',
    instruction:
        'Choose your first real food before hunger has to improvise for you.',
    steps: <String>[
      'Name the first real food you will eat today.',
      'Put it within reach now — on the counter, in the fridge front, or in your bag.',
    ],
  ),
  4: OfferingTablePracticePresentation(
    previewSummary: 'Give your body one piece of care you’ve been putting off.',
    why:
        'Small acts of neglect build quietly. Today you correct one before it becomes normal.',
    instruction: 'Make one delayed care task small enough to move today.',
    steps: <String>[
      'Wash your face, hands, or mouth slowly.',
      'Name the body-care task you keep putting off.',
      'Do the two-minute version now — or book it.',
    ],
  ),
  5: OfferingTablePracticePresentation(
    previewSummary: 'Protect tonight’s rest before the day spends it.',
    why:
        'Rest is not leftover time. It is something that has to be provided for on purpose.',
    instruction:
        'Make one concrete change now that gives tonight a better chance.',
    steps: <String>[
      'Name how many hours you slept last night.',
      'Name what is most likely to cut tonight short.',
      'Cut thirty minutes from it, or set a stop time.',
    ],
  ),
};

OfferingTablePracticePresentation offeringTablePracticePresentation(
  OfferingTableDay day,
) {
  final approved = _firstFivePracticePresentations[day.dayNumber];
  final presentation =
      approved ??
      OfferingTablePracticePresentation(
        previewSummary: _firstSentence(day.provisionAct),
        why: day.purpose,
        instruction: day.provisionAct,
        steps: <String>[day.provisionAct, ...day.optionalSteps],
      );

  return presentation;
}

String _firstSentence(String value) {
  final normalized = value.trim();
  final firstSentence = RegExp(r'^.*?[.!?](?:\s|$)').firstMatch(normalized);
  return firstSentence?.group(0)?.trim() ?? normalized;
}
