import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_day_presentation.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _captureReadingHouseDayVisuals = bool.fromEnvironment(
  'CAPTURE_READING_HOUSE_DAY_VISUALS',
);

void main() {
  setUpAll(() async {
    if (_captureReadingHouseDayVisuals) {
      await loadMaatFlowVisualTestFonts();
    }
  });

  Future<void> pumpPresentation(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    ReadingHouseDayVisualFixture fixture = kReadingHouseDayVisualFixture,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
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
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[Color(0xFF17130C), Colors.black],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: InstrumentEventSheetHost(
                      semanticLabel: 'Reading House sitting details',
                      handleColor: ReadingHouseDayTokens.mint,
                      initialExtent: 1,
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

  for (final fixture in <(String, Size, double, ReadingHouseDayVisualFixture)>[
    ('minimum', const Size(320, 700), 1, kReadingHouseDayVisualFixture),
    ('mockup', const Size(390, 720), 1, kReadingHouseDayVisualFixture),
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
  ]) {
    testWidgets('Reading House Day View visual ${fixture.$1}', (tester) async {
      await pumpPresentation(
        tester,
        size: fixture.$2,
        textScale: fixture.$3,
        fixture: fixture.$4,
      );
      expect(tester.takeException(), isNull);
      if (!_captureReadingHouseDayVisuals) return;
      await expectLater(
        find.byKey(const ValueKey<String>('reading-house-day-visual-capture')),
        matchesGoldenFile('/tmp/reading-house-day-${fixture.$1}.png'),
      );
    });
  }
}
