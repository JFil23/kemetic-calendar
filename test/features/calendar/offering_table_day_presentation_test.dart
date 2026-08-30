import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/maat_flow_response_draft_store.dart';
import 'package:mobile/features/calendar/maat_flow_response_journal_blocks.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_day_presentation.dart';
import 'package:mobile/features/calendar/the_offering_table/presentation/offering_table_presentation_copy.dart';
import 'package:mobile/features/calendar/the_offering_table_flow.dart';
import 'package:mobile/features/calendar/the_offering_table_local_store.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _viewport = Size(390, 844);
const _flowId = 91;

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
    kMaatFlowResponseDraftStore.clearForTesting();
  });
  tearDown(kMaatFlowResponseDraftStore.clearForTesting);

  test('all thirty days resolve a non-empty shared ritual checklist', () {
    for (final day in kOfferingTableDays) {
      final presentation = offeringTablePracticePresentation(day);
      expect(presentation.steps, isNotEmpty, reason: 'Day ${day.dayNumber}');
    }
    expect(
      offeringTablePracticePresentation(kOfferingTableDays.first).steps,
      const <String>[
        'Fill a cup of water.',
        'Name one basic need that has been unmet for a few days.',
        'Do the smallest thing that begins to meet it.',
      ],
    );
  });

  testWidgets('moves the intention smoothly through its vertical target', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await _pumpPresentation(tester);

    final gesture = find.byKey(
      const ValueKey<String>('offering-table-intention-drag'),
    );
    final rect = tester.getRect(gesture);
    final heroRect = tester.getRect(
      find.byKey(const ValueKey<String>('offering-table-cup-hero')),
    );
    expect(rect.width, 176);
    expect(rect.height, 72);
    expect(rect.width, lessThan(heroRect.width));
    expect(rect.height, lessThan(heroRect.height));
    expect(
      rect.top,
      closeTo(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey<String>('offering-table-intention-air'),
              ),
            )
            .dy,
        0.1,
      ),
    );
    final lowerBody = find.byKey(
      const ValueKey<String>('offering-table-foreground-layer'),
    );
    final lowerBodyBefore = tester.widget<Container>(lowerBody);

    await tester.tapAt(Offset(rect.center.dx, rect.top + rect.height * 0.75));
    await tester.pump();
    expect(tester.getSemantics(gesture).value, isNot('0 percent placed'));

    final currentRect = tester.getRect(gesture);
    final pointer = await tester.startGesture(currentRect.center);
    for (var step = 1; step <= 12; step++) {
      await pointer.moveBy(const Offset(0, 4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pointer.up();
    await tester.pump();
    final placementAfterDown = tester.getSemantics(gesture).value;
    expect(placementAfterDown, isNot('0 percent placed'));
    final intentionAtStart = tester.getTopLeft(
      find.byKey(const ValueKey<String>('offering-table-intention-air')),
    );

    final movedRect = tester.getRect(gesture);
    final upward = await tester.startGesture(movedRect.center);
    for (var step = 1; step <= 8; step++) {
      await upward.moveBy(const Offset(0, -4));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await upward.up();
    await tester.pump();
    final intentionAtEnd = tester.getTopLeft(
      find.byKey(const ValueKey<String>('offering-table-intention-air')),
    );
    expect(intentionAtEnd.dy, lessThan(intentionAtStart.dy));

    final node = tester.getSemantics(gesture);
    // The widget-test semantics owner for the active render view remains on
    // this compatibility accessor in the current Flutter test binding.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.decrease,
    );
    await tester.pump();
    expect(tester.getSemantics(gesture).value, isNot(placementAfterDown));
    expect(
      identical(tester.widget<Container>(lowerBody), lowerBodyBefore),
      isTrue,
      reason: 'instrument updates must not rebuild the lower ritual body',
    );
    semanticsHandle.dispose();
  });

  testWidgets('vertical swipe over the hero scrolls without moving intention', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await _pumpPresentation(tester);

    final gesture = find.byKey(
      const ValueKey<String>('offering-table-intention-drag'),
    );
    final heroRect = tester.getRect(
      find.byKey(const ValueKey<String>('offering-table-cup-hero')),
    );
    final placementBefore = tester.getSemantics(gesture).value;

    final scrollable = find
        .descendant(
          of: find.byKey(
            const ValueKey<String>('offering-table-presentation-body'),
          ),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    final scrollBefore = position.pixels;

    await tester.dragFrom(
      Offset(heroRect.left + 12, heroRect.center.dy),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(scrollBefore));
    expect(tester.getSemantics(gesture).value, placementBefore);
    semanticsHandle.dispose();
  });

  testWidgets('uses Follow Sky drag guidance without visible slider chrome', (
    tester,
  ) async {
    await _pumpPresentation(tester);

    final instruction = tester.widget<Text>(
      find.byKey(const ValueKey<String>('offering-table-drag-instruction')),
    );
    expect(instruction.data, 'Drag your intention into the water.');
    expect(instruction.style?.fontFamily, 'GentiumPlus');
    expect(instruction.style?.fontSize, 11.5);
    expect(instruction.style?.fontStyle, FontStyle.italic);
    expect(instruction.style?.height, 1.2);
    expect(instruction.style?.color, const Color(0xFF6F685F));
    expect(instruction.style?.shadows, isNull);
    expect(find.text('Speak your intention into the water'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('offering-table-placement-thumb')),
      findsNothing,
    );

    final lowerBody = tester.widget<Container>(
      find.byKey(const ValueKey<String>('offering-table-foreground-layer')),
    );
    final decoration = lowerBody.decoration! as BoxDecoration;
    expect(decoration.boxShadow, isNull);
  });

  testWidgets('Day 1 ritual and why use the shared Offering authority', (
    tester,
  ) async {
    await _pumpPresentation(tester);
    final presentation = offeringTablePracticePresentation(
      kOfferingTableDays.first,
    );

    expect(find.text("TODAY'S RITUAL"), findsOneWidget);
    for (final step in presentation.steps) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text('Protect my sleep.'), findsWidgets);

    final body = find.byKey(
      const ValueKey<String>('offering-table-presentation-body'),
    );
    await tester.drag(body, const Offset(0, -500));
    await tester.pumpAndSettle();
    final toggle = find.byKey(
      const ValueKey<String>('offering-table-day-sheet-context-toggle'),
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text(presentation.why), findsOneWidget);
  });

  testWidgets('Reflect reuses the shared tool and writes through Journal', (
    tester,
  ) async {
    final blocks = <MaatJournalResponseBlock>[];
    await _pumpPresentation(
      tester,
      reflectionSaveDebounce: Duration.zero,
      onWriteJournalResponse: (block) async => blocks.add(block),
    );

    await tester.ensureVisible(find.text('Reflect'));
    await tester.pumpAndSettle();
    final reflectTool = find.ancestor(
      of: find.text('Reflect'),
      matching: find.byType(InkWell),
    );
    expect(reflectTool, findsOneWidget);
    expect(tester.getSize(reflectTool).height, 69);
    expect(
      find.text('What did you notice about what needs to be fed?'),
      findsNothing,
    );

    await tester.tap(find.text('Reflect'));
    await tester.pumpAndSettle();
    expect(
      find.text('What did you notice about what needs to be fed?'),
      findsOneWidget,
    );
    expect(
      find.textContaining('automatically kept in today’s Journal'),
      findsOneWidget,
    );

    const reflection = 'Rest needed to be counted before the day filled.';
    final field = find.byKey(
      const ValueKey<String>('offering-table-reflection-field'),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, reflection);
    await tester.pumpAndSettle();

    expect(blocks, hasLength(1));
    expect(blocks.single.text, reflection);
    expect(blocks.single.localDate, DateTime(2026, 8, 29));
    expect(
      blocks.single.sourceId,
      'maat_response:the-offering-table:cid:offering-table-test-event:offering-table-reflection',
    );
    expect(blocks.single.sourceMetadata['kind'], 'offering_table_reflection');

    await tester.ensureVisible(find.text('Reflect'));
    await tester.tap(find.text('Reflect'));
    await tester.pumpAndSettle();
    expect(field, findsNothing);
  });

  testWidgets(
    'narrow presentation keeps a fixed instrument and vertical body',
    (tester) async {
      await _pumpPresentation(tester, size: const Size(320, 700));
      final body = find.byKey(
        const ValueKey<String>('offering-table-presentation-body'),
      );
      final xBefore = tester.getTopLeft(body).dx;
      await tester.drag(body, const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(body).dx, closeTo(xBefore, 0.1));
      expect(find.text('Completion fixture'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Offering uses the shared resizable instrument host', (
    tester,
  ) async {
    await _pumpOfferingSheet(tester);

    final sheet = find.byKey(
      const ValueKey<String>('offering-table-resizable-sheet'),
    );
    final handle = find.byKey(
      const ValueKey<String>('follow-sky-sheet-resize-handle'),
    );
    final page = find.descendant(of: sheet, matching: find.byType(PageView));
    final hero = find.byKey(const ValueKey<String>('offering-table-cup-hero'));
    expect(sheet, findsOneWidget);
    expect(handle, findsOneWidget);
    expect(tester.getSize(hero).height, 238);
    expect(
      find.byKey(const ValueKey<String>('offering-table-day-presentation')),
      findsOneWidget,
    );

    final availableHeight = _viewport.height - 12;
    final minimumPageHeight = availableHeight * 0.58 - 120;
    expect(tester.getSize(page).height, closeTo(minimumPageHeight, 0.1));

    await tester.drag(handle, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(tester.getSize(page).height, closeTo(minimumPageHeight + 120, 0.1));
    expect(tester.getSize(hero).height, 238);

    final body = find.byKey(
      const ValueKey<String>('offering-table-presentation-body'),
    );
    final xBefore = tester.getTopLeft(body).dx;
    await tester.drag(body, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(body).dx, closeTo(xBefore, 0.1));
  });
}

Future<void> _pumpPresentation(
  WidgetTester tester, {
  Size size = const Size(390, 700),
  Duration reflectionSaveDebounce = const Duration(milliseconds: 450),
  MaatJournalResponseBlockWriter? onWriteJournalResponse,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: OfferingTableDayPresentation(
          day: kOfferingTableDays.first,
          localDate: DateTime(2026, 8, 29),
          startMinute: 7 * 60 + 30,
          initialNeed: 'Protect my sleep.',
          lens: OfferingTableLens.neutral,
          completionPanel: const Text('Completion fixture'),
          clientEventId: 'offering-table-test-event',
          onWriteJournalResponse: onWriteJournalResponse,
          reflectionSaveDebounce: reflectionSaveDebounce,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpOfferingSheet(WidgetTester tester) async {
  tester.view.physicalSize = _viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);

  const store = OfferingTableLocalStore();
  await store.saveNeed(_flowId, 'Protect my sleep.');
  final day = kOfferingTableDays.first;
  final localDate = DateTime(2026, 8, 29);
  final schedule = offeringTableScheduleForDate(
    day,
    localDate,
    TrackSkyTimeZone.pacific,
  );
  final target = DayViewSheetEventTarget(
    ky: 1,
    km: 1,
    kd: 1,
    event: EventItem(
      clientEventId: 'offering-table-sheet-fixture',
      title: offeringTableEventTitle(day),
      startMin: 7 * 60 + 30,
      endMin: 7 * 60 + 35,
      flowId: _flowId,
      color: const Color(0xFFC99A3D),
      allDay: false,
      behaviorPayload: offeringTableBehaviorPayload(
        day: day,
        schedule: schedule,
        lens: OfferingTableLens.neutral,
        noCupMode: false,
      ),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          body: CalendarEventDetailSheet(
            hostContext: context,
            initialTarget: target,
            flowResolver: (flowId) => flowId == _flowId
                ? const FlowData(
                    id: _flowId,
                    name: kOfferingTableTitle,
                    color: Color(0xFFC99A3D),
                    active: true,
                    notes:
                        'mode=gregorian;maat=the-offering-table;offering_lens=neutral',
                  )
                : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
