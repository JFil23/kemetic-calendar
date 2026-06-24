import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';

void main() {
  test('default initial prompt resolver exposes exactly four pilot flows', () {
    expect(kInitialMaatFlowPromptSpecs, hasLength(4));

    final moonReturn = resolveMaatFlowInitialPromptSpec(
      flowKey: 'the-moon-return',
    );
    expect(moonReturn, isNotNull);
    expect(moonReturn!.fields.single.label, 'What do you set down?');

    final course = resolveMaatFlowInitialPromptSpec(flowKey: 'the-course');
    expect(course, isNotNull);
    expect(course!.fields.single.label, 'What action fits this hour?');

    final offering = resolveMaatFlowInitialPromptSpec(
      flowKey: 'the-offering-table',
    );
    expect(offering, isNotNull);
    expect(offering!.fields.single.label, 'What was fed?');

    final decanWatch = resolveMaatFlowInitialPromptSpec(
      flowKey: 'the-decan-watch',
    );
    expect(decanWatch, isNotNull);
    expect(decanWatch!.fields.map((field) => field.label), <String>[
      'Visibility',
      'What did the sky show?',
      'What bearing do you carry into the next ten days?',
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

  test('pilot fields are local-only initial-detail specs', () {
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
