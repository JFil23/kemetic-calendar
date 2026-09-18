import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_detail_page.dart';
import 'package:mobile/features/calendar/the_djed/presentation/djed_event_block_visual.dart';
import 'package:mobile/features/calendar/the_djed_flow.dart';
import 'package:mobile/features/calendar/the_kar/the_kar.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_event_block_visual.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_room_repository.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';
import 'package:mobile/widgets/keyboard_aware.dart';
import 'package:mobile/widgets/kemetic_keyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/maat_flow_visual_test_fonts.dart';
import '../../support/maat_flow_visual_goldens.dart';

const _visualCaptureKey = ValueKey<String>(
  'authored-event-block-day-view-capture',
);
const _captureKarVisuals = bool.fromEnvironment('CAPTURE_KAR_VISUALS');
const _captureDjedEventBlockLayouts = bool.fromEnvironment(
  'CAPTURE_DJED_EVENT_BLOCK_LAYOUTS',
);
final _goldenRoot = maatFlowVisualGoldenRoot;

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
    httpClient: _EmptySupabaseClient(),
  );
}

class _EmptySupabaseClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isModerationRpc = request.url.path.endsWith(
      '/rpc/reading_house_can_moderate_calendar',
    );
    final body = isModerationRpc ? 'false' : '[]';
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      request: request,
      headers: const <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );
  }
}

class _OneReaderHouseDataSource implements ReadingHouseRoomDataSource {
  const _OneReaderHouseDataSource({required this.flowId});

  static const _userId = 'reader-you';
  final int flowId;

  @override
  String get currentUserId => _userId;

  @override
  Future<List<ReadingHouseRoomSummary>> listSummaries() async =>
      <ReadingHouseRoomSummary>[
        ReadingHouseRoomSummary(
          identity: ReadingHouseRoomIdentity(
            calendarId: 'authored-calendar-$flowId',
            flowId: flowId,
          ),
          title: 'catcher in the rye',
          members: <ReadingHouseRoomMember>[
            ReadingHouseRoomMember(
              userId: _userId,
              role: 'owner',
              displayName: 'You',
            ),
          ],
          memberCount: 1,
          unreadCount: 0,
          active: true,
          locked: true,
          ended: false,
        ),
      ];

  @override
  Future<List<ReadingHouseRoomMessage>> listMessages({
    required ReadingHouseRoomIdentity identity,
    DateTime? before,
    int limit = 50,
  }) async => const <ReadingHouseRoomMessage>[];

  @override
  Future<void> sendMessage({
    required ReadingHouseRoomIdentity identity,
    required String body,
  }) async {}

  @override
  Future<void> updateMessage({
    required ReadingHouseRoomIdentity identity,
    required String messageId,
    required String body,
  }) async {}

  @override
  Future<void> deleteMessage({
    required ReadingHouseRoomIdentity identity,
    required String messageId,
  }) async {}

  @override
  Future<DateTime> markRead({
    required ReadingHouseRoomIdentity identity,
    required DateTime through,
  }) async => through;

  @override
  Stream<void> watchRoom(ReadingHouseRoomIdentity identity) =>
      const Stream<void>.empty();

  @override
  Stream<List<ReadingHouseRoomSummary>> watchSummaries() =>
      const Stream<List<ReadingHouseRoomSummary>>.empty();
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
      final djedRect = tester.getRect(find.byType(DjedEventBlockVisual));
      expect(djedRect.left, closeTo(60, .1));
      expect(djedRect.width, closeTo(251.2, .1));
      expect(tester.takeException(), isNull);
      if (_captureDjedEventBlockLayouts) {
        await expectLater(
          find.byKey(_visualCaptureKey),
          matchesGoldenFile('/tmp/djed-event-standard-390x844.png'),
        );
      }
      await tester.tap(find.byType(DjedEventBlockVisual));
      await tester.pumpAndSettle();
      _expectCanonicalMaatDayViewHousing(
        tester,
        hostKey: 'djed-resizable-sheet',
        completionKey: 'djed-completion-picker',
      );
      expect(find.text('×'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Djed fits the shared lane in an overlapping event pair', (
    tester,
  ) async {
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
      additionalNotes: const <NoteData>[
        NoteData(
          clientEventId: 'zz-ordinary-overlap',
          title: 'Ordinary overlap',
          allDay: false,
          start: TimeOfDay(hour: 7, minute: 30),
          end: TimeOfDay(hour: 8, minute: 30),
          manualColor: Color(0xFF62C18C),
        ),
      ],
    );
    await tester.pumpAndSettle();

    final djedRect = tester.getRect(find.byType(DjedEventBlockVisual));
    expect(djedRect.left, closeTo(60, .1));
    expect(djedRect.width, closeTo(155, .1));
    expect(djedRect.right, lessThanOrEqualTo(374));
    expect(find.text('Ordinary overlap'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (_captureDjedEventBlockLayouts) {
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/djed-event-overlap-390x844.png'),
      );
    }
  });

