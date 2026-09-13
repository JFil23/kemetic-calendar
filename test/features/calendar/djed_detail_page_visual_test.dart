import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_day_presentation.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_event_block_visual.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import '../../support/maat_flow_visual_goldens.dart';

const _captureDjedVisuals = bool.fromEnvironment('CAPTURE_DJED_VISUALS');
final _goldenRoot = maatFlowVisualGoldenRoot;

void main() {
  setUpAll(loadMaatFlowVisualTestFonts);

  Future<void> pumpDjed(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    double topPadding = 0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            padding: EdgeInsets.only(top: topPadding),
            viewPadding: EdgeInsets.only(top: topPadding),
          ),
          child: RepaintBoundary(
            key: const ValueKey<String>('djed-visual-capture'),
            child: DjedDetailSurface(onCarry: () {}, onBack: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
    Object? heroLoadError;
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(DjedDetailTokens.heroAsset),
        tester.element(find.byType(DjedDetailSurface)),
        onError: (exception, stackTrace) => heroLoadError = exception,
      ),
    );
    expect(heroLoadError, isNull);
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
      expect(find.byType(MaatFlowThirtyDayCalendar), findsOneWidget);
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

  testWidgets(
    'all nine Djed detail sittings open the canonical sitting sheet',
    (tester) async {
      await pumpDjed(tester, size: const Size(390, 844));

      Future<void> openAndClose(Finder target, int sittingNumber) async {
        await Scrollable.ensureVisible(
          tester.element(target),
          alignment: .5,
          duration: Duration.zero,
        );
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            ValueKey<String>('djed-detail-sitting-sheet-$sittingNumber'),
          ),
          findsOneWidget,
        );
        final presentation = tester.widget<DjedDayPresentation>(
          find.byType(DjedDayPresentation),
        );
        expect(presentation.fixture.sittingNumber, sittingNumber);
        await tester.tap(
          find.byKey(
            ValueKey<String>('djed-detail-sitting-close-$sittingNumber'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DjedDayPresentation), findsNothing);
      }

      for (var sitting = 1; sitting <= 5; sitting++) {
        await openAndClose(
          find.byKey(ValueKey<String>('djed-event-block-detail-$sitting')),
          sitting,
        );
      }

      final remaining = find.byKey(
        const ValueKey<String>('djed-see-remaining-sittings'),
      );
      await Scrollable.ensureVisible(
        tester.element(remaining),
        alignment: .5,
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
      await tester.tap(remaining);
      await tester.pumpAndSettle();
      for (var sitting = 6; sitting <= 9; sitting++) {
        await openAndClose(
          find.byKey(ValueKey<String>('djed-compact-sitting-$sitting')),
          sitting,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('beam and row selection follow the authored support focus', (
    tester,
  ) async {
    await pumpDjed(tester, size: const Size(390, 844));

    double rowOpacity(int support) => tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byKey(ValueKey<String>('djed-support-row-$support')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    double beamOpacity(int support) => tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byKey(ValueKey<String>('djed-spine-support-$support')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    expect(rowOpacity(1), 1);
    expect(rowOpacity(2), .48);
    expect(beamOpacity(1), 1);
    expect(beamOpacity(2), .42);

    await tester.tap(
      find.byKey(const ValueKey<String>('djed-spine-support-2')),
    );
    await tester.pump();
    expect(rowOpacity(1), .48);
    expect(rowOpacity(2), 1);
    expect(beamOpacity(1), .42);
    expect(beamOpacity(2), 1);
    expect(
      tester
          .widget<EditableText>(
            find
                .descendant(
                  of: find.byKey(const ValueKey<String>('djed-support-name-2')),
                  matching: find.byType(EditableText),
                )
                .first,
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('djed-support-name-2')),
      'the weekly call with my sister',
    );
    await tester.pump();

    final condition = find.byKey(
      const ValueKey<String>('djed-support-2-wobbling'),
    );
    await Scrollable.ensureVisible(
      tester.element(condition),
      alignment: .55,
      duration: Duration.zero,
    );
    await tester.pump();
    await tester.tap(condition);
    await tester.pump();
    expect(rowOpacity(2), .48);
    expect(rowOpacity(3), 1);
    expect(beamOpacity(2), .42);
    expect(beamOpacity(3), 1);
    expect(
      tester
          .widget<EditableText>(
            find
                .descendant(
                  of: find.byKey(const ValueKey<String>('djed-support-name-3')),
                  matching: find.byType(EditableText),
                )
                .first,
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches the locked Djed detail mockup at 390 by 844', (
    tester,
  ) async {
    await pumpDjed(tester, size: const Size(390, 844), topPadding: 52);
    await expectLater(
      find.byKey(const ValueKey<String>('djed-visual-capture')),
      matchesGoldenFile('$_goldenRoot/djed-detail-390x844.png'),
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
      matchesGoldenFile('$_goldenRoot/djed-detail-supports-390x844.png'),
    );

    scrollState.position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('djed-spine-support-2')),
    );
    tester.binding.focusManager.primaryFocus?.unfocus();
    scrollState.position.jumpTo(
      scrollState.position.maxScrollExtent.clamp(0, 820),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey<String>('djed-visual-capture')),
      matchesGoldenFile(
        '$_goldenRoot/djed-detail-support-2-selected-390x844.png',
      ),
    );
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
