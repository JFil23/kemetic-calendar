import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_response_models.dart';
import 'package:mobile/features/calendar/maat_flow_response_resolver.dart';

void main() {
  test('default initial prompt resolver has no enabled specs', () {
    expect(kInitialMaatFlowPromptSpecs, isEmpty);

    for (final flowKey in const <String>[
      'the-moon-return',
      'the-course',
      'the-offering-table',
      'the-decan-watch',
      'the-true-name',
    ]) {
      expect(resolveMaatFlowInitialPromptSpec(flowKey: flowKey), isNull);
      expect(
        kDefaultMaatFlowInitialPromptResolver.supports(flowKey: flowKey),
        isFalse,
      );
    }
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

    expect(prompt.enabled, isTrue);
    expect(prompt.requiredBeforeJoin, isFalse);
    expect(prompt.isRenderable, isTrue);
    expect(prompt.fields.single, same(field));
    expect(prompt.fields.single.surface, MaatFlowResponseSurface.initialDetail);
  });

  test('initial prompt resolver ignores disabled and fieldless specs', () {
    const field = MaatFlowResponseSpec(
      id: 'course-initial-action',
      flowKey: 'the-course',
      surface: MaatFlowResponseSurface.initialDetail,
      kind: MaatFlowResponseKind.text,
      label: 'What action fits this hour?',
    );
    const disabled = MaatFlowInitialPromptSpec(
      flowKey: 'the-moon-return',
      title: 'Disabled prompt',
      enabled: false,
      fields: <MaatFlowResponseSpec>[field],
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
      specs: <MaatFlowInitialPromptSpec>[disabled, fieldless, active],
    );

    expect(resolver.resolve(flowKey: 'the-moon-return'), isNull);
    expect(resolver.resolve(flowKey: 'unknown-flow'), isNull);
    expect(resolver.resolve(flowKey: ' '), isNull);
    expect(resolver.resolve(flowKey: 'the-course'), same(active));
    expect(resolver.supports(flowKey: 'the-course'), isTrue);
  });
}