  testWidgets('Day View opens Reading House in the canonical Ma\'at housing', (
    tester,
  ) async {
    await _pumpDayView(
      tester,
      flowId: 82,
      flowName: kReadingHouseTitle,
      flowKey: kReadingHouseFlowKey,
      title: 'Open the Text',
      start: const TimeOfDay(hour: 19, minute: 0),
      end: const TimeOfDay(hour: 22, minute: 0),
      firstVisibleMinute: 14 * 60,
      payload: const <String, dynamic>{
        'kind': 'maat_reading_house_sitting',
        'flow_key': kReadingHouseFlowKey,
        'event_number': 1,
        'book_title': 'catcher in the rye',
      },
      calendarName: 'Reading House · catcher in the rye',
    );

    expect(find.byType(ReadingHouseEventBlockVisual), findsOneWidget);
    expect(find.text(kReadingHouseSittings.first.title), findsOneWidget);
    expect(find.text('THE READING HOUSE · SITTING 01'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('You and 2 other readers'), findsNothing);
    final readingHouseRect = tester.getRect(
      find.byType(ReadingHouseEventBlockVisual),
    );
    expect(readingHouseRect.left, closeTo(60, .1));
    expect(readingHouseRect.width, closeTo(251.2, .1));
    expect(readingHouseRect.height, 60);
    await expectLater(
      find.byKey(_visualCaptureKey),
      matchesGoldenFile('$_goldenRoot/reading-house-day-view-390x844.png'),
    );
    await tester.tap(find.byType(ReadingHouseEventBlockVisual));
    await tester.pumpAndSettle();
    _expectCanonicalMaatDayViewHousing(
      tester,
      hostKey: 'reading-house-resizable-sheet',
      completionKey: 'reading-house-completion-picker',
    );
    expect(find.text('1 reader'), findsOneWidget);
    expect(find.text('catcher in the rye'), findsOneWidget);
    expect(find.text('Reading House · catcher in the rye'), findsNothing);
    final hostFinder = find.byKey(
      const ValueKey<String>('reading-house-resizable-sheet'),
    );
    final practiceFinder = find.byKey(
      const ValueKey<String>('reading-house-practice-sheet'),
    );
    final houseChatTitle = find.text('House Chat');
    final hostBeforeScroll = tester.getRect(hostFinder);
    final practiceBeforeScroll = tester.getRect(practiceFinder);
    final titleBeforeScroll = tester.getRect(houseChatTitle);
    final chatField = find.byKey(
      const ValueKey<String>('reading-house-chat-message-field'),
    );
    final fieldBeforeScroll = tester.getRect(chatField);
    expect(
      find.ancestor(
        of: chatField,
        matching: find.byKey(
          const ValueKey<String>('reading-house-fixed-chat-layer'),
        ),
      ),
      findsOneWidget,
    );
    await expectLater(
      find.byKey(_visualCaptureKey),
      matchesGoldenFile(
        '$_goldenRoot/maat-day-housing-reading-house-lowered-390x844.png',
      ),
    );
    await tester.dragFrom(
      Offset(practiceBeforeScroll.center.dx, practiceBeforeScroll.top + 20),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(hostFinder), hostBeforeScroll);
    expect(
      tester.getRect(practiceFinder).top,
      lessThan(practiceBeforeScroll.top),
    );
    expect(tester.getRect(houseChatTitle), titleBeforeScroll);
    expect(tester.getRect(chatField), fieldBeforeScroll);
    await expectLater(
      find.byKey(_visualCaptureKey),
      matchesGoldenFile(
        '$_goldenRoot/maat-day-housing-reading-house-raised-390x844.png',
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('follow-sky-sheet-resize-handle')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    final hostAfterResize = tester.getRect(hostFinder);
    expect(hostAfterResize.top, lessThan(hostBeforeScroll.top));
    expect(hostAfterResize.height, greaterThan(hostBeforeScroll.height));
    expect(tester.takeException(), isNull);

    // Dispose the live-room subscription before the test binding checks for
    // pending reconnect timers. The product route owns this subscription;
    // this only makes the visual harness deterministic.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Reading House uses the shared lane for overlapping events', (
    tester,
  ) async {
    await _pumpDayView(
      tester,
      flowId: 82,
      flowName: kReadingHouseTitle,
      flowKey: kReadingHouseFlowKey,
      title: 'Open the Text',
      payload: const <String, dynamic>{
        'kind': 'maat_reading_house_sitting',
        'flow_key': kReadingHouseFlowKey,
        'event_number': 1,
      },
      additionalNotes: const <NoteData>[
        NoteData(
          clientEventId: 'reading-house-overlap',
          title: 'Ordinary overlap',
          allDay: false,
          start: TimeOfDay(hour: 7, minute: 45),
          end: TimeOfDay(hour: 8, minute: 45),
          manualColor: Color(0xFF62C18C),
        ),
      ],
    );
    await tester.pumpAndSettle();

    final readingHouseRect = tester.getRect(
      find.byType(ReadingHouseEventBlockVisual),
    );
    expect(readingHouseRect.left, closeTo(60, .1));
    expect(readingHouseRect.width, closeTo(155, .1));
    expect(readingHouseRect.height, 60);
    expect(find.text('Ordinary overlap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Reading House keeps its focused chat field clear while fixed actions stay behind the keyboard',
    (tester) async {
      final keyboardVisible = ValueNotifier<bool>(false);
      addTearDown(keyboardVisible.dispose);

      await _pumpDayView(
        tester,
        flowId: 87,
        flowName: kReadingHouseTitle,
        flowKey: kReadingHouseFlowKey,
        title: 'Open the Text',
        start: const TimeOfDay(hour: 19, minute: 0),
        firstVisibleMinute: 14 * 60,
        payload: const <String, dynamic>{
          'kind': 'maat_reading_house_sitting',
          'flow_key': kReadingHouseFlowKey,
          'event_number': 1,
          'book_title': 'catcher in the rye',
        },
        calendarName: 'Reading House · catcher in the rye',
        keyboardVisibility: keyboardVisible,
      );

      await tester.tap(find.byType(ReadingHouseEventBlockVisual));
      await tester.pumpAndSettle();

      final field = find.byKey(
        const ValueKey<String>('reading-house-chat-message-field'),
      );
      final editable = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      const makeTodoKey = ValueKey<String>('maat-day-view-make-todo');
      const calendarKey = ValueKey<String>('maat-day-view-calendar');

      expect(field, findsOneWidget);
      expect(find.byKey(makeTodoKey), findsOneWidget);
      expect(find.byKey(calendarKey), findsOneWidget);

      await tester.tap(field);
      await tester.pump();
      keyboardVisible.value = true;
      await tester.pumpAndSettle();

      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
      expect(find.byKey(makeTodoKey), findsNothing);
      expect(find.byKey(calendarKey), findsNothing);
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(544));

      keyboardVisible.value = false;
      await tester.pumpAndSettle();

      expect(find.byKey(makeTodoKey), findsOneWidget);
      expect(find.byKey(calendarKey), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('Day View opens Kꜣr behavior in the existing shared sheet', (
    tester,
  ) async {
    Map<String, dynamic>? recordedCompletion;
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
      end: const TimeOfDay(hour: 12, minute: 0),
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
      onRecordCompletion:
          ({
            required clientEventId,
            required flowId,
            required completedOnDate,
            metadata,
          }) async {
            recordedCompletion = metadata;
          },
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
    expect(find.byType(KarDayViewPresentation), findsOneWidget);
    expect(find.byType(KarDetailSittingBehaviorSurface), findsNothing);
    expect(find.byType(KarDetailSittingPresentation), findsNothing);
    expect(find.byType(MaatDayViewSheetHost), findsOneWidget);
    expect(find.byType(MaatDayViewForegroundShell), findsOneWidget);
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
    expect(karSheetRect.height, closeTo((844 - 12) * .71 + 8, 1.5));
    expect(karSheetRect.bottom, closeTo(844, .01));
    final collapsedPracticeRect = tester.getRect(
      find.byKey(const ValueKey<String>('kar-practice-sheet')),
    );
    final shrineStageRect = tester.getRect(
      find.byKey(const ValueKey<String>('kar-day-shrine-stage')),
    );
    expect(
      shrineStageRect.bottom,
      lessThanOrEqualTo(collapsedPracticeRect.top),
    );
    final karFrame = tester.widget<InstrumentEventPresentationFrame>(
      find.byType(InstrumentEventPresentationFrame),
    );
    expect(karFrame.graphicSpace.fixedHeight, 354);
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
    expect(find.byTooltip('Event options'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('kar-completion-picker')),
      findsOneWidget,
    );
    expect(find.text('Observed'), findsOneWidget);
    expect(find.text('Partly'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);
    final reflectionButton = find.byKey(
      const ValueKey<String>('day-view-add-reflection'),
    );
    expect(reflectionButton, findsOneWidget);
    expect(tester.getSize(reflectionButton).height, 34);
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey<String>('day-view-add-reflection-touch-target'),
            ),
          )
          .height,
      48,
    );
    await expectLater(
      find.byKey(_visualCaptureKey),
      matchesGoldenFile(
        '$_goldenRoot/maat-day-housing-kar-lowered-390x844.png',
      ),
    );
    await tester.drag(
      find.byKey(const ValueKey<String>('kar-day-sheet-scroll')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    final raisedPracticeRect = tester.getRect(
      find.byKey(const ValueKey<String>('kar-practice-sheet')),
    );
    expect(raisedPracticeRect.top, lessThan(collapsedPracticeRect.top));
    final scrollPosition = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('kar-day-sheet-scroll')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(scrollPosition.pixels, closeTo(scrollPosition.maxScrollExtent, .1));
    final presentationRect = tester.getRect(
      find.byKey(const ValueKey<String>('kar-day-presentation')),
    );
    final completionSlotRect = tester.getRect(
      find.byKey(const ValueKey<String>('maat-day-view-completion-slot')),
    );
    expect(completionSlotRect.bottom, closeTo(presentationRect.bottom - 22, 1));
    await expectLater(
      find.byKey(_visualCaptureKey),
      matchesGoldenFile('$_goldenRoot/maat-day-housing-kar-raised-390x844.png'),
    );
    if (_captureKarVisuals) {
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/kar-day-fresh-raised-flutter.png'),
      );
    }
    final partlyButton = find.ancestor(
      of: find.text('Partly'),
      matching: find.byType(OutlinedButton),
    );
    tester.widget<OutlinedButton>(partlyButton).onPressed!();
    await tester.pumpAndSettle();
    expect(recordedCompletion?['status'], 'observed_partly');
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
        of: find.byKey(const ValueKey<String>('kar-practice-sheet')),
        matching: find.text('Walk the kꜣr'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('kar-practice-sheet')),
        matching: find.text('Five places. Nothing new to make.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('kar-practice-sheet')),
        matching: find.text(
          'Only this cycle is walked. Dim historical places remain behind the route.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('kar-fixed-hero')),
        matching: find.text('Walk the kꜣr'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('kar-fixed-hero')),
        matching: find.text(
          'Enter at the threshold. Find the five places in order.',
        ),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('kar-begin-walk')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('kar-practice-sheet')),
        matching: find.byKey(const ValueKey<String>('kar-begin-walk')),
      ),
      findsOneWidget,
    );
    if (_captureKarVisuals) {
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/kar-day-walk-flutter.png'),
      );
    }

    await tester.drag(
      find.byKey(const ValueKey<String>('kar-day-sheet-scroll')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    final walkPresentationRect = tester.getRect(
      find.byKey(const ValueKey<String>('kar-day-presentation')),
    );
    final walkCompletionRect = tester.getRect(
      find.byKey(const ValueKey<String>('maat-day-view-completion-slot')),
    );
    expect(
      walkCompletionRect.bottom,
      closeTo(walkPresentationRect.bottom - 22, 1),
    );
    if (_captureKarVisuals) {
      await expectLater(
        find.byKey(_visualCaptureKey),
        matchesGoldenFile('/tmp/kar-day-walk-raised-flutter.png'),
      );
    }
    await tester.tap(find.byKey(const ValueKey<String>('kar-begin-walk')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('kar-fixed-hero')),
        matching: find.text('Threshold'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('kar-fixed-hero')),
        matching: find.text(
          'Find this place before asking for what was saved.',
        ),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('kar-begin-walk')), findsNothing);
    expect(find.text('Is it here?'), findsOneWidget);
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
    await tester.tap(field);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
    await tester.pumpAndSettle();

    const keyboardTop = 844.0 - 300.0;
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(keyboardTop));
    expect(find.byKey(editableModalSystemInsetOwnerKey), findsOneWidget);
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
      find.ancestor(
        of: captureWindow,
        matching: find.byType(KeyboardInsetBoundary),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: captureWindow,
          matching: find.byType(KeyboardInsetBoundary),
        ),
        matching: find.byType(KeyboardAwareEditableSurface),
      ),
      findsOneWidget,
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

void _expectCanonicalMaatDayViewHousing(
  WidgetTester tester, {
  required String hostKey,
  required String completionKey,
}) {
  final hostFinder = find.byKey(ValueKey<String>(hostKey));
  expect(hostFinder, findsOneWidget);
  expect(find.byType(MaatDayViewSheetHost), findsOneWidget);
  expect(find.byType(MaatDayViewForegroundShell), findsOneWidget);
  expect(find.byType(MaatDayViewForegroundContent), findsOneWidget);
  expect(
    find.byKey(const ValueKey<String>('maat-day-view-completion-slot')),
    findsOneWidget,
  );
  final host = tester.widget<InstrumentEventSheetHost>(hostFinder);
  expect(host.initialExtent, instrumentEventSheetMinExtent);
  expect(host.geometry, isNull);
  expect(
    find.byKey(const ValueKey<String>('instrument-sheet-handle-mark')),
    findsOneWidget,
  );
  expect(find.byTooltip('Event options'), findsOneWidget);
  final reflectionButton = find.byKey(
    const ValueKey<String>('day-view-add-reflection'),
  );
  expect(reflectionButton, findsOneWidget);
  expect(tester.getSize(reflectionButton).height, 34);
  expect(
    tester
        .getSize(
          find.byKey(
            const ValueKey<String>('day-view-add-reflection-touch-target'),
          ),
        )
        .height,
    48,
  );
  expect(
    find.byKey(const ValueKey<String>('maat-day-view-make-todo')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('maat-day-view-calendar')),
    findsOneWidget,
  );
  expect(find.byKey(ValueKey<String>(completionKey)), findsOneWidget);
  expect(
    find.descendant(
      of: find.byType(InstrumentEventPresentationFrame),
      matching: find.byType(CustomScrollView),
    ),
    findsOneWidget,
  );
}

Future<void> _pumpDayView(
  WidgetTester tester, {
  required int flowId,
  required String flowName,
  required String flowKey,
  required String title,
  required Map<String, dynamic> payload,
  String? calendarName,
  TimeOfDay start = const TimeOfDay(hour: 7, minute: 30),
  TimeOfDay? end,
  int firstVisibleMinute = 6 * 60,
  List<NoteData> additionalNotes = const <NoteData>[],
  KarRepository? karRepository,
  ValueListenable<bool>? keyboardVisibility,
  Future<void> Function({
    required String clientEventId,
    required int flowId,
    required DateTime completedOnDate,
    Map<String, dynamic>? metadata,
  })?
  onRecordCompletion,
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
        builder: keyboardVisibility == null
            ? null
            : (context, navigator) => ValueListenableBuilder<bool>(
                valueListenable: keyboardVisibility,
                child: navigator,
                builder: (context, visible, navigatorChild) =>
                    KemeticKeyboardScope(
                      isCustomKeyboardVisible: false,
                      customKeyboardInset: 0,
                      systemKeyboardInset: visible ? 300 : 0,
                      visibleTop: 0,
                      visibleBottom: visible ? 544 : 844,
                      isSystemKeyboardVisible: visible,
                      child: navigatorChild!,
                    ),
              ),
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
                  calendarId: 'authored-calendar-$flowId',
                  calendarName: calendarName,
                  clientEventId: 'authored-event-$flowId',
                  title: title,
                  allDay: false,
                  start: start,
                  end:
                      end ??
                      TimeOfDay(hour: start.hour + 1, minute: start.minute),
                  flowId: flowId,
                  behaviorPayload: payload,
                ),
              ...additionalNotes,
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
            readingHouseRoomDataSource: flowKey == kReadingHouseFlowKey
                ? _OneReaderHouseDataSource(flowId: flowId)
                : null,
            onRecordCompletion: onRecordCompletion,
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
