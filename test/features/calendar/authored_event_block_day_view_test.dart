import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_event_block_visual.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_event_block_visual.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
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
      expect(find.text('name the four parts that need strengthening'), findsOneWidget);
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
        payload: const <String, dynamic>{
          'kind': 'maat_reading_house_sitting',
          'flow_key': kReadingHouseFlowKey,
        },
      );

      expect(find.byType(ReadingHouseEventBlockVisual), findsOneWidget);
      expect(find.text(kReadingHouseSittings.first.title), findsOneWidget);
      expect(
        find.text('THE READING HOUSE · SITTING 01'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpDayView(
  WidgetTester tester, {
  required int flowId,
  required String flowName,
  required String flowKey,
  required String title,
  required Map<String, dynamic> payload,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DayViewGrid(
          ky: 1,
          km: 1,
          kd: 1,
          notes: <NoteData>[
            NoteData(
              clientEventId: 'authored-event-$flowId',
              title: title,
              allDay: false,
              start: const TimeOfDay(hour: 7, minute: 30),
              end: const TimeOfDay(hour: 8, minute: 30),
              flowId: flowId,
              behaviorPayload: payload,
            ),
          ],
          showGregorian: false,
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
          initialScrollOffset: 6 * 60,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
