import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_event_block_behavior_surface.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_event_block_visual.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_room_repository.dart';

void main() {
  Future<void> pumpBlocks(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF050504),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  ReadingHouseEventBlockVisual(),
                  SizedBox(height: 24),
                  ReadingHouseEventBlockVisual(
                    size: ReadingHouseEventBlockSize.compact,
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

  for (final size in <Size>[
    const Size(320, 700),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('featured and compact Reading House blocks fit $size', (
      tester,
    ) async {
      await pumpBlocks(tester, size);
      expect(
        find.byKey(
          const ValueKey<String>('reading-house-event-block-featured'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('reading-house-event-block-compact')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact membership follows the real room summary', (
    tester,
  ) async {
    const identity = ReadingHouseRoomIdentity(
      calendarId: 'house-calendar',
      flowId: 12,
    );
    final source = _MembershipDataSource();
    addTearDown(source.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadingHouseEventBlockBehaviorSurface(
            identity: identity,
            dataSource: source,
            sittingNumber: 1,
            title: 'Open the Text',
            prompt: 'Hold the opening.',
            width: 251.2,
            height: 60,
          ),
        ),
      ),
    );

    source.emit(
      const ReadingHouseRoomSummary(
        identity: identity,
        title: 'The Book',
        members: <ReadingHouseRoomMember>[
          ReadingHouseRoomMember(userId: 'me', role: 'owner'),
        ],
        memberCount: 1,
        unreadCount: 0,
        active: true,
        locked: false,
        ended: false,
      ),
    );
    await tester.pump();
    expect(find.text('You'), findsOneWidget);
    expect(find.text('You and 2 other readers'), findsNothing);
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('reading-house-event-block-compact')),
      ),
      const Size(251.2, 60),
    );

    source.emit(
      const ReadingHouseRoomSummary(
        identity: identity,
        title: 'The Book',
        members: <ReadingHouseRoomMember>[
          ReadingHouseRoomMember(userId: 'me', role: 'owner'),
          ReadingHouseRoomMember(
            userId: 'reader-a',
            role: 'viewer',
            displayName: 'Amina Bell',
          ),
          ReadingHouseRoomMember(
            userId: 'reader-b',
            role: 'viewer',
            displayName: 'Kai',
          ),
        ],
        memberCount: 3,
        unreadCount: 0,
        active: true,
        locked: false,
        ended: false,
      ),
    );
    await tester.pump();
    expect(find.text('You and 2 other readers'), findsOneWidget);
  });
}

class _MembershipDataSource implements ReadingHouseRoomDataSource {
  final _summaries = StreamController<List<ReadingHouseRoomSummary>>.broadcast(
    sync: true,
  );

  void emit(ReadingHouseRoomSummary summary) =>
      _summaries.add(<ReadingHouseRoomSummary>[summary]);

  Future<void> dispose() => _summaries.close();

  @override
  String? get currentUserId => 'me';

  @override
  Stream<List<ReadingHouseRoomSummary>> watchSummaries() => _summaries.stream;

  @override
  Future<void> deleteMessage({
    required ReadingHouseRoomIdentity identity,
    required String messageId,
  }) => throw UnimplementedError();

  @override
  Future<List<ReadingHouseRoomMessage>> listMessages({
    required ReadingHouseRoomIdentity identity,
    DateTime? before,
    int limit = 50,
  }) => throw UnimplementedError();

  @override
  Future<List<ReadingHouseRoomSummary>> listSummaries() =>
      throw UnimplementedError();

  @override
  Future<DateTime> markRead({
    required ReadingHouseRoomIdentity identity,
    required DateTime through,
  }) => throw UnimplementedError();

  @override
  Future<void> sendMessage({
    required ReadingHouseRoomIdentity identity,
    required String body,
  }) => throw UnimplementedError();

  @override
  Future<void> updateMessage({
    required ReadingHouseRoomIdentity identity,
    required String messageId,
    required String body,
  }) => throw UnimplementedError();

  @override
  Stream<void> watchRoom(ReadingHouseRoomIdentity identity) =>
      throw UnimplementedError();
}
