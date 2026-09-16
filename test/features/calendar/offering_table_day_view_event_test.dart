import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_contract.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_state.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_event_block_visual.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_local_store.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
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
      expect(find.text('“put real food within reach”'), findsOneWidget);
      expect(find.textContaining('Protect my sleep.'), findsNothing);
      final block = tester.widget<OfferingTableEventBlockVisual>(
        find.byType(OfferingTableEventBlockVisual),
      );
      expect(block.prompt, offeringTableDayViewContract(day.dayNumber).prompt);
      expect(block.stage, OfferingTableBlockStage.personal);
      expect(block.resolvedVisualState, OfferingTableBlockVisualState.named);
      expect(
        tester.getSize(find.byType(OfferingTableCupVisual)),
        const Size(58, 54),
      );
      expect(block.height, 60);

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
    expect(find.text('“check one thing before it runs out”'), findsOneWidget);
    expect(find.textContaining('No need was named'), findsNothing);
    final block = tester.widget<OfferingTableEventBlockVisual>(
      find.byType(OfferingTableEventBlockVisual),
    );
    expect(block.resolvedVisualState, OfferingTableBlockVisualState.named);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Offering block preserves the authored width alone and shared lanes when overlapping',
    (tester) async {
      await _pumpDayView(tester, flowId: 73);

      var blockRect = tester.getRect(
        find.byType(OfferingTableEventBlockVisual),
      );
      var block = tester.widget<OfferingTableEventBlockVisual>(
        find.byType(OfferingTableEventBlockVisual),
      );
      expect(blockRect.left, closeTo(50, .1));
      expect(block.width, closeTo(324, .1));
      expect(blockRect.width, closeTo(328, .1));
      expect(block.height, 60);
      expect(blockRect.height, 62);

      await _pumpDayView(
        tester,
        flowId: 73,
        additionalNotes: const <NoteData>[
          NoteData(
            clientEventId: 'ordinary-overlap',
            title: 'Ordinary overlap',
            allDay: false,
            start: TimeOfDay(hour: 7, minute: 45),
            end: TimeOfDay(hour: 8, minute: 45),
            manualColor: Color(0xFF62C18C),
          ),
        ],
      );

      blockRect = tester.getRect(find.byType(OfferingTableEventBlockVisual));
      block = tester.widget<OfferingTableEventBlockVisual>(
        find.byType(OfferingTableEventBlockVisual),
      );
      expect(blockRect.left, closeTo(60, .1));
      expect(block.width, closeTo(155, .1));
      expect(blockRect.width, closeTo(159, .1));
      expect(block.height, 60);
      expect(blockRect.height, 62);
      expect(find.text('Ordinary overlap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'each Offering event edits and restores only its Day View state',
    (tester) async {
      const flowId = 75;
      const store = OfferingTableLocalStore();
      await store.saveIntention(flowId, 1, 'Protect my sleep.');
      final dayTwo = kOfferingTableDays[1];

      await _pumpDayView(tester, flowId: flowId, day: dayTwo);
      await tester.tap(find.byType(OfferingTableEventBlockVisual));
      await tester.pumpAndSettle();

      final field = find.byKey(
        const ValueKey<String>('offering-table-field-input'),
      );
      expect(tester.widget<TextField>(field).controller?.text, isEmpty);
      expect(find.text('What matters to me.'), findsNothing);
      expect(
        find.text('No need was named when this table was carried.'),
        findsNothing,
      );

      await tester.enterText(field, 'Call my mother.');
      await tester.pump(const Duration(milliseconds: 400));
      final saved = OfferingTableDayViewState.fromJson(
        await store.loadDayViewState(flowId, 2),
      );
      expect(saved.words['input'], 'Call my mother.');

      await tester.tapAt(const Offset(195, 100));
      await tester.pumpAndSettle();
      expect(CalendarEventDetailSheetCoordinator.isOpenOrOpening, isFalse);

      await _pumpDayView(tester, flowId: flowId, day: dayTwo);
      await tester.tap(find.byType(OfferingTableEventBlockVisual));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller?.text,
        'Call my mother.',
      );
      expect(await store.loadIntention(flowId, 1), 'Protect my sleep.');
      expect(await store.loadDayViewState(flowId, 3), isEmpty);
    },
  );

  testWidgets('Day 30 fields clear the keyboard in the real Day View sheet', (
    tester,
  ) async {
    await _pumpDayView(tester, flowId: 76, day: kOfferingTableDays[29]);
    await tester.tap(find.byType(OfferingTableEventBlockVisual));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('offering-table-day-30-move-shortfall'),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(
      const ValueKey<String>('offering-table-field-shortfall'),
    );
    expect(tester.widget<TextField>(field).focusNode?.hasFocus, isTrue);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
    await tester.pumpAndSettle();
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();

    expect(find.byKey(editableModalSystemInsetOwnerKey), findsOneWidget);
    expect(MediaQuery.viewInsetsOf(tester.element(field)).bottom, 0);
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(544));
    expect(tester.testTextInput.isVisible, isTrue);
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
      expect(preview.dayViewFace, isFalse);
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

  test(
    'ripple eligibility follows only the next not-yet-started occurrence',
    () {
      final now = DateTime(2026, 8, 29, 7, 0);
      final today = KemeticMath.fromGregorian(now);
      final first = _offeringEvent('first', 7 * 60 + 30);
      final second = _offeringEvent('second', 9 * 60);

      bool eligible(EventItem target, DateTime clock) =>
          offeringTableEventIsNextNotStarted(
            target: target,
            events: <EventItem>[first, second],
            ky: today.kYear,
            km: today.kMonth,
            kd: today.kDay,
            now: clock,
          );

      expect(eligible(first, now), isTrue);
      expect(eligible(second, now), isFalse);
      expect(eligible(first, DateTime(2026, 8, 29, 8)), isFalse);
      expect(eligible(second, DateTime(2026, 8, 29, 8)), isTrue);
      expect(eligible(second, DateTime(2026, 8, 29, 10)), isFalse);
      final kemeticTomorrow = KemeticMath.fromGregorian(
        now.add(const Duration(days: 1)),
      );
      expect(
        offeringTableEventIsNextNotStarted(
          target: first,
          events: <EventItem>[first],
          ky: kemeticTomorrow.kYear,
          km: kemeticTomorrow.kMonth,
          kd: kemeticTomorrow.kDay,
          now: now,
        ),
        isTrue,
        reason: 'Day 1 is next when a flow begins tomorrow.',
      );
      expect(kOfferingTableRippleCycle, const Duration(milliseconds: 5400));
      expect(
        kOfferingTableRipplePhaseSeparation,
        const Duration(milliseconds: 1800),
      );
    },
  );

  testWidgets('Day View animates only the next scheduled daily occurrence', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 29, 7);
    final today = KemeticMath.fromGregorian(now);
    final past = KemeticMath.fromGregorian(
      now.subtract(const Duration(days: 3)),
    );
    final tomorrow = KemeticMath.fromGregorian(
      now.add(const Duration(days: 1)),
    );
    final future = KemeticMath.fromGregorian(now.add(const Duration(days: 3)));

    Future<bool> render({
      required int ky,
      required int km,
      required int kd,
      required DateTime clock,
    }) async {
      await _pumpRippleDayView(tester, ky: ky, km: km, kd: kd, clock: clock);
      return tester
          .widget<OfferingTableEventBlockVisual>(
            find.byType(OfferingTableEventBlockVisual),
          )
          .animateRipple;
    }

    expect(
      await render(
        ky: today.kYear,
        km: today.kMonth,
        kd: today.kDay,
        clock: now,
      ),
      isTrue,
    );
    expect(
      await render(
        ky: today.kYear,
        km: today.kMonth,
        kd: today.kDay,
        clock: DateTime(2026, 8, 29, 8),
      ),
      isFalse,
    );
    expect(
      await render(
        ky: tomorrow.kYear,
        km: tomorrow.kMonth,
        kd: tomorrow.kDay,
        clock: DateTime(2026, 8, 29, 8),
      ),
      isTrue,
    );
    expect(
      await render(ky: past.kYear, km: past.kMonth, kd: past.kDay, clock: now),
      isFalse,
    );
    expect(
      await render(
        ky: future.kYear,
        km: future.kMonth,
        kd: future.kDay,
        clock: now,
      ),
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

  testWidgets('Day View preserves the exact authored checklist', (
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

    expect(find.text('2 steps'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('offering-table-day-03-move-place')),
      findsOneWidget,
    );
    expect(find.text('Drink water.'), findsNothing);
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
              dayViewFace: height >= 88 && height <= 94,
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
  required DateTime clock,
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
          clock: () => clock,
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
  List<NoteData> additionalNotes = const <NoteData>[],
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
            ...additionalNotes,
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
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

EventItem _offeringEvent(String id, int startMinute) => EventItem(
  clientEventId: id,
  title: 'The Offering Table · Day 01 · The Small Supply',
  startMin: startMinute,
  endMin: startMinute + 3,
  flowId: 80,
  color: const Color(0xFFC99A3D),
  allDay: false,
  behaviorPayload: const <String, dynamic>{
    'kind': 'maat_offering_table_day',
    'flow_key': kOfferingTableFlowKey,
    'day': 1,
  },
);
