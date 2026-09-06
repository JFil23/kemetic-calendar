import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_event_block_visual.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _captureDjedVisuals = bool.fromEnvironment('CAPTURE_DJED_VISUALS');

void main() {
  setUpAll(() async {
    if (_captureDjedVisuals) await loadMaatFlowVisualTestFonts();
  });

  Future<void> pumpDjed(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: RepaintBoundary(
            key: const ValueKey<String>('djed-visual-capture'),
            child: DjedDetailPage(onCarry: () {}, onBack: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Djed ember visual uses the shared detail shell and authored calendar',
    (tester) async {
      await pumpDjed(tester, size: const Size(390, 844));

      expect(find.byType(MaatFlowDetailShell), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('djed-thirty-day-calendar')),
        findsOneWidget,
      );
      expect(find.byType(DjedSpineVisual), findsOneWidget);
      expect(find.text('The Djed'), findsOneWidget);
      expect(find.text('30 DAYS'), findsOneWidget);
      expect(find.text('4 SUPPORTS'), findsOneWidget);
      expect(find.text('9 SITTINGS'), findsOneWidget);
      expect(find.text('Your Djed'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('djed-carry')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Djed detail uses the same event block for expanded sittings', (
    tester,
  ) async {
    await pumpDjed(tester, size: const Size(390, 844));
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('djed-event-block-detail-1')),
      500,
      scrollable: scrollable,
    );
    expect(find.byType(DjedEventBlockVisual), findsWidgets);
    expect(find.text('Set your footing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final fixture in <(String, Size, double)>[
    ('minimum', const Size(320, 700), 1),
    ('mockup', const Size(390, 844), 1),
    ('large', const Size(430, 932), 1),
    ('accessible', const Size(390, 844), 1.35),
  ]) {
    testWidgets('Djed visual ${fixture.$1}', (tester) async {
      await pumpDjed(tester, size: fixture.$2, textScale: fixture.$3);
      expect(tester.takeException(), isNull);
      if (!_captureDjedVisuals) return;
      await expectLater(
        find.byKey(const ValueKey<String>('djed-visual-capture')),
        matchesGoldenFile('/tmp/djed-${fixture.$1}-hero.png'),
      );

      final scrollState = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollState.position.jumpTo(
        scrollState.position.maxScrollExtent.clamp(0, 820),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey<String>('djed-visual-capture')),
        matchesGoldenFile('/tmp/djed-${fixture.$1}-supports.png'),
      );
    });
  }
}
