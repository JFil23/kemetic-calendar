import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/inbox/presentation/reading_house_inbox_section.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

const _captureReadingHouseInboxVisuals = bool.fromEnvironment(
  'CAPTURE_READING_HOUSE_INBOX_VISUALS',
);

void main() {
  setUpAll(() async {
    if (_captureReadingHouseInboxVisuals) {
      await loadMaatFlowVisualTestFonts();
    }
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    double textScale = 1,
    List<ReadingHouseInboxRoomFixture> rooms =
        const <ReadingHouseInboxRoomFixture>[
          kReadingHouseInboxRoomVisualFixture,
        ],
    ReadingHouseInboxSectionStatus sectionStatus =
        ReadingHouseInboxSectionStatus.loaded,
    bool showPendingInvite = false,
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
          child: RepaintBoundary(
            key: const ValueKey<String>('reading-house-inbox-visual-capture'),
            child: ReadingHouseInboxVisualFixturePage(
              rooms: rooms,
              sectionStatus: sectionStatus,
              showPendingInvite: showPendingInvite,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('accepted room sits directly below Invites and before Messages', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(390, 844));
    final invites = find.byKey(
      const ValueKey<String>('reading-house-invites-row'),
    );
    final room = find.byKey(
      const ValueKey<String>(
        'reading-house-inbox-room-odyssey-house-calendar-41',
      ),
    );
    final messages = find.text('MESSAGES');
    expect(room, findsOneWidget);
    expect(
      tester.getBottomLeft(invites).dy,
      lessThanOrEqualTo(tester.getTopLeft(room).dy),
    );
    expect(
      tester.getBottomLeft(room).dy,
      lessThan(tester.getTopLeft(messages).dy),
    );
    expect(find.text('The Odyssey · 3 readers'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each room opens with its own canonical House identity', (
    tester,
  ) async {
    String? calendarId;
    int? flowId;
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingHouseInboxRoomSection(
          rooms: kReadingHouseInboxMultipleRoomVisualFixtures,
          onOpenRoom: (calendar, flow) {
            calendarId = calendar;
            flowId = flow;
          },
        ),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'reading-house-inbox-room-celestine-house-calendar-82',
        ),
      ),
    );
    expect(calendarId, 'celestine-house-calendar');
    expect(flowId, 82);
  });

  testWidgets('loading and error are dedicated Reading House section states', (
    tester,
  ) async {
    for (final state in const <ReadingHouseInboxSectionStatus>[
      ReadingHouseInboxSectionStatus.loading,
      ReadingHouseInboxSectionStatus.error,
    ]) {
      await pumpPage(
        tester,
        size: const Size(390, 844),
        rooms: const <ReadingHouseInboxRoomFixture>[],
        sectionStatus: state,
      );
      expect(tester.takeException(), isNull);
    }
  });

  for (final fixture
      in <(String, Size, double, List<ReadingHouseInboxRoomFixture>, bool)>[
        (
          'minimum',
          const Size(320, 700),
          1,
          const <ReadingHouseInboxRoomFixture>[
            kReadingHouseInboxRoomVisualFixture,
          ],
          false,
        ),
        (
          'mockup',
          const Size(390, 844),
          1,
          const <ReadingHouseInboxRoomFixture>[
            kReadingHouseInboxRoomVisualFixture,
          ],
          false,
        ),
        (
          'large',
          const Size(430, 932),
          1,
          const <ReadingHouseInboxRoomFixture>[
            kReadingHouseInboxRoomVisualFixture,
          ],
          false,
        ),
        (
          'accessible',
          const Size(390, 844),
          1.35,
          const <ReadingHouseInboxRoomFixture>[
            kReadingHouseInboxRoomVisualFixture,
          ],
          false,
        ),
        (
          'multiple',
          const Size(390, 844),
          1,
          kReadingHouseInboxMultipleRoomVisualFixtures,
          false,
        ),
        (
          'pending-invite',
          const Size(390, 844),
          1,
          const <ReadingHouseInboxRoomFixture>[
            kReadingHouseInboxRoomVisualFixture,
          ],
          true,
        ),
      ]) {
    testWidgets('Reading House Inbox visual ${fixture.$1}', (tester) async {
      await pumpPage(
        tester,
        size: fixture.$2,
        textScale: fixture.$3,
        rooms: fixture.$4,
        showPendingInvite: fixture.$5,
      );
      expect(tester.takeException(), isNull);
      if (!_captureReadingHouseInboxVisuals) return;
      await expectLater(
        find.byKey(
          const ValueKey<String>('reading-house-inbox-visual-capture'),
        ),
        matchesGoldenFile('/tmp/reading-house-inbox-${fixture.$1}.png'),
      );
    });
  }
}
