import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_day_presentation.dart';
import 'package:mobile/features/calendar/the_reading_house_flow.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _captureReadingHouseDayVisuals = bool.fromEnvironment(
  'CAPTURE_READING_HOUSE_DAY_VISUALS',
);
const _goldenRoot = '../../visual_reference/maat_flows/goldens';

double _authoredOpenSheetExtent(Size size) =>
    math.min(600, size.height * .72) / (size.height - 12);

void main() {
  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
  });

  Future<void> pumpPresentation(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    double initialExtent = 1,
    ReadingHouseDayVisualFixture fixture = kReadingHouseDayVisualFixture,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: RepaintBoundary(
              key: const ValueKey<String>('reading-house-day-visual-capture'),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: MediaQuery(
                      data: MediaQueryData(
                        size: size,
                        textScaler: TextScaler.linear(textScale),
                        padding: const EdgeInsets.only(top: 47),
                      ),
                      child: DayViewPage(
                        initialKy: 2,
                        initialKm: 6,
                        initialKd: 18,
                        showGregorian: false,
                        notesForDay: (ky, km, kd) => <NoteData>[
                          if (ky == 2 && km == 6 && kd == 18)
                            const NoteData(
                              calendarId: 'reading-house-visual-calendar',
                              clientEventId: 'reading-house-visual-event',
                              title: 'Open the Text',
                              allDay: false,
                              start: TimeOfDay(hour: 19, minute: 0),
                              end: TimeOfDay(hour: 20, minute: 0),
                              flowId: 82,
                              behaviorPayload: <String, dynamic>{
                                'kind': 'maat_reading_house_sitting',
                                'flow_key': kReadingHouseFlowKey,
                              },
                            ),
                        ],
                        flowIndex: const <int, FlowData>{
                          82: FlowData(
                            id: 82,
                            name: kReadingHouseTitle,
                            color: Color(0xFF3FA98A),
                            active: true,
                            notes: 'mode=gregorian;maat=$kReadingHouseFlowKey',
                          ),
                        },
                        activeLedgerFlowIds: const <int>{82},
                        getMonthName: (_) => 'Rekh-Wer (Rḫ-wr)',
                        initialFirstVisibleMinute: 14 * 60,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: InstrumentEventSheetHost(
                      key: const ValueKey<String>(
                        'reading-house-visual-sheet-host',
                      ),
                      semanticLabel: 'Reading House sitting details',
                      handleColor: ReadingHouseDayTokens.mint,
                      initialExtent: initialExtent,
                      geometry: InstrumentEventSheetGeometry.layered,
                      trailing: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF756E68),
                      ),
                      body: ReadingHouseDayPresentation(
                        fixture: fixture,
                        onSendMessage: (_) {},
                        onJumpToLatest: () {},
                        onPostAnnouncement: (_) {},
                        onPostSharedNote: (_) {},
                        onCompletionSelected: (_) {},
                      ),
                      footer: ReadingHouseDayFooterActions(
                        onMakeTodo: () {},
                        onCalendar: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reuses the layered frame and preserves the approved lanes', (
    tester,
  ) async {
    await pumpPresentation(tester, size: const Size(390, 720));
    expect(find.byType(InstrumentEventPresentationFrame), findsOneWidget);
    expect(find.text('House Chat'), findsOneWidget);
    expect(find.text('Host announcement'), findsWidgets);
    expect(find.text('Shared note'), findsOneWidget);
    expect(find.text('Private reflection'), findsOneWidget);
    expect(find.text('Post to Feed'), findsOneWidget);
    expect(find.textContaining('House Margin'), findsNothing);
    expect(find.textContaining('shared margin'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked and ended room states remove the composer authority', (
    tester,
  ) async {
    for (final state in const <ReadingHouseRoomVisualState>[
      ReadingHouseRoomVisualState.locked,
      ReadingHouseRoomVisualState.ended,
    ]) {
      await pumpPresentation(
        tester,
        size: const Size(390, 720),
        fixture: ReadingHouseDayVisualFixture(
          roomState: state,
          messages: kReadingHouseDayVisualFixture.messages,
        ),
      );
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('reading-house-chat-message-field')),
      );
      expect(field.enabled, isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shared host remains keyboard-aware', (tester) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: InstrumentEventSheetHost(
                semanticLabel: 'Reading House sitting details',
                handleColor: ReadingHouseDayTokens.mint,
                body: ReadingHouseDayPresentation(),
                footer: ReadingHouseDayFooterActions(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion selection uses the authored three-state control', (
    tester,
  ) async {
    final selected = <ReadingHouseCompletionVisualState>[];
    const size = Size(390, 720);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: ReadingHouseDayPresentation(onCompletionSelected: selected.add),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final body = find.byKey(
      const ValueKey<String>('reading-house-presentation-body'),
    );
    await tester.drag(body, const Offset(0, -1800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Observed'));
    await tester.pumpAndSettle();

    expect(selected, <ReadingHouseCompletionVisualState>[
      ReadingHouseCompletionVisualState.observed,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Reading House scroll raises the inner practice card before outer resize',
    (tester) async {
      await pumpPresentation(
        tester,
        size: const Size(390, 844),
        initialExtent: .71,
      );
      final host = find.byKey(
        const ValueKey<String>('reading-house-visual-sheet-host'),
      );
      final lower = find.byKey(
        const ValueKey<String>('reading-house-practice-sheet'),
      );
      final hostBefore = tester.getRect(host);
      final lowerBefore = tester.getRect(lower);
      expect(hostBefore.top, closeTo(245, 12));
      expect(
        tester
            .getRect(
              find.byKey(
                const ValueKey<String>('follow-sky-sheet-resize-handle'),
              ),
            )
            .top,
        closeTo(245, 12),
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('reading-house-presentation-body')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final hostAfter = tester.getRect(host);
      final lowerAfter = tester.getRect(lower);
      expect(hostAfter.top, closeTo(hostBefore.top, .5));
      expect(hostAfter.height, closeTo(hostBefore.height, .5));
      expect(lowerAfter.top, lessThan(lowerBefore.top));
      await expectLater(
        find.byKey(const ValueKey<String>('reading-house-day-visual-capture')),
        matchesGoldenFile(
          '$_goldenRoot/reading-house-day-sheet-body-390x844.png',
        ),
      );
      await tester.drag(
        find.byKey(const ValueKey<String>('reading-house-presentation-body')),
        const Offset(0, -1600),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey<String>('reading-house-day-visual-capture')),
        matchesGoldenFile(
          '$_goldenRoot/reading-house-day-sheet-bottom-390x844.png',
        ),
      );
    },
  );

  for (final fixture in <(String, Size, double, ReadingHouseDayVisualFixture)>[
    ('minimum', const Size(320, 700), 1, kReadingHouseDayVisualFixture),
    ('mockup', const Size(390, 844), 1, kReadingHouseDayVisualFixture),
    ('large', const Size(430, 820), 1, kReadingHouseDayVisualFixture),
    ('accessible', const Size(390, 760), 1.35, kReadingHouseDayVisualFixture),
    (
      'locked',
      const Size(390, 720),
      1,
      const ReadingHouseDayVisualFixture(
        roomState: ReadingHouseRoomVisualState.locked,
        messages: <ReadingHouseChatMessageFixture>[],
      ),
    ),
    (
      'ended',
      const Size(390, 720),
      1,
      ReadingHouseDayVisualFixture(
        roomState: ReadingHouseRoomVisualState.ended,
        messages: kReadingHouseDayVisualFixture.messages,
      ),
    ),
    (
      'incoming',
      const Size(390, 720),
      1,
      ReadingHouseDayVisualFixture(
        roomState: ReadingHouseRoomVisualState.active,
        messages: kReadingHouseDayVisualFixture.messages,
        newMessageCount: 1,
      ),
    ),
    (
      'complete',
      const Size(390, 720),
      1,
      ReadingHouseDayVisualFixture(
        roomState: ReadingHouseRoomVisualState.active,
        messages: kReadingHouseDayVisualFixture.messages,
        completion: ReadingHouseCompletionVisualState.observed,
      ),
    ),
  ]) {
    testWidgets('Reading House Day View visual ${fixture.$1}', (tester) async {
      await pumpPresentation(
        tester,
        size: fixture.$2,
        textScale: fixture.$3,
        initialExtent: fixture.$1 == 'mockup' || fixture.$1 == 'incoming'
            ? _authoredOpenSheetExtent(fixture.$2)
            : 1,
        fixture: fixture.$4,
      );
      if (fixture.$1 == 'complete') {
        await tester.drag(
          find.byKey(const ValueKey<String>('reading-house-presentation-body')),
          const Offset(0, -1800),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      final goldenPath = fixture.$1 == 'mockup'
          ? '$_goldenRoot/reading-house-day-sheet-390x844.png'
          : fixture.$1 == 'locked'
          ? '$_goldenRoot/reading-house-day-sheet-locked-390x720.png'
          : fixture.$1 == 'ended'
          ? '$_goldenRoot/reading-house-day-sheet-ended-390x720.png'
          : fixture.$1 == 'incoming'
          ? '$_goldenRoot/reading-house-day-sheet-incoming-390x720.png'
          : fixture.$1 == 'complete'
          ? '$_goldenRoot/reading-house-day-sheet-complete-390x720.png'
          : _captureReadingHouseDayVisuals
          ? '/tmp/reading-house-day-${fixture.$1}.png'
          : null;
      if (goldenPath != null) {
        await expectLater(
          find.byKey(
            const ValueKey<String>('reading-house-day-visual-capture'),
          ),
          matchesGoldenFile(goldenPath),
        );
      }
    });
  }
}
