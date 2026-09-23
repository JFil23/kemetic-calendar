import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/profile/posted_flow_artifact.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

String get _socialFlowArtifactsGolden {
  if (!Platform.isLinux) {
    return 'goldens/social_flow_artifacts.png';
  }
  return switch (Abi.current()) {
    Abi.linuxX64 => 'goldens/linux-x64/social_flow_artifacts.png',
    final abi => throw UnsupportedError(
      'No exact social flow artifact golden is registered for $abi.',
    ),
  };
}

void main() {
  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    final systemFont = FontLoader('Ahem')
      ..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Regular.ttf'));
    await systemFont.load();
  });

  testWidgets(
    'social flow artifacts match the approved image and plain states',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final heroData = await rootBundle.load(
        'assets/the_reading_house/reference_hero.jpg',
      );
      final heroBytes = heroData.buffer.asUint8List(
        heroData.offsetInBytes,
        heroData.lengthInBytes,
      );

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'GentiumPlus'),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: RepaintBoundary(
              key: const ValueKey<String>('social-flow-visual-contract'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PostedFlowArtifact(
                      name: 'Illustrated Practice',
                      color: 0xFF6F93A8,
                      notes: 'A measured practice with its chosen image.',
                      startDate: DateTime(2026, 9, 1),
                      endDate: DateTime(2026, 11, 29),
                      appearance: const FlowAppearance(
                        imageObjectPath: 'visual-contract-fixture.jpg',
                        signKind: FlowSignKind.palmCount,
                        accentArgb: 0xFF6F93A8,
                      ),
                      localImageBytes: heroBytes,
                    ),
                    const SizedBox(height: 22),
                    PostedFlowArtifact(
                      name: 'A Plain Reset',
                      color: 0xFFC08E6E,
                      notes: 'Kept plain on purpose. The list is the practice.',
                      startDate: DateTime(2026, 9, 1),
                      endDate: DateTime(2026, 9, 10),
                      appearance: FlowAppearance.empty,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(heroBytes),
          tester.element(find.byType(Scaffold)),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey<String>('social-flow-visual-contract')),
        matchesGoldenFile(_socialFlowArtifactsGolden),
      );
    },
  );
}
