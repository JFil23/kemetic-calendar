import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_thirty_day_calendar.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_day_presentation.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_sitting_presentation.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_event_block_visual.dart';
import 'package:mobile/features/calendar/the_djed_v2_flow.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import '../../support/maat_flow_visual_goldens.dart';

const _captureDjedVisuals = bool.fromEnvironment('CAPTURE_DJED_VISUALS');
const _captureDjedDetailSittings = bool.fromEnvironment(
  'CAPTURE_DJED_DETAIL_SITTINGS',
);
final _goldenRoot = maatFlowVisualGoldenRoot;

const _djedSittingContexts = <String>[
  'You do not have to fix everything at once. For each support: make one small move, then return and see what happened.',
  'You do not have to solve this. Find one useful part that is fully in your hands.',
  'Come back to the move you chose. Read what actually happened before deciding anything else.',
  'Same method, new beam. One useful move. Small enough to complete before you return.',
  'The work already happened outside the app. This sitting only asks what the move taught you.',
  'You know the pattern now: find the part you can move, keep it small, put it in time.',
  'Look at the result, not the intention. What happened is enough to tell you what comes next.',
  'Last beam. Do not make the move bigger because it is last. Small and doable still wins.',
  'Read the last result. Then stand and raise the whole structure.',
];

const _representativeDjedSupports = <DjedSupportFixture>[
  DjedSupportFixture(name: 'Body', condition: DjedSupportCondition.holding),
  DjedSupportFixture(
    name: 'Family',
    condition: DjedSupportCondition.underPressure,
  ),
  DjedSupportFixture(name: 'Work', condition: DjedSupportCondition.wobbling),
  DjedSupportFixture(name: 'Practice', condition: DjedSupportCondition.holding),
];

