import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
  final StreamController<void> activity = StreamController<void>.broadcast();

  @override
  String? get currentUserId => 'current-user';

  @override
  Future<List<ReadingHouseRoomMessage>> listMessages({
    required ReadingHouseRoomIdentity identity,
    DateTime? before,
    int limit = 50,
  }) async {
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

  @override
  Stream<void> watchRoom(ReadingHouseRoomIdentity identity) => activity.stream;

  @override
  Stream<List<ReadingHouseRoomSummary>> watchSummaries() =>
      Stream<List<ReadingHouseRoomSummary>>.value(summaries);
}
