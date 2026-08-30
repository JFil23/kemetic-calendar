import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable, listEquals;
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

  test('live ripple eligibility covers today before and after event time', () {
    final beforeEvent = DateTime(2026, 8, 29, 6, 0);
    final afterEvent = DateTime(2026, 8, 29, 22, 0);
    final today = KemeticMath.fromGregorian(beforeEvent);
    final yesterday = KemeticMath.fromGregorian(
      beforeEvent.subtract(const Duration(days: 1)),
    );
    final tomorrow = KemeticMath.fromGregorian(
      beforeEvent.add(const Duration(days: 1)),
    );

    bool isLive({
      required int ky,
      required int km,
      required int kd,
      required DateTime now,
    }) => offeringTableEventIsLive(ky: ky, km: km, kd: kd, now: now);

    expect(
      isLive(
        ky: today.kYear,
        km: today.kMonth,
        kd: today.kDay,
        now: beforeEvent,
      ),
      isTrue,
    );
    expect(
      isLive(
        ky: today.kYear,
        km: today.kMonth,
        kd: today.kDay,
        now: afterEvent,
      ),
      isTrue,
    );
    expect(
      isLive(
        ky: yesterday.kYear,
        km: yesterday.kMonth,
        kd: yesterday.kDay,
        now: beforeEvent,
      ),
      isFalse,
    );
    expect(
      isLive(
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

  testWidgets(
    'every Offering block on today receives the shared ripple animation',
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
      expect(byDay[1]!.rippleAnimation, same(controller));
      expect(byDay[2]!.rippleAnimation, same(controller));
      expect(byDay[3]!.rippleAnimation, same(controller));
    },
  );

  testWidgets('DayViewPage starts its real ripple after event hydration', (
    tester,
  ) async {
    final notes = <NoteData>[];
    final dataVersion = ValueNotifier<int>(0);
    addTearDown(dataVersion.dispose);

    await _pumpRealRippleDayViewPage(
      tester,
      notes: notes,
      dataVersion: dataVersion,
    );
    expect(find.byType(OfferingTableEventBlockVisual), findsNothing);

    notes.add(_offeringRippleNote());
    dataVersion.value++;
    await tester.pump();

    final controller = _realRippleController(tester);
    final initialValue = controller.value;
    await tester.pump(const Duration(milliseconds: 300));
    final firstAdvance = controller.value;
    await tester.pump(const Duration(milliseconds: 300));
    final secondAdvance = controller.value;

    expect(firstAdvance, isNot(initialValue));
    expect(secondAdvance, isNot(firstAdvance));
    expect(controller.isAnimating, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hydration activation restarts the real DayViewPage controller', (
    tester,
  ) async {
    final hydrationActivation = ValueNotifier<int>(0);
    addTearDown(hydrationActivation.dispose);

    await _pumpRealRippleDayViewPage(
      tester,
      notes: <NoteData>[_offeringRippleNote()],
      hydrationActivation: hydrationActivation,
    );
    final controller = _realRippleController(tester);
    controller
      ..stop()
      ..value = 0;

    hydrationActivation.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.isAnimating, isTrue);
    expect(controller.value, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets("reduced motion keeps today's shared ripple controller still", (
    tester,
  ) async {
    await _pumpRealRippleDayViewPage(
      tester,
      notes: <NoteData>[_offeringRippleNote()],
      mediaQueryData: const MediaQueryData(disableAnimations: true),
    );
    final controller = _realRippleController(tester);
    expect(controller.isAnimating, isFalse);
    expect(controller.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accessible navigation alone does not suppress today ripple', (
    tester,
  ) async {
    await _pumpRealRippleDayViewPage(
      tester,
      notes: <NoteData>[_offeringRippleNote()],
      mediaQueryData: const MediaQueryData(accessibleNavigation: true),
    );
    final controller = _realRippleController(tester);
    final initialValue = controller.value;

    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.isAnimating, isTrue);
    expect(controller.value, isNot(initialValue));
    expect(tester.takeException(), isNull);
  });

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

  test('ripple painter produces visibly different loop frames', () async {
    final start = await _rasterizedRippleFrame(0);
    final rise = await _rasterizedRippleFrame(0.18);
    final middle = await _rasterizedRippleFrame(0.5);

    expect(listEquals(start, rise), isFalse);
    expect(listEquals(rise, middle), isFalse);
    expect(_pixelDelta(start, rise), greaterThan(1000));
    expect(_pixelDelta(rise, middle), greaterThan(1000));
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

NoteData _offeringRippleNote() {
  final day = kOfferingTableDays.first;
  return NoteData(
    clientEventId: 'offering-real-ripple-today',
    title: offeringTableEventTitle(day),
    allDay: false,
    start: const TimeOfDay(hour: 7, minute: 30),
    end: const TimeOfDay(hour: 7, minute: 33),
    flowId: 81,
    behaviorPayload: <String, dynamic>{
      'kind': 'maat_offering_table_day',
      'flow_key': kOfferingTableFlowKey,
      'day': day.dayNumber,
    },
  );
}

Future<void> _pumpRealRippleDayViewPage(
  WidgetTester tester, {
  required List<NoteData> notes,
  ValueListenable<int>? dataVersion,
  ValueListenable<int>? hydrationActivation,
  MediaQueryData mediaQueryData = const MediaQueryData(),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final today = KemeticMath.fromGregorian(DateTime.now());
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: mediaQueryData,
        child: DayViewPage(
          initialKy: today.kYear,
          initialKm: today.kMonth,
          initialKd: today.kDay,
          showGregorian: false,
          notesForDay: (ky, km, kd) =>
              ky == today.kYear && km == today.kMonth && kd == today.kDay
              ? notes
              : const <NoteData>[],
          flowIndex: <int, FlowData>{
            81: FlowData(
              id: 81,
              name: kOfferingTableTitle,
              color: const Color(0xFFC99A3D),
              active: true,
              notes: 'mode=gregorian;maat=$kOfferingTableFlowKey',
            ),
          },
          activeLedgerFlowIds: const <int>{81},
          dataVersion: dataVersion,
          hydrationActivation: hydrationActivation,
          getMonthName: (month) => 'Month $month',
        ),
      ),
    ),
  );
  await tester.pump();
}

AnimationController _realRippleController(WidgetTester tester) {
  final block = tester.widget<OfferingTableEventBlockVisual>(
    find.byType(OfferingTableEventBlockVisual).first,
  );
  return block.rippleAnimation! as AnimationController;
}

Future<Uint8List> _rasterizedRippleFrame(double value) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 56, 52),
    Paint()..color = Colors.black,
  );
  OfferingTableRipplePainter(
    visible: true,
    animation: AlwaysStoppedAnimation<double>(value),
  ).paint(canvas, const Size(56, 52));
  final image = await recorder.endRecording().toImage(56, 52);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

int _pixelDelta(Uint8List left, Uint8List right) {
  var delta = 0;
  for (var index = 0; index < left.length; index++) {
    delta += (left[index] - right[index]).abs();
  }
  return delta;
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
