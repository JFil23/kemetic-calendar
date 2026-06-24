import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';

void main() {
  test('default initial prompt resolver exposes the prompt-enabled flows', () {
    expect(kInitialMaatFlowPromptSpecs, hasLength(16));

    final moonReturn = resolveMaatFlowInitialPromptSpec(
      flowKey: 'the-moon-return',
    );
    expect(moonReturn, isNotNull);
    expect(moonReturn!.fields.single.label, 'What do you set down?');

    final course = resolveMaatFlowInitialPromptSpec(flowKey: 'the-course');
    expect(course, isNotNull);
    expect(course!.fields.single.label, 'What action fits this hour?');

    final dawnHouse = resolveMaatFlowInitialPromptSpec(
      flowKey: 'dawn-house-rite',
    );
    expect(dawnHouse, isNotNull);
    expect(
      dawnHouse!.fields.single.label,
      'What order do you bring into the day?',
    );

    final closing = resolveMaatFlowInitialPromptSpec(
      flowKey: 'evening-threshold-rite',
    );
    expect(closing, isNotNull);
    expect(closing!.fields.single.label, 'What do you release tonight?');

    final offering = resolveMaatFlowInitialPromptSpec(
      flowKey: 'the-offering-table',
    );
    expect(offering, isNotNull);
    expect(offering!.fields.map((field) => field.label), <String>[
      'What was fed?',
      'What did you provide today?',
    ]);

    final decanWatch = resolveMaatFlowInitialPromptSpec(
      flowKey: 'the-decan-watch',
    );
    expect(decanWatch, isNotNull);
    expect(decanWatch!.fields.map((field) => field.label), <String>[
      'Visibility',
      'What did the sky show?',
      'What bearing do you carry into the next ten days?',
    ]);

    final firstArrangement = resolveMaatFlowInitialPromptSpec(
      flowKey: 'the-first-arrangement',
    );
    expect(firstArrangement, isNotNull);
    expect(firstArrangement!.fields.map((field) => field.label), <String>[
      'What space will you put in order?',
      'What changed in the space?',
    ]);

    final livingPattern = resolveMaatFlowInitialPromptSpec(
      flowKey: 'the-living-pattern',
    );
    expect(livingPattern, isNotNull);
    expect(livingPattern!.fields.map((field) => field.label), <String>[
      'What pattern are you watching?',
      'What principle did the pattern teach?',
    ]);

    final houseOfLife = resolveMaatFlowInitialPromptSpec(
      flowKey: 'the-house-of-life',
    );
    expect(houseOfLife, isNotNull);
    expect(houseOfLife!.fields.map((field) => field.label), <String>[
      'What knowledge are you preserving?',
      'What did you learn, write, recite, or transmit?',
    ]);

    final hotep = resolveMaatFlowInitialPromptSpec(flowKey: 'hotep');
    expect(hotep, isNotNull);
    expect(hotep!.fields.map((field) => field.label), <String>[
      'What can be enough tonight?',
      'What did you let be enough tonight?',
    ]);

    final openHand = resolveMaatFlowInitialPromptSpec(flowKey: 'the-open-hand');
    expect(openHand, isNotNull);
    expect(openHand!.fields.map((field) => field.label), <String>[
      'What need are you willing to meet?',
      'What moved through your hand?',
    ]);

    final djed = resolveMaatFlowInitialPromptSpec(flowKey: 'the-djed');
    expect(djed, isNotNull);
    expect(djed!.fields.map((field) => field.label), <String>[
      'What must stand upright?',
      'What did you raise or restore?',
    ]);

    final tending = resolveMaatFlowInitialPromptSpec(flowKey: 'the-tending');
    expect(tending, isNotNull);
    expect(tending!.fields.map((field) => field.label), <String>[
      'What care needs to become specific?',
      'What tending act did you complete?',
    ]);

    final keptWord = resolveMaatFlowInitialPromptSpec(flowKey: 'the-kept-word');
    expect(keptWord, isNotNull);
    expect(keptWord!.fields.map((field) => field.label), <String>[
      'What word or agreement needs attention?',
      'What word, repair, or conversation needs to be remembered?',
    ]);

    final wag = resolveMaatFlowInitialPromptSpec(flowKey: 'the-wag');
    expect(wag, isNotNull);
    expect(wag!.fields.map((field) => field.label), <String>[
      'What gift, memory, or legacy will you carry?',
      'What gift, memory, or legacy did you carry?',
    ]);

    final khat = resolveMaatFlowInitialPromptSpec(flowKey: 'the-khat');
    expect(khat, isNotNull);
    expect(khat!.fields.map((field) => field.label), <String>[
      'What is the body asking for?',
      'What care did you give the body?',
    ]);

    expect(resolveMaatFlowInitialPromptSpec(flowKey: 'the-true-name'), isNull);
    expect(resolveMaatFlowInitialPromptSpec(flowKey: 'the-weighing'), isNull);
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
