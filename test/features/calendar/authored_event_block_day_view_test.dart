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
    await tester.tap(eventBlock);
    await tester.pumpAndSettle();

    expect(find.byType(KarDayBehaviorSurface), findsOneWidget);
    expect(find.byKey(dayViewBottomSheetBackplateKey), findsOneWidget);
    expect(find.byType(ModalBottomSheetRoute), findsNothing);
    expect(
      find.descendant(
        of: find.byType(KarDayBehaviorSurface),
        matching: find.text('Wisdom, dressed'),
      ),
      findsOneWidget,
    );
    expect(find.text('Draw'), findsOneWidget);
    expect(find.text('Describe'), findsOneWidget);
    if (_captureKarVisuals) {
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/kar-day-flutter.png'),
      );
    }
    expect(tester.takeException(), isNull);
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
