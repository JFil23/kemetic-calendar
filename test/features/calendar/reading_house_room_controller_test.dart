import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_day_behavior_surface.dart';
import 'package:mobile/features/calendar/the_reading_house/presentation/reading_house_day_presentation.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_room_controller.dart';
import 'package:mobile/features/calendar/the_reading_house/reading_house_room_repository.dart';

void main() {
  const roomA = ReadingHouseRoomIdentity(calendarId: 'calendar-a', flowId: 41);
  const roomB = ReadingHouseRoomIdentity(calendarId: 'calendar-b', flowId: 42);

  test(
    'room controller loads and marks only its exact House identity',
    () async {
      final source = _FakeRoomDataSource(
        <ReadingHouseRoomIdentity, List<ReadingHouseRoomMessage>>{
          roomA: <ReadingHouseRoomMessage>[_message('a-1', roomA, minute: 1)],
          roomB: <ReadingHouseRoomMessage>[_message('b-1', roomB, minute: 2)],
        },
      );
      final controller = ReadingHouseRoomController(
        dataSource: source,
        identity: roomA,
      );
      addTearDown(controller.dispose);

      await controller.start();

      expect(controller.messages.map((message) => message.id), <String>['a-1']);
      expect(source.markedAt.keys, <ReadingHouseRoomIdentity>{roomA});
      expect(source.markedAt, isNot(contains(roomB)));
    },
  );

  test('new activity stays unread while transcript is scrolled up', () async {
    final source = _FakeRoomDataSource(
      <ReadingHouseRoomIdentity, List<ReadingHouseRoomMessage>>{
        roomA: <ReadingHouseRoomMessage>[_message('a-1', roomA, minute: 1)],
      },
    );
    final controller = ReadingHouseRoomController(
      dataSource: source,
      identity: roomA,
    );
    addTearDown(controller.dispose);
    await controller.start();
    final firstRead = source.markedAt[roomA];
    controller.setFollowingLatest(false);

    source.messages[roomA] = <ReadingHouseRoomMessage>[
      ...source.messages[roomA]!,
      _message('a-2', roomA, minute: 2, authorId: 'another-reader'),
    ];
    await controller.refresh();

    expect(controller.newMessageCount, 1);
    expect(source.markedAt[roomA], firstRead);

    await controller.jumpToLatest();
    expect(controller.newMessageCount, 0);
    expect(source.markedAt[roomA], DateTime.utc(2026, 9, 5, 10, 2));
  });

  testWidgets(
    'open House renders a second reader live and rejects another House',
    (tester) async {
      const otherHouse = ReadingHouseRoomIdentity(
        calendarId: 'calendar-b',
        flowId: 41,
      );
      final source = _FakeRoomDataSource(
        <ReadingHouseRoomIdentity, List<ReadingHouseRoomMessage>>{
          roomA: <ReadingHouseRoomMessage>[_message('a-1', roomA, minute: 1)],
          otherHouse: <ReadingHouseRoomMessage>[],
        },
      );
      final controller = ReadingHouseRoomController(
        dataSource: source,
        identity: roomA,
      );
      addTearDown(controller.dispose);
      await controller.start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => ReadingHouseChatPresentation(
                fixture: readingHouseRoomVisualFixture(
                  context: context,
                  controller: controller,
                  currentUserId: source.currentUserId,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('a-1'), findsOneWidget);
      expect(source.watchStarts[roomA], 1);

      source.post(
        _message(
          'Reader B arrived live',
          roomA,
          minute: 2,
          authorId: 'reader-b',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reader B arrived live'), findsOneWidget);
      expect(source.watchStarts[roomA], 1);
      final roomAReadsAfterLiveMessage = source.messageReads[roomA];

      source.post(
        _message(
          'Another House must stay private',
          otherHouse,
          minute: 3,
          authorId: 'reader-c',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Another House must stay private'), findsNothing);
      expect(source.messageReads[roomA], roomAReadsAfterLiveMessage);
      expect(source.watchStarts[roomA], 1);
    },
  );

  test(
    'locked and ended rooms reject sends before repository writes',
    () async {
      final source = _FakeRoomDataSource(
        <ReadingHouseRoomIdentity, List<ReadingHouseRoomMessage>>{
          roomA: <ReadingHouseRoomMessage>[],
        },
        summaries: <ReadingHouseRoomSummary>[_summary(roomA, locked: true)],
      );
      final controller = ReadingHouseRoomController(
        dataSource: source,
        identity: roomA,
      );
      addTearDown(controller.dispose);
      await controller.start();

      await controller.send('This must not be written.');

      expect(source.sentBodies, isEmpty);
    },
  );

  test('message edit and delete stay scoped to the controller House', () async {
    final source = _FakeRoomDataSource(
      <ReadingHouseRoomIdentity, List<ReadingHouseRoomMessage>>{
        roomA: <ReadingHouseRoomMessage>[_message('a-1', roomA, minute: 1)],
      },
    );
    final controller = ReadingHouseRoomController(
      dataSource: source,
      identity: roomA,
    );
    addTearDown(controller.dispose);
    await controller.start();

    await controller.updateMessage('a-1', 'corrected');
    await controller.deleteMessage('a-1');

    expect(source.updated, <String>['calendar-a:41:a-1:corrected']);
    expect(source.deleted, <String>['calendar-a:41:a-1']);
  });
}

ReadingHouseRoomMessage _message(
  String id,
  ReadingHouseRoomIdentity identity, {
  required int minute,
  String authorId = 'current-user',
}) {
  final createdAt = DateTime.utc(2026, 9, 5, 10, minute);
  return ReadingHouseRoomMessage(
    id: id,
    identity: identity,
    authorId: authorId,
    body: id,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

ReadingHouseRoomSummary _summary(
  ReadingHouseRoomIdentity identity, {
  bool locked = false,
  bool ended = false,
}) {
  return ReadingHouseRoomSummary(
    identity: identity,
    title: identity.calendarId,
    members: const <ReadingHouseRoomMember>[],
    memberCount: locked ? 1 : 2,
    unreadCount: 0,
    active: !ended,
    locked: locked,
    ended: ended,
  );
}

class _FakeRoomDataSource implements ReadingHouseRoomDataSource {
  _FakeRoomDataSource(this.messages, {List<ReadingHouseRoomSummary>? summaries})
    : summaries =
          summaries ??
          <ReadingHouseRoomSummary>[
            for (final identity in messages.keys) _summary(identity),
          ];

  final Map<ReadingHouseRoomIdentity, List<ReadingHouseRoomMessage>> messages;
  final List<ReadingHouseRoomSummary> summaries;
  final Map<ReadingHouseRoomIdentity, DateTime> markedAt =
      <ReadingHouseRoomIdentity, DateTime>{};
  final List<String> sentBodies = <String>[];
  final List<String> updated = <String>[];
  final List<String> deleted = <String>[];
  final Map<ReadingHouseRoomIdentity, int> messageReads =
      <ReadingHouseRoomIdentity, int>{};
  final Map<ReadingHouseRoomIdentity, int> watchStarts =
      <ReadingHouseRoomIdentity, int>{};
  final StreamController<ReadingHouseRoomIdentity> activity =
      StreamController<ReadingHouseRoomIdentity>.broadcast();

  @override
  String? get currentUserId => 'current-user';

  @override
  Future<List<ReadingHouseRoomMessage>> listMessages({
    required ReadingHouseRoomIdentity identity,
    DateTime? before,
    int limit = 50,
  }) async {
    messageReads.update(identity, (count) => count + 1, ifAbsent: () => 1);
    final available = messages[identity] ?? const <ReadingHouseRoomMessage>[];
    return available
        .where(
          (message) => before == null || message.createdAt.isBefore(before),
        )
        .toList(growable: false);
  }

  @override
  Future<List<ReadingHouseRoomSummary>> listSummaries() async => summaries;

  @override
  Future<DateTime> markRead({
    required ReadingHouseRoomIdentity identity,
    required DateTime through,
  }) async {
    final previous = markedAt[identity];
    if (previous == null || through.isAfter(previous)) {
      markedAt[identity] = through;
    }
    return markedAt[identity]!;
  }

  @override
  Future<void> sendMessage({
    required ReadingHouseRoomIdentity identity,
    required String body,
  }) async {
    sentBodies.add(body);
  }

  @override
  Future<void> updateMessage({
    required ReadingHouseRoomIdentity identity,
    required String messageId,
    required String body,
  }) async {
    updated.add('${identity.calendarId}:${identity.flowId}:$messageId:$body');
  }

  @override
  Future<void> deleteMessage({
    required ReadingHouseRoomIdentity identity,
    required String messageId,
  }) async {
    deleted.add('${identity.calendarId}:${identity.flowId}:$messageId');
  }

  void post(ReadingHouseRoomMessage message) {
    messages.update(
      message.identity,
      (existing) => <ReadingHouseRoomMessage>[...existing, message],
      ifAbsent: () => <ReadingHouseRoomMessage>[message],
    );
    activity.add(message.identity);
  }

  @override
  Stream<void> watchRoom(ReadingHouseRoomIdentity identity) {
    watchStarts.update(identity, (count) => count + 1, ifAbsent: () => 1);
    return activity.stream
        .where((changedIdentity) => changedIdentity == identity)
        .map((_) {});
  }

  @override
  Stream<List<ReadingHouseRoomSummary>> watchSummaries() =>
      Stream<List<ReadingHouseRoomSummary>>.value(summaries);
}
