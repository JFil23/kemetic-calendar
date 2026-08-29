import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/calendar/calendar_page.dart'
    show
        EndFlowFailureKind,
        EndFlowOutcome,
        KemeticMath,
        beginOptimisticNoteEditorSave;
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/day_view_chrome.dart';
import 'package:mobile/features/calendar/landscape_month_view.dart';
import 'package:mobile/features/calendar/living_text_day_one_node_store.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:mobile/features/calendar/maat_flow_response_draft_store.dart';
import 'package:mobile/features/calendar/maat_flow_palette.dart';
import 'package:mobile/features/calendar/the_weighing_flow.dart';
import 'package:mobile/features/journal/journal_badge_utils.dart';
import 'package:mobile/features/journal/journal_event_badge.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/calendar_floating_shortcuts.dart';
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
    kMaatFlowResponseDraftStore.clearForTesting();
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });
  tearDown(() {
    kMaatFlowResponseDraftStore.clearForTesting();
    CalendarEventDetailSheetCoordinator.debugResetForTests();
  });

  test(
    'optimistic note save stages and closes before persistence completes',
    () {
      final persistence = Completer<String>();
      final order = <String>[];

      final save = beginOptimisticNoteEditorSave<String>(
        startSave: () {
          order.add('staged');
          return persistence.future;
        },
        closeEditor: () => order.add('closed'),
      );

      expect(order, <String>['staged', 'closed']);
      expect(persistence.isCompleted, isFalse);
      persistence.complete('saved');
      expect(save, completion('saved'));
    },
  );

  testWidgets(
    'optimistic note save closes its editor and paints the event immediately',
    (tester) async {
      await _setPhoneViewport(tester);
      final persistence = Completer<void>();
      final dataVersion = ValueNotifier<int>(0);
      addTearDown(dataVersion.dispose);
      var notes = <NoteData>[];
      var editorOpen = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    if (editorOpen)
                      ElevatedButton(
                        key: const ValueKey<String>(
                          'optimistic-note-save-button',
                        ),
                        onPressed: () {
                          final save = beginOptimisticNoteEditorSave<void>(
                            startSave: () {
                              setState(() {
                                notes = const [
                                  NoteData(
                                    title: 'Immediate event block',
                                    allDay: false,
                                    start: TimeOfDay(hour: 12, minute: 0),
                                    end: TimeOfDay(hour: 13, minute: 0),
                                  ),
                                ];
                                dataVersion.value++;
                              });
                              return persistence.future;
                            },
                            closeEditor: () {
                              setState(() => editorOpen = false);
                            },
                          );
                          unawaited(save);
                        },
                        child: const Text('Save note'),
                      ),
                    Expanded(
                      child: DayViewGrid(
                        ky: 1,
                        km: 1,
                        kd: 1,
                        notes: notes,
                        dataVersion: dataVersion,
                        showGregorian: false,
                        flowIndex: const {},
                        initialScrollOffset: 11 * 60,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('optimistic-note-save-button')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('optimistic-note-save-button')),
        findsNothing,
      );
      expect(find.text('Immediate event block'), findsOneWidget);
      expect(persistence.isCompleted, isFalse);

      persistence.complete();
      await tester.pump();
    },
  );

  testWidgets(
    'day view collapses optimistic and server reminder projections by occurrence identity',
    (tester) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        const _DayViewHarness(
          flowIndex: <int, FlowData>{
            42: FlowData(
              id: 42,
              name: 'Delete test',
              color: Colors.blue,
              active: true,
            ),
          },
          notes: <NoteData>[
            NoteData(
              clientEventId:
                  'reminder:11111111-1111-1111-1111-111111111111:2026-08-15',
              title: 'Delete test',
              allDay: false,
              start: TimeOfDay(hour: 2, minute: 15),
              end: TimeOfDay(hour: 2, minute: 45),
              manualColor: Colors.purple,
              isReminder: true,
              reminderId: '11111111-1111-1111-1111-111111111111',
            ),
            NoteData(
              id: 'server-event-row',
              clientEventId:
                  'reminder:11111111-1111-1111-1111-111111111111:2026-08-15',
              title: 'Delete test',
              allDay: false,
              start: TimeOfDay(hour: 2, minute: 15),
              end: TimeOfDay(hour: 2, minute: 45),
              flowId: 42,
              manualColor: Colors.blue,
              isReminder: true,
              reminderId: '11111111-1111-1111-1111-111111111111',
            ),
          ],
          initialScrollOffset: 60,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete test'), findsOneWidget);
    },
  );

  test(
    'Day View timeline does not render a false empty state while hydrating',
    () async {
      final source = await File(
        'lib/features/calendar/day_view.dart',
      ).readAsString();
      final timelineSource = _sourceBetween(
        source,
        'Widget _buildTimelineEventLayer({',
        'Widget _buildTimelineOverlayLayer() {',
      );

      expect(timelineSource, isNot(contains('No events')));
      expect(timelineSource, isNot(contains('Nothing scheduled')));
      expect(timelineSource, isNot(contains('empty')));
    },
  );

  test(
    'shared instrument host keeps Follow Sky minimum and overflow chrome',
    () async {
      final dayView = await File(
        'lib/features/calendar/day_view.dart',
      ).readAsString();
      final sharedHost = await File(
        'lib/features/calendar/presentation/'
        'instrument_event_presentation_frame.dart',
      ).readAsString();

      expect(
        sharedHost,
        contains('const double instrumentEventSheetMinExtent = 0.58;'),
      );
      expect(sharedHost, contains('availableSheetHeight * effectiveExtent'));
      expect(
        sharedHost,
        contains('.clamp(instrumentEventSheetMinExtent, 1.0)'),
      );
      expect(sharedHost, contains('isDismissible: true'));
      expect(sharedHost, contains('enableDrag: true'));
      expect(sharedHost, contains('useRootNavigator: false'));
      expect(sharedHost, isNot(contains('child: Align(')));
      expect(dayView, contains('InstrumentEventSheetHost('));
      expect(dayView, contains('trailing: _buildEventDetailOverflowButton('));
    },
  );

  test('End Flow successor is same-day, stable, and excludes ending flow', () {
    const targetEvent = EventItem(
      clientEventId: 'cid-b',
      title: 'Ending event',
      startMin: 600,
      endMin: 630,
      flowId: 7,
      color: Colors.red,
      allDay: false,
    );
    const sameFlowLater = EventItem(
      clientEventId: 'cid-d',
      title: 'Same flow later',
      startMin: 610,
      endMin: 640,
      flowId: 7,
      color: Colors.red,
      allDay: false,
    );
    const tiedSuccessor = EventItem(
      clientEventId: 'cid-c',
      title: 'Stable tied successor',
      startMin: 600,
      endMin: 630,
      flowId: 8,
      color: Colors.blue,
      allDay: false,
    );
    const earlier = EventItem(
      clientEventId: 'cid-a',
      title: 'Earlier',
      startMin: 540,
      endMin: 570,
      flowId: 8,
      color: Colors.blue,
      allDay: false,
    );

    final successor = sameDayEndFlowSuccessor(
      target: const DayViewSheetEventTarget(
        ky: 1,
        km: 2,
        kd: 3,
        event: targetEvent,
      ),
      events: const [sameFlowLater, tiedSuccessor, earlier, targetEvent],
      endingFlowId: 7,
    );

    expect(successor?.event.clientEventId, 'cid-c');
    expect((successor?.ky, successor?.km, successor?.kd), (1, 2, 3));
    expect(
      sameDayEndFlowSuccessor(
        target: const DayViewSheetEventTarget(
          ky: 1,
          km: 2,
          kd: 3,
          event: targetEvent,
        ),
        events: const [earlier, targetEvent, sameFlowLater],
        endingFlowId: 7,
      ),
      isNull,
    );
  });

  group('DayViewGrid overlapping event gestures', () {
    testWidgets(
      'saved initial scroll offset is clamped to the current extent',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          const _DayViewHarness(notes: [], initialScrollOffset: 999999),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('first visible minute restores before raw pixel offset', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DayViewGrid(
              ky: 1,
              km: 1,
              kd: 1,
              notes: [],
              showGregorian: false,
              flowIndex: {},
              initialFirstVisibleMinute: 8 * 60,
              initialScrollOffset: 120,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.pixels, closeTo(8 * 60, 0.001));
    });

    testWidgets(
      'timeline reserves safe-area bottom room without drawer chrome',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(bottom: 34),
              ),
              child: Scaffold(
                body: DayViewGrid(
                  ky: 1,
                  km: 1,
                  kd: 1,
                  notes: [],
                  showGregorian: false,
                  flowIndex: {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final listView = tester.widget<ListView>(
          find.byKey(const PageStorageKey<String>('day_timeline_list')),
        );
        final padding = listView.padding as EdgeInsets;

        expect(padding.bottom, 58);
      },
    );

    testWidgets(
      'tablet landscape event layout uses constraint width and keeps bottom inset clear',
      (tester) async {
        await _setTabletLandscapeViewport(tester);

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                title: 'Arrive in NYC',
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final listView = tester.widget<ListView>(
          find.byKey(const PageStorageKey<String>('day_timeline_list')),
        );
        final padding = listView.padding as EdgeInsets;
        expect(padding.bottom, 24);

        final eventSizedBoxes = tester.widgetList<SizedBox>(
          find.ancestor(
            of: find.text('Arrive in NYC'),
            matching: find.byType(SizedBox),
          ),
        );

        expect(
          eventSizedBoxes.any(
            (box) => box.width != null && (box.width! - 1122).abs() < 0.001,
          ),
          isTrue,
        );
      },
    );

    testWidgets('Track Sky event cards fit long moon copy without overflow', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        _DayViewHarness(
          initialScrollOffset: 15 * 60,
          flowIndex: const <int, FlowData>{
            99: FlowData(
              id: 99,
              name: 'Follow the sky',
              color: Colors.indigo,
              active: true,
              notes: 'sky_tz=pacific',
            ),
          },
          notes: [
            _timedNote(
              title: 'Strawberry Moon + Micromoon (Full)',
              startHour: 15,
              startMinute: 30,
              endHour: 16,
              endMinute: 15,
              flowId: 99,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Follow the sky'), findsWidgets);
      expect(find.text('Strawberry Moon + Micromoon (Full)'), findsWidgets);
    });

    testWidgets('phone landscape Day View uses the landscape month surface', (
      tester,
    ) async {
      await _setPhoneLandscapeViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DayViewPage(
            initialKy: 1,
            initialKm: 2,
            initialKd: 5,
            showGregorian: false,
            notesForDay: (_, _, _) => const [],
            flowIndex: const {},
            getMonthName: (month) => 'Month $month',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LandscapeMonthView), findsOneWidget);
      expect(find.byType(DayViewGrid), findsNothing);
      expect(find.byKey(calendarFloatingTodaySurfaceKey), findsOneWidget);
      expect(find.byKey(calendarFloatingCalendarsButtonKey), findsOneWidget);
      expect(find.byKey(calendarFloatingInboxButtonKey), findsOneWidget);
    });

    test(
      'single non-overlapping events keep the phone width factor by default',
      () {
        final blocks = EventLayoutEngine.layoutEventItems(
          events: const [
            EventItem(
              title: 'Phone Width Event',
              startMin: 10 * 60,
              endMin: 11 * 60,
              color: Colors.green,
              allDay: false,
            ),
          ],
          availableWidth: 314,
          columnGap: 4,
          textScale: 1.0,
          day: 1,
        );

        expect(blocks.single.width, closeTo(314 * 0.8, 0.001));
      },
    );

    test('tablet landscape single events can use the full timeline lane', () {
      final blocks = EventLayoutEngine.layoutEventItems(
        events: const [
          EventItem(
            title: 'Tablet Width Event',
            startMin: 10 * 60,
            endMin: 11 * 60,
            color: Colors.green,
            allDay: false,
          ),
        ],
        availableWidth: 1118,
        columnGap: 4,
        textScale: 1.0,
        day: 1,
        singleEventWidthFactor: 1.0,
      );

      expect(blocks.single.width, closeTo(1118, 0.001));
    });

    test('staggered overlapping events are assigned separate lanes', () {
      final blocks = EventLayoutEngine.layoutEventItems(
        events: const [
          EventItem(
            title: 'First Event',
            startMin: 16 * 60 + 45,
            endMin: 17 * 60 + 30,
            flowId: 1,
            color: Colors.green,
            allDay: false,
          ),
          EventItem(
            title: 'Second Event',
            startMin: 17 * 60,
            endMin: 18 * 60,
            flowId: 2,
            color: Colors.red,
            allDay: false,
          ),
        ],
        availableWidth: 314,
        columnGap: 4,
        textScale: 1.0,
        day: 1,
      );

      final first = blocks.firstWhere(
        (block) => block.event.title == 'First Event',
      );
      final second = blocks.firstWhere(
        (block) => block.event.title == 'Second Event',
      );

      expect(first.leftOffset, 0);
      expect(second.leftOffset, greaterThan(0));
      expect(first.width, closeTo(second.width, 0.001));
    });

    test('overlap layout caps each carousel page at three event columns', () {
      final blocks = EventLayoutEngine.layoutEventItems(
        events: const [
          EventItem(
            title: 'First',
            startMin: 12 * 60,
            endMin: 13 * 60,
            color: Colors.red,
            allDay: false,
          ),
          EventItem(
            title: 'Second',
            startMin: 12 * 60,
            endMin: 13 * 60,
            color: Colors.orange,
            allDay: false,
          ),
          EventItem(
            title: 'Third',
            startMin: 12 * 60,
            endMin: 13 * 60,
            color: Colors.yellow,
            allDay: false,
          ),
          EventItem(
            title: 'Fourth',
            startMin: 12 * 60,
            endMin: 13 * 60,
            color: Colors.green,
            allDay: false,
          ),
          EventItem(
            title: 'Fifth',
            startMin: 12 * 60,
            endMin: 13 * 60,
            color: Colors.blue,
            allDay: false,
          ),
        ],
        availableWidth: 314,
        columnGap: 4,
        textScale: 1.0,
        day: 1,
      );

      expect(blocks, hasLength(5));
      expect(blocks.map((block) => block.totalColumns).toSet(), <int>{5});
      final blocksByPage = <int, List<PositionedEventBlock>>{};
      for (final block in blocks) {
        blocksByPage
            .putIfAbsent(
              block.carouselPageIndex,
              () => <PositionedEventBlock>[],
            )
            .add(block);
      }
      expect(blocksByPage.keys, <int>{0, 1});
      expect(blocksByPage[0], hasLength(dayViewMaxVisibleEventColumns));
      expect(blocksByPage[1], hasLength(2));
      expect(
        blocks.every((block) => block.width == blocks.first.width),
        isTrue,
      );
      expect(blocks.first.width, closeTo((314 - 8) / 3, 0.001));
    });

    testWidgets('more than three overlapping blocks swipe horizontally', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        const _DayViewHarness(
          initialScrollOffset: 11 * 60,
          notes: [
            NoteData(
              title: 'First',
              allDay: false,
              start: TimeOfDay(hour: 12, minute: 0),
              end: TimeOfDay(hour: 13, minute: 0),
            ),
            NoteData(
              title: 'Second',
              allDay: false,
              start: TimeOfDay(hour: 12, minute: 0),
              end: TimeOfDay(hour: 13, minute: 0),
            ),
            NoteData(
              title: 'Third',
              allDay: false,
              start: TimeOfDay(hour: 12, minute: 0),
              end: TimeOfDay(hour: 13, minute: 0),
            ),
            NoteData(
              title: 'Fourth',
              allDay: false,
              start: TimeOfDay(hour: 12, minute: 0),
              end: TimeOfDay(hour: 13, minute: 0),
            ),
            NoteData(
              title: 'Fifth',
              allDay: false,
              start: TimeOfDay(hour: 12, minute: 0),
              end: TimeOfDay(hour: 13, minute: 0),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final carousel = find.byKey(dayViewEventCarouselKey(0));
      expect(carousel, findsOneWidget);
      final controller = tester.widget<PageView>(carousel).controller!;
      expect(controller.page, closeTo(0, 0.001));

      await tester.drag(carousel, const Offset(-260, 0));
      await tester.pumpAndSettle();

      expect(controller.page, closeTo(1, 0.001));
    });

    test(
      'events with non-overlapping times still split lanes when their rendered cards would collide',
      () {
        final blocks = EventLayoutEngine.layoutEventItems(
          events: const [
            EventItem(
              title: 'Short Top Event',
              startMin: 13 * 60,
              endMin: 13 * 60 + 30,
              flowId: 1,
              color: Colors.green,
              allDay: false,
            ),
            EventItem(
              title: 'Later Event',
              startMin: 13 * 60 + 45,
              endMin: 14 * 60 + 30,
              flowId: 2,
              color: Colors.red,
              allDay: false,
            ),
          ],
          availableWidth: 314,
          columnGap: 4,
          textScale: 1.0,
          day: 1,
        );

        final top = blocks.firstWhere(
          (block) => block.event.title == 'Short Top Event',
        );
        final later = blocks.firstWhere(
          (block) => block.event.title == 'Later Event',
        );

        expect(top.leftOffset, 0);
        expect(later.leftOffset, greaterThan(0));
        expect(top.width, closeTo(later.width, 0.001));
      },
    );

    test(
      'flow-owned events keep the flow chrome color even when not ledger-active',
      () {
        final blocks = EventLayoutEngine.layoutEventsForDay(
          notes: [
            _timedNote(
              title: 'Archived Practice',
              startHour: 10,
              startMinute: 0,
              endHour: 11,
              endMinute: 0,
              flowId: 9,
            ),
          ],
          flowIndex: const {
            9: FlowData(
              id: 9,
              name: 'Archived Practice Flow',
              color: Colors.green,
              active: false,
            ),
          },
          availableWidth: 314,
          columnGap: 4,
          textScale: 1.0,
          day: 1,
        );

        expect(blocks, hasLength(1));
        expect(blocks.single.event.color, Colors.green);
      },
    );

    testWidgets(
      'a short event card inherits the tallest hit height in its overlap row',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                title: 'Kung Fu Practice',
                startHour: 10,
                startMinute: 0,
                endHour: 10,
                endMinute: 30,
                flowId: 1,
              ),
              _timedNote(
                title: 'Tax Day',
                startHour: 10,
                startMinute: 0,
                endHour: 13,
                endMinute: 0,
                flowId: 2,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final ancestorBoxes = tester.widgetList<SizedBox>(
          find.ancestor(
            of: find.text('Kung Fu Practice'),
            matching: find.byType(SizedBox),
          ),
        );

        expect(ancestorBoxes.any((box) => box.height == 182), isTrue);
      },
    );

    testWidgets(
      'new event preview stays single while crossing into the next hour',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(const _DayViewHarness(notes: []));
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(const Offset(200, 450));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

        expect(find.text('New Event'), findsOneWidget);
        expect(find.text('4:30 PM'), findsOneWidget);
        expect(
          _dayViewTimelineLayerKeys(tester),
          containsAllInOrder([
            dayViewTimelineGridLayerKey,
            dayViewTimelineEventLayerKey,
            dayViewTimelinePreviewLayerKey,
            dayViewTimelineOverlayLayerKey,
          ]),
        );

        await gesture.moveBy(const Offset(0, 45));
        await tester.pump();

        expect(find.text('New Event'), findsOneWidget);
        expect(find.text('5:15 PM'), findsOneWidget);

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('timeline grid layer stays below event and preview layers', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        const _DayViewHarness(
          initialScrollOffset: 14 * 60,
          notes: [
            NoteData(
              clientEventId: 'multi-hour-card',
              title: 'test',
              allDay: false,
              start: TimeOfDay(hour: 15, minute: 30),
              end: TimeOfDay(hour: 16, minute: 30),
              manualColor: Colors.green,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('test'), findsWidgets);

      final keys = _dayViewTimelineLayerKeys(tester);
      expect(
        keys,
        containsAllInOrder([
          dayViewTimelineGridLayerKey,
          dayViewTimelineLabelLayerKey,
          dayViewTimelineEventLayerKey,
          dayViewTimelinePreviewLayerKey,
          dayViewTimelineOverlayLayerKey,
        ]),
      );
      expect(
        keys.indexOf(dayViewTimelineGridLayerKey),
        lessThan(keys.indexOf(dayViewTimelineEventLayerKey)),
      );
      expect(
        keys.indexOf(dayViewTimelineEventLayerKey),
        lessThan(keys.indexOf(dayViewTimelinePreviewLayerKey)),
      );
    });
  });

  group('DayViewGrid detail sheet refresh', () {
    testWidgets('reminder previews keep category and title visible', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        const _DayViewHarness(
          initialScrollOffset: 7 * 60,
          notes: [
            NoteData(
              clientEventId: 'cid-journal-every-day',
              title: 'journal every day',
              allDay: false,
              start: TimeOfDay(hour: 8, minute: 0),
              end: TimeOfDay(hour: 9, minute: 0),
              manualColor: Colors.green,
              isReminder: true,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REMINDER'), findsWidgets);
      expect(find.text('journal every day'), findsWidgets);
    });

    testWidgets(
      'timeline and detail sheet replace raw YouTube URL with smart action',
      (tester) async {
        await _setPhoneViewport(tester);
        const url = 'https://www.youtube.com/watch?v=abc123';

        await tester.pumpWidget(
          const _DayViewHarness(
            initialScrollOffset: 11 * 60,
            notes: [
              NoteData(
                clientEventId: 'cid-daily-math-youtube',
                title: 'Explain the Mystery',
                detail:
                    'Watch the linked video. Focus: explain the basic mystery.',
                location: url,
                category: 'Daily Math Visuals · 30-Day Path',
                allDay: false,
                start: TimeOfDay(hour: 12, minute: 0),
                end: TimeOfDay(hour: 13, minute: 0),
                manualColor: Colors.blue,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('DAILY MATH VISUALS · 30-DAY PATH'), findsWidgets);
        expect(find.text('Explain the Mystery'), findsWidgets);
        expect(find.text(url), findsNothing);

        await tester.tap(find.text('Explain the Mystery').first);
        await tester.pumpAndSettle();

        expect(find.text('Watch on YouTube'), findsOneWidget);
        expect(find.text(url), findsNothing);
      },
    );

    testWidgets(
      'Ma_at flow detail sheet uses gold section headers without duplicate labels',
      (tester) async {
        await _setPhoneViewport(tester);
        final event = kTheWeighingEvents.singleWhere(
          (event) => event.eventNumber == 9,
        );
        final title = theWeighingEventTitle(event);
        final recordedStatuses = <CompletionStatus>[];

        await tester.pumpWidget(
          _DayViewHarness(
            initialScrollOffset: 9 * 60,
            flowIndex: const <int, FlowData>{
              90: FlowData(
                id: 90,
                name: kTheWeighingTitle,
                color: Colors.amber,
                active: true,
                notes: 'weighing_lens=neutral',
              ),
            },
            notes: [
              NoteData(
                clientEventId: 'cid-the-weighing-9',
                title: title,
                detail: theWeighingDetailText(
                  event,
                  lens: TheWeighingLens.neutral,
                ),
                category: event.decanSection,
                allDay: false,
                start: const TimeOfDay(hour: 10, minute: 0),
                end: const TimeOfDay(hour: 10, minute: 10),
                flowId: 90,
              ),
            ],
            onRecordCompletion:
                ({
                  required String clientEventId,
                  required int flowId,
                  required DateTime completedOnDate,
                  Map<String, dynamic>? metadata,
                }) async {
                  recordedStatuses.add(
                    CompletionStatusX.fromWireName(
                      metadata?['completion_status']?.toString(),
                    ),
                  );
                },
          ),
        );
        await tester.pumpAndSettle();

        final eventSurface = find
            .ancestor(
              of: find.text(title).first,
              matching: find.byType(GestureDetector),
            )
            .last;
        await tester.tap(eventSurface);
        await tester.pumpAndSettle();

        for (final label in const <String>['PURPOSE', 'WORDS', 'STEPS']) {
          final finder = find.text(label);
          expect(finder, findsOneWidget);
          final text = tester.widget<Text>(finder);
          expect(text.style?.color, MaatFlowPalette.interiorLabel);
          expect(text.style?.letterSpacing, 1.6);
        }
        expect(find.text('Purpose'), findsNothing);

        final bodyFinder = find.textContaining(
          'Speak only the truth-check lines you can speak honestly.',
        );
        expect(bodyFinder, findsOneWidget);
        final bodyText = tester.widget<Text>(bodyFinder);
        expect(bodyText.style?.color, isNot(MaatFlowPalette.interiorLabel));

        expect(find.text('Observed'), findsWidgets);
        expect(find.text('Partly'), findsWidgets);
        expect(find.text('Skipped'), findsWidgets);

        await tester.ensureVisible(find.text('Observed').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Observed').last);
        await tester.pumpAndSettle();

        expect(recordedStatuses, <CompletionStatus>[CompletionStatus.observed]);
      },
    );

    testWidgets('overlapping math cards remain visible as compact previews', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      const url = 'https://www.youtube.com/watch?v=abc123';

      await tester.pumpWidget(
        const _DayViewHarness(
          initialScrollOffset: 11 * 60,
          notes: [
            NoteData(
              title: 'Explain the Mystery',
              location: url,
              category: '30-Day Path',
              allDay: false,
              start: TimeOfDay(hour: 12, minute: 0),
              end: TimeOfDay(hour: 13, minute: 0),
              manualColor: Colors.blue,
            ),
            NoteData(
              title: 'sin(a+b) Formula',
              location: url,
              category: '90-Day Ladder',
              allDay: false,
              start: TimeOfDay(hour: 12, minute: 0),
              end: TimeOfDay(hour: 13, minute: 0),
              manualColor: Colors.deepOrange,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('30-DAY PATH'), findsWidgets);
      expect(find.text('Explain the Mystery'), findsWidgets);
      expect(find.text('90-DAY LADDER'), findsWidgets);
      expect(find.text('sin(a+b) Formula'), findsWidgets);
      expect(find.text(url), findsNothing);
    });

    testWidgets(
      'completion buttons toggle off and replace journal badges by source id',
      (tester) async {
        await _setPhoneViewport(tester);

        final appendedBadges = <String>[];
        final recordedStatuses = <CompletionStatus>[];
        final unrecordedClientEventIds = <String>[];
        final removedBadgeIds = <String>[];

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                clientEventId: 'cid-focus-completion',
                title: 'Focus Completion',
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
                flowId: 1,
              ),
            ],
            onAppendToJournal: (text) async {
              appendedBadges.add(text);
            },
            onRecordCompletion:
                ({
                  required String clientEventId,
                  required int flowId,
                  required DateTime completedOnDate,
                  Map<String, dynamic>? metadata,
                }) async {
                  recordedStatuses.add(
                    CompletionStatusX.fromWireName(
                      metadata?['completion_status']?.toString() ??
                          metadata?['status']?.toString(),
                    ),
                  );
                },
            onUnrecordCompletion: (clientEventId) async {
              unrecordedClientEventIds.add(clientEventId);
            },
            onRemoveCompletionBadge: (badgeId) async {
              removedBadgeIds.add(badgeId);
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Focus Completion'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Observed').last);
        await tester.pumpAndSettle();

        expect(recordedStatuses, <CompletionStatus>[CompletionStatus.observed]);
        expect(appendedBadges, hasLength(1));
        var tokens = appendedBadges
            .map(JournalBadgeUtils.parseRawToken)
            .whereType<EventBadgeToken>()
            .toList();
        expect(tokens.single.completionStatus, CompletionStatus.observed);

        await tester.tap(find.text('Observed').last);
        await tester.pumpAndSettle();

        expect(unrecordedClientEventIds, <String>['cid-focus-completion']);
        expect(removedBadgeIds, <String>[tokens.single.id]);

        await tester.tap(find.text('Partly').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Skipped').last);
        await tester.pumpAndSettle();

        expect(recordedStatuses, <CompletionStatus>[
          CompletionStatus.observed,
          CompletionStatus.partial,
          CompletionStatus.skipped,
        ]);
        expect(appendedBadges, hasLength(3));
        tokens = appendedBadges
            .map(JournalBadgeUtils.parseRawToken)
            .whereType<EventBadgeToken>()
            .toList();
        expect(tokens.map((token) => token.id).toSet(), hasLength(1));
        expect(tokens.last.completionStatus, CompletionStatus.skipped);
      },
    );

    testWidgets(
      'ordinary flow observed completion pulses the rim and requests medium haptic',
      (tester) async {
        await _setPhoneViewport(tester);

        final recordedStatuses = <CompletionStatus>[];

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                clientEventId: 'cid-ritual-observed',
                title: 'Ritual Observed',
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
                flowId: 1,
              ),
            ],
            onRecordCompletion:
                ({
                  required String clientEventId,
                  required int flowId,
                  required DateTime completedOnDate,
                  Map<String, dynamic>? metadata,
                }) async {
                  recordedStatuses.add(
                    CompletionStatusX.fromWireName(
                      metadata?['completion_status']?.toString() ??
                          metadata?['status']?.toString(),
                    ),
                  );
                },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ritual Observed'));
        await tester.pumpAndSettle();

        final hapticCalls = _capturePlatformHaptics(tester);
        final stableCardFill = _ritualCardFillColor(tester);
        expect(stableCardFill, isNotNull);
        expect(_ritualRimIntensity(tester), 0);
        expect(_ritualPulsePaintsFill(tester), isFalse);

        await tester.tap(find.text('Observed').last);
        await tester.pump();
        await tester.pump(
          kCalendarCompletionFeedbackDelay - const Duration(milliseconds: 1),
        );
        expect(_ritualRimIntensity(tester), 0);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 140));

        expect(recordedStatuses, <CompletionStatus>[CompletionStatus.observed]);
        expect(_ritualPulseMode(tester), 'observed');
        expect(_ritualRimIntensity(tester), greaterThan(0));
        expect(_ritualPulseFillAlpha(tester), 0);
        expect(_ritualPulsePaintsFill(tester), isFalse);
        expect(_ritualCardFillColor(tester), stableCardFill);
        expect(
          _hapticArguments(hapticCalls),
          contains('HapticFeedbackType.mediumImpact'),
        );

        await tester.pumpAndSettle();
        expect(_ritualRimIntensity(tester), 0);
        expect(_ritualCardFillColor(tester), stableCardFill);
      },
    );

    testWidgets(
      'ordinary flow partly completion pulses the rim weaker and requests light haptic',
      (tester) async {
        await _setPhoneViewport(tester);

        final recordedStatuses = <CompletionStatus>[];

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                clientEventId: 'cid-ritual-partly',
                title: 'Ritual Partly',
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
                flowId: 1,
              ),
            ],
            onRecordCompletion:
                ({
                  required String clientEventId,
                  required int flowId,
                  required DateTime completedOnDate,
                  Map<String, dynamic>? metadata,
                }) async {
                  recordedStatuses.add(
                    CompletionStatusX.fromWireName(
                      metadata?['completion_status']?.toString() ??
                          metadata?['status']?.toString(),
                    ),
                  );
                },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ritual Partly'));
        await tester.pumpAndSettle();

        final hapticCalls = _capturePlatformHaptics(tester);
        final stableCardFill = _ritualCardFillColor(tester);
        expect(stableCardFill, isNotNull);

        await tester.tap(find.text('Observed').last);
        await tester.pump();
        await tester.pump(kCalendarCompletionFeedbackDelay);
        await tester.pump(const Duration(milliseconds: 140));
        final observedRimIntensity = _ritualRimIntensity(tester);
        expect(_ritualPulseMode(tester), 'observed');
        expect(_ritualPulseFillAlpha(tester), 0);
        expect(_ritualPulsePaintsFill(tester), isFalse);
        expect(_ritualCardFillColor(tester), stableCardFill);

        await tester.pumpAndSettle();
        await tester.tap(find.text('Partly').last);
        await tester.pump();
        await tester.pump(kCalendarCompletionFeedbackDelay);
        await tester.pump(const Duration(milliseconds: 140));
        final partialRimIntensity = _ritualRimIntensity(tester);

        expect(recordedStatuses, <CompletionStatus>[
          CompletionStatus.observed,
          CompletionStatus.partial,
        ]);
        expect(_ritualPulseMode(tester), 'partial');
        expect(partialRimIntensity, greaterThan(0));
        expect(partialRimIntensity, lessThan(observedRimIntensity));
        expect(_ritualPulseFillAlpha(tester), 0);
        expect(_ritualPulsePaintsFill(tester), isFalse);
        expect(_ritualCardFillColor(tester), stableCardFill);
        expect(
          _hapticArguments(hapticCalls),
          contains('HapticFeedbackType.lightImpact'),
        );
      },
    );

    testWidgets(
      'ordinary flow skipped completion pulses and requests light haptic',
      (tester) async {
        await _setPhoneViewport(tester);

        final appendedBadges = <String>[];
        final recordedStatuses = <CompletionStatus>[];

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                clientEventId: 'cid-ritual-skipped',
                title: 'Ritual Skipped',
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
                flowId: 1,
              ),
            ],
            onAppendToJournal: (text) async {
              appendedBadges.add(text);
            },
            onRecordCompletion:
                ({
                  required String clientEventId,
                  required int flowId,
                  required DateTime completedOnDate,
                  Map<String, dynamic>? metadata,
                }) async {
                  recordedStatuses.add(
                    CompletionStatusX.fromWireName(
                      metadata?['completion_status']?.toString() ??
                          metadata?['status']?.toString(),
                    ),
                  );
                },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ritual Skipped'));
        await tester.pumpAndSettle();

        final hapticCalls = _capturePlatformHaptics(tester);

        await tester.tap(find.text('Skipped').last);
        await tester.pump();
        await tester.pump(kCalendarCompletionFeedbackDelay);
        await tester.pump(const Duration(milliseconds: 140));

        expect(recordedStatuses, <CompletionStatus>[CompletionStatus.skipped]);
        expect(appendedBadges, hasLength(1));
        expect(_ritualPulseMode(tester), 'skipped');
        expect(_ritualRimIntensity(tester), greaterThan(0));
        expect(_ritualPulsePaintsFill(tester), isFalse);
        expect(
          _hapticArguments(hapticCalls),
          contains('HapticFeedbackType.lightImpact'),
        );
      },
    );

    testWidgets('restored flow completion state does not pulse the card', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      SharedPreferences.setMockInitialValues(<String, Object>{
        'calendar_completion:local:cid:cid-ritual-restored': 'observed',
      });

      await tester.pumpWidget(
        _DayViewHarness(
          notes: [
            _timedNote(
              clientEventId: 'cid-ritual-restored',
              title: 'Ritual Restored',
              startHour: 10,
              startMinute: 0,
              endHour: 11,
              endMinute: 0,
              flowId: 1,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ritual Restored'));
      await tester.pumpAndSettle();

      expect(find.text('Observed'), findsWidgets);
      expect(_ritualRimIntensity(tester), 0);
      expect(_ritualPulsePaintsFill(tester), isFalse);
    });

    testWidgets(
      'flow event notification restoration opens the matching detail sheet',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _RestoredDetailGridHarness(
            notes: [
              _timedNote(
                clientEventId: 'cid-flow-target',
                title: 'Dawn Practice',
                startHour: 6,
                startMinute: 0,
                endHour: 6,
                endMinute: 30,
                flowId: 42,
              ),
              _timedNote(
                clientEventId: 'cid-flow-other',
                title: 'Evening Practice',
                startHour: 18,
                startMinute: 0,
                endHour: 18,
                endMinute: 30,
                flowId: 42,
              ),
            ],
            flowIndex: const {
              42: FlowData(
                id: 42,
                name: 'Daily Practice Flow',
                color: Colors.green,
                active: true,
              ),
            },
            restoration: const EventDetailRestorationState(
              kYear: 1,
              kMonth: 1,
              kDay: 1,
              identityType: eventDetailIdentityClientEventId,
              identityValue: 'cid-flow-target',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Dawn Practice'), findsWidgets);
        expect(find.text('6:00 AM – 6:30 AM'), findsOneWidget);
        expect(find.text('Daily Practice Flow'), findsWidgets);
        expect(find.text('New Event'), findsNothing);
      },
    );

    testWidgets(
      'note notification restoration opens existing note detail, not creation',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _RestoredDetailGridHarness(
            notes: [
              _timedNote(
                id: 'event-note-target',
                clientEventId: 'cid-note-target',
                title: 'Existing Note',
                startHour: 10,
                startMinute: 0,
                endHour: 10,
                endMinute: 45,
              ),
            ],
            restoration: const EventDetailRestorationState(
              kYear: 1,
              kMonth: 1,
              kDay: 1,
              identityType: eventDetailIdentityClientEventId,
              identityValue: 'cid-note-target',
            ),
            onDeleteNote: (_, _, _, _) async {},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Existing Note'), findsWidgets);
        expect(find.text('10:00 AM – 10:45 AM'), findsOneWidget);
        expect(find.text('Add reflection'), findsOneWidget);
        expect(find.text('End Note'), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('End Note'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.text('New Event'), findsNothing);
      },
    );

    testWidgets(
      'reminder notification restoration opens the matching reminder detail',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _RestoredDetailGridHarness(
            notes: [
              _timedReminderNote(
                clientEventId: 'cid-reminder-target',
                reminderId: 'reminder-target',
                title: 'Hydrate',
                startHour: 9,
              ),
              _timedReminderNote(
                clientEventId: 'cid-reminder-other',
                reminderId: 'reminder-other',
                title: 'Stretch',
                startHour: 10,
              ),
            ],
            restoration: const EventDetailRestorationState(
              kYear: 1,
              kMonth: 1,
              kDay: 1,
              identityType: eventDetailIdentityReminderId,
              identityValue: 'reminder-target',
            ),
            onEndReminder: (_) async {},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Hydrate'), findsWidgets);
        expect(find.text('9:00 AM – 9:30 AM'), findsOneWidget);
        expect(find.text('Add reflection'), findsOneWidget);
        expect(find.text('End Reminder'), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('End Reminder'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.text('Stretch'), findsOneWidget);
        expect(find.text('New Event'), findsNothing);
      },
    );

    testWidgets(
      'reminder detail separates occurrence deletion from ending the rule',
      (tester) async {
        await _setPhoneViewport(tester);
        EventItem? deletedOccurrence;

        await tester.pumpWidget(
          _RestoredDetailGridHarness(
            notes: [
              _timedReminderNote(
                clientEventId: 'reminder:reminder-delete-one:2026-08-15',
                reminderId: 'reminder-delete-one',
                title: 'Journal every day',
                startHour: 9,
              ),
            ],
            restoration: const EventDetailRestorationState(
              kYear: 1,
              kMonth: 1,
              kDay: 1,
              identityType: eventDetailIdentityReminderId,
              identityValue: 'reminder-delete-one',
            ),
            onDeleteNote: (_, _, _, event) async {
              deletedOccurrence = event;
            },
            onEndReminder: (_) async {},
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('Delete Occurrence'), findsOneWidget);
        expect(find.text('End Reminder'), findsOneWidget);

        await tester.tap(find.text('Delete Occurrence'));
        await tester.pumpAndSettle();

        expect(deletedOccurrence, isNotNull);
        expect(
          deletedOccurrence!.clientEventId,
          'reminder:reminder-delete-one:2026-08-15',
        );
      },
    );

    testWidgets('generic new-note UI still invokes the create-note action', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      var openedCreateNote = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DayViewPage(
            initialKy: 1,
            initialKm: 1,
            initialKd: 1,
            showGregorian: false,
            notesForDay: (_, _, _) => const <NoteData>[],
            flowIndex: const {},
            getMonthName: _gregorianMonthName,
            onOpenQuickAdd: (_) async {
              openedCreateNote = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('New note'));
      await tester.pumpAndSettle();

      expect(openedCreateNote, isTrue);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets(
      'header new-note action opens quick add from the current Day View',
      (tester) async {
        await _setPhoneViewport(tester);
        final openedDates = <({int ky, int km, int kd})>[];
        var openedQuickAdd = false;

        await tester.pumpWidget(
          MaterialApp(
            home: DayViewPage(
              initialKy: 6268,
              initialKm: 2,
              initialKd: 5,
              showGregorian: false,
              notesForDay: (_, _, _) => const <NoteData>[],
              flowIndex: const {},
              getMonthName: _gregorianMonthName,
              onOpenQuickAdd: (_) async {
                openedQuickAdd = true;
              },
              onAddNote: (ky, km, kd) {
                openedDates.add((ky: ky, km: km, kd: kd));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('New note'));
        await tester.pumpAndSettle();

        expect(openedQuickAdd, isTrue);
        expect(openedDates, isEmpty);

        openedQuickAdd = false;

        await tester.pumpWidget(
          MaterialApp(
            home: DayViewPage(
              initialKy: 6268,
              initialKm: 2,
              initialKd: 6,
              showGregorian: false,
              notesForDay: (_, _, _) => const <NoteData>[],
              flowIndex: const {},
              getMonthName: _gregorianMonthName,
              onOpenQuickAdd: (_) async {
                openedQuickAdd = true;
              },
              onAddNote: (ky, km, kd) {
                openedDates.add((ky: ky, km: km, kd: kd));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('New note'));
        await tester.pumpAndSettle();

        expect(openedQuickAdd, isTrue);
        expect(openedDates, isEmpty);
      },
    );

    testWidgets(
      'Day Sheet event request opens detail on the existing Day View without a page push',
      (tester) async {
        await _setPhoneViewport(tester);
        final request = ValueNotifier<DayViewSheetEventTarget?>(null);
        addTearDown(request.dispose);
        final observer = _PagePushCountingNavigatorObserver();
        final note = _timedNote(
          id: 'sheet-note-1',
          clientEventId: 'sheet-note-client-1',
          title: 'Sheet Note Target',
          startHour: 10,
          startMinute: 0,
          endHour: 11,
          endMinute: 0,
        );

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [observer],
            home: DayViewPage(
              initialKy: 1,
              initialKm: 1,
              initialKd: 1,
              showGregorian: false,
              notesForDay: (_, _, _) => [note],
              flowIndex: const {},
              getMonthName: _gregorianMonthName,
              eventDetailRequestListenable: request,
              onEventDetailRequestHandled: () {
                request.value = null;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        observer.reset();

        request.value = DayViewSheetEventTarget(
          ky: 1,
          km: 1,
          kd: 1,
          event: _eventFromNote(note),
        );
        await tester.pumpAndSettle();

        expect(observer.pagePushCount, 0);
        expect(request.value, isNull);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Sheet Note Target'), findsWidgets);
      },
    );

    testWidgets(
      'Day Sheet event request changes the existing Day View date without a page push',
      (tester) async {
        await _setPhoneViewport(tester);
        final request = ValueNotifier<DayViewSheetEventTarget?>(null);
        addTearDown(request.dispose);
        final observer = _PagePushCountingNavigatorObserver();
        final dayOneNote = _timedNote(
          id: 'sheet-note-day-1',
          clientEventId: 'sheet-note-client-day-1',
          title: 'Day One Note',
          startHour: 8,
          startMinute: 0,
          endHour: 9,
          endMinute: 0,
        );
        final dayTwoNote = _timedNote(
          id: 'sheet-note-day-2',
          clientEventId: 'sheet-note-client-day-2',
          title: 'Day Two Note',
          startHour: 14,
          startMinute: 0,
          endHour: 15,
          endMinute: 0,
        );

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [observer],
            home: DayViewPage(
              initialKy: 1,
              initialKm: 1,
              initialKd: 1,
              showGregorian: false,
              notesForDay: (ky, km, kd) =>
                  kd == 2 ? [dayTwoNote] : [dayOneNote],
              flowIndex: const {},
              getMonthName: _gregorianMonthName,
              eventDetailRequestListenable: request,
              onEventDetailRequestHandled: () {
                request.value = null;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        observer.reset();

        request.value = DayViewSheetEventTarget(
          ky: 1,
          km: 1,
          kd: 2,
          event: _eventFromNote(dayTwoNote),
        );
        await tester.pumpAndSettle();

        expect(observer.pagePushCount, 0);
        expect(request.value, isNull);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Day Two Note'), findsWidgets);
      },
    );

    testWidgets(
      'tap consumes echoed detail restoration state without opening a second sheet',
      (tester) async {
        await _setPhoneViewport(tester);
        CalendarEventDetailSheetCoordinator.debugResetForTests();

        final restoration = ValueNotifier<EventDetailRestorationState?>(null);
        var disposed = false;
        addTearDown(() {
          disposed = true;
          restoration.dispose();
          CalendarEventDetailSheetCoordinator.debugResetForTests();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<EventDetailRestorationState?>(
                valueListenable: restoration,
                builder: (context, eventDetail, _) {
                  return DayViewGrid(
                    ky: 1,
                    km: 1,
                    kd: 1,
                    notes: [
                      _timedNote(
                        clientEventId: 'cid-focus',
                        title: 'Focus Block',
                        startHour: 10,
                        startMinute: 0,
                        endHour: 11,
                        endMinute: 0,
                      ),
                    ],
                    showGregorian: false,
                    flowIndex: const {},
                    initialScrollOffset: 9 * 60,
                    initialEventDetailRestorationState: eventDetail,
                    onEventDetailRestorationChanged: (state) {
                      if (!disposed) {
                        restoration.value = state;
                      }
                    },
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Focus Block'));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('10:00 AM – 11:00 AM'), findsOneWidget);
        expect(find.text('Make to-do'), findsOneWidget);
      },
    );

    testWidgets(
      'detail sheet refreshes stale event data before showing time and share actions',
      (tester) async {
        await _setPhoneViewport(tester);

        final notes = ValueNotifier<List<NoteData>>([
          _timedNote(
            title: 'Focus Block',
            startHour: 10,
            startMinute: 0,
            endHour: 11,
            endMinute: 0,
            clientEventId: 'cid-focus',
          ),
        ]);
        final dataVersion = ValueNotifier<int>(0);
        EventItem? sharedEvent;

        addTearDown(() {
          notes.dispose();
          dataVersion.dispose();
        });

        await tester.pumpWidget(
          _MutableDayViewHarness(
            notes: notes,
            dataVersion: dataVersion,
            onShareNote: (event) async {
              sharedEvent = event;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Focus Block'));
        await tester.pumpAndSettle();

        expect(find.text('10:00 AM – 11:00 AM'), findsOneWidget);

        notes.value = [
          _timedNote(
            id: 'evt-focus',
            clientEventId: 'cid-focus',
            title: 'Focus Block',
            startHour: 13,
            startMinute: 0,
            endHour: 14,
            endMinute: 0,
          ),
        ];
        dataVersion.value++;
        await tester.pumpAndSettle();

        expect(find.text('1:00 PM – 2:00 PM'), findsOneWidget);
        expect(find.text('Make to-do'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Share Note'), findsOneWidget);
        await tester.tap(find.text('Share Note'));
        await tester.pumpAndSettle();

        expect(sharedEvent, isNotNull);
        expect(sharedEvent!.id, 'evt-focus');
        expect(sharedEvent!.clientEventId, 'cid-focus');
        expect(sharedEvent!.startMin, 13 * 60);
        expect(sharedEvent!.endMin, 14 * 60);
      },
    );

    testWidgets(
      'detail sheet survives source grid disposal and notifier rebuilds',
      (tester) async {
        await _setPhoneViewport(tester);

        final showGrid = ValueNotifier<bool>(true);
        final dataVersion = ValueNotifier<int>(0);

        addTearDown(() {
          showGrid.dispose();
          dataVersion.dispose();
        });

        await tester.pumpWidget(
          _SheetPersistenceHarness(
            showGrid: showGrid,
            dataVersion: dataVersion,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Flow Block'));
        await tester.pumpAndSettle();

        expect(find.text('Add reflection'), findsOneWidget);
        expect(find.text('End Flow'), findsNothing);

        showGrid.value = false;
        await tester.pump();

        dataVersion.value++;
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Add reflection'), findsOneWidget);
        expect(find.text('End Flow'), findsNothing);
      },
    );

    testWidgets(
      'detail sheet keeps inactive chrome flow ending out of the primary slot',
      (tester) async {
        await _setPhoneViewport(tester);
        int? endedFlowId;

        await tester.pumpWidget(
          _DayViewHarness(
            notes: const [
              NoteData(
                title: 'Archived Practice',
                allDay: false,
                start: TimeOfDay(hour: 10, minute: 0),
                end: TimeOfDay(hour: 11, minute: 0),
                flowId: 9,
              ),
            ],
            flowIndex: const {
              9: FlowData(
                id: 9,
                name: 'Archived Practice Flow',
                color: Colors.green,
                active: false,
              ),
            },
            activeLedgerFlowIds: const <int>{},
            onEndFlow: (flowId) async {
              endedFlowId = flowId;
              return EndFlowOutcome.success(operationId: 'inactive-unused');
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Archived Practice'));
        await tester.pumpAndSettle();

        expect(find.text('Archived Practice Flow'), findsWidgets);
        expect(find.text('Make to-do'), findsOneWidget);
        expect(find.text('Share Flow'), findsNothing);
        expect(find.text('Add reflection'), findsOneWidget);
        expect(find.text('End Flow'), findsNothing);
        expect(find.text('End Note'), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Share Flow'), findsOneWidget);
        expect(find.text('End Flow'), findsNothing);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(endedFlowId, isNull);
      },
    );

    testWidgets(
      'detail sheet keeps End Flow in overflow for active chrome flows outside the active ledger',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _DayViewHarness(
            notes: const [
              NoteData(
                title: 'Evening Reflection',
                allDay: false,
                start: TimeOfDay(hour: 20, minute: 0),
                end: TimeOfDay(hour: 20, minute: 12),
                flowId: 11,
              ),
            ],
            flowIndex: {
              11: FlowData(
                id: 11,
                name: 'Cooking and Art Mastery',
                color: Colors.teal,
                active: true,
              ),
            },
            activeLedgerFlowIds: const <int>{},
            onEndFlow: (_) async =>
                EndFlowOutcome.success(operationId: 'active-overflow'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Evening Reflection'));
        await tester.pumpAndSettle();

        expect(find.text('Cooking and Art Mastery'), findsWidgets);
        expect(find.text('Make to-do'), findsOneWidget);
        expect(find.text('Share Flow'), findsNothing);
        expect(find.text('Add reflection'), findsOneWidget);
        expect(find.text('End Flow'), findsNothing);
        expect(find.text('End Note'), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Share Flow'), findsOneWidget);
        expect(find.text('End Flow'), findsOneWidget);
      },
    );

    testWidgets('End Flow dismisses before its owner completes', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      int? endedFlowId;
      final endResult = Completer<EndFlowOutcome>();

      await tester.pumpWidget(
        _DayViewHarness(
          notes: [
            _timedNote(
              title: 'Local Flow',
              startHour: 10,
              startMinute: 0,
              endHour: 11,
              endMinute: 0,
              flowId: 1,
            ),
          ],
          onEndFlow: (flowId) {
            endedFlowId = flowId;
            return endResult.future;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Local Flow'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Flow'));
      await tester.pumpAndSettle();

      expect(endedFlowId, 1);
      expect(find.text('Add reflection'), findsNothing);
      expect(find.byType(CalendarEventDetailSheet), findsNothing);

      endResult.complete(EndFlowOutcome.success(operationId: 'sheet-ok'));
      await tester.pumpAndSettle();

      expect(find.text('Add reflection'), findsNothing);
    });

    testWidgets(
      'End Flow applies optimistic removal and reveals the successor',
      (tester) async {
        await _setPhoneViewport(tester);
        final endResult = Completer<EndFlowOutcome>();

        await tester.pumpWidget(
          _OptimisticEndFlowHarness(onEndFlow: (_) => endResult.future),
        );
        await tester.pumpAndSettle();
        final timeline = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final initialOffset = timeline.position.pixels;

        await tester.tap(find.text('Ending Flow Event'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('End Flow'));
        await tester.pumpAndSettle();

        expect(find.byType(CalendarEventDetailSheet), findsNothing);
        expect(find.text('Ending Flow Event'), findsNothing);
        expect(find.text('Same Flow Later'), findsNothing);
        expect(find.text('Successor Event'), findsOneWidget);
        expect(timeline.position.pixels, greaterThan(initialOffset));

        endResult.complete(EndFlowOutcome.success(operationId: 'optimistic'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'failed End Flow keeps the sheet closed and reports at the root',
      (tester) async {
        await _setPhoneViewport(tester);
        final endResult = Completer<EndFlowOutcome>();
        int? endedFlowId;

        await tester.pumpWidget(
          _DayViewHarness(
            notes: [
              _timedNote(
                title: 'Rollback Flow',
                startHour: 10,
                startMinute: 0,
                endHour: 11,
                endMinute: 0,
                flowId: 1,
              ),
            ],
            initialScrollOffset: 8 * 60,
            onEndFlow: (flowId) {
              endedFlowId = flowId;
              return endResult.future;
            },
          ),
        );
        await tester.pumpAndSettle();

        final timeline = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final anchor = timeline.position.pixels;

        await tester.tap(find.text('Rollback Flow'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('End Flow'));
        await tester.pumpAndSettle();

        expect(endedFlowId, 1);
        expect(find.byType(CalendarEventDetailSheet), findsNothing);
        timeline.position.jumpTo(anchor + 120);
        await tester.pump();

        endResult.complete(
          EndFlowOutcome.failure(
            operationId: 'rollback-op',
            failureKind: EndFlowFailureKind.transport,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(timeline.position.pixels, closeTo(anchor + 120, 0.001));
        expect(find.text('Add reflection'), findsNothing);
        expect(
          find.textContaining('Couldn’t reach the server.'),
          findsOneWidget,
        );
        expect(find.text('Copy diagnostics'), findsOneWidget);
      },
    );

    testWidgets('failed End Flow does not undo a manual pending scroll', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      final endResult = Completer<EndFlowOutcome>();

      await tester.pumpWidget(
        _DayViewHarness(
          notes: [
            _timedNote(
              title: 'Manual Scroll Flow',
              startHour: 10,
              startMinute: 0,
              endHour: 11,
              endMinute: 0,
              flowId: 1,
            ),
          ],
          initialScrollOffset: 8 * 60,
          onEndFlow: (_) => endResult.future,
        ),
      );
      await tester.pumpAndSettle();

      final timeline = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Manual Scroll Flow'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Flow'));
      await tester.pump();

      await tester.drag(
        find.byKey(const PageStorageKey<String>('day_timeline_list')),
        const Offset(0, -140),
      );
      await tester.pumpAndSettle();
      final userOffset = timeline.position.pixels;

      endResult.complete(
        EndFlowOutcome.failure(
          operationId: 'manual-scroll-op',
          failureKind: EndFlowFailureKind.server,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(timeline.position.pixels, closeTo(userOffset, 0.001));
    });

    testWidgets('pending End Flow can finish after leaving the Day View', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      final showGrid = ValueNotifier<bool>(true);
      final dataVersion = ValueNotifier<int>(0);
      final endResult = Completer<EndFlowOutcome>();
      addTearDown(() {
        showGrid.dispose();
        dataVersion.dispose();
      });

      await tester.pumpWidget(
        _SheetPersistenceHarness(
          showGrid: showGrid,
          dataVersion: dataVersion,
          onEndFlow: (_) => endResult.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flow Block'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Flow'));
      await tester.pump();

      showGrid.value = false;
      await tester.pump();
      endResult.complete(
        EndFlowOutcome.failure(
          operationId: 'left-route-op',
          failureKind: EndFlowFailureKind.transport,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Couldn’t reach the server.'), findsOneWidget);
    });

    testWidgets('overlapping End Flow failures do not steal timeline focus', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      final firstResult = Completer<EndFlowOutcome>();
      final secondResult = Completer<EndFlowOutcome>();

      await tester.pumpWidget(
        _DayViewHarness(
          notes: [
            _timedNote(
              title: 'First Pending Flow',
              startHour: 10,
              startMinute: 0,
              endHour: 11,
              endMinute: 0,
              flowId: 1,
            ),
            _timedNote(
              title: 'Second Pending Flow',
              startHour: 12,
              startMinute: 0,
              endHour: 13,
              endMinute: 0,
              flowId: 2,
            ),
          ],
          initialScrollOffset: 8 * 60,
          onEndFlow: (flowId) => switch (flowId) {
            1 => firstResult.future,
            2 => secondResult.future,
            _ => throw StateError('Unexpected flow $flowId'),
          },
        ),
      );
      await tester.pumpAndSettle();
      final timeline = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      await tester.tap(find.text('First Pending Flow'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Flow'));
      await tester.pump();
      timeline.position.jumpTo(650);
      await tester.pump();
      await tester.tap(find.text('Second Pending Flow'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Flow'));
      await tester.pump();

      timeline.position.jumpTo(300);
      firstResult.complete(
        EndFlowOutcome.failure(
          operationId: 'first-overlap-op',
          failureKind: EndFlowFailureKind.server,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(timeline.position.pixels, closeTo(300, 0.001));

      secondResult.complete(
        EndFlowOutcome.failure(
          operationId: 'second-overlap-op',
          failureKind: EndFlowFailureKind.transport,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(timeline.position.pixels, closeTo(300, 0.001));
    });

    testWidgets('Living Text CTA routes to fixed node slug from payload', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        _DayViewRouterHarness(
          notes: [
            _livingTextNote(
              title: 'Living Text 4: Add Your First Reflection',
              label: 'Add your insight',
              nodeSlug: 'ptah',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Living Text 4: Add Your First Reflection'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add your insight'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add your insight'));
      await tester.pumpAndSettle();

      expect(find.text('Node target: ptah action:add_insight'), findsOneWidget);
    });

    testWidgets(
      'Living Text CTA routes to stored Day 1 slug when payload is null',
      (tester) async {
        await _setPhoneViewport(tester);
        await const LivingTextDayOneNodeStore().writeSlug(
          userId: 'local',
          flowInstanceId: '77',
          nodeSlug: 'maat',
        );

        await tester.pumpWidget(
          _DayViewRouterHarness(
            notes: [
              _livingTextNote(
                title: 'Living Text 4: Add Your First Reflection',
                label: 'Add your insight',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Living Text 4: Add Your First Reflection'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Add your insight'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add your insight'));
        await tester.pumpAndSettle();

        expect(
          find.text('Node target: maat action:add_insight'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Living Text CTA falls back to Library root without Day 1 slug',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          _DayViewRouterHarness(
            notes: [
              _livingTextNote(
                title: 'Living Text 7: Return to Day 1’s Entry',
                label: 'Revise your insight',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Living Text 7: Return to Day 1’s Entry'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Choose the Day 1 entry you read, then open Your Insights.',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Revise your insight'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Revise your insight'));
        await tester.pumpAndSettle();

        expect(find.text('Library root'), findsOneWidget);
      },
    );

    testWidgets('event without library CTA does not render CTA panel', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        _DayViewRouterHarness(
          notes: [
            _timedNote(
              clientEventId: 'the-living-text:77:event-3',
              title: 'Living Text 3: Find What You Don’t Understand',
              startHour: 10,
              startMinute: 0,
              endHour: 10,
              endMinute: 30,
              flowId: 77,
              behaviorPayload: const <String, dynamic>{
                'flow_key': kLivingTextFlowKey,
                'event_number': 3,
              },
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Living Text 3: Find What You Don’t Understand'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add your insight'), findsNothing);
      expect(find.text('Library'), findsNothing);
    });

    testWidgets(
      'detail sheet keeps a stable height when paging through same-sized reminders',
      (tester) async {
        await _setPhoneViewport(tester);

        final notes = [
          _timedReminderNote(
            clientEventId: 'cid-reminder-1',
            reminderId: 'reminder-family-salon-1',
            title: 'Family Salon A',
            startHour: 10,
          ),
          _timedReminderNote(
            clientEventId: 'cid-reminder-2',
            reminderId: 'reminder-family-salon-2',
            title: 'Family Salon B',
            startHour: 11,
          ),
          _timedReminderNote(
            clientEventId: 'cid-reminder-3',
            reminderId: 'reminder-family-salon-3',
            title: 'Family Salon C',
            startHour: 12,
          ),
          _timedReminderNote(
            clientEventId: 'cid-reminder-4',
            reminderId: 'reminder-family-salon-4',
            title: 'Family Salon D',
            startHour: 13,
          ),
        ];

        await tester.pumpWidget(_PagedReminderDayViewHarness(notes: notes));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Family Salon B'));
        await tester.pumpAndSettle();

        final initialHeight = _detailSheetPageHeight(tester);
        expect(find.text('Family Salon B'), findsWidgets);

        await tester.drag(find.byType(PageView), const Offset(-320, 0));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(PageView), const Offset(-320, 0));
        await tester.pumpAndSettle();

        final finalHeight = _detailSheetPageHeight(tester);
        expect(find.text('Family Salon D'), findsWidgets);
        expect(finalHeight, closeTo(initialHeight, 0.01));
      },
    );

    testWidgets(
      'reminder detail sheet exposes make todo and shares from the menu',
      (tester) async {
        await _setPhoneViewport(tester);
        EventItem? sharedReminder;

        await tester.pumpWidget(
          _PagedReminderDayViewHarness(
            notes: [
              _timedReminderNote(
                clientEventId: 'cid-reminder-share',
                reminderId: 'reminder-share',
                title: 'Journal every day',
                startHour: 10,
              ),
            ],
            onShareReminder: (event) async {
              sharedReminder = event;
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Journal every day'));
        await tester.pumpAndSettle();

        expect(find.text('Make to-do'), findsOneWidget);
        expect(find.text('Share Reminder'), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text('Share Reminder'), findsOneWidget);
        await tester.tap(find.text('Share Reminder'));
        await tester.pumpAndSettle();

        expect(sharedReminder, isNotNull);
        expect(sharedReminder!.title, 'Journal every day');
        expect(sharedReminder!.reminderId, 'reminder-share');
      },
    );
  });

  group('DayViewPage header toggle', () {
    testWidgets('close button dismisses a pushed day view route', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      final closeEvents = <String>[];
      var userCloseReported = false;
      var lateRestorationReports = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (routeContext) => DayViewPage(
                          initialKy: 1,
                          initialKm: 2,
                          initialKd: 5,
                          showGregorian: false,
                          notesForDay: (ky, km, kd) => const [],
                          flowIndex: const {},
                          getMonthName: (month) => 'Month $month',
                          onUserClose: () async {
                            userCloseReported = true;
                            closeEvents.add('userClose');
                          },
                          onClose: () {
                            closeEvents.add('close');
                            Navigator.of(routeContext).pop();
                          },
                          onRestorationStateChanged:
                              ({
                                required int kYear,
                                required int kMonth,
                                required int kDay,
                                required bool showGregorian,
                                int? firstVisibleMinute,
                                double? scrollOffset,
                                EventDetailRestorationState? eventDetail,
                              }) {
                                if (userCloseReported) {
                                  lateRestorationReports += 1;
                                }
                              },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open day view'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open day view'));
      await tester.pumpAndSettle();

      expect(find.byType(DayViewPage), findsOneWidget);
      expect(find.text('Open day view'), findsNothing);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DayViewPage), findsNothing);
      expect(find.text('Open day view'), findsOneWidget);
      expect(closeEvents, <String>['userClose', 'close']);
      expect(lateRestorationReports, 0);
    });

    testWidgets(
      'day view uses floating shortcuts without a header Today action',
      (tester) async {
        await _setPhoneViewport(tester);

        var calendarTaps = 0;
        var inboxTaps = 0;
        final priorDay = KemeticMath.fromGregorian(
          DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 2)),
        );
        final today = KemeticMath.fromGregorian(
          DateUtils.dateOnly(DateTime.now()),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DayViewPage(
              initialKy: priorDay.kYear,
              initialKm: priorDay.kMonth,
              initialKd: priorDay.kDay,
              showGregorian: false,
              notesForDay: (ky, km, kd) => const [],
              flowIndex: const {},
              getMonthName: (month) => 'Month $month',
              onOpenCalendars: () => calendarTaps += 1,
              onOpenInbox: () => inboxTaps += 1,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip('Menu'), findsNothing);
        expect(find.byIcon(Icons.more_vert), findsNothing);
        expect(find.byTooltip('New note'), findsOneWidget);
        expect(find.byTooltip('Search notes'), findsOneWidget);
        expect(find.byTooltip('Today'), findsNothing);
        expect(find.bySemanticsLabel('Today'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(KemeticDayViewHeader),
            matching: find.byTooltip('Today'),
          ),
          findsNothing,
        );
        expect(find.byTooltip('My Profile'), findsOneWidget);
        expect(find.byKey(calendarFloatingTodaySurfaceKey), findsOneWidget);
        expect(find.byKey(calendarFloatingCalendarsButtonKey), findsOneWidget);
        expect(find.byKey(calendarFloatingInboxButtonKey), findsOneWidget);

        await tester.tap(find.byKey(calendarFloatingCalendarsButtonKey));
        await tester.tap(find.byKey(calendarFloatingInboxButtonKey));
        expect(calendarTaps, 1);
        expect(inboxTaps, 1);

        await tester.tap(find.byKey(calendarFloatingTodaySurfaceKey));
        await tester.pumpAndSettle();

        final header = tester.widget<KemeticDayViewHeader>(
          find.byType(KemeticDayViewHeader),
        );
        expect(header.currentKy, today.kYear);
        expect(header.currentKm, today.kMonth);
        expect(header.currentKd, today.kDay);
        expect(find.byType(DayViewPage), findsOneWidget);
      },
    );

    testWidgets(
      'Today on the current day centers now without replacing the grid',
      (tester) async {
        await _setPhoneViewport(tester);
        final today = KemeticMath.fromGregorian(
          DateUtils.dateOnly(DateTime.now()),
        );
        await _pumpDayViewPage(
          tester,
          ky: today.kYear,
          km: today.kMonth,
          kd: today.kDay,
        );

        final gridState = tester.state(_todayGridFinder());
        final timeline = _todayTimelineScrollable(tester);
        final awayOffset = timeline.position.pixels < 200
            ? timeline.position.maxScrollExtent
            : 0.0;
        timeline.position.jumpTo(awayOffset);
        await tester.pump();
        expect(timeline.position.pixels, closeTo(awayOffset, 0.5));

        await tester.tap(find.byKey(calendarFloatingTodaySurfaceKey));
        await tester.pumpAndSettle();

        expect(identical(tester.state(_todayGridFinder()), gridState), isTrue);
        final header = tester.widget<KemeticDayViewHeader>(
          find.byType(KemeticDayViewHeader),
        );
        expect(header.currentKy, today.kYear);
        expect(header.currentKm, today.kMonth);
        expect(header.currentKd, today.kDay);
        _expectTimelineCenteredOnNow(tester);
      },
    );

    testWidgets(
      'explicit Today tap ignores a stale initialFirstVisibleMinute',
      (tester) async {
        await _setPhoneViewport(tester);
        final today = KemeticMath.fromGregorian(
          DateUtils.dateOnly(DateTime.now()),
        );
        final staleMinute = _staleMinuteFarFromTodayTarget();
        await _pumpDayViewPage(
          tester,
          ky: today.kYear,
          km: today.kMonth,
          kd: today.kDay,
          initialFirstVisibleMinute: staleMinute,
        );

        expect(
          _todayTimelineScrollable(tester).position.pixels,
          closeTo(staleMinute.toDouble(), 0.5),
        );

        await tester.tap(find.byKey(calendarFloatingTodaySurfaceKey));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 600));

        final pixels = _todayTimelineScrollable(tester).position.pixels;
        expect(pixels, isNot(closeTo(staleMinute.toDouble(), 30)));
        _expectTimelineCenteredOnNow(tester);
      },
    );

    testWidgets('opening Day View still restores initialFirstVisibleMinute', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      final today = KemeticMath.fromGregorian(
        DateUtils.dateOnly(DateTime.now()),
      );
      const restoredMinute = 3 * 60;
      await _pumpDayViewPage(
        tester,
        ky: today.kYear,
        km: today.kMonth,
        kd: today.kDay,
        initialFirstVisibleMinute: restoredMinute,
      );

      expect(
        _todayTimelineScrollable(tester).position.pixels,
        closeTo(restoredMinute.toDouble(), 0.5),
      );
      final header = tester.widget<KemeticDayViewHeader>(
        find.byType(KemeticDayViewHeader),
      );
      expect(header.currentKy, today.kYear);
      expect(header.currentKm, today.kMonth);
      expect(header.currentKd, today.kDay);
    });

    testWidgets(
      'Today from another day reaches today and centers current time',
      (tester) async {
        await _setPhoneViewport(tester);
        final priorDay = KemeticMath.fromGregorian(
          DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 2)),
        );
        final today = KemeticMath.fromGregorian(
          DateUtils.dateOnly(DateTime.now()),
        );
        await _pumpDayViewPage(
          tester,
          ky: priorDay.kYear,
          km: priorDay.kMonth,
          kd: priorDay.kDay,
        );

        await tester.tap(find.byKey(calendarFloatingTodaySurfaceKey));
        await tester.pumpAndSettle();

        final header = tester.widget<KemeticDayViewHeader>(
          find.byType(KemeticDayViewHeader),
        );
        expect(header.currentKy, today.kYear);
        expect(header.currentKm, today.kMonth);
        expect(header.currentKd, today.kDay);
        _expectTimelineCenteredOnNow(tester);
      },
    );

    testWidgets('system back reports user close for restoration clearing', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      var userCloseCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DayViewPage(
                          initialKy: 1,
                          initialKm: 2,
                          initialKd: 5,
                          showGregorian: false,
                          notesForDay: (ky, km, kd) => const [],
                          flowIndex: const {},
                          getMonthName: (month) => 'Month $month',
                          onUserClose: () async {
                            userCloseCalls += 1;
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open day view'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open day view'));
      await tester.pumpAndSettle();

      expect(find.byType(DayViewPage), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(DayViewPage), findsNothing);
      expect(userCloseCalls, 1);
    });

    testWidgets('reopening after user close allows restoration reports again', (
      tester,
    ) async {
      await _setPhoneViewport(tester);
      var openSerial = 0;
      var secondOpenRestorationReports = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    final serial = ++openSerial;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (routeContext) => DayViewPage(
                          initialKy: 1,
                          initialKm: 2,
                          initialKd: 5,
                          showGregorian: false,
                          notesForDay: (ky, km, kd) => const [],
                          flowIndex: const {},
                          getMonthName: (month) => 'Month $month',
                          onUserClose: () async {},
                          onClose: () => Navigator.of(routeContext).pop(),
                          onRestorationStateChanged:
                              ({
                                required int kYear,
                                required int kMonth,
                                required int kDay,
                                required bool showGregorian,
                                int? firstVisibleMinute,
                                double? scrollOffset,
                                EventDetailRestorationState? eventDetail,
                              }) {
                                if (serial == 2) {
                                  secondOpenRestorationReports += 1;
                                }
                              },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open day view'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open day view'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Open day view'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('day_view_month_toggle')));
      await tester.pumpAndSettle();

      expect(find.byType(DayViewPage), findsOneWidget);
      expect(secondOpenRestorationReports, greaterThan(0));
    });

    testWidgets(
      'tapping the month label toggles the day header between Kemetic and Gregorian labels',
      (tester) async {
        await _setPhoneViewport(tester);

        const ky = 1;
        const km = 2;
        const kd = 5;
        final gregorian = KemeticMath.toGregorian(ky, km, kd);

        await tester.pumpWidget(
          MaterialApp(
            home: DayViewPage(
              initialKy: ky,
              initialKm: km,
              initialKd: kd,
              showGregorian: false,
              notesForDay: (_, _, _) => const [],
              flowIndex: const {},
              getMonthName: (month) {
                switch (month) {
                  case 1:
                    return 'Thoth (Tḥwty)';
                  case 2:
                    return 'Paopi (Mnḫt)';
                  default:
                    return 'Month $month';
                }
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final localizations = MaterialLocalizations.of(
          tester.element(find.byType(Scaffold)),
        );
        final gregorianLabel = localizations.formatMediumDate(gregorian);
        final legacyGridHeader =
            '${gregorian.month}/${gregorian.day}/${gregorian.year}';
        final kemeticLabel = 'Paopi 5, ${gregorian.year}';
        final gregorianMonthLabel = _gregorianMonthName(gregorian.month);

        expect(find.text('Paopi (Mnḫt)'), findsOneWidget);
        expect(find.text(kemeticLabel), findsOneWidget);
        expect(find.text(gregorianLabel), findsNothing);
        expect(find.text(legacyGridHeader), findsNothing);

        await tester.tap(find.byKey(const ValueKey('day_view_month_toggle')));
        await tester.pumpAndSettle();

        expect(find.text(gregorianMonthLabel), findsOneWidget);
        expect(find.text(gregorianLabel), findsOneWidget);
        expect(find.text(legacyGridHeader), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is GlossyText &&
                widget.text == gregorianLabel &&
                widget.gradient == blueGloss,
          ),
          findsOneWidget,
        );
        expect(find.text(kemeticLabel), findsNothing);

        await tester.tap(find.byKey(const ValueKey('day_view_month_toggle')));
        await tester.pumpAndSettle();

        expect(find.text('Paopi (Mnḫt)'), findsOneWidget);
        expect(find.text(kemeticLabel), findsOneWidget);
      },
    );

    testWidgets('toggling to Gregorian updates the mini day strip labels too', (
      tester,
    ) async {
      await _setPhoneViewport(tester);

      const ky = 1;
      const km = 2;
      const kd = 5;
      final selectedGregorian = KemeticMath.toGregorian(ky, km, kd);
      final previousGregorian = KemeticMath.toGregorian(ky, km, kd - 1);

      await tester.pumpWidget(
        MaterialApp(
          home: DayViewPage(
            initialKy: ky,
            initialKm: km,
            initialKd: kd,
            showGregorian: false,
            notesForDay: (_, _, _) => const [],
            flowIndex: const {},
            getMonthName: (month) {
              switch (month) {
                case 1:
                  return 'Thoth (Tḥwty)';
                case 2:
                  return 'Paopi (Mnḫt)';
                default:
                  return 'Month $month';
              }
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('$kd'), findsWidgets);
      expect(find.text('${selectedGregorian.day}'), findsNothing);
      expect(find.text('${previousGregorian.day}'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('day_view_month_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('${selectedGregorian.day}'), findsOneWidget);
      expect(find.text('${previousGregorian.day}'), findsOneWidget);
    });

    testWidgets(
      'current day stays centered in the mini date strip by default',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          MaterialApp(
            home: DayViewPage(
              initialKy: 1,
              initialKm: 2,
              initialKd: 10,
              showGregorian: false,
              notesForDay: (_, _, _) => const [],
              flowIndex: const {},
              getMonthName: (month) => 'Month $month',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .getCenter(find.byKey(const ValueKey('day_view_mini_chip_10')))
              .dx,
          closeTo(_screenCenterX(tester), 1.0),
        );

        await tester.drag(find.byType(PageView), const Offset(-320, 0));
        await tester.pumpAndSettle();

        expect(
          tester
              .getCenter(find.byKey(const ValueKey('day_view_mini_chip_11')))
              .dx,
          closeTo(_screenCenterX(tester), 1.0),
        );
      },
    );

    testWidgets(
      'manual mini date strip movement disables further auto-centering',
      (tester) async {
        await _setPhoneViewport(tester);

        await tester.pumpWidget(
          MaterialApp(
            home: DayViewPage(
              initialKy: 1,
              initialKm: 2,
              initialKd: 10,
              showGregorian: false,
              notesForDay: (_, _, _) => const [],
              flowIndex: const {},
              getMonthName: (month) => 'Month $month',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(
          find.byKey(const ValueKey('day_view_mini_calendar')),
          const Offset(-120, 0),
        );
        await tester.pumpAndSettle();

        final screenCenter = _screenCenterX(tester);
        expect(
          (tester
                      .getCenter(
                        find.byKey(const ValueKey('day_view_mini_chip_10')),
                      )
                      .dx -
                  screenCenter)
              .abs(),
          greaterThan(40.0),
        );

        await tester.drag(find.byType(PageView), const Offset(-320, 0));
        await tester.pumpAndSettle();

        expect(
          (tester
                      .getCenter(
                        find.byKey(const ValueKey('day_view_mini_chip_11')),
                      )
                      .dx -
                  screenCenter)
              .abs(),
          greaterThan(40.0),
        );
      },
    );
  });

  testWidgets('Event Workspace respects the iOS bottom safe area', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: CalendarEventDetailSheet(
              hostContext: context,
              initialTarget: const DayViewSheetEventTarget(
                ky: 1,
                km: 1,
                kd: 1,
                event: EventItem(
                  clientEventId: 'safe-area-workspace',
                  title: 'Safe Area Workspace',
                  location: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
                  startMin: 10 * 60,
                  endMin: 11 * 60,
                  flowId: -1,
                  color: Colors.blue,
                  allDay: false,
                ),
              ),
              initialPresentation: 'workspace',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Safe Area Workspace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Extend publishes the next-day canonical end and clears expiry', (
    tester,
  ) async {
    await _setPhoneViewport(tester);
    final revision = ValueNotifier<int>(0);
    addTearDown(revision.dispose);
    final initialEnd = DateTime.now().subtract(const Duration(minutes: 1));
    late EventItem liveEvent;
    liveEvent = EventItem(
      id: 'extend-next-day',
      clientEventId: 'extend-next-day-cid',
      title: 'Extend Next Day',
      location: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      startMin: 23 * 60 + 30,
      endMin: 23 * 60 + 58,
      canonicalEnd: initialEnd,
      flowId: -1,
      color: Colors.blue,
      allDay: false,
      hasCanonicalSchedule: true,
    );
    DateTime? capturedNow;
    DateTime? persistedEnd;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: CalendarEventDetailSheet(
              hostContext: context,
              initialTarget: DayViewSheetEventTarget(
                ky: 1,
                km: 1,
                kd: 1,
                event: liveEvent,
              ),
              resolveCurrentEventTarget: (target) => DayViewSheetEventTarget(
                ky: target.ky,
                km: target.km,
                kd: target.kd,
                event: liveEvent,
              ),
              dataVersion: revision,
              initialPresentation: eventWorkspacePresentationWorkspace,
              onRequestEndChange:
                  ({
                    required ky,
                    required km,
                    required kd,
                    required event,
                    required extension,
                  }) async {
                    final today = DateTime.now();
                    capturedNow = DateTime(
                      today.year,
                      today.month,
                      today.day,
                      23,
                      59,
                    );
                    persistedEnd = eventWorkspaceExtendedCanonicalEnd(
                      canonicalStart: DateTime(
                        today.year,
                        today.month,
                        today.day,
                        23,
                        30,
                      ),
                      canonicalEnd: event.canonicalEnd!,
                      wallClockNow: capturedNow!,
                      extension: extension,
                    );
                    liveEvent = EventItem(
                      id: event.id,
                      clientEventId: event.clientEventId,
                      title: event.title,
                      location: event.location,
                      startMin: event.startMin,
                      endMin: persistedEnd!.hour * 60 + persistedEnd!.minute,
                      canonicalEnd: persistedEnd,
                      flowId: event.flowId,
                      color: event.color,
                      allDay: event.allDay,
                      hasCanonicalSchedule: event.hasCanonicalSchedule,
                    );
                    revision.value += 1;
                    return true;
                  },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This event has ended.'), findsOneWidget);
    await tester.tap(find.text('+5 min'));
    await tester.pumpAndSettle();

    expect(persistedEnd, isNotNull);
    expect(persistedEnd!.difference(capturedNow!), const Duration(minutes: 5));
    expect(persistedEnd!.day, capturedNow!.add(const Duration(days: 1)).day);
    expect(liveEvent.canonicalEnd, persistedEnd);
    expect(find.text('This event has ended.'), findsNothing);
    expect(find.textContaining('remaining'), findsOneWidget);
  });
}

String _gregorianMonthName(int month) {
  const monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return monthNames[month - 1];
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpDayViewPage(
  WidgetTester tester, {
  required int ky,
  required int km,
  required int kd,
  int? initialFirstVisibleMinute,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DayViewPage(
        initialKy: ky,
        initialKm: km,
        initialKd: kd,
        showGregorian: false,
        notesForDay: (ky, km, kd) => const [],
        flowIndex: const {},
        getMonthName: (month) => 'Month $month',
        initialFirstVisibleMinute: initialFirstVisibleMinute,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _todayGridFinder() {
  final today = KemeticMath.fromGregorian(DateUtils.dateOnly(DateTime.now()));
  return find.byWidgetPredicate(
    (widget) =>
        widget is DayViewGrid &&
        widget.ky == today.kYear &&
        widget.km == today.kMonth &&
        widget.kd == today.kDay,
  );
}

ScrollableState _todayTimelineScrollable(WidgetTester tester) {
  return tester.state<ScrollableState>(
    find
        .descendant(of: _todayGridFinder(), matching: find.byType(Scrollable))
        .first,
  );
}

int _staleMinuteFarFromTodayTarget() {
  final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
  // Today centers the current time in the viewport, so comparing the stale
  // minute directly with wall-clock minutes can accidentally select the same
  // scroll offset. Pick the opposite half-day instead.
  return nowMin < 12 * 60 ? 12 * 60 : 3 * 60;
}

void _expectTimelineCenteredOnNow(WidgetTester tester) {
  final position = _todayTimelineScrollable(tester).position;
  final now = DateTime.now();
  final nowMin = now.hour * 60 + now.minute + now.second / 60.0;
  final expected = (nowMin - position.viewportDimension * 0.5 + 0.5).clamp(
    0.0,
    position.maxScrollExtent,
  );
  expect(position.pixels, closeTo(expected, 16));
}

Future<void> _setPhoneLandscapeViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(844, 390);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _setTabletLandscapeViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1194, 834);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

NoteData _timedNote({
  String? id,
  String? clientEventId,
  required String title,
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
  int? flowId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return NoteData(
    id: id,
    clientEventId: clientEventId,
    title: title,
    allDay: false,
    start: TimeOfDay(hour: startHour, minute: startMinute),
    end: TimeOfDay(hour: endHour, minute: endMinute),
    flowId: flowId,
    behaviorPayload: behaviorPayload,
  );
}

NoteData _livingTextNote({
  required String title,
  required String label,
  String? nodeSlug,
}) {
  return _timedNote(
    clientEventId: 'the-living-text:77:${title.toLowerCase()}',
    title: title,
    startHour: 10,
    startMinute: 0,
    endHour: 10,
    endMinute: 30,
    flowId: 77,
    behaviorPayload: <String, dynamic>{
      'flow_key': kLivingTextFlowKey,
      'event_number': title.contains(' 7:') ? 7 : 4,
      'library_cta': <String, dynamic>{
        'type': kMaatLibraryCtaAddInsight,
        'node_slug': nodeSlug,
        'label': label,
      },
    },
  );
}

class _PagePushCountingNavigatorObserver extends NavigatorObserver {
  int pagePushCount = 0;

  void reset() {
    pagePushCount = 0;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null && route is MaterialPageRoute<dynamic>) {
      pagePushCount++;
    }
  }
}

NoteData _timedReminderNote({
  required String clientEventId,
  required String reminderId,
  required String title,
  required int startHour,
}) {
  return NoteData(
    clientEventId: clientEventId,
    title: title,
    allDay: false,
    start: TimeOfDay(hour: startHour, minute: 0),
    end: TimeOfDay(hour: startHour, minute: 30),
    isReminder: true,
    reminderId: reminderId,
  );
}

double _detailSheetPageHeight(WidgetTester tester) {
  final sizedBox = find.byWidgetPredicate(
    (widget) => widget is SizedBox && widget.child is PageView,
  );
  return tester.getSize(sizedBox).height;
}

List<MethodCall> _capturePlatformHaptics(WidgetTester tester) {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call);
      }
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  return calls;
}

Iterable<Object?> _hapticArguments(List<MethodCall> calls) {
  return calls.map((call) => call.arguments);
}

Color? _ritualCardFillColor(WidgetTester tester) {
  final containers = tester.widgetList<Container>(
    find.byKey(
      const ValueKey<String>('day-view-ritual-completion-feedback-card'),
    ),
  );
  if (containers.isEmpty) return null;
  final container = containers.last;
  final decoration = container.decoration;
  if (decoration is! BoxDecoration) return null;
  return decoration.color;
}

String _ritualPulseDiagnostics(WidgetTester tester) {
  final painters = tester.widgetList<CustomPaint>(
    find.byKey(
      const ValueKey<String>('day-view-ritual-completion-feedback-rim'),
    ),
  );
  return painters.map((paint) => paint.painter.toString()).join('\n');
}

double _ritualPulseDiagnosticDouble(WidgetTester tester, String field) {
  final diagnostics = _ritualPulseDiagnostics(tester);
  final matches = RegExp('$field: ([0-9.]+)').allMatches(diagnostics);
  return matches.fold<double>(0, (maxValue, match) {
    final value = double.tryParse(match.group(1) ?? '') ?? 0;
    return math.max(maxValue, value);
  });
}

double _ritualRimIntensity(WidgetTester tester) {
  return _ritualPulseDiagnosticDouble(tester, 'rimIntensity');
}

double _ritualPulseFillAlpha(WidgetTester tester) {
  return _ritualPulseDiagnosticDouble(tester, 'fillAlpha');
}

bool _ritualPulsePaintsFill(WidgetTester tester) {
  return _ritualPulseDiagnostics(tester).contains('paintsFill: true');
}

String? _ritualPulseMode(WidgetTester tester) {
  final diagnostics = _ritualPulseDiagnostics(tester);
  return RegExp('mode: ([a-z]+)').firstMatch(diagnostics)?.group(1);
}

double _screenCenterX(WidgetTester tester) =>
    tester.getSize(find.byType(Scaffold)).width / 2;

List<Key?> _dayViewTimelineLayerKeys(WidgetTester tester) {
  final stack = tester.widget<Stack>(find.byKey(dayViewTimelineStackKey));
  return stack.children.map((child) => child.key).toList();
}

const Map<int, FlowData> _defaultFlowIndex = {
  1: FlowData(id: 1, name: 'Practice', color: Colors.green, active: true),
  2: FlowData(id: 2, name: 'Focus', color: Colors.red, active: true),
  3: FlowData(id: 3, name: 'Taxes', color: Colors.blue, active: true),
  4: FlowData(id: 4, name: 'Overflow', color: Colors.purple, active: true),
};

class _OptimisticEndFlowHarness extends StatefulWidget {
  const _OptimisticEndFlowHarness({required this.onEndFlow});

  final Future<EndFlowOutcome> Function(int flowId) onEndFlow;

  @override
  State<_OptimisticEndFlowHarness> createState() =>
      _OptimisticEndFlowHarnessState();
}

class _OptimisticEndFlowHarnessState extends State<_OptimisticEndFlowHarness> {
  List<NoteData> _notes = [
    _timedNote(
      clientEventId: 'ending',
      title: 'Ending Flow Event',
      startHour: 10,
      startMinute: 0,
      endHour: 11,
      endMinute: 0,
      flowId: 1,
    ),
    _timedNote(
      clientEventId: 'same-flow-later',
      title: 'Same Flow Later',
      startHour: 11,
      startMinute: 0,
      endHour: 12,
      endMinute: 0,
      flowId: 1,
    ),
    _timedNote(
      clientEventId: 'successor',
      title: 'Successor Event',
      startHour: 22,
      startMinute: 0,
      endHour: 23,
      endMinute: 0,
      flowId: 2,
    ),
  ];

  Future<EndFlowOutcome> _endFlow(int flowId) {
    setState(() {
      _notes = _notes.where((note) => note.flowId != flowId).toList();
    });
    return widget.onEndFlow(flowId);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: DayViewGrid(
          ky: 1,
          km: 1,
          kd: 1,
          notes: _notes,
          showGregorian: false,
          flowIndex: const {
            1: FlowData(
              id: 1,
              name: 'Ending Flow',
              color: Colors.red,
              active: true,
            ),
            2: FlowData(
              id: 2,
              name: 'Successor Flow',
              color: Colors.blue,
              active: true,
            ),
          },
          activeLedgerFlowIds: const {1, 2},
          initialScrollOffset: 9 * 60,
          onEndFlow: _endFlow,
        ),
      ),
    );
  }
}

class _DayViewHarness extends StatelessWidget {
  const _DayViewHarness({
    required this.notes,
    this.initialScrollOffset = 9 * 60,
    this.flowIndex = _defaultFlowIndex,
    this.activeLedgerFlowIds,
    this.onEndFlow,
    this.onAppendToJournal,
    this.onRecordCompletion,
    this.onUnrecordCompletion,
    this.onRemoveCompletionBadge,
  });

  final List<NoteData> notes;
  final double initialScrollOffset;
  final Map<int, FlowData> flowIndex;
  final Set<int>? activeLedgerFlowIds;
  final Future<EndFlowOutcome> Function(int flowId)? onEndFlow;
  final Future<void> Function(String text)? onAppendToJournal;
  final Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion;
  final Future<void> Function(String clientEventId)? onUnrecordCompletion;
  final Future<void> Function(String badgeId)? onRemoveCompletionBadge;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: DayViewGrid(
          ky: 1,
          km: 1,
          kd: 1,
          notes: notes,
          showGregorian: false,
          flowIndex: flowIndex,
          activeLedgerFlowIds: activeLedgerFlowIds ?? flowIndex.keys.toSet(),
          initialScrollOffset: initialScrollOffset,
          onEndFlow: onEndFlow,
          onAppendToJournal: onAppendToJournal,
          onRecordCompletion: onRecordCompletion,
          onUnrecordCompletion: onUnrecordCompletion,
          onRemoveCompletionBadge: onRemoveCompletionBadge,
        ),
      ),
    );
  }
}

class _DayViewRouterHarness extends StatelessWidget {
  const _DayViewRouterHarness({required this.notes});

  final List<NoteData> notes;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: DayViewGrid(
              ky: 1,
              km: 1,
              kd: 1,
              notes: notes,
              showGregorian: false,
              flowIndex: const {
                77: FlowData(
                  id: 77,
                  name: kLivingTextTitle,
                  color: Colors.amber,
                  active: true,
                ),
              },
              activeLedgerFlowIds: const <int>{77},
              initialScrollOffset: 9 * 60,
            ),
          ),
        ),
        GoRoute(
          path: '/nodes',
          builder: (context, state) =>
              const Scaffold(body: Text('Library root')),
        ),
        GoRoute(
          path: '/nodes/:nodeId',
          builder: (context, state) {
            final nodeId = state.pathParameters['nodeId']!;
            final action = state.uri.queryParameters['action'] ?? '';
            return Scaffold(body: Text('Node target: $nodeId action:$action'));
          },
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }
}

class _RestoredDetailGridHarness extends StatelessWidget {
  const _RestoredDetailGridHarness({
    required this.notes,
    required this.restoration,
    this.flowIndex = const <int, FlowData>{},
    this.onDeleteNote,
    this.onEndReminder,
  });

  final List<NoteData> notes;
  final EventDetailRestorationState restoration;
  final Map<int, FlowData> flowIndex;
  final Future<void> Function(int ky, int km, int kd, EventItem event)?
  onDeleteNote;
  final Future<void> Function(String reminderId)? onEndReminder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: DayViewGrid(
          ky: 1,
          km: 1,
          kd: 1,
          notes: notes,
          showGregorian: false,
          flowIndex: flowIndex,
          activeLedgerFlowIds: flowIndex.keys.toSet(),
          initialScrollOffset: 8 * 60,
          initialEventDetailRestorationState: restoration,
          onDeleteNote: onDeleteNote,
          onEndReminder: onEndReminder,
        ),
      ),
    );
  }
}

class _MutableDayViewHarness extends StatelessWidget {
  const _MutableDayViewHarness({
    required this.notes,
    required this.dataVersion,
    this.onShareNote,
  });

  final ValueNotifier<List<NoteData>> notes;
  final ValueNotifier<int> dataVersion;
  final Future<void> Function(EventItem event)? onShareNote;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<int>(
          valueListenable: dataVersion,
          builder: (context, _, child) {
            return DayViewGrid(
              ky: 1,
              km: 1,
              kd: 1,
              notes: notes.value,
              dataVersion: dataVersion,
              showGregorian: false,
              flowIndex: const {},
              initialScrollOffset: 9 * 60,
              onShareNote: onShareNote,
              resolveCurrentEventTarget: (target) {
                for (final note in notes.value) {
                  final sameId =
                      target.event.id != null &&
                      target.event.id!.isNotEmpty &&
                      note.id == target.event.id;
                  final sameClientId =
                      target.event.clientEventId != null &&
                      target.event.clientEventId!.isNotEmpty &&
                      note.clientEventId == target.event.clientEventId;
                  if (!sameId && !sameClientId) continue;
                  return DayViewSheetEventTarget(
                    ky: target.ky,
                    km: target.km,
                    kd: target.kd,
                    event: _eventFromNote(note),
                  );
                }
                return target;
              },
            );
          },
        ),
      ),
    );
  }
}

class _SheetPersistenceHarness extends StatelessWidget {
  const _SheetPersistenceHarness({
    required this.showGrid,
    required this.dataVersion,
    this.onEndFlow,
  });

  final ValueNotifier<bool> showGrid;
  final ValueNotifier<int> dataVersion;
  final Future<EndFlowOutcome> Function(int flowId)? onEndFlow;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: showGrid,
          builder: (context, isVisible, _) {
            if (!isVisible) {
              return const SizedBox.expand();
            }

            return DayViewGrid(
              ky: 1,
              km: 1,
              kd: 1,
              notes: [
                _timedNote(
                  title: 'Flow Block',
                  startHour: 10,
                  startMinute: 0,
                  endHour: 11,
                  endMinute: 0,
                  flowId: 1,
                ),
              ],
              dataVersion: dataVersion,
              showGregorian: false,
              flowIndex: const {
                1: FlowData(
                  id: 1,
                  name: 'Practice',
                  color: Colors.green,
                  active: true,
                ),
              },
              activeLedgerFlowIds: const {1},
              initialScrollOffset: 9 * 60,
              onEndFlow: onEndFlow,
            );
          },
        ),
      ),
    );
  }
}

class _PagedReminderDayViewHarness extends StatelessWidget {
  const _PagedReminderDayViewHarness({
    required this.notes,
    this.onShareReminder,
  });

  final List<NoteData> notes;
  final Future<void> Function(EventItem event)? onShareReminder;

  @override
  Widget build(BuildContext context) {
    final events = notes.map(_eventFromNote).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    DayViewSheetEventTarget? resolveAdjacent({
      required int ky,
      required int km,
      required int kd,
      required EventItem event,
      required bool forward,
    }) {
      final index = events.indexWhere(
        (candidate) => candidate.clientEventId == event.clientEventId,
      );
      if (index < 0) return null;
      final nextIndex = forward ? index + 1 : index - 1;
      if (nextIndex < 0 || nextIndex >= events.length) return null;
      return DayViewSheetEventTarget(
        ky: ky,
        km: km,
        kd: kd,
        event: events[nextIndex],
      );
    }

    DayViewSheetEventTarget resolveCurrent(DayViewSheetEventTarget target) {
      for (final event in events) {
        if (event.clientEventId != target.event.clientEventId) continue;
        return DayViewSheetEventTarget(
          ky: target.ky,
          km: target.km,
          kd: target.kd,
          event: event,
        );
      }
      return target;
    }

    return MaterialApp(
      home: Scaffold(
        body: DayViewGrid(
          ky: 1,
          km: 1,
          kd: 1,
          notes: notes,
          showGregorian: false,
          flowIndex: const {},
          initialScrollOffset: 9 * 60,
          onShareReminder: onShareReminder,
          resolveAdjacentEvent: resolveAdjacent,
          resolveCurrentEventTarget: resolveCurrent,
        ),
      ),
    );
  }
}

EventItem _eventFromNote(NoteData note) {
  final startMin = (note.start?.hour ?? 9) * 60 + (note.start?.minute ?? 0);
  final endMin = (note.end?.hour ?? 17) * 60 + (note.end?.minute ?? 0);
  return EventItem(
    id: note.id,
    clientEventId: note.clientEventId,
    title: note.title,
    detail: note.detail,
    location: note.location,
    startMin: startMin,
    endMin: endMin,
    flowId: note.flowId,
    color: note.manualColor ?? Colors.blue,
    manualColor: note.manualColor,
    allDay: note.allDay,
    category: note.category,
    isReminder: note.isReminder,
    reminderId: note.reminderId,
    behaviorPayload: note.behaviorPayload,
  );
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing source start: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing source end: $end');
  return source.substring(startIndex, endIndex);
}
