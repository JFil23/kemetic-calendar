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
    double height = 180,
    UserFlowAppearanceSurface surface = UserFlowAppearanceSurface.standard,
    int animationRevision = 0,
    int? animationFromCompletedOccurrences,
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: RepaintBoundary(
              key: const ValueKey('appearance-capture'),
              child: UserFlowAppearanceHero(
                appearance: appearance,
                accent: accent,
                localImageBytes: withImage ? imageBytes : null,
                height: height,
                surface: surface,
                completedOccurrences: completedOccurrences,
                totalOccurrences: totalOccurrences,
                showProgressFooter: showProgressFooter,
                animationRevision: animationRevision,
                animationFromCompletedOccurrences:
                    animationFromCompletedOccurrences,
              ),
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

  testWidgets('surface contract preserves detail image and subdues Day View', (
    tester,
  ) async {
    const appearance = FlowAppearance(
      signKind: FlowSignKind.palmCount,
      accentArgb: 0xFF6F93A8,
    );

    await pumpHero(
      tester,
      appearance: appearance,
      withImage: true,
      height: 300,
      surface: UserFlowAppearanceSurface.fullDetail,
    );
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('user-flow-appearance-image-opacity')),
          )
          .opacity,
      1,
    );
    expect(
      tester.widget<FlowSignVisual>(find.byType(FlowSignVisual)).size,
      152,
    );

    await pumpHero(
      tester,
      appearance: appearance,
      withImage: true,
      height: 190,
      surface: UserFlowAppearanceSurface.daySheet,
    );
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('user-flow-appearance-image-opacity')),
          )
          .opacity,
      0.24,
    );
    expect(
      tester.widget<FlowSignVisual>(find.byType(FlowSignVisual)).size,
      136,
    );

    await pumpHero(
      tester,
      appearance: const FlowAppearance(accentArgb: 0xFF6F93A8),
      withImage: true,
      height: 190,
      surface: UserFlowAppearanceSurface.daySheet,
    );
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('user-flow-appearance-image-opacity')),
          )
          .opacity,
      1,
    );
  });

  testWidgets('timeline badge is Merkhet-only and never renders its image', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            UserFlowAppearanceBadge(
              appearance: const FlowAppearance(
                imageObjectPath: 'owner/photo.jpg',
                signKind: FlowSignKind.riverPath,
              ),
              localImageBytes: imageBytes,
              accent: accent,
            ),
            UserFlowAppearanceBadge(
              appearance: const FlowAppearance(
                imageObjectPath: 'owner/image-only.jpg',
              ),
              localImageBytes: imageBytes,
              accent: accent,
            ),
          ],
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('user-flow-appearance-image-layer')),
      findsNothing,
    );
    expect(find.byType(FlowSignVisual), findsOneWidget);
    expect(find.byType(UserFlowAppearanceHero), findsOneWidget);
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

  test('an unhydrated Merkhet never presents completed progress', () {
    expect(
      resolveUserFlowMerkhetProgress(
        completedOccurrences: 0,
        totalOccurrences: 0,
      ),
      0,
    );
  });

  test('Palm Count counts long-flow occurrences as whole marks', () {
    expect(
      resolvePalmCountLitMarks(completedOccurrences: 1, displayedMarkCount: 30),
      1,
    );
    expect(
      resolvePalmCountLitMarks(
        completedOccurrences: 30,
        displayedMarkCount: 30,
      ),
      30,
    );
    expect(
      resolvePalmCountLitMarks(
        completedOccurrences: 31,
        displayedMarkCount: 30,
      ),
      1,
    );
  });

  for (final kind in FlowSignKind.values) {
    testWidgets('${kind.name} animates its next measured step', (tester) async {
      final appearance = FlowAppearance(signKind: kind);
      await pumpHero(
        tester,
        appearance: appearance,
        completedOccurrences: 3,
        totalOccurrences: 12,
        surface: UserFlowAppearanceSurface.daySheet,
      );
      await pumpHero(
        tester,
        appearance: appearance,
        completedOccurrences: 4,
        totalOccurrences: 12,
        surface: UserFlowAppearanceSurface.daySheet,
        animationRevision: 1,
        animationFromCompletedOccurrences: 3,
      );

      expect(
        find.byKey(
          ValueKey<String>('user-flow-merkhet-animation-${kind.name}-1'),
        ),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  }

  testWidgets('reduced motion applies the measured step without animation', (
    tester,
  ) async {
    const appearance = FlowAppearance(signKind: FlowSignKind.palmCount);
    await pumpHero(
      tester,
      appearance: appearance,
      completedOccurrences: 3,
      totalOccurrences: 12,
      surface: UserFlowAppearanceSurface.daySheet,
      disableAnimations: true,
    );
    await pumpHero(
      tester,
      appearance: appearance,
      completedOccurrences: 4,
      totalOccurrences: 12,
      surface: UserFlowAppearanceSurface.daySheet,
      animationRevision: 1,
      animationFromCompletedOccurrences: 3,
      disableAnimations: true,
    );

    expect(tester.hasRunningAnimations, isFalse);
  });
}
