import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';

void main() {
  test('default initial prompt resolver exposes the prompt-enabled flows', () {
    expect(kInitialMaatFlowPromptSpecs, hasLength(31));

    final expectedLabelsByFlow = <String, List<String>>{
      'the-moon-return': <String>['What do you set down?'],
      'the-course': <String>['What action fits this hour?'],
      'dawn-house-rite': <String>['What order do you bring into the day?'],
      'evening-threshold-rite': <String>['What do you release tonight?'],
      'the-offering-table': <String>[
        'What was fed?',
        'What did you provide today?',
      ],
      'the-decan-watch': <String>[
        'Visibility',
        'What did the sky show?',
        'What bearing do you carry into the next ten days?',
      ],
      'the-first-arrangement': <String>[
        'What space will you put in order?',
        'What changed in the space?',
      ],
      'the-living-pattern': <String>[
        'What pattern are you watching?',
        'What principle did the pattern teach?',
      ],
      'the-house-of-life': <String>[
        'What knowledge are you preserving?',
        'What did you learn, write, recite, or transmit?',
      ],
      'hotep': <String>[
        'What can be enough tonight?',
        'What did you let be enough tonight?',
      ],
      'the-open-hand': <String>[
        'What need are you willing to meet?',
        'What moved through your hand?',
      ],
      'the-djed': <String>[
        'What must stand upright?',
        'What did you raise or restore?',
      ],
      'the-tending': <String>[
        'What care needs to become specific?',
        'What tending act did you complete?',
      ],
      'the-kept-word': <String>[
        'What word or agreement needs attention?',
        'What word, repair, or conversation needs to be remembered?',
      ],
      'the-wag': <String>[
        'What gift, memory, or legacy will you carry?',
        'What gift, memory, or legacy did you carry?',
      ],
      'the-khat': <String>[
        'What is the body asking for?',
        'What care did you give the body?',
      ],
      'track-the-sky': <String>[
        'What change are you watching above?',
        'What changed above you?',
      ],
      'the-weighing': <String>[
        'What needs to be placed on the scale?',
        'What record, number, or correction needs to be witnessed?',
      ],
      'the-days-outside-the-year': <String>['What threshold are you crossing?'],
      'the-fair-hearing': <String>[
        'What must be heard before deciding?',
        'What decision, measure, or unheard side needs to be remembered?',
      ],
      'the-boundary-stone': <String>[
        'What marker needs restoring?',
        'What moved, and what did you restore?',
      ],
      'the-open-mouth': <String>[
        'What word needs discipline?',
        'What needed to be spoken, withheld, repaired, or governed?',
      ],
      'the-shore': <String>[
        'What exchange needs honest measure?',
        'What was given, received, or measured clearly?',
      ],
      'the-living-text': <String>[
        'What line is asking to live through you?',
        'What did you read, question, connect, or apply?',
      ],
      'the-clearing': <String>[
        'What heat needs space before response?',
        'What changed because you waited before responding?',
      ],
      'het-heru': <String>[
        'What hot force needs cooling?',
        'What brought the force back toward joy?',
      ],
      'the-autobiography': <String>[
        'What part of your record needs naming?',
        'What capacity, work, gift, or claim needs to be remembered?',
      ],
      'the-true-name': <String>[
        'What false account is ready to lose power?',
        'What accurate account did the record support?',
      ],
      'the-living-record': <String>[
        'What record will you make living?',
        'What did you record, apply, or carry into the physical world?',
      ],
      'the-oracle': <String>[
        'What question are you carrying?',
        'What shape did the sign take?',
        'What did you receive, without forcing meaning too early?',
      ],
      'the-wandering': <String>[
        'What remains with you?',
        'What did you find in the wandering?',
      ],
    };

    for (final entry in expectedLabelsByFlow.entries) {
      final prompt = resolveMaatFlowInitialPromptSpec(flowKey: entry.key);
      expect(prompt, isNotNull, reason: entry.key);
      expect(
        prompt!.fields.map((field) => field.label),
        entry.value,
        reason: entry.key,
      );
    }

    expect(
      resolveMaatFlowInitialPromptSpec(flowKey: 'evening_threshold'),
      isNull,
    );
    expect(resolveMaatFlowInitialPromptSpec(flowKey: 'not-a-flow'), isNull);
  });

  test('initial prompt spec reuses response field specs', () {
    const field = MaatFlowResponseSpec(
      id: 'moon-return-initial-set-down',
      flowKey: 'the-moon-return',
      surface: MaatFlowResponseSurface.initialDetail,
      kind: MaatFlowResponseKind.text,
      label: 'What do you set down?',
      journalPolicy: MaatFlowJournalPolicy.localOnly,
    );
    const prompt = MaatFlowInitialPromptSpec(
      flowKey: 'the-moon-return',
      title: 'Begin reflection',
      subtitle: "Carry a first thought into today's practice.",
      fields: <MaatFlowResponseSpec>[field],
    );

    expect(prompt.isRenderable, isTrue);
    expect(prompt.fields.single, same(field));
    expect(prompt.fields.single.surface, MaatFlowResponseSurface.initialDetail);
  });

  test('enabled initial prompt fields are local-only initial-detail specs', () {
    for (final prompt in kInitialMaatFlowPromptSpecs) {
      for (final field in prompt.fields) {
        expect(field.surface, MaatFlowResponseSurface.initialDetail);
        expect(field.journalPolicy, MaatFlowJournalPolicy.localOnly);
      }
    }
  });

  test('initial prompt resolver ignores fieldless specs', () {
    const field = MaatFlowResponseSpec(
      id: 'course-initial-action',
      flowKey: 'the-course',
      surface: MaatFlowResponseSurface.initialDetail,
      kind: MaatFlowResponseKind.text,
      label: 'What action fits this hour?',
    );
    const fieldless = MaatFlowInitialPromptSpec(
      flowKey: 'the-course',
      title: 'Fieldless prompt',
    );
    const active = MaatFlowInitialPromptSpec(
      flowKey: 'the-course',
      title: 'Begin reflection',
      fields: <MaatFlowResponseSpec>[field],
    );
    const resolver = MaatFlowInitialPromptResolver(
      specs: <MaatFlowInitialPromptSpec>[fieldless, active],
    );

    expect(resolver.resolve(flowKey: 'unknown-flow'), isNull);
    expect(resolver.resolve(flowKey: ' '), isNull);
    expect(resolver.resolve(flowKey: 'the-course'), same(active));
    expect(resolver.supports(flowKey: 'the-course'), isTrue);
  });
}
