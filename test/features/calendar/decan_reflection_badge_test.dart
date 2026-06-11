import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/decan_reflection_model.dart';
import 'package:mobile/features/calendar/decan_reflection_badge.dart';

void main() {
  test('deterministic spectrum prompt uses badge body and full detail body', () {
    final prompt = _prompt(
      reflectionText:
          'The scale was approached. The sitting was entered but not completed.',
      renderMetadata: const DecanReflectionRenderMetadata(
        renderer: 'deterministic_spectrum',
        usedLlm: false,
        llmCost: 0,
        spectrumFlowKey: 'the-weighing',
        badgeBody: 'The sitting was entered but not completed.',
        detailBody:
            'The scale was approached. The sitting was entered but not completed.',
      ),
    );

    expect(prompt.isTheWeighingSpectrum, isTrue);
    expect(prompt.badgeText, 'The sitting was entered but not completed.');
    expect(
      prompt.detailText,
      'The scale was approached. The sitting was entered but not completed.',
    );
  });

  testWidgets('lower-third badge displays deterministic spectrum badge copy', (
    tester,
  ) async {
    var taps = 0;
    final prompt = _prompt(
      reflectionText:
          'The scale was approached. The sitting was entered but not completed.',
      renderMetadata: const DecanReflectionRenderMetadata(
        renderer: 'deterministic_spectrum',
        usedLlm: false,
        llmCost: 0,
        spectrumFlowKey: 'the-weighing',
        badgeBody: 'The sitting was entered but not completed.',
        detailBody:
            'The scale was approached. The sitting was entered but not completed.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DecanReflectionLowerThirdBadge(
              prompt: prompt,
              maxWidth: 280,
              onTap: () => taps += 1,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(decanReflectionLowerThirdBadgeKey), findsOneWidget);
    expect(find.text('Decan reflection'), findsOneWidget);
    expect(
      find.text('The sitting was entered but not completed.'),
      findsOneWidget,
    );
    expect(find.textContaining('The scale was approached'), findsNothing);

    await tester.tap(find.byKey(decanReflectionLowerThirdBadgeKey));
    expect(taps, 1);
  });

  testWidgets('lower-third badge keeps non-spectrum reflection text fallback', (
    tester,
  ) async {
    final prompt = _prompt(reflectionText: 'A generated end-decan reflection.');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DecanReflectionLowerThirdBadge(
              prompt: prompt,
              maxWidth: 280,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(decanReflectionLowerThirdBadgeKey), findsOneWidget);
    expect(find.text('A generated end-decan reflection.'), findsOneWidget);
  });
}

CalendarDecanReflectionPrompt _prompt({
  String reflectionText = 'Reflection body.',
  DecanReflectionRenderMetadata? renderMetadata,
}) {
  return CalendarDecanReflectionPrompt(
    id: 'reflection-1',
    decanName: 'Hathor - Decan I',
    decanTheme: 'Hathor',
    decanStart: DateTime.utc(2026, 5, 16),
    decanEnd: DateTime.utc(2026, 5, 25),
    badgeCount: 6,
    reflectionText: reflectionText,
    persisted: true,
    renderMetadata: renderMetadata,
  );
}
