import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_event_block_visual.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_kar/the_kar.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_event_block_visual.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import '../../support/maat_flow_visual_goldens.dart';

const _visualCaptureKey = ValueKey<String>(
  'authored-event-block-day-view-capture',
);
const _captureKarVisuals = bool.fromEnvironment('CAPTURE_KAR_VISUALS');
final _goldenRoot = maatFlowVisualGoldenRoot;

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

  testWidgets(
    'Day View paints the Djed ember card from flow identity, not sitting payload',
    (tester) async {
      await _pumpDayView(
        tester,
        flowId: 81,
        flowName: kTheDjedTitle,
        flowKey: kTheDjedFlowKey,
        title: 'Set your footing',
        payload: const <String, dynamic>{
          'kind': 'maat_djed_v2_event',
          'flow_key': kTheDjedFlowKey,
        },
      );

      expect(find.byType(DjedEventBlockVisual), findsOneWidget);
      expect(find.text(kDjedSittingFixtures.first.title), findsOneWidget);
      expect(
        find.text('name the four parts that need strengthening'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Day View paints the Reading House compact card from flow identity, not sitting payload',
    (tester) async {
      await _pumpDayView(
        tester,
        flowId: 82,
        flowName: kReadingHouseTitle,
        flowKey: kReadingHouseFlowKey,
        title: 'Open the Text',
        start: const TimeOfDay(hour: 19, minute: 0),
        firstVisibleMinute: 14 * 60,
        payload: const <String, dynamic>{
          'kind': 'maat_reading_house_sitting',
          'flow_key': kReadingHouseFlowKey,
        },
      );

      expect(find.byType(ReadingHouseEventBlockVisual), findsOneWidget);
      expect(find.text(kReadingHouseSittings.first.title), findsOneWidget);
      expect(find.text('THE READING HOUSE · SITTING 01'), findsOneWidget);
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('$_goldenRoot/reading-house-day-view-390x844.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Day View opens Kꜣr behavior in the existing shared sheet', (
    tester,
  ) async {
    final repository = MemoryKarRepository(
      initial: <KarNetjer, KarShrine>{
        KarNetjer.djehuty:
            KarShrine(
              id: 'kar-user-djehuty',
              netjer: KarNetjer.djehuty,
              revision: 0,
              cycles: const <KarCycle>[],
            ).beginCycle(
              cycleId: 'cycle-1',
              anchorDate: DateTime(2026, 9, 10),
              flowId: 83,
            ),
      },
    );
    await _pumpDayView(
      tester,
      flowId: 83,
      flowName: kKarTitle,
      flowKey: kKarFlowKey,
      title: KarNetjer.djehuty.labels.first,
      start: const TimeOfDay(hour: 9, minute: 0),
      payload: const <String, dynamic>{
        'kind': 'maat_kar_scene',
        'flow_key': kKarFlowKey,
        'kar_cycle_id': 'cycle-1',
        'kar_cycle_sequence': 1,
        'kar_netjer': 'djehuty',
        'kar_stage_index': 0,
        'kar_day': 1,
        'kar_place': 'Threshold',
      },
      karRepository: repository,
    );

    final eventBlock = find.byType(KarEventBlockVisual);
    expect(eventBlock, findsOneWidget);
    expect(find.text('01 · Threshold'), findsOneWidget);
    expect(find.text('THE KꜣR · DJEHUTY · CYCLE 01'), findsOneWidget);
    expect(find.text('SITTING 1 OF 5'), findsOneWidget);
    expect(tester.getSize(eventBlock).height, 60);
    expect(tester.getSize(eventBlock).width, closeTo(251.2, .1));
    if (_captureKarVisuals) {
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/kar-day-block-flutter.png'),
      );
    }
    await tester.tap(eventBlock);
    await tester.pumpAndSettle();

    expect(find.byType(KarDayBehaviorSurface), findsOneWidget);
    expect(find.byKey(dayViewBottomSheetBackplateKey), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('kar-resizable-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('kar-day-presentation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('kar-practice-sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('kar-day-shrine-stage')),
      findsOneWidget,
    );
    final karSheetRect = tester.getRect(
      find.byKey(const ValueKey<String>('kar-resizable-sheet')),
    );
    expect(karSheetRect.height, closeTo((844 - 12) * .71, 1.5));
    expect(karSheetRect.bottom, closeTo(844, .01));
    final collapsedPracticeRect = tester.getRect(
      find.byKey(const ValueKey<String>('kar-practice-sheet')),
    );
    expect(collapsedPracticeRect.top, closeTo(528.25, 2));
    expect(find.byType(ModalBottomSheetRoute), findsNothing);
    expect(
      find.descendant(
        of: find.byType(KarDayBehaviorSurface),
        matching: find.text('Wisdom'),
      ),
      findsOneWidget,
    );
    expect(find.text('Draw'), findsOneWidget);
    expect(find.text('Describe'), findsOneWidget);
    expect(find.byTooltip('Event options'), findsNothing);
    expect(find.text('Observed'), findsNothing);
    expect(find.text('Partly'), findsNothing);
    expect(find.text('Skipped'), findsNothing);
    if (_captureKarVisuals) {
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/kar-day-flutter.png'),
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('kar-day-sheet-scroll')),
        const Offset(0, -430),
      );
      await tester.pumpAndSettle();
      final raisedPracticeRect = tester.getRect(
        find.byKey(const ValueKey<String>('kar-practice-sheet')),
      );
      expect(raisedPracticeRect.top, closeTo(267, 2));
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/kar-day-fresh-raised-flutter.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Day View return state keeps the authored layered presentation', (
    tester,
  ) async {
    var shrine = _activeKarShrine(flowId: 84);
    shrine = _placeKar(
      shrine,
      stageIndex: 0,
      content: 'A blue robe, circular room, and silver pipe.',
    );
    await _pumpDayView(
      tester,
      flowId: 84,
      flowName: kKarTitle,
      flowKey: kKarFlowKey,
      title: KarNetjer.djehuty.labels.first,
      start: const TimeOfDay(hour: 9, minute: 0),
      payload: const <String, dynamic>{
        'kind': 'maat_kar_scene',
        'flow_key': kKarFlowKey,
        'kar_cycle_id': 'cycle-1',
        'kar_cycle_sequence': 1,
        'kar_netjer': 'djehuty',
        'kar_stage_index': 0,
        'kar_day': 1,
        'kar_place': 'Threshold',
      },
      karRepository: MemoryKarRepository(
        initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: shrine},
      ),
    );

    await tester.tap(find.byType(KarEventBlockVisual));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(KarDayBehaviorSurface),
        matching: find.text('Is it here?'),
      ),
      findsOneWidget,
    );
    expect(find.text('It’s here'), findsOneWidget);
    expect(find.text('I have a piece'), findsOneWidget);
    expect(find.text('Not yet'), findsOneWidget);
    if (_captureKarVisuals) {
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/kar-day-return-flutter.png'),
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('kar-day-sheet-scroll')),
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/kar-day-return-raised-flutter.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Day View closing walk stays in the authored shared sheet', (
    tester,
  ) async {
    var shrine = _activeKarShrine(flowId: 85);
    for (var stageIndex = 0; stageIndex < 5; stageIndex++) {
      shrine = _placeKar(
        shrine,
        stageIndex: stageIndex,
        content: 'Placed scene ${stageIndex + 1}.',
      );
    }
    await _pumpDayView(
      tester,
      flowId: 85,
      flowName: kKarTitle,
      flowKey: kKarFlowKey,
      title: 'Walk the kꜣr',
      start: const TimeOfDay(hour: 9, minute: 0),
      payload: const <String, dynamic>{
        'kind': 'maat_kar_walk',
        'flow_key': kKarFlowKey,
        'kar_cycle_id': 'cycle-1',
        'kar_cycle_sequence': 1,
        'kar_netjer': 'djehuty',
        'kar_stage_index': 5,
        'kar_day': 30,
        'kar_place': 'Inner chamber',
      },
      karRepository: MemoryKarRepository(
        initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: shrine},
      ),
    );

    await tester.tap(find.byType(KarEventBlockVisual));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(KarDayBehaviorSurface),
        matching: find.text('Walk the kꜣr'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('kar-begin-walk')),
      findsOneWidget,
    );
    if (_captureKarVisuals) {
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/kar-day-walk-flutter.png'),
      );
    }

    await tester.tap(find.byKey(const ValueKey<String>('kar-begin-walk')));
    await tester.pumpAndSettle();
    expect(find.text('Threshold'), findsOneWidget);
    expect(
      find.text('Find this place before asking for what was saved.'),
      findsOneWidget,
    );
    if (_captureKarVisuals) {
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/kar-day-walk-active-flutter.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kꜣr description stays above one system-keyboard inset', (
    tester,
  ) async {
    await _pumpDayView(
      tester,
      flowId: 86,
      flowName: kKarTitle,
      flowKey: kKarFlowKey,
      title: KarNetjer.djehuty.labels.first,
      start: const TimeOfDay(hour: 9, minute: 0),
      payload: const <String, dynamic>{
        'kind': 'maat_kar_scene',
        'flow_key': kKarFlowKey,
        'kar_cycle_id': 'cycle-1',
        'kar_cycle_sequence': 1,
        'kar_netjer': 'djehuty',
        'kar_stage_index': 0,
        'kar_day': 1,
        'kar_place': 'Threshold',
      },
      karRepository: MemoryKarRepository(
        initial: <KarNetjer, KarShrine>{
          KarNetjer.djehuty: _activeKarShrine(flowId: 86),
        },
      ),
    );
    await tester.tap(find.byType(KarEventBlockVisual));
    await tester.pumpAndSettle();
    final scroll = find.byKey(const ValueKey<String>('kar-day-sheet-scroll'));
    await tester.drag(scroll, const Offset(0, -430));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Describe'));
    await tester.pumpAndSettle();
    final captureWindow = find.byKey(
      const ValueKey<String>('kar-capture-window'),
    );
    final unobscuredCaptureRect = tester.getRect(captureWindow);
    expect(unobscuredCaptureRect.size, const Size(354, 610));
    expect(unobscuredCaptureRect.center, const Offset(195, 422));
    final field = find.byKey(const ValueKey<String>('kar-describe-field'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
    await tester.pumpAndSettle();

    const keyboardTop = 844.0 - 300.0;
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(keyboardTop));
    expect(find.byKey(editableModalSystemInsetOwnerKey), findsNothing);
    expect(captureWindow, findsOneWidget);
    expect(
      tester.getCenter(captureWindow).dx,
      closeTo(tester.view.physicalSize.width / 2, .01),
    );
    expect(
      tester.getRect(captureWindow).bottom,
      lessThanOrEqualTo(keyboardTop),
    );
    expect(
      tester
          .widgetList<KeyboardAwareEditableSurface>(
            find.byType(KeyboardAwareEditableSurface),
          )
          .where((surface) => surface.manageSystemKeyboardInset),
      hasLength(1),
    );
    expect(
      find.ancestor(
        of: captureWindow,
        matching: find.byType(KarDayBehaviorSurface),
      ),
      findsNothing,
    );
    if (_captureKarVisuals) {
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/kar-day-keyboard-flutter.png'),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kꜣr event progress comes from the cycle, not sitting number', (
    tester,
  ) async {
    var shrine =
        KarShrine(
          id: 'kar-user-djehuty',
          netjer: KarNetjer.djehuty,
          revision: 0,
          cycles: const <KarCycle>[],
        ).beginCycle(
          cycleId: 'cycle-1',
          anchorDate: DateTime(2026, 9, 10),
          flowId: 83,
        );
    shrine = shrine
        .saveDraft(
          cycleId: 'cycle-1',
          stageIndex: 0,
          draft: KarDraft(
            kind: 'description',
            content: 'Only the threshold is placed.',
            savedAt: DateTime.utc(2026, 9, 10),
          ),
        )
        .placeDraft(
          cycleId: 'cycle-1',
          stageIndex: 0,
          versionId: 'threshold-entry',
          now: DateTime.utc(2026, 9, 10, 12),
        );
    final repository = MemoryKarRepository(
      initial: <KarNetjer, KarShrine>{KarNetjer.djehuty: shrine},
    );

    await _pumpDayView(
      tester,
      flowId: 83,
      flowName: kKarTitle,
      flowKey: kKarFlowKey,
      title: KarNetjer.djehuty.labels[3],
      start: const TimeOfDay(hour: 9, minute: 0),
      payload: const <String, dynamic>{
        'kind': 'maat_kar_scene',
        'flow_key': kKarFlowKey,
        'kar_cycle_id': 'cycle-1',
        'kar_cycle_sequence': 1,
        'kar_netjer': 'djehuty',
        'kar_stage_index': 3,
        'kar_day': 15,
        'kar_place': 'Lintel',
      },
      karRepository: repository,
    );
    await tester.pumpAndSettle();

    final visual = tester.widget<KarEventBlockVisual>(
      find.byType(KarEventBlockVisual),
    );
    expect(visual.placedCount, 1);
    expect(visual.placedStages, <int>{0});
    expect(visual.returning, isFalse);
    expect(find.text('04 · Lintel'), findsOneWidget);
  });
}

Future<void> _pumpDayView(
  WidgetTester tester, {
  required int flowId,
  required String flowName,
  required String flowKey,
  required String title,
  required Map<String, dynamic> payload,
  TimeOfDay start = const TimeOfDay(hour: 7, minute: 30),
  int firstVisibleMinute = 6 * 60,
  KarRepository? karRepository,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _visualCaptureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 47),
          ),
          child: DayViewPage(
            initialKy: 2,
            initialKm: 6,
            initialKd: 18,
            showGregorian: false,
            getMonthName: (_) => 'Rekh-Wer (Rḫ-wr)',
            notesForDay: (ky, km, kd) => <NoteData>[
              if (ky == 2 && km == 6 && kd == 18)
                NoteData(
                  clientEventId: 'authored-event-$flowId',
                  title: title,
                  allDay: false,
                  start: start,
                  end: TimeOfDay(hour: start.hour + 1, minute: start.minute),
                  flowId: flowId,
                  behaviorPayload: payload,
                ),
            ],
            flowIndex: <int, FlowData>{
              flowId: FlowData(
                id: flowId,
                name: flowName,
                color: const Color(0xFFC99A3D),
                active: true,
                notes: 'mode=gregorian;maat=$flowKey',
              ),
            },
            activeLedgerFlowIds: <int>{flowId},
            initialFirstVisibleMinute: firstVisibleMinute,
            karRepository: karRepository,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

KarShrine _activeKarShrine({required int flowId}) =>
    KarShrine(
      id: 'kar-user-djehuty',
      netjer: KarNetjer.djehuty,
      revision: 0,
      cycles: const <KarCycle>[],
    ).beginCycle(
      cycleId: 'cycle-1',
      anchorDate: DateTime(2026, 9, 10),
      flowId: flowId,
    );

KarShrine _placeKar(
  KarShrine shrine, {
  required int stageIndex,
  required String content,
}) {
  final cycle = shrine.activeCycle!;
  return shrine
      .saveDraft(
        cycleId: cycle.id,
        stageIndex: stageIndex,
        draft: KarDraft(
          kind: 'description',
          content: content,
          savedAt: DateTime.utc(2026, 9, 10),
        ),
      )
      .placeDraft(
        cycleId: cycle.id,
        stageIndex: stageIndex,
        versionId: 'entry-${cycle.id}-$stageIndex',
        now: DateTime.utc(2026, 9, 10, 12),
      );
}
