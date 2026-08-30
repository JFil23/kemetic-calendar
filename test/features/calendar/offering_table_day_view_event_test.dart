import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_event_block_visual.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_local_store.dart';
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
    'Offering block uses authored prompt while detail retains private need',
    (tester) async {
      final day = kOfferingTableDays[2];
      await _pumpDayView(
        tester,
        flowId: 71,
        day: day,
        initialNeed: 'Protect my sleep.',
      );

      expect(find.text('THE OFFERING TABLE · DAY 03'), findsOneWidget);
      expect(find.text(day.title), findsWidgets);
      expect(find.text('“eat before the day starts”'), findsOneWidget);
      expect(find.textContaining('Protect my sleep.'), findsNothing);
      final block = tester.widget<OfferingTableEventBlockVisual>(
        find.byType(OfferingTableEventBlockVisual),
      );
      expect(block.prompt, day.eventBlockPrompt);
      expect(block.stage, OfferingTableBlockStage.personal);
      expect(block.resolvedVisualState, OfferingTableBlockVisualState.named);
      expect(
        tester.getSize(find.byType(OfferingTableCupVisual)),
        const Size(48, 50),
      );

      await tester.tap(find.byType(OfferingTableEventBlockVisual));
      await tester.pumpAndSettle();

      expect(find.text('Protect my sleep.'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Offering block remains authored when no private need exists', (
    tester,
  ) async {
    await _pumpDayView(tester, flowId: 72);

    expect(find.text(kOfferingTableDays.first.title), findsWidgets);
    expect(find.text('“name what needs to be fed”'), findsOneWidget);
    expect(find.textContaining('No need was named'), findsNothing);
    final block = tester.widget<OfferingTableEventBlockVisual>(
      find.byType(OfferingTableEventBlockVisual),
    );
    expect(block.resolvedVisualState, OfferingTableBlockVisualState.named);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'static block states and responsive cup geometry match the mock',
    (tester) async {
      expect(
        offeringTableBlockStageForDay(8),
        OfferingTableBlockStage.personal,
      );
      expect(
        offeringTableBlockStageForDay(14),
        OfferingTableBlockStage.household,
      );
      expect(
        offeringTableBlockStageForDay(23),
        OfferingTableBlockStage.flowing,
      );

      await _pumpStaticBlock(
        tester,
        width: 164,
        height: 56,
        dayNumber: 23,
        title: 'The River Unblocked',
        prompt: 'move one delayed thing downstream',
        isPreview: true,
      );

      expect(find.text('THE OFFERING TABLE · DAY 23'), findsOneWidget);
      expect(find.text('The River Unblocked'), findsOneWidget);
      expect(find.text('“move one delayed thing downstream”'), findsOneWidget);
      final promptText = tester.widget<Text>(
        find.byKey(const ValueKey<String>('offering-table-block-teaser')),
      );
      expect(promptText.maxLines, 1);
      expect(promptText.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSize(find.byType(OfferingTableCupVisual)),
        const Size(48, 50),
      );
      final preview = tester.widget<OfferingTableEventBlockVisual>(
        find.byType(OfferingTableEventBlockVisual),
      );
      expect(preview.isPreview, isTrue);
      expect(preview.dashedBorder, isTrue);
      expect(preview.stage, OfferingTableBlockStage.flowing);
      expect(tester.takeException(), isNull);

      await _pumpStaticBlock(
        tester,
        width: 300,
        height: 74,
        dayNumber: 14,
        title: 'The Waiting Bowl',
        prompt: 'refill what has been waiting',
        visualState: OfferingTableBlockVisualState.received,
      );

      expect(
        tester.getSize(find.byType(OfferingTableCupVisual)),
        const Size(58, 60),
      );
      final received = tester.widget<OfferingTableEventBlockVisual>(
        find.byType(OfferingTableEventBlockVisual),
      );
      expect(received.stage, OfferingTableBlockStage.household);
      expect(
        received.resolvedVisualState,
        OfferingTableBlockVisualState.received,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('live ripple eligibility uses the existing event schedule', () {
    final now = DateTime(2026, 8, 29, 7, 31);
    final today = KemeticMath.fromGregorian(now);
    final prior = KemeticMath.fromGregorian(
      now.subtract(const Duration(days: 1)),
    );
    const live = EventItem(
      title: 'Day 2: The Cup Before the Noise',
      startMin: 450,
      endMin: 455,
      color: Color(0xFFC99A3D),
      allDay: false,
    );
    const past = EventItem(
      title: 'Day 1: The First Water',
      startMin: 420,
      endMin: 425,
      color: Color(0xFFC99A3D),
      allDay: false,
    );
    const future = EventItem(
      title: 'Day 3: Bread Enough',
      startMin: 480,
      endMin: 485,
      color: Color(0xFFC99A3D),
      allDay: false,
    );

    bool isLive(EventItem event, {int? ky, int? km, int? kd}) =>
        offeringTableEventIsLive(
          ky: ky ?? today.kYear,
          km: km ?? today.kMonth,
          kd: kd ?? today.kDay,
          event: event,
          now: now,
        );

    expect(isLive(live), isTrue);
    expect(isLive(past), isFalse);
    expect(isLive(future), isFalse);
    expect(
      isLive(live, ky: prior.kYear, km: prior.kMonth, kd: prior.kDay),
      isFalse,
    );
    expect(kOfferingTableRippleCycle, const Duration(milliseconds: 5400));
    expect(
      kOfferingTableRipplePhaseSeparation,
      const Duration(milliseconds: 1800),
    );
  });

  testWidgets(
    'only the live Day View block receives the shared ripple animation',
    (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: kOfferingTableRippleCycle,
      );
      addTearDown(controller.dispose);
      final now = DateTime(2026, 8, 29, 7, 31);
      final today = KemeticMath.fromGregorian(now);

      await _pumpRippleDayView(
        tester,
        now: now,
        controller: controller,
        ky: today.kYear,
        km: today.kMonth,
        kd: today.kDay,
      );

      final byDay = <int, OfferingTableEventBlockVisual>{
        for (final block in tester.widgetList<OfferingTableEventBlockVisual>(
          find.byType(OfferingTableEventBlockVisual),
        ))
          block.dayNumber: block,
      };
      expect(byDay.keys, containsAll(<int>[1, 2, 3]));
      expect(byDay[1]!.rippleAnimation, isNull);
      expect(byDay[2]!.rippleAnimation, same(controller));
      expect(byDay[3]!.rippleAnimation, isNull);
    },
  );

  testWidgets('empty, received, and reduced-motion cups remain still', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: kOfferingTableRippleCycle,
    );
    addTearDown(controller.dispose);

    Future<OfferingTableRipplePainter> pumpState(
      OfferingTableBlockVisualState state, {
      Animation<double>? animation,
    }) async {
      await _pumpStaticBlock(
        tester,
        width: 220,
        height: 58,
        dayNumber: 3,
        title: 'Bread Enough',
        prompt: 'eat before the day starts',
        visualState: state,
        rippleAnimation: animation,
      );
      return tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<OfferingTableRipplePainter>()
          .single;
    }

    final animated = await pumpState(
      OfferingTableBlockVisualState.named,
      animation: controller,
    );
    expect(animated.visible, isTrue);
    expect(animated.animation, same(controller));

    final empty = await pumpState(
      OfferingTableBlockVisualState.empty,
      animation: controller,
    );
    expect(empty.visible, isFalse);
    expect(empty.animation, isNull);

    final received = await pumpState(
      OfferingTableBlockVisualState.received,
      animation: controller,
    );
    expect(received.visible, isFalse);
    expect(received.animation, isNull);

    final reducedMotion = await pumpState(OfferingTableBlockVisualState.named);
    expect(reducedMotion.visible, isTrue);
    expect(reducedMotion.animation, isNull);
  });

  testWidgets('Day View renders the canonical closing water checkbox', (
    tester,
  ) async {
    final day = kOfferingTableDays[2];
    await _pumpDayView(
      tester,
      flowId: 74,
      day: day,
      initialNeed: 'Protect my sleep.',
    );

    await tester.tap(find.byType(OfferingTableEventBlockVisual));
    await tester.pumpAndSettle();

    expect(find.text('4 steps'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('offering-table-day-03-step-4')),
      findsOneWidget,
    );
    expect(find.text('Drink water.'), findsOneWidget);
  });

  testWidgets('Day View Reflect writes through the shared Journal authority', (
    tester,
  ) async {
    final blocks = <MaatJournalResponseBlock>[];
    await _pumpDayView(
      tester,
      flowId: 73,
      initialNeed: 'Protect my sleep.',
      onWriteJournalResponse: (block) async => blocks.add(block),
    );

    await tester.tap(find.byType(OfferingTableEventBlockVisual));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey<String>('offering-table-presentation-body')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reflect'));
    await tester.pumpAndSettle();

    final field = find.byKey(
      const ValueKey<String>('offering-table-reflection-field'),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, 'I made room for rest before work.');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(blocks, hasLength(1));
    expect(blocks.single.text, 'I made room for rest before work.');
    expect(
      blocks.single.sourceId,
      'maat_response:the-offering-table:cid:offering-table-event-73:offering-table-reflection',
    );
  });
}

Future<void> _pumpStaticBlock(
  WidgetTester tester, {
  required double width,
  required double height,
  required int dayNumber,
  required String title,
  required String prompt,
  bool isPreview = false,
  OfferingTableBlockVisualState? visualState,
  Animation<double>? rippleAnimation,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Align(
          alignment: Alignment.topLeft,
          child: OfferingTableEventBlockVisual(
            dayNumber: dayNumber,
            title: title,
            prompt: prompt,
            width: width,
            height: height,
            isPreview: isPreview,
            dashedBorder: isPreview,
            visualState: visualState,
            rippleAnimation: rippleAnimation,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpRippleDayView(
  WidgetTester tester, {
  required DateTime now,
  required Animation<double> controller,
  required int ky,
  required int km,
  required int kd,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  NoteData noteFor({
    required int dayIndex,
    required int hour,
    required int minute,
    required int endMinute,
  }) {
    final day = kOfferingTableDays[dayIndex];
    return NoteData(
      clientEventId: 'offering-ripple-${day.dayNumber}',
      title: offeringTableEventTitle(day),
      allDay: false,
      start: TimeOfDay(hour: hour, minute: minute),
      end: TimeOfDay(hour: hour, minute: endMinute),
      flowId: 80,
      behaviorPayload: <String, dynamic>{
        'kind': 'maat_offering_table_day',
        'flow_key': kOfferingTableFlowKey,
        'day': day.dayNumber,
      },
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DayViewGrid(
          ky: ky,
          km: km,
          kd: kd,
          notes: <NoteData>[
            noteFor(dayIndex: 0, hour: 7, minute: 0, endMinute: 5),
            noteFor(dayIndex: 1, hour: 7, minute: 30, endMinute: 35),
            noteFor(dayIndex: 2, hour: 8, minute: 0, endMinute: 5),
          ],
          showGregorian: false,
          flowIndex: <int, FlowData>{
            80: FlowData(
              id: 80,
              name: kOfferingTableTitle,
              color: const Color(0xFFC99A3D),
              active: true,
              notes: 'mode=gregorian;maat=$kOfferingTableFlowKey',
            ),
          },
          activeLedgerFlowIds: const <int>{80},
          initialScrollOffset: 6 * 60,
          offeringTableRippleAnimation: controller,
          nowProvider: () => now,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpDayView(
  WidgetTester tester, {
  required int flowId,
  OfferingTableDay? day,
  String? initialNeed,
  MaatJournalResponseBlockWriter? onWriteJournalResponse,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  if (initialNeed != null) {
    await const OfferingTableLocalStore().saveNeed(flowId, initialNeed);
  }
  final resolvedDay = day ?? kOfferingTableDays.first;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DayViewGrid(
          ky: 1,
          km: 1,
          kd: 1,
          notes: <NoteData>[
            NoteData(
              clientEventId: 'offering-table-event-$flowId',
              title: offeringTableEventTitle(resolvedDay),
              allDay: false,
              start: const TimeOfDay(hour: 7, minute: 30),
              end: const TimeOfDay(hour: 8, minute: 30),
              flowId: flowId,
              behaviorPayload: <String, dynamic>{
                'kind': 'maat_offering_table_day',
                'flow_key': kOfferingTableFlowKey,
                'day': resolvedDay.dayNumber,
              },
            ),
          ],
          showGregorian: false,
          flowIndex: <int, FlowData>{
            flowId: FlowData(
              id: flowId,
              name: kOfferingTableTitle,
              color: const Color(0xFFC99A3D),
              active: true,
              notes: 'mode=gregorian;maat=$kOfferingTableFlowKey',
            ),
          },
          activeLedgerFlowIds: <int>{flowId},
          initialScrollOffset: 6 * 60,
          onWriteJournalResponse: onWriteJournalResponse,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