void main() {
  setUpAll(loadMaatFlowVisualTestFonts);

  Future<void> pumpDjed(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    double topPadding = 0,
    double keyboardInset = 0,
    bool ownedActionable = false,
    List<DjedSupportFixture> supports = kDjedSupportFixtures,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            padding: EdgeInsets.only(top: topPadding),
            viewPadding: EdgeInsets.only(top: topPadding),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: RepaintBoundary(
            key: const ValueKey<String>('djed-visual-capture'),
            child: DjedDetailSurface(
              flowId: ownedActionable ? 42 : null,
              canActOnEvents: ownedActionable,
              supports: supports,
              onCarry: () {},
              onBack: () {},
            ),
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
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('djed-event-block-detail-1')),
          )
          .height,
      106,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all nine Djed detail sittings open the canonical sitting sheet',
    (tester) async {
      await pumpDjed(
        tester,
        size: const Size(390, 844),
        supports: _representativeDjedSupports,
      );

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
        final presentation = tester.widget<DjedDetailSittingPresentation>(
          find.byType(DjedDetailSittingPresentation),
        );
        expect(presentation.fixture.sittingNumber, sittingNumber);
        final sheet = find.byKey(
          ValueKey<String>('djed-detail-sitting-sheet-$sittingNumber'),
        );
        final host = tester.widget<InstrumentEventSheetHost>(sheet);
        expect(host.initialExtent, closeTo((844 * .86) / (844 - 12), .001));
        expect(host.geometry, isNotNull);
        expect(
          host.geometry,
          isNot(same(InstrumentEventSheetGeometry.layered)),
        );
        expect(host.geometry?.topBarHeight, 48);
        expect(host.geometry?.bodyTopGap, 0);
        expect(host.geometry?.footerHeight, 0);
        expect(host.geometry?.sheetBorderRadius, 24);
        expect(find.byType(InstrumentEventPresentationFrame), findsNothing);
        final sitting = kDjedSittingFixtures[sittingNumber - 1];
        final title = find.byKey(
          const ValueKey<String>('djed-detail-sitting-title'),
        );
        final kicker = find.byKey(
          const ValueKey<String>('djed-detail-sitting-kicker'),
        );
        final stage = find.byKey(
          const ValueKey<String>('djed-detail-sitting-stage'),
        );
        expect(tester.widget<Text>(title).data, sitting.title);
        expect(
          tester.widget<Text>(kicker).data,
          'SITTING ${sittingNumber.toString().padLeft(2, '0')} · '
          'DAY ${presentation.event.flowDay} · ${presentation.event.phase}',
        );
        expect(
          find.text('${sitting.timeLabel} · ${sitting.durationLabel}'),
          findsOneWidget,
        );
        expect(find.text('TODAY'), findsOneWidget);
        expect(
          find.text(_djedSittingContexts[sittingNumber - 1]),
          findsOneWidget,
        );
        expect(tester.getSize(stage), const Size(360, 214));
        expect(tester.widget<Text>(kicker).style?.fontSize, 9);
        expect(tester.widget<Text>(title).style?.fontSize, 29);
        expect(find.byType(DjedDayPresentation), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('djed-practice-sheet-handle')),
          findsNothing,
        );
        expect(find.text('Why this belongs at the Djed'), findsOneWidget);
        expect(
          find.descendant(of: sheet, matching: find.text('In Kemet')),
          findsNothing,
        );
        expect(
          find.descendant(of: sheet, matching: find.text('Calendar')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(DjedDetailSittingPresentation),
            matching: find.byType(ListView),
          ),
          findsOneWidget,
        );
        if (sittingNumber == 1) {
          expect(find.text('Pick one ten-minute reset.'), findsOneWidget);
        } else if (sittingNumber.isEven) {
          expect(find.text('Do today'), findsOneWidget);
          expect(find.text('Put on calendar'), findsOneWidget);
        } else {
          expect(find.text('It helped'), findsOneWidget);
          expect(find.text('No change'), findsOneWidget);
          expect(find.text("I didn't do it"), findsOneWidget);
        }
        if (_captureDjedDetailSittings) {
          await expectLater(
            find.byType(Overlay).first,
            matchesGoldenFile(
              '/tmp/djed-detail-sitting-$sittingNumber-top.png',
            ),
          );
        }
        await tester.drag(
          find.byKey(
            const PageStorageKey<String>('djed-detail-sitting-scroll'),
          ),
          const Offset(0, -900),
        );
        await tester.pumpAndSettle();
        expect(find.text('Back to the Djed'), findsOneWidget);
        Navigator.of(tester.element(sheet)).pop();
        await tester.pumpAndSettle();
        expect(find.byType(DjedDetailSittingPresentation), findsNothing);
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

  testWidgets('Djed detail sitting matches the dedicated sheet reference', (
    tester,
  ) async {
    CalendarPage.debugOwnedDjedSittingEventTargetForTesting =
        ({required flowId, required sittingNumber}) {
          final event = djedV2EventByNumber(sittingNumber)!;
          return DayViewSheetEventTarget(
            ky: 1,
            km: 1,
            kd: event.flowDay,
            event: EventItem(
              title: event.title,
              startMin: 11 * 60,
              endMin: 11 * 60 + 5,
              color: const Color(0xFFE0873C),
              allDay: false,
              flowId: flowId,
              clientEventId: djedV2ClientEventId(flowId: flowId, event: event),
            ),
          );
        };
    addTearDown(
      () => CalendarPage.debugOwnedDjedSittingEventTargetForTesting = null,
    );
    await pumpDjed(
      tester,
      size: const Size(390, 844),
      topPadding: 52,
      ownedActionable: true,
      supports: _representativeDjedSupports,
    );
    final sitting = find.byKey(
      const ValueKey<String>('djed-event-block-detail-2'),
    );
    await Scrollable.ensureVisible(
      tester.element(sitting),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(sitting);
    await tester.pumpAndSettle();

    expect(find.byType(DjedDetailSittingPresentation), findsOneWidget);
    expect(find.byType(DjedDayPresentation), findsNothing);
    expect(find.byType(InstrumentEventPresentationFrame), findsNothing);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Do today'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Put on calendar'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile(
        _captureDjedVisuals
            ? '/tmp/djed-detail-sitting-2-top.png'
            : '$_goldenRoot/djed-detail-sitting-2-top-390x844.png',
      ),
    );

    await tester.drag(
      find.byKey(const PageStorageKey<String>('djed-detail-sitting-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.text('Back to the Djed'), findsOneWidget);
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile(
        _captureDjedVisuals
            ? '/tmp/djed-detail-sitting-2-bottom.png'
            : '$_goldenRoot/djed-detail-sitting-2-bottom-390x844.png',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail sitting keeps its 214px stage on a short keyboard view', (
    tester,
  ) async {
    await pumpDjed(tester, size: const Size(320, 700), keyboardInset: 300);
    final sitting = find.byKey(
      const ValueKey<String>('djed-event-block-detail-2'),
    );
    await Scrollable.ensureVisible(
      tester.element(sitting),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(sitting);
    await tester.pumpAndSettle();

    expect(find.byType(DjedDetailSittingPresentation), findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('djed-detail-sitting-stage')),
      ),
      const Size(290, 214),
    );
    expect(tester.takeException(), isNull);
  });

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
