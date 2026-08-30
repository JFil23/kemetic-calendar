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
        initialIntention: 'Protect my sleep.',
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

  testWidgets('each Offering event edits and restores only its own intention', (
    tester,
  ) async {
    const flowId = 75;
    const store = OfferingTableLocalStore();
    await store.saveIntention(flowId, 1, 'Protect my sleep.');
    final dayTwo = kOfferingTableDays[1];

    await _pumpDayView(tester, flowId: flowId, day: dayTwo);
    await tester.tap(find.byType(OfferingTableEventBlockVisual));
    await tester.pumpAndSettle();

    final field = find.byKey(
      const ValueKey<String>('offering-table-intention-field'),
    );
    expect(tester.widget<TextField>(field).controller?.text, isEmpty);
    expect(find.text('What matters to me.'), findsNothing);
    expect(
      find.text('No need was named when this table was carried.'),
      findsNothing,
    );

    await tester.enterText(field, 'Call my mother.');
    await tester.pump(const Duration(milliseconds: 400));
    expect(await store.loadIntention(flowId, 2), 'Call my mother.');

    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();
    expect(CalendarEventDetailSheetCoordinator.isOpenOrOpening, isFalse);

    await _pumpDayView(tester, flowId: flowId, day: dayTwo);
    await tester.tap(find.byType(OfferingTableEventBlockVisual));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller?.text, 'Call my mother.');
    expect(await store.loadIntention(flowId, 1), 'Protect my sleep.');
    expect(await store.loadIntention(flowId, 3), isEmpty);
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

  test('ripple eligibility is today only, independent of event time', () {
    final beforeEvent = DateTime(2026, 8, 29, 6, 0);
    final afterEvent = DateTime(2026, 8, 29, 22, 0);
    final today = KemeticMath.fromGregorian(beforeEvent);
    final yesterday = KemeticMath.fromGregorian(
      beforeEvent.subtract(const Duration(days: 1)),
    );
    final tomorrow = KemeticMath.fromGregorian(
      beforeEvent.add(const Duration(days: 1)),
    );

    bool isToday({
      required int ky,
      required int km,
      required int kd,
      required DateTime now,
    }) => offeringTableEventIsToday(ky: ky, km: km, kd: kd, now: now);

    expect(
      isToday(
        ky: today.kYear,
        km: today.kMonth,
        kd: today.kDay,
        now: beforeEvent,
      ),
      isTrue,
    );
    expect(
      isToday(
        ky: today.kYear,
        km: today.kMonth,
        kd: today.kDay,
        now: afterEvent,
      ),
      isTrue,
    );
    expect(
      isToday(
        ky: yesterday.kYear,
        km: yesterday.kMonth,
        kd: yesterday.kDay,
        now: beforeEvent,
      ),
      isFalse,
    );
    expect(
      isToday(
        ky: tomorrow.kYear,
        km: tomorrow.kMonth,
        kd: tomorrow.kDay,
        now: beforeEvent,
      ),
      isFalse,
    );
    expect(kOfferingTableRippleCycle, const Duration(milliseconds: 5400));
    expect(
      kOfferingTableRipplePhaseSeparation,
      const Duration(milliseconds: 1800),
    );
  });

  testWidgets('Day View marks today true and past or future false', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = KemeticMath.fromGregorian(now);
    final past = KemeticMath.fromGregorian(
      now.subtract(const Duration(days: 3)),
    );
    final future = KemeticMath.fromGregorian(now.add(const Duration(days: 3)));

    Future<bool> render({
      required int ky,
      required int km,
      required int kd,
    }) async {
      await _pumpRippleDayView(tester, ky: ky, km: km, kd: kd);
      return tester
          .widget<OfferingTableEventBlockVisual>(
            find.byType(OfferingTableEventBlockVisual),
          )
          .animateRipple;
    }

    expect(
      await render(ky: today.kYear, km: today.kMonth, kd: today.kDay),
      isTrue,
    );
    expect(
      await render(ky: past.kYear, km: past.kMonth, kd: past.kDay),
      isFalse,
    );
    expect(
      await render(ky: future.kYear, km: future.kMonth, kd: future.kDay),
      isFalse,
    );
  });

  testWidgets('the cup owns its loop and reduced motion keeps it still', (
    tester,
  ) async {
    Future<OfferingTableRipplePainter> pumpState(
      OfferingTableBlockVisualState state, {
      bool animateRipple = true,
      MediaQueryData mediaQueryData = const MediaQueryData(),
    }) async {
      await _pumpStaticBlock(
        tester,
        width: 220,
        height: 58,
        dayNumber: 3,
        title: 'Bread Enough',
        prompt: 'eat before the day starts',
        visualState: state,
        animateRipple: animateRipple,
        mediaQueryData: mediaQueryData,
      );
      return tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<OfferingTableRipplePainter>()
          .single;
    }

    final animated = await pumpState(OfferingTableBlockVisualState.named);
    expect(animated.visible, isTrue);
    expect(animated.animation, isA<AnimationController>());
    final controller = animated.animation!;
    final initialValue = controller.value;
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.value, isNot(initialValue));

    final empty = await pumpState(OfferingTableBlockVisualState.empty);
    expect(empty.visible, isFalse);
    expect(empty.animation, isNull);

    final received = await pumpState(OfferingTableBlockVisualState.received);
    expect(received.visible, isFalse);
    expect(received.animation, isNull);

    final reducedMotion = await pumpState(
      OfferingTableBlockVisualState.named,
      mediaQueryData: const MediaQueryData(disableAnimations: true),
    );
    expect(reducedMotion.visible, isTrue);
    expect(reducedMotion.animation, isNull);

    final pastOrFuture = await pumpState(
      OfferingTableBlockVisualState.named,
      animateRipple: false,
    );
    expect(pastOrFuture.visible, isTrue);
    expect(pastOrFuture.animation, isNull);
  });

  test('ripple frames match the approved pulse envelope', () {
    final start = offeringTableRippleFrameForPhase(0);
    final peak = offeringTableRippleFrameForPhase(0.18);
    final middle = offeringTableRippleFrameForPhase(0.5);
    final end = offeringTableRippleFrameForPhase(1);

    expect(start.scale, closeTo(0.3, 0.0001));
    expect(start.opacity, closeTo(0, 0.0001));
    expect(peak.opacity, closeTo(0.6, 0.0001));
    expect(middle.scale, greaterThan(peak.scale));
    expect(middle.opacity, lessThan(peak.opacity));
    expect(end.scale, closeTo(1, 0.0001));
    expect(end.opacity, closeTo(0, 0.0001));
  });

  testWidgets('Day View renders the canonical closing water checkbox', (
    tester,
  ) async {
    final day = kOfferingTableDays[2];
    await _pumpDayView(
      tester,
      flowId: 74,
      day: day,
      initialIntention: 'Protect my sleep.',
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
      initialIntention: 'Protect my sleep.',
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
  bool animateRipple = false,
  MediaQueryData mediaQueryData = const MediaQueryData(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: mediaQueryData,
        child: Scaffold(
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
              animateRipple: animateRipple,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpRippleDayView(
  WidgetTester tester, {
  required int ky,
  required int km,
  required int kd,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final day = kOfferingTableDays.first;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DayViewGrid(
          ky: ky,
          km: km,
          kd: kd,
          notes: <NoteData>[
            NoteData(
              clientEventId: 'offering-ripple-${day.dayNumber}',
              title: offeringTableEventTitle(day),
              allDay: false,
              start: const TimeOfDay(hour: 7, minute: 30),
              end: const TimeOfDay(hour: 7, minute: 33),
              flowId: 80,
              behaviorPayload: <String, dynamic>{
                'kind': 'maat_offering_table_day',
                'flow_key': kOfferingTableFlowKey,
                'day': day.dayNumber,
              },
            ),
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
  String? initialIntention,
  MaatJournalResponseBlockWriter? onWriteJournalResponse,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final resolvedDay = day ?? kOfferingTableDays.first;
  if (initialIntention != null) {
    await const OfferingTableLocalStore().saveIntention(
      flowId,
      resolvedDay.dayNumber,
      initialIntention,
    );
  }
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
