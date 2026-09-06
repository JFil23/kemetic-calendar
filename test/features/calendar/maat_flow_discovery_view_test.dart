import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_discovery_view.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _captureDiscoveryVisuals = bool.fromEnvironment(
  'CAPTURE_MAAT_FLOW_DISCOVERY_VISUALS',
);

void main() {
  setUpAll(() async {
    if (_captureDiscoveryVisuals) await loadMaatFlowVisualTestFonts();
  });

  Future<void> pumpDiscovery(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    ValueChanged<String>? onOpen,
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
            key: const ValueKey<String>('discovery-visual-capture'),
            child: MaatFlowDiscoveryView(onCreate: () {}, onOpen: onOpen),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the approved four-flow hierarchy in canonical order', (
    tester,
  ) async {
    String? opened;
    await pumpDiscovery(
      tester,
      size: const Size(390, 844),
      onOpen: (key) => opened = key,
    );

    final keys = <String>[
      'track-the-sky',
      'the-offering-table',
      'the-reading-house',
      'the-djed',
    ];
    expect(
      kFourMaatFlowDiscoveryFixtures.map((card) => card.flowKey),
      orderedEquals(keys),
    );
    expect(
      find.byKey(
        const ValueKey<String>('maat-flow-discovery-card-track-the-sky'),
      ),
      findsOneWidget,
    );
    expect(find.text('Follow the Sky'), findsOneWidget);
    expect(find.text('The Offering Table'), findsOneWidget);
    expect(find.text('JOINED'), findsNothing);
    expect(find.text('NOT YET JOINED'), findsNothing);

    final followSkyButton = find.byKey(
      const ValueKey<String>('maat-flow-discovery-open-track-the-sky'),
    );
    await tester.ensureVisible(followSkyButton);
    await tester.tap(followSkyButton);
    expect(opened, 'track-the-sky');

    final djedCard = find.byKey(
      const ValueKey<String>('maat-flow-discovery-card-the-djed'),
    );
    await tester.scrollUntilVisible(
      djedCard,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(djedCard, findsOneWidget);
    expect(find.text('The Djed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final fixture in <(String, Size, double)>[
    ('minimum', const Size(320, 700), 1),
    ('mockup', const Size(390, 844), 1),
    ('large', const Size(430, 932), 1),
    ('accessible', const Size(390, 844), 1.45),
  ]) {
    testWidgets('discovery visual ${fixture.$1}', (tester) async {
      await pumpDiscovery(
        tester,
        size: fixture.$2,
        textScale: fixture.$3,
        onOpen: (_) {},
      );
      expect(tester.takeException(), isNull);
      if (!_captureDiscoveryVisuals) return;
      await expectLater(
        find.byKey(const ValueKey<String>('discovery-visual-capture')),
        matchesGoldenFile('/tmp/maat-flow-discovery-${fixture.$1}.png'),
      );
    });
  }
}
