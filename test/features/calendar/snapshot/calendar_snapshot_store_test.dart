import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_backend.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_models.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_store.dart';

void main() {
  group('CalendarSnapshotStore', () {
    test('round trips exact canonical data and normalized coverage', () async {
      final backend = MemoryCalendarSnapshotBackend();
      final store = CalendarSnapshotStore(backend);
      final commit = _commit();

      final result = await store.commit(commit);
      final restored = await store.readLatest(_userScope);

      expect(result.generation, 1);
      expect(restored, isNotNull);
      expect(restored!.generation, 1);
      expect(restored.canonicalDigest, commit.canonicalDigest);
      expect(restored.serverRevision, 'server-1');
      expect(restored.overlayRevision, 'overlay-3');
      expect(restored.viewRevision, 'server-1:overlay-3');
      expect(restored.coverage, hasLength(1));
      expect(restored.coverage.single.startUtc, DateTime.utc(2026, 8, 1));
      expect(restored.coverage.single.endUtc, DateTime.utc(2026, 10, 1));
      expect(
        restored.eventsByDay.keys,
        containsAll(<String>['139-1-1', '139-2-1']),
      );
      expect(restored.flows.single['name'], 'Morning walk');
      expect(restored.calendarMetadata['personalCalendarId'], 'personal-1');
      expect(restored.overlayRecords.single['clientEventId'], 'pending-1');
    });

    test(
      'shards are content addressed and unchanged objects are reused',
      () async {
        final backend = MemoryCalendarSnapshotBackend();
        final store = CalendarSnapshotStore(backend);
        final first = await store.commit(_commit());
        final second = await store.commit(
          _commit(
            serverRevision: 'server-2',
            eventsByDay: <String, List<Map<String, Object?>>>{
              ..._events,
              '139-3-1': <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'event-3',
                  'title': 'New month',
                  'allDay': true,
                },
              ],
            },
          ),
          expectedGeneration: first.generation,
        );

        expect(second.generation, 2);
        expect(second.reusedObjectCount, greaterThanOrEqualTo(4));
        expect(second.writtenObjectCount, 1);
        final restored = await store.readLatest(_userScope);
        expect(restored!.eventsByDay, contains('139-3-1'));
      },
    );

    test(
      'crash before manifest keeps the previous generation readable',
      () async {
        final backend = MemoryCalendarSnapshotBackend();
        final store = CalendarSnapshotStore(backend);
        final first = await store.commit(_commit());
        backend.failWriteNumber = backend.writeCount + 1;

        await expectLater(
          store.commit(
            _commit(
              serverRevision: 'server-2',
              eventsByDay: <String, List<Map<String, Object?>>>{
                ..._events,
                '139-4-1': <Map<String, Object?>>[
                  <String, Object?>{
                    'id': 'event-4',
                    'title': 'Never published',
                  },
                ],
              },
            ),
            expectedGeneration: first.generation,
          ),
          throwsStateError,
        );

        final restored = await store.readLatest(_userScope);
        expect(restored!.generation, first.generation);
        expect(restored.serverRevision, 'server-1');
        expect(restored.eventsByDay, isNot(contains('139-4-1')));
      },
    );

    test(
      'corrupt current shard falls back to retained previous generation',
      () async {
        final backend = MemoryCalendarSnapshotBackend();
        final store = CalendarSnapshotStore(backend);
        await store.commit(_commit());
        await store.commit(
          _commit(
            serverRevision: 'server-2',
            eventsByDay: <String, List<Map<String, Object?>>>{
              ..._events,
              '139-5-1': <Map<String, Object?>>[
                <String, Object?>{'id': 'event-5', 'title': 'Corrupt me'},
              ],
            },
          ),
        );

        final objectKey = backend.values.keys.firstWhere((key) {
          final raw = backend.values[key];
          return key.contains(':object:') &&
              raw?.contains('Corrupt me') == true;
        });
        backend
            .values; // Assert through the public read-only view before faulting.
        final mutableSeed = Map<String, String>.from(backend.values);
        mutableSeed[objectKey] = jsonEncode(<String, Object?>{
          'days': 'broken',
        });
        final corruptBackend = MemoryCalendarSnapshotBackend(seed: mutableSeed);
        final recoveringStore = CalendarSnapshotStore(corruptBackend);

        final restored = await recoveringStore.readLatest(_userScope);
        expect(restored, isNotNull);
        expect(restored!.generation, 1);
        expect(restored.serverRevision, 'server-1');
        expect(restored.recoveredPreviousGeneration, isTrue);
      },
    );

    test('same expected generation admits one concurrent writer', () async {
      final backend = MemoryCalendarSnapshotBackend();
      final firstStore = CalendarSnapshotStore(backend);
      final secondStore = CalendarSnapshotStore(backend);
      final first = await firstStore.commit(_commit());

      final outcomes = await Future.wait<Object>(<Future<Object>>[
        firstStore
            .commit(
              _commit(serverRevision: 'server-a'),
              expectedGeneration: first.generation,
            )
            .then<Object>((value) => value)
            .catchError((Object error) => error),
        secondStore
            .commit(
              _commit(serverRevision: 'server-b'),
              expectedGeneration: first.generation,
            )
            .then<Object>((value) => value)
            .catchError((Object error) => error),
      ]);

      expect(outcomes.whereType<CalendarSnapshotCommitResult>(), hasLength(1));
      expect(outcomes.whereType<CalendarSnapshotConflict>(), hasLength(1));
      final restored = await firstStore.readLatest(_userScope);
      expect(restored!.generation, 2);
    });

    test('failed account deletion quarantines the old user scope', () async {
      final backend = MemoryCalendarSnapshotBackend();
      final store = CalendarSnapshotStore(backend);
      await store.commit(_commit());
      await store.commit(_commit(userScope: 'other-user'));
      backend.failDeleteKey = backend.values.keys.firstWhere(
        (key) =>
            key.contains(calendarSnapshotDigest(_userScope)) &&
            key.contains(':object:'),
      );

      await expectLater(store.deleteUserScope(_userScope), throwsStateError);

      expect(await store.readLatest(_userScope), isNull);
      expect(await store.readLatest('other-user'), isNotNull);
      await expectLater(store.commit(_commit()), throwsStateError);
    });

    test('partial shard read does not claim full digest validation', () async {
      final backend = MemoryCalendarSnapshotBackend();
      final store = CalendarSnapshotStore(backend);
      await store.commit(_commit());

      final restored = await store.readLatest(
        _userScope,
        eventShardIds: <String>{'139-2'},
      );

      expect(restored!.eventsByDay.keys, <String>['139-2-1']);
      expect(restored.canonicalDigest, _commit().canonicalDigest);
    });
  });
}

