import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/data/flow_appearance_store.dart';
import 'package:mobile/features/calendar/presentation/user_flow_appearance_visual.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const accent = Color(0xFF6F93A8);
  final imageBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'anon-key-0123456789012345678901234567890123456789',
      );
    }
  });

  setUp(FlowAppearanceStore.debugResetImageCacheForTesting);
  tearDown(FlowAppearanceStore.debugResetImageCacheForTesting);

  Future<void> pumpHero(
    WidgetTester tester, {
    required FlowAppearance appearance,
    bool withImage = false,
    int completedOccurrences = 0,
    int totalOccurrences = 0,
    bool showProgressFooter = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('appearance-capture'),
            child: UserFlowAppearanceHero(
              appearance: appearance,
              accent: accent,
              localImageBytes: withImage ? imageBytes : null,
              height: 180,
              completedOccurrences: completedOccurrences,
              totalOccurrences: totalOccurrences,
              showProgressFooter: showProgressFooter,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('no image and no sign keeps the legacy fallback', (tester) async {
    await pumpHero(tester, appearance: FlowAppearance.empty);

    expect(
      find.byKey(const ValueKey('user-flow-appearance-fallback-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('user-flow-appearance-image-layer')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('user-flow-appearance-sign-layer')),
      findsNothing,
    );
  });

  testWidgets('image sits behind the selected sign', (tester) async {
    await pumpHero(
      tester,
      appearance: const FlowAppearance(
        signKind: FlowSignKind.papyrus,
        signLabel: 'Study',
        accentArgb: 0xFF6F93A8,
      ),
      withImage: true,
    );

    expect(
      find.byKey(const ValueKey('user-flow-appearance-image-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('user-flow-appearance-treatment-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('user-flow-appearance-vignette-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('user-flow-appearance-grain-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('user-flow-appearance-sign-layer')),
      findsOneWidget,
    );
    expect(find.text('Study'), findsOneWidget);
  });

  testWidgets('image without a sign remains the complete hero', (tester) async {
    await pumpHero(
      tester,
      appearance: const FlowAppearance(accentArgb: 0xFF6F93A8),
      withImage: true,
    );

    expect(
      find.byKey(const ValueKey('user-flow-appearance-image-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('user-flow-appearance-sign-layer')),
      findsNothing,
    );
  });

  testWidgets('persisted image hydration is shared across rebuilds', (
    tester,
  ) async {
    final download = Completer<Uint8List>();
    var downloadCount = 0;
    FlowAppearanceStore.debugDownloadImageForTesting = (_, path) {
      expect(path, 'owner/flow-image.jpg');
      downloadCount += 1;
      return download.future;
    };
    const appearance = FlowAppearance(
      imageObjectPath: 'owner/flow-image.jpg',
      accentArgb: 0xFF6F93A8,
    );

    await pumpHero(tester, appearance: appearance);
    await pumpHero(tester, appearance: appearance);

    expect(downloadCount, 1);
    download.complete(imageBytes);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('user-flow-appearance-image-layer')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
  });

  testWidgets('day hero reports completion-derived sign progress', (
    tester,
  ) async {
    await pumpHero(
      tester,
      appearance: const FlowAppearance(
        signKind: FlowSignKind.palmCount,
        signLabel: 'nights walked',
      ),
      completedOccurrences: 11,
      totalOccurrences: 28,
      showProgressFooter: true,
    );

    expect(
      find.byKey(const ValueKey('user-flow-appearance-progress-footer')),
      findsOneWidget,
    );
    expect(find.text('nights walked'), findsWidgets);
    expect(find.text('11 OF 28'), findsOneWidget);
  });

  testWidgets('Merkhet footer names the selected measurement', (tester) async {
    await pumpHero(
      tester,
      appearance: const FlowAppearance(signKind: FlowSignKind.palmCount),
      completedOccurrences: 4,
      totalOccurrences: 12,
      showProgressFooter: true,
    );

    expect(find.text('completed occurrences'), findsOneWidget);
    expect(find.text('4 OF 12'), findsOneWidget);
  });
}
