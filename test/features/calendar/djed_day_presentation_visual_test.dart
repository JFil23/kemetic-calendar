import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_day_presentation.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_sitting_presentation.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_event_block_visual.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_djed_v2_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import '../../support/maat_flow_visual_goldens.dart';

const _captureDjedDayVisuals = bool.fromEnvironment('CAPTURE_DJED_DAY_VISUALS');
const _captureDjedSittingStages = bool.fromEnvironment(
  'CAPTURE_DJED_SITTING_STAGES',
);
final _goldenRoot = maatFlowVisualGoldenRoot;
const _releasedSupportVisualFixtures = <DjedSupportFixture>[
  DjedSupportFixture(
    name: 'support 01',
    condition: DjedSupportCondition.unassessed,
  ),
  DjedSupportFixture(
    name: 'the weekly call with my sister',
    condition: DjedSupportCondition.unassessed,
  ),
  DjedSupportFixture(
    name: 'support 03',
    condition: DjedSupportCondition.unassessed,
    released: true,
  ),
  DjedSupportFixture(
    name: 'support 04',
    condition: DjedSupportCondition.unassessed,
  ),
];

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const appLinksMessages = MethodChannel('com.llfbandit.app_links/messages');
    const appLinksEvents = MethodChannel('com.llfbandit.app_links/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(appLinksMessages, (_) async => null);
    messenger.setMockMethodCallHandler(appLinksEvents, (_) async {
      scheduleMicrotask(
        () =>
            messenger.handlePlatformMessage(appLinksEvents.name, null, (_) {}),
      );
      return null;
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
    await loadMaatFlowVisualTestFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });
  tearDown(CalendarEventDetailSheetCoordinator.debugResetForTests);

  Future<void> pumpPresentation(
    WidgetTester tester, {
    required Size size,
    Key? presentationKey,
    double textScale = 1,
    DjedDayVisualFixture fixture = kDjedDayVisualFixture,
    List<DjedSupportFixture> supports = kDjedSupportFixtures,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: RepaintBoundary(
              key: const ValueKey<String>('djed-day-visual-capture'),
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[Color(0xFF17130C), Colors.black],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: InstrumentEventSheetHost(
                      semanticLabel: 'Djed sitting details',
                      handleColor: const Color(0xFF72571E),
                      body: DjedDayPresentation(
                        key: presentationKey,
                        fixture: fixture,
                        supports: supports,
                        onStageAction: () {},
                        onResultSelected: (_) {},
                        onCompletionSelected: (_) {},
                      ),
                      footer: DjedDayFooterActions(
                        onMakeTodo: () {},
                        onCalendar: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Djed reuses the shared layer frame and HTML-authored stage', (
    tester,
  ) async {
    await pumpPresentation(tester, size: const Size(390, 720));
    expect(find.byType(InstrumentEventPresentationFrame), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('djed-day-live-stage')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('djed-day-live-stage'))),
      const Size(340, 205),
    );
    final title = find.byKey(const ValueKey<String>('djed-instrument-title'));
    final stage = find.byKey(const ValueKey<String>('djed-day-live-stage'));
    final practiceSheet = find.byKey(
      const ValueKey<String>('djed-practice-sheet'),
    );
    expect(tester.widget<Text>(title).data, 'Make one move');
    expect(tester.getRect(stage).top - tester.getRect(title).bottom, 12);
    expect(
      tester.getRect(practiceSheet).top - tester.getRect(stage).bottom,
      closeTo(24, 1),
    );
    expect(find.textContaining('SITTING 04'), findsNothing);
    expect(find.text('Dawn + 30 min · 5 min'), findsNothing);
    expect(find.text('TODAY'), findsNothing);
    expect(
      find.text(
        'Same method, new beam. One useful move. Small enough to complete before you return.',
      ),
      findsNothing,
    );
    expect(find.text('Make one move'), findsWidgets);
    expect(find.text('the weekly call with my sister'), findsOneWidget);
    expect(find.text('Do today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Djed beams retain the authored support hierarchy and palettes', () {
    expect(DjedDayTokens.unselectedSupportOpacity, .34);
    expect(DjedDayTokens.orientationSupportOpacity, .78);
    expect(DjedDayTokens.raisingGlow, const Color(0xFFF0C96A));
    expect(DjedDayTokens.supportGradientStops, const <double>[0, .54, 1]);
    expect(DjedDayTokens.wobblingSupportGradientStops, const <double>[
      0,
      .5,
      1,
    ]);
    expect(DjedDayTokens.unassessedSupportGradient, const <Color>[
      Color(0xFFD9C99D),
      Color(0xFFAC8C50),
      Color(0xFF705129),
    ]);
    expect(DjedDayTokens.holdingSupportGradient, const <Color>[
      Color(0xFFF4E4B2),
      Color(0xFFD2AE63),
      Color(0xFF8D662B),
    ]);
    expect(DjedDayTokens.underPressureSupportGradient, const <Color>[
      Color(0xFFEBCBAD),
      Color(0xFFC58D61),
      Color(0xFF7D4D32),
    ]);
    expect(DjedDayTokens.wobblingSupportGradient, const <Color>[
      Color(0xFFE4C782),
      Color(0xFFB28A42),
      Color(0xFF695021),
    ]);
  });

  testWidgets('Djed paints all authored support conditions in one stage', (
    tester,
  ) async {
    await pumpPresentation(
      tester,
      size: const Size(390, 844),
      supports: const <DjedSupportFixture>[
        DjedSupportFixture(
          name: 'holding support',
          condition: DjedSupportCondition.holding,
        ),
        DjedSupportFixture(
          name: 'pressure support',
          condition: DjedSupportCondition.underPressure,
        ),
        DjedSupportFixture(
          name: 'wobbling support',
          condition: DjedSupportCondition.wobbling,
        ),
        DjedSupportFixture(
          name: 'unassessed support',
          condition: DjedSupportCondition.unassessed,
        ),
      ],
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('djed-day-live-stage'))),
      const Size(340, 230),
    );
    await expectLater(
      find.byKey(const ValueKey<String>('djed-day-visual-capture')),
      matchesGoldenFile('$_goldenRoot/djed-day-support-states-390x844.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Djed renders released history as a filled beam without a ghost',
    (tester) async {
      expect(_releasedSupportVisualFixtures[2].released, isTrue);
      await pumpPresentation(
        tester,
        size: const Size(390, 720),
        fixture: const DjedDayVisualFixture(
          sittingNumber: 7,
          stage: DjedPracticeStageVisual.readResult,
          supportSlot: 3,
          supportName: 'support 03',
        ),
        supports: _releasedSupportVisualFixtures,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey<String>('djed-day-live-stage')),
        ),
        const Size(340, 205),
      );
      await expectLater(
        find.byKey(const ValueKey<String>('djed-day-visual-capture')),
        matchesGoldenFile('$_goldenRoot/djed-day-released-filled-390x720.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all sittings show one pillar, four filled beams, and guides only 3–8',
    (tester) async {
      for (var sittingNumber = 1; sittingNumber <= 9; sittingNumber++) {
        await pumpPresentation(
          tester,
          size: const Size(390, 844),
          presentationKey: ValueKey<String>('djed-sitting-$sittingNumber'),
          fixture: djedDayVisualFixtureForEvent(
            djedV2EventByNumber(sittingNumber)!,
            supportName: 'support $sittingNumber',
          ),
          supports: _releasedSupportVisualFixtures,
        );
        final title = find.byKey(
          const ValueKey<String>('djed-instrument-title'),
        );
        final stage = find.byKey(const ValueKey<String>('djed-day-live-stage'));
        final practiceSheet = find.byKey(
          const ValueKey<String>('djed-practice-sheet'),
        );
        expect(
          tester.widget<Text>(title).data,
          kDjedSittingFixtures[sittingNumber - 1].title,
        );
        expect(tester.getRect(stage).top - tester.getRect(title).bottom, 12);
        expect(tester.getSize(stage), const Size(340, 230));
        final initialStageTop = tester.getRect(stage).top;
        final initialPracticeTop = tester.getRect(practiceSheet).top;
        expect(
          tester.getRect(practiceSheet).top - tester.getRect(stage).bottom,
          closeTo(24, 1),
          reason: 'sitting $sittingNumber must reveal the entire Djed stage',
        );
        if (_captureDjedSittingStages) {
          await expectLater(
            find.byKey(const ValueKey<String>('djed-day-visual-capture')),
            matchesGoldenFile(
              '/tmp/djed-day-sitting-$sittingNumber-released-filled-390x844.png',
            ),
          );
        }
        await tester.drag(
          find.byKey(const ValueKey<String>('djed-presentation-body')),
          const Offset(0, -120),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(practiceSheet).top, lessThan(initialPracticeTop));
        expect(tester.getRect(stage).top, closeTo(initialStageTop, .1));
        expect(tester.getSize(stage), const Size(340, 230));
        await tester.drag(
          find.byKey(const ValueKey<String>('djed-presentation-body')),
          const Offset(0, 440),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(practiceSheet).top,
          closeTo(initialPracticeTop, 1),
        );
        expect(tester.getRect(stage).top, closeTo(initialStageTop, .1));
        expect(tester.getSize(stage), const Size(340, 230));
        expect(
          tester.getRect(practiceSheet).top - tester.getRect(stage).bottom,
          closeTo(24, 1),
        );
        final disclosure = find.byKey(
          const ValueKey<String>('djed-in-kemet-disclosure'),
        );
        expect(disclosure, findsOneWidget);
        expect(find.text('In Kemet'), findsOneWidget);
        expect(
          find.text(
            'The djed pillar carried the idea of stability and uprightness. Its raising made that stability physical: the pillar had to stand. This flow keeps that logic intact by asking what actually bears weight, what has been tested, and what can be raised again.',
          ),
          findsNothing,
        );
        expect(find.text('Back to Day View'), findsNothing);
        await tester.ensureVisible(disclosure);
        await tester.pumpAndSettle();
        await tester.tap(disclosure);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'The djed pillar carried the idea of stability and uprightness. Its raising made that stability physical: the pillar had to stand. This flow keeps that logic intact by asking what actually bears weight, what has been tested, and what can be raised again.',
          ),
          findsOneWidget,
          reason: 'sitting $sittingNumber must use the exact shared copy',
        );
        await tester.tap(disclosure);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('djed-in-kemet-explanation')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  test('missing support_name keeps the authored sitting-four name', () {
    final event = djedV2EventByNumber(4)!;
    expect(
      djedDayVisualFixtureForEvent(event).supportName,
      'the weekly call with my sister',
    );
  });

  test('unnamed later sittings do not invent support 0N copy', () {
    expect(authoredDjedSupportNameForSitting(8), isEmpty);
    expect(authoredDjedSupportNameForSitting(9), isEmpty);
    expect(
      djedDayVisualFixtureForEvent(djedV2EventByNumber(8)!).supportName,
      isEmpty,
    );
    expect(djedSheetSupportBarLabel(slotNumber: 4, name: ''), '04');
    expect(
      djedSheetSupportBarLabel(
        slotNumber: 2,
        name: 'the weekly call with my sister',
      ),
      '02 · the weekly call wit…',
    );
  });

  testWidgets('Djed Day View uses the exact angled ember event block', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey<String>('djed-production-day-view-capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: DayViewPage(
            clock: () => DateTime(2026, 9, 14, 12),
            initialKy: 2,
            initialKm: 6,
            initialKd: 27,
            showGregorian: false,
            getMonthName: (_) => 'Rekh-Wer (Rḫ-wr)',
            notesForDay: (ky, km, kd) => <NoteData>[
              if (ky == 2 && km == 6 && kd == 27) ...<NoteData>[
                NoteData(
                  clientEventId: 'djed-event-4',
                  title: 'Djed 4: Make one move',
                  allDay: false,
                  start: const TimeOfDay(hour: 7, minute: 12),
                  end: const TimeOfDay(hour: 7, minute: 17),
                  flowId: 84,
                  behaviorPayload: <String, dynamic>{
                    'kind': kDjedV2BehaviorKind,
                    'flow_key': kTheDjedFlowKey,
                    'djed_schema_version': kDjedV2SchemaVersion,
                    'semantic_step_id': 'support-02-make-move',
                    'event_number': 4,
                    'support_name': 'the weekly call with my sister',
                  },
                ),
                const NoteData(
                  clientEventId: 'journal-context-event',
                  title: 'journal every day',
                  allDay: false,
                  start: TimeOfDay(hour: 6, minute: 8),
                  end: TimeOfDay(hour: 6, minute: 38),
                  manualColor: Color(0xFF62C18C),
                ),
                const NoteData(
                  clientEventId: 'bits-context-event',
                  title: 'Bits and Operations',
                  allDay: false,
                  start: TimeOfDay(hour: 10, minute: 7),
                  end: TimeOfDay(hour: 10, minute: 37),
                  manualColor: Color(0xFF4D8FD1),
                ),
                const NoteData(
                  clientEventId: 'spider-context-event',
                  title: "The Spider's Shortcut",
                  allDay: false,
                  start: TimeOfDay(hour: 11, minute: 42),
                  end: TimeOfDay(hour: 12, minute: 12),
                  manualColor: Color(0xFFD6625C),
                ),
              ],
            ],
            flowIndex: const <int, FlowData>{
              84: FlowData(
                id: 84,
                name: kTheDjedTitle,
                color: Color(0xFFE0873C),
                active: true,
                notes:
                    'mode=gregorian;maat=$kTheDjedFlowKey;djed_schema_version=2',
              ),
            },
            activeLedgerFlowIds: const <int>{84},
            initialFirstVisibleMinute: 6 * 60,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DjedEventBlockVisual), findsOneWidget);
    expect(find.text('Make one move'), findsOneWidget);
    expect(find.text('the weekly call with my sister'), findsOneWidget);
    expect(find.text('One small thing today'), findsOneWidget);
    expect(find.text('Second of four'), findsOneWidget);
    final djedEventRect = tester.getRect(find.byType(DjedEventBlockVisual));
    final ordinaryEventTitleRect = tester.getRect(
      find.text('journal every day'),
    );
    expect(djedEventRect.height, 60);
    expect(djedEventRect.width, closeTo(251.2, .1));
    expect(djedEventRect.left, closeTo(ordinaryEventTitleRect.left - 10, .1));
    expect(find.byType(InstrumentEventSheetHost), findsNothing);

    await expectLater(
      find.byKey(const ValueKey<String>('djed-production-day-view-capture')),
      matchesGoldenFile('$_goldenRoot/djed-day-view-390x844.png'),
    );

    await tester.tap(find.byType(DjedEventBlockVisual));
    await tester.pumpAndSettle();
    expect(find.byType(InstrumentEventSheetHost), findsOneWidget);
    expect(find.byType(InstrumentEventPresentationFrame), findsOneWidget);
    final host = tester.widget<InstrumentEventSheetHost>(
      find.byType(InstrumentEventSheetHost),
    );
    expect(host.initialExtent, instrumentEventSheetMinExtent);
    expect(host.geometry, isNull);
    final presentation = tester.widget<DjedDayPresentation>(
      find.byType(DjedDayPresentation),
    );
    expect(presentation.fixture.sittingNumber, 4);
    final frame = tester.widget<InstrumentEventPresentationFrame>(
      find.byType(InstrumentEventPresentationFrame),
    );
    expect(frame.initialLowerSheetPeek, isNull);
    expect(
      find.descendant(
        of: find.byType(InstrumentEventPresentationFrame),
        matching: find.byType(CustomScrollView),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('instrument-sheet-handle-mark')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('djed-practice-sheet-handle')),
      findsNothing,
    );
    expect(find.byTooltip('Event options'), findsOneWidget);
    expect(find.text('×'), findsNothing);
    expect(find.textContaining('SITTING 04'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('djed-detail-make-todo')),
      findsOneWidget,
    );
    final practiceSheet = find.byKey(
      const ValueKey<String>('djed-practice-sheet'),
    );
    final frameRect = tester.getRect(
      find.byType(InstrumentEventPresentationFrame),
    );
    final initialPracticeTop = tester.getTopLeft(practiceSheet).dy;
    final djedStage = find.byKey(const ValueKey<String>('djed-day-live-stage'));
    final initialStageTop = tester.getTopLeft(djedStage).dy;
    final initialStageSize = tester.getSize(djedStage);
    expect(initialStageSize, const Size(340, 230));
    final instrumentTitle = find.byKey(
      const ValueKey<String>('djed-instrument-title'),
    );
    expect(tester.widget<Text>(instrumentTitle).data, 'Make one move');
    expect(
      tester.getRect(djedStage).top - tester.getRect(instrumentTitle).bottom,
      12,
    );
    await tester.drag(
      find.byKey(const ValueKey<String>('djed-presentation-body')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    final raisedPracticeTop = tester.getTopLeft(practiceSheet).dy;
    expect(raisedPracticeTop, lessThan(initialPracticeTop));
    expect(tester.getTopLeft(djedStage).dy, closeTo(initialStageTop, .1));
    expect(tester.getSize(djedStage), initialStageSize);
    expect(
      tester.getSize(find.byType(InstrumentEventSheetHost)).height,
      closeTo((844 - 12) * instrumentEventSheetMinExtent + 8, .1),
    );
    await tester.drag(
      find.byKey(const ValueKey<String>('djed-presentation-body')),
      const Offset(0, 440),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(practiceSheet).dy, closeTo(initialPracticeTop, 1));
    expect(tester.getSize(djedStage), initialStageSize);
    expect(
      tester.getRect(practiceSheet).top - tester.getRect(djedStage).bottom,
      closeTo(24, 1),
    );
    await expectLater(
      find.byKey(const ValueKey<String>('djed-production-day-view-capture')),
      matchesGoldenFile('$_goldenRoot/djed-day-sheet-390x844.png'),
    );
    final dockDistance = initialPracticeTop - frameRect.top;
    await tester.drag(
      find.byKey(const ValueKey<String>('djed-presentation-body')),
      Offset(0, -(dockDistance + 20)),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(practiceSheet).dy, closeTo(frameRect.top, 1));
    final footerTop = tester.getRect(find.byType(DjedDayFooterChrome)).top;
    final requiredAtDock = <Finder>[
      find.descendant(
        of: practiceSheet,
        matching: find.text('the weekly call with my sister'),
      ),
      find.descendant(
        of: practiceSheet,
        matching: find.text(
          'What is one useful thing you can do that is fully in your hands?',
        ),
      ),
      find.byKey(const ValueKey<String>('djed-move-field')),
      find.descendant(of: practiceSheet, matching: find.text('Do today')),
      find.descendant(
        of: practiceSheet,
        matching: find.text('Put on calendar'),
      ),
    ];
    for (final target in requiredAtDock) {
      final rect = tester.getRect(target);
      expect(rect.top, greaterThanOrEqualTo(frameRect.top));
      expect(rect.bottom, lessThanOrEqualTo(footerTop));
    }
    await expectLater(
      find.byKey(const ValueKey<String>('djed-production-day-view-capture')),
      matchesGoldenFile(
        '$_goldenRoot/djed-day-sheet-practice-raised-production-390x844.png',
      ),
    );
    final inKemetDisclosure = find.byKey(
      const ValueKey<String>('djed-in-kemet-disclosure'),
    );
    final remainingControls = <Finder>[
      inKemetDisclosure,
      find.descendant(of: practiceSheet, matching: find.text('Observed')),
      find.descendant(of: practiceSheet, matching: find.text('Partly')),
      find.descendant(of: practiceSheet, matching: find.text('Skipped')),
    ];
    for (final target in remainingControls) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      final rect = tester.getRect(target);
      expect(rect.top, greaterThanOrEqualTo(frameRect.top));
      expect(rect.bottom, lessThanOrEqualTo(footerTop));
    }
    expect(find.text('Why this belongs at the Djed'), findsNothing);
    expect(find.text('Back to Day View'), findsNothing);
    expect(
      tester
              .getRect(
                find.byKey(const ValueKey<String>('djed-completion-picker')),
              )
              .top -
          tester.getRect(inKemetDisclosure).bottom,
      closeTo(5, .1),
    );
    final disclosureButton = tester.widget<TextButton>(inKemetDisclosure);
    expect(
      disclosureButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      const Color(0xFF8A8378),
    );
    expect(
      disclosureButton.style?.padding?.resolve(<WidgetState>{}),
      const EdgeInsets.symmetric(vertical: 13),
    );
    final disclosureTextStyle = disclosureButton.style?.textStyle?.resolve(
      <WidgetState>{},
    );
    expect(disclosureTextStyle?.fontSize, 14);
    expect(disclosureTextStyle?.fontStyle, FontStyle.italic);
    await tester.tap(inKemetDisclosure);
    await tester.pumpAndSettle();
    final explanation = find.byKey(
      const ValueKey<String>('djed-in-kemet-explanation'),
    );
    expect(explanation, findsOneWidget);
    final explanationText = tester.widget<Text>(
      find.descendant(of: explanation, matching: find.byType(Text)),
    );
    expect(
      explanationText.data,
      'The djed pillar carried the idea of stability and uprightness. Its raising made that stability physical: the pillar had to stand. This flow keeps that logic intact by asking what actually bears weight, what has been tested, and what can be raised again.',
    );
    expect(explanationText.style?.fontSize, 14);
    expect(explanationText.style?.fontStyle, isNull);
    expect(explanationText.style?.fontWeight, FontWeight.w400);
    expect(explanationText.style?.height, 1.4);
    expect(explanationText.style?.color, const Color(0xFFA69A83));
    await tester.ensureVisible(explanation);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey<String>('djed-production-day-view-capture')),
      matchesGoldenFile(
        '$_goldenRoot/djed-day-sheet-in-kemet-expanded-production-390x844.png',
      ),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('djed-completion-picker')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getRect(find.byKey(const ValueKey<String>('djed-completion-picker')))
          .bottom,
      lessThanOrEqualTo(footerTop),
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey<String>('djed-detail-make-todo')))
          .bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Day View keeps In Kemet expansion and scroll position through updates',
    (tester) async {
      await pumpPresentation(tester, size: const Size(390, 844));
      final disclosure = find.byKey(
        const ValueKey<String>('djed-in-kemet-disclosure'),
      );
      await tester.ensureVisible(disclosure);
      await tester.pumpAndSettle();
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      final practiceSheet = find.byKey(
        const ValueKey<String>('djed-practice-sheet'),
      );
      final practiceTop = tester.getTopLeft(practiceSheet).dy;
      final disclosureTop = tester.getTopLeft(disclosure).dy;

      await pumpPresentation(
        tester,
        size: const Size(390, 844),
        fixture: const DjedDayVisualFixture(
          sittingNumber: 4,
          stage: DjedPracticeStageVisual.makeMove,
          supportSlot: 2,
          supportName: 'the weekly call with my sister',
          move: 'updated move',
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('djed-in-kemet-explanation')),
        findsOneWidget,
      );
      expect(tester.getTopLeft(practiceSheet).dy, closeTo(practiceTop, .1));
      expect(tester.getTopLeft(disclosure).dy, closeTo(disclosureTop, .1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detail-entry disclosure and Back action remain unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DjedDetailSittingPresentation(
            event: kDjedV2Events[3],
            sitting: kDjedSittingFixtures[3],
            fixture: kDjedDayVisualFixture,
            supports: kDjedSupportFixtures,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DjedDayPresentation), findsNothing);
    expect(find.byType(InstrumentEventPresentationFrame), findsNothing);
    expect(find.text('Why this belongs at the Djed'), findsOneWidget);
    expect(find.text('In Kemet'), findsNothing);
    expect(find.text('Back to the Djed'), findsOneWidget);
    expect(find.text('Back to Day View'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('djed-in-kemet-disclosure')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Day View keeps the authored Djed face without a sitting payload',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: DayViewPage(
            initialKy: 2,
            initialKm: 6,
            initialKd: 27,
            showGregorian: false,
            getMonthName: (_) => 'Rekh-Wer (Rḫ-wr)',
            notesForDay: (ky, km, kd) => <NoteData>[
              if (ky == 2 && km == 6 && kd == 27)
                const NoteData(
                  clientEventId: 'djed-event-4-no-payload',
                  title: 'Djed 4: Make one move',
                  allDay: false,
                  start: TimeOfDay(hour: 7, minute: 12),
                  end: TimeOfDay(hour: 7, minute: 17),
                  flowId: 84,
                ),
            ],
            flowIndex: const <int, FlowData>{
              84: FlowData(
                id: 84,
                name: kTheDjedTitle,
                color: Color(0xFFE0873C),
                active: true,
                notes: 'mode=gregorian;maat=$kTheDjedFlowKey',
              ),
            },
            activeLedgerFlowIds: const <int>{84},
            initialFirstVisibleMinute: 6 * 60,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DjedEventBlockVisual), findsOneWidget);
      expect(find.text('Make one move'), findsOneWidget);
      expect(find.text('the weekly call with my sister'), findsOneWidget);
      expect(find.text('One small thing today'), findsOneWidget);
      expect(find.text('Second of four'), findsOneWidget);
      expect(tester.getSize(find.byType(DjedEventBlockVisual)).height, 60);
      expect(find.byType(InstrumentEventSheetHost), findsNothing);

      await tester.tap(find.byType(DjedEventBlockVisual));
      await tester.pumpAndSettle();
      expect(find.byType(InstrumentEventSheetHost), findsOneWidget);
      expect(find.byType(InstrumentEventPresentationFrame), findsOneWidget);
      expect(find.byTooltip('Event options'), findsOneWidget);
      expect(find.text('×'), findsNothing);
      expect(find.textContaining('SITTING 04'), findsNothing);
      expect(find.text('Make one move'), findsWidgets);
      expect(find.text('the weekly call with my sister'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('djed-detail-make-todo')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('result fixture presents helped, no change, and not done', (
    tester,
  ) async {
    await pumpPresentation(
      tester,
      size: const Size(390, 720),
      fixture: const DjedDayVisualFixture(
        sittingNumber: 3,
        stage: DjedPracticeStageVisual.readResult,
        supportSlot: 1,
        supportName: 'daily energy',
        result: DjedResultVisualState.noChange,
      ),
    );
    expect(find.text('It helped'), findsOneWidget);
    expect(find.text('No change'), findsOneWidget);
    expect(find.text("I didn't do it"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared host remains bounded with a keyboard inset', (
    tester,
  ) async {
    const size = Size(390, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: InstrumentEventSheetHost(
                semanticLabel: 'Djed sitting details',
                handleColor: DjedDayTokens.gold,
                body: DjedDayPresentation(),
                footer: DjedDayFooterActions(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('djed-day-live-stage'))),
      const Size(340, 230),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Djed stage size follows only the full viewport breakpoint', (
    tester,
  ) async {
    await pumpPresentation(tester, size: const Size(390, 844));
    final stage = find.byKey(const ValueKey<String>('djed-day-live-stage'));
    expect(tester.getSize(stage), const Size(340, 230));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Day View uses the shared foreground start and one handle', (
    tester,
  ) async {
    await pumpPresentation(tester, size: const Size(390, 844));
    final sheet = find.byType(InstrumentEventSheetHost);
    final frameRect = tester.getRect(
      find.byType(InstrumentEventPresentationFrame),
    );
    final practiceRect = tester.getRect(
      find.byKey(const ValueKey<String>('djed-practice-sheet')),
    );
    expect(frameRect.bottom - practiceRect.top, greaterThan(30));
    final frame = tester.widget<InstrumentEventPresentationFrame>(
      find.byType(InstrumentEventPresentationFrame),
    );
    expect(frame.initialLowerSheetPeek, isNull);
    expect(
      find.byKey(const ValueKey<String>('instrument-sheet-handle-mark')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('djed-practice-sheet-handle')),
      findsNothing,
    );

    final initialHeight = tester.getSize(sheet).height;
    final dockDistance = practiceRect.top - frameRect.top;
    await tester.drag(
      find.byKey(const ValueKey<String>('djed-presentation-body')),
      Offset(0, -(dockDistance + 20)),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(sheet).height, closeTo(initialHeight, 0.1));
    final dockedPracticeRect = tester.getRect(
      find.byKey(const ValueKey<String>('djed-practice-sheet')),
    );
    expect(dockedPracticeRect.top, lessThanOrEqualTo(frameRect.top + 1));
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byKey(const ValueKey<String>('djed-day-visual-capture')),
      matchesGoldenFile(
        '$_goldenRoot/djed-day-sheet-practice-raised-390x844.png',
      ),
    );
  });

  for (final fixture in <(String, Size, double, DjedDayVisualFixture)>[
    ('minimum', const Size(320, 700), 1, kDjedDayVisualFixture),
    ('mockup', const Size(390, 844), 1, kDjedDayVisualFixture),
    ('large', const Size(430, 820), 1, kDjedDayVisualFixture),
    ('accessible', const Size(390, 760), 1.35, kDjedDayVisualFixture),
    (
      'result',
      const Size(390, 720),
      1,
      const DjedDayVisualFixture(
        sittingNumber: 3,
        stage: DjedPracticeStageVisual.readResult,
        supportSlot: 1,
        supportName: 'daily energy',
        result: DjedResultVisualState.helped,
        completion: DjedCompletionVisualState.observed,
      ),
    ),
    (
      'retry',
      const Size(390, 720),
      1,
      const DjedDayVisualFixture(
        sittingNumber: 5,
        stage: DjedPracticeStageVisual.smallerRetry,
        supportSlot: 2,
        supportName: 'the work',
        move: 'Open the document and write one sentence.',
        completion: DjedCompletionVisualState.partly,
      ),
    ),
    (
      'raising',
      const Size(390, 720),
      1,
      const DjedDayVisualFixture(
        sittingNumber: 9,
        stage: DjedPracticeStageVisual.finalRaising,
        supportSlot: 4,
        supportName: 'close relationships',
        completion: DjedCompletionVisualState.skipped,
      ),
    ),
  ]) {
    testWidgets('Djed Day View visual ${fixture.$1}', (tester) async {
      await pumpPresentation(
        tester,
        size: fixture.$2,
        textScale: fixture.$3,
        fixture: fixture.$4,
      );
      expect(tester.takeException(), isNull);
      final goldenPath = switch (fixture.$1) {
        'result' => '$_goldenRoot/djed-day-result-390x720.png',
        'retry' => '$_goldenRoot/djed-day-retry-390x720.png',
        'raising' => '$_goldenRoot/djed-day-raising-390x720.png',
        _ when _captureDjedDayVisuals => '/tmp/djed-day-${fixture.$1}.png',
        _ => null,
      };
      if (goldenPath != null) {
        await expectLater(
          find.byKey(const ValueKey<String>('djed-day-visual-capture')),
          matchesGoldenFile(goldenPath),
        );
      }
    });
  }
}