const String _userScope = 'calendar-user-1';

final Map<String, List<Map<String, Object?>>> _events =
    <String, List<Map<String, Object?>>>{
      '139-2-1': <Map<String, Object?>>[
        <String, Object?>{
          'title': 'Second event',
          'id': 'event-2',
          'allDay': false,
          'startMinutes': 720,
        },
      ],
      '139-1-1': <Map<String, Object?>>[
        <String, Object?>{
          'allDay': true,
          'id': 'event-1',
          'title': 'First event',
        },
      ],
    };

CalendarSnapshotCommit _commit({
  String userScope = _userScope,
  String serverRevision = 'server-1',
  Map<String, List<Map<String, Object?>>>? eventsByDay,
}) => CalendarSnapshotCommit(
  userScope: userScope,
  serverRevision: serverRevision,
  overlayRevision: 'overlay-3',
  catalogFingerprint: 'catalog-a',
  origin: 'test_complete_viewport',
  committedAtUtc: DateTime.utc(2026, 8, 14, 7),
  lastSuccessfulRefreshAtUtc: DateTime.utc(2026, 8, 14, 6, 59),
  coverage: <CalendarSnapshotCoverageInterval>[
    CalendarSnapshotCoverageInterval(
      startUtc: DateTime.utc(2026, 9, 1),
      endUtc: DateTime.utc(2026, 10, 1),
    ),
    CalendarSnapshotCoverageInterval(
      startUtc: DateTime.utc(2026, 8, 1),
      endUtc: DateTime.utc(2026, 9, 1),
    ),
  ],
  eventsByDay: eventsByDay ?? _events,
  flows: <Map<String, Object?>>[
    <String, Object?>{'name': 'Morning walk', 'id': 7, 'active': true},
  ],
  calendarMetadata: const <String, Object?>{
    'personalCalendarId': 'personal-1',
    'hiddenCalendarIds': <String>['hidden-1'],
  },
  overlayRecords: <Map<String, Object?>>[
    <String, Object?>{
      'kind': 'create',
      'clientEventId': 'pending-1',
      'dayKey': '139-1-2',
    },
  ],
);
