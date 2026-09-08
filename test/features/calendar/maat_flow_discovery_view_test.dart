import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_discovery_view.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import '../../support/maat_flow_visual_goldens.dart';

const _captureDiscoveryVisuals = bool.fromEnvironment(
  'CAPTURE_MAAT_FLOW_DISCOVERY_VISUALS',
);
final _goldenRoot = maatFlowVisualGoldenRoot;

void main() {
  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
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
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 32),
            viewPadding: const EdgeInsets.only(top: 32),
            textScaler: TextScaler.linear(textScale),
          ),
          child: RepaintBoundary(
            key: const ValueKey<String>('discovery-visual-capture'),
            child: MaatFlowDiscoveryView(onCreate: () {}, onOpen: onOpen),
          ),
        ),
      ),
    );
    await tester.pump();
    final discoveryContext = tester.element(find.byType(MaatFlowDiscoveryView));
    Object? heroLoadError;
    for (final card in kFourMaatFlowDiscoveryFixtures) {
      await tester.runAsync(
        () => precacheImage(
          AssetImage(card.heroAsset),
          discoveryContext,
          onError: (exception, stackTrace) => heroLoadError = exception,
        ),
      );
    }
    expect(heroLoadError, isNull);
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
    await tester.pumpAndSettle();
    expect(opened, isNull);
    expect(
      find.byKey(
        const ValueKey<String>('maat-flow-discovery-detail-track-the-sky'),
      ),
      findsOneWidget,
    );
    expect(find.text('Carry this flow'), findsOneWidget);
    final carry = find.byKey(
      const ValueKey<String>('maat-flow-discovery-carry'),
    );
    await tester.ensureVisible(carry);
    await tester.pumpAndSettle();
    await tester.tap(carry);
    await tester.pump();
    expect(opened, 'track-the-sky');
    await tester.drag(
      find.byKey(
        const ValueKey<String>('maat-flow-discovery-detail-track-the-sky'),
      ),
      const Offset(0, 2000),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('maat-flow-discovery-back')),
    );
    await tester.pumpAndSettle();

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

  testWidgets('tracks the complete four-card discovery scroll inventory', (
    tester,
  ) async {
    await pumpDiscovery(tester, size: const Size(390, 844), onOpen: (_) {});
    for (final state in const <({String flowKey, String golden})>[
      (
        flowKey: 'the-offering-table',
        golden: 'maat-flow-discovery-offering-390x844.png',
      ),
      (
        flowKey: 'the-reading-house',
        golden: 'maat-flow-discovery-reading-house-390x844.png',
      ),
      (flowKey: 'the-djed', golden: 'maat-flow-discovery-djed-390x844.png'),
    ]) {
      final card = find.byKey(
        ValueKey<String>('maat-flow-discovery-card-${state.flowKey}'),
      );
      await tester.scrollUntilVisible(
        card,
        420,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey<String>('discovery-visual-capture')),
        matchesGoldenFile('$_goldenRoot/${state.golden}'),
      );
    }
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
      final goldenPath = fixture.$1 == 'mockup'
          ? '$_goldenRoot/maat-flow-discovery-390x844.png'
          : _captureDiscoveryVisuals
          ? '/tmp/maat-flow-discovery-${fixture.$1}.png'
          : null;
      if (goldenPath != null) {
        await expectLater(
          find.byKey(const ValueKey<String>('discovery-visual-capture')),
          matchesGoldenFile(goldenPath),
        );
      }
    });
  }
}
