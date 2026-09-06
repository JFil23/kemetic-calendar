import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_day_presentation.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_event_block_visual.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_djed_v2_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _captureDjedDayVisuals = bool.fromEnvironment('CAPTURE_DJED_DAY_VISUALS');

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
    if (_captureDjedDayVisuals) await loadMaatFlowVisualTestFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });
  tearDown(CalendarEventDetailSheetCoordinator.debugResetForTests);

  Future<void> pumpPresentation(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    DjedDayVisualFixture fixture = kDjedDayVisualFixture,
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
                      initialExtent: .71,
                      geometry: InstrumentEventSheetGeometry.layered,
                      trailing: const SizedBox(
                        width: 48,
                        child: Center(
                          child: Text(
                            '×',
                            style: TextStyle(
                              color: Color(0xFFB9A883),
                              fontFamily: 'GentiumPlus',
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ),
                      body: DjedDayPresentation(
                        fixture: fixture,
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
    expect(find.text('Make one move'), findsWidgets);
    expect(find.text('the weekly call with my sister'), findsOneWidget);
    expect(find.text('Do today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Djed Day View uses the exact angled ember event block', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'GentiumPlus'),
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey<String>('djed-production-day-view-capture'),
            child: DayViewGrid(
              ky: 1,
              km: 1,
              kd: 1,
              notes: <NoteData>[
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
              ],
              showGregorian: false,
              flowIndex: <int, FlowData>{
                84: FlowData(
                  id: 84,
                  name: kTheDjedTitle,
                  color: const Color(0xFFE0873C),
                  active: true,
                  notes:
                      'mode=gregorian;maat=$kTheDjedFlowKey;djed_schema_version=2',
                ),
              },
              activeLedgerFlowIds: const <int>{84},
              initialScrollOffset: 6 * 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DjedEventBlockVisual), findsOneWidget);
    expect(find.text('Make one move'), findsOneWidget);
    expect(find.text('Second of four'), findsOneWidget);
    expect(tester.getSize(find.byType(DjedEventBlockVisual)).height, 106);
    expect(find.byType(InstrumentEventSheetHost), findsNothing);

    if (_captureDjedDayVisuals) {
      await expectLater(
        find.byKey(const ValueKey<String>('djed-production-day-view-capture')),
        matchesGoldenFile('/tmp/djed-flutter-day-view-390.png'),
      );
    }

    await tester.tap(find.byType(DjedEventBlockVisual));
    await tester.pumpAndSettle();
    expect(find.byType(InstrumentEventSheetHost), findsOneWidget);
    expect(find.byType(InstrumentEventPresentationFrame), findsOneWidget);
    if (_captureDjedDayVisuals) {
      await expectLater(
        find.byKey(const ValueKey<String>('djed-production-day-view-capture')),
        matchesGoldenFile('/tmp/djed-flutter-day-sheet-390.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });

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
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('Djed sheet opens with the mockup thirty-pixel practice peek', (
    tester,
  ) async {
    await pumpPresentation(tester, size: const Size(390, 844));
    final frameRect = tester.getRect(
      find.byType(InstrumentEventPresentationFrame),
    );
    final practiceRect = tester.getRect(
      find.byKey(const ValueKey<String>('djed-practice-sheet')),
    );
    expect(frameRect.bottom - practiceRect.top, closeTo(30, 1));

    await tester.drag(
      find.byKey(const ValueKey<String>('djed-presentation-body')),
      const Offset(0, -440),
    );
    await tester.pumpAndSettle();
    final dockedPracticeRect = tester.getRect(
      find.byKey(const ValueKey<String>('djed-practice-sheet')),
    );
    expect(dockedPracticeRect.top, lessThanOrEqualTo(frameRect.top + 1));
    expect(tester.takeException(), isNull);

    if (_captureDjedDayVisuals) {
      await expectLater(
        find.byKey(const ValueKey<String>('djed-day-visual-capture')),
        matchesGoldenFile('/tmp/djed-day-docked.png'),
      );
    }
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
      if (!_captureDjedDayVisuals) return;
      await expectLater(
        find.byKey(const ValueKey<String>('djed-day-visual-capture')),
        matchesGoldenFile('/tmp/djed-day-${fixture.$1}.png'),
      );
    });
  }
}
