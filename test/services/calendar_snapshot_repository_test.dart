import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/calendar_snapshot_repository.dart';

const _identity = CalendarSnapshotIdentity(
  projectRef: 'project-ref',
  userId: 'user-1',
);

final _coverage = CalendarSnapshotCoverage(
  startUtc: DateTime.utc(2026, 6, 1),
  endUtc: DateTime.utc(2026, 9, 1),
);

void main() {
  test('complete candidate is confirmed before becoming last-good', () async {
    final store = MemoryCalendarSnapshotStore();
    final repository = CalendarSnapshotRepository(store: store);

    final promoted = await repository.promote(
      _candidate(events: const ['event-1']),
    );

    expect(promoted.eventCount, 1);
    expect(promoted.flowCount, 1);
    expect(promoted.completedLanes, containsAll(calendarSnapshotRequiredLanes));
    expect(repository.peek(_identity)?.digest, promoted.digest);

    final restarted = CalendarSnapshotRepository(store: store);
    final restored = await restarted.restore(_identity);
    expect(restored?.digest, promoted.digest);
    expect(restored?.eventCount, 1);
  });

  test(
    'complete candidate survives same-process remount while durable write is blocked',
    () async {
      final store = _BlockingCalendarSnapshotStore();
      final repository = CalendarSnapshotRepository(store: store);

      final promotion = repository.promote(
        _candidate(events: const ['event-1']),
      );
      await store.writeStarted.future;

      final remounted = await repository.restore(_identity);
      expect(
        remounted?.eventCount,
        1,
        reason:
            'A complete authoritative Calendar already on screen must remain '
            'available to a new route instance without waiting for IndexedDB.',
      );
      expect(
        repository.peek(_identity),
        isNull,
        reason:
            'The unconfirmed process handoff must not masquerade as durable '
            'last-good authority.',
      );

      store.releaseWrites();
      final confirmed = await promotion;
      expect(repository.peek(_identity)?.digest, confirmed.digest);
    },
  );

  test(
    'latest complete candidate keeps every visible field while an older write is blocked',
    () async {
      final store = _BlockingCalendarSnapshotStore();
      final repository = CalendarSnapshotRepository(store: store);

      final firstPromotion = repository.promote(
        _candidate(
          events: const ['old-event'],
          extraPayload: const <String, dynamic>{
            'calendarView': 'month',
            'activeOverlay': 'old-overlay',
            'editorDraft': 'old-draft',
            'cacheEpoch': 1,
            'dayViewMinute': 120,
          },
        ),
      );
      await store.writeStarted.future;

      final secondPromotion = repository.promote(
        _candidate(
          events: const ['new-event-1', 'new-event-2'],
          generation: 2,
          extraPayload: const <String, dynamic>{
            'calendarView': 'day',
            'activeOverlay': 'new-overlay',
            'editorDraft': 'new-draft',
            'cacheEpoch': 2,
            'dayViewMinute': 780,
          },
        ),
      );

      final remounted = await repository.restore(_identity);
      expect(remounted?.generation, 2);
      expect(remounted?.eventCount, 2);
      expect(remounted?.json, containsPair('calendarView', 'day'));
      expect(remounted?.json, containsPair('activeOverlay', 'new-overlay'));
      expect(remounted?.json, containsPair('editorDraft', 'new-draft'));
      expect(remounted?.json, containsPair('cacheEpoch', 2));
      expect(remounted?.json, containsPair('dayViewMinute', 780));

      store.releaseWrites();
      await Future.wait(<Future<CalendarSnapshotDocument>>[
        firstPromotion,
        secondPromotion,
      ]);
      expect(repository.peek(_identity)?.generation, 2);
    },
  );

  test(
    'older same-generation confirmation cannot replace a newer process mutation',
    () async {
      final store = _BlockingCalendarSnapshotStore();
      final repository = CalendarSnapshotRepository(store: store);

      final olderPromotion = repository.promote(
        _candidate(
          events: const ['old-event'],
          extraPayload: const <String, dynamic>{
            'calendarView': 'month',
            'activeOverlay': 'old-overlay',
            'editorDraft': 'old-draft',
            'cacheEpoch': 1,
            'dayViewMinute': 120,
          },
        ),
      );
      await store.writeStarted.future;

      repository.retainForProcessRemount(
        _candidate(
          events: const ['new-event'],
          extraPayload: const <String, dynamic>{
            'calendarView': 'day',
            'activeOverlay': 'new-overlay',
            'editorDraft': 'new-draft',
            'cacheEpoch': 2,
            'dayViewMinute': 780,
          },
        ),
      );

      store.releaseWrites();
      await olderPromotion;

      final remounted = await repository.restore(_identity);
      expect(remounted?.json, containsPair('calendarView', 'day'));
      expect(remounted?.json, containsPair('activeOverlay', 'new-overlay'));
      expect(remounted?.json, containsPair('editorDraft', 'new-draft'));
      expect(remounted?.json, containsPair('cacheEpoch', 2));
      expect(remounted?.json, containsPair('dayViewMinute', 780));
      expect(remounted?.eventCount, 1);
    },
  );

  test(
    'empty delayed disk restore yields a complete candidate retained during the read',
    () async {
      final store = _FirstReadBlockingCalendarSnapshotStore();
      final repository = CalendarSnapshotRepository(store: store);

      final restore = repository.restore(_identity);
      await store.firstReadStarted.future;
      final promotion = repository.promote(
        _candidate(events: const ['new-event']),
      );
      store.releaseFirstRead();

      final restored = await restore;
      expect(restored?.eventCount, 1);
      expect(restored?.generation, 1);
      await promotion;
    },
  );

  test('flows-only candidate without complete event lanes is rejected', () {
    final repository = CalendarSnapshotRepository(
      store: MemoryCalendarSnapshotStore(),
    );

    expect(
      () => repository.encodeCandidate(
        _candidate(
          events: const [],
          lanes: const <String>{calendarSnapshotLaneFlows},
        ),
      ),
      throwsStateError,
    );
  });

  test('valid empty calendar requires every lane and round-trips', () async {
    final repository = CalendarSnapshotRepository(
      store: MemoryCalendarSnapshotStore(),
    );

    final promoted = await repository.promote(_candidate(events: const []));

    expect(promoted.eventCount, 0);
    expect(promoted.completedLanes, containsAll(calendarSnapshotRequiredLanes));
  });

  test('event count or payload tampering invalidates durable authority', () {
    final repository = CalendarSnapshotRepository(
      store: MemoryCalendarSnapshotStore(),
    );
    final encoded = repository.encodeCandidate(
      _candidate(events: const ['event-1']),
    );
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    decoded['eventCount'] = 0;

    expect(
      repository.decodeAndValidate(
        jsonEncode(decoded),
        expectedIdentity: _identity,
      ),
      isNull,
    );
  });

  test(
    'failed durable write preserves the previous last-good snapshot',
    () async {
      final store = _FailingCalendarSnapshotStore();
      final repository = CalendarSnapshotRepository(store: store);
      final first = await repository.promote(
        _candidate(events: const ['event-1']),
      );
      store.failWrites = true;

      await expectLater(
        repository.promote(
          _candidate(events: const [], generation: 2, source: 'failed-refresh'),
        ),
        throwsStateError,
      );

      expect(repository.peek(_identity)?.digest, first.digest);
      expect(repository.peek(_identity)?.eventCount, 1);
    },
  );

  test('completed empty refresh may replace populated last-good', () async {
    final repository = CalendarSnapshotRepository(
      store: MemoryCalendarSnapshotStore(),
    );
    await repository.promote(
      _candidate(events: const ['a', 'b', 'c', 'd', 'e']),
    );

    final empty = await repository.promote(
      _candidate(
        events: const [],
        generation: 2,
        source: 'confirmed-empty-refresh',
      ),
    );

    expect(empty.eventCount, 0);
    expect(repository.peek(_identity)?.digest, empty.digest);
  });

  test(
    'new complete coverage replaces older coverage without false authority',
    () async {
      final repository = CalendarSnapshotRepository(
        store: MemoryCalendarSnapshotStore(),
      );
      await repository.promote(_candidate(events: const ['a']));

      final focused = await repository.promote(
        _candidate(
          events: const ['a'],
          generation: 2,
          coverage: CalendarSnapshotCoverage(
            startUtc: DateTime.utc(2026, 7, 1),
            endUtc: DateTime.utc(2026, 8, 1),
          ),
        ),
      );

      expect(
        focused.covers(
          CalendarSnapshotCoverage(
            startUtc: DateTime.utc(2026, 7, 10),
            endUtc: DateTime.utc(2026, 7, 20),
          ),
        ),
        isTrue,
      );
      expect(
        focused.covers(
          CalendarSnapshotCoverage(
            startUtc: DateTime.utc(2026, 5, 1),
            endUtc: DateTime.utc(2026, 6, 1),
          ),
        ),
        isFalse,
      );
    },
  );

  test(
    'snapshot outside the restored viewport is not covering authority',
    () async {
      final repository = CalendarSnapshotRepository(
        store: MemoryCalendarSnapshotStore(),
      );
      final promoted = await repository.promote(
        _candidate(events: const ['event-1']),
      );

      expect(
        promoted.covers(
          CalendarSnapshotCoverage(
            startUtc: DateTime.utc(2027, 1, 1),
            endUtc: DateTime.utc(2027, 2, 1),
          ),
        ),
        isFalse,
      );
    },
  );

  test('older generation cannot replace a newer durable authority', () async {
    final repository = CalendarSnapshotRepository(
      store: MemoryCalendarSnapshotStore(),
    );
    await repository.promote(
      _candidate(events: const ['newer'], generation: 2),
    );

    await expectLater(
      repository.promote(_candidate(events: const ['older'], generation: 1)),
      throwsStateError,
    );

    expect(repository.peek(_identity)?.generation, 2);
    expect(repository.peek(_identity)?.eventCount, 1);
  });

  test('delayed restore cannot replace a concurrent newer promotion', () async {
    final store = _FirstReadBlockingCalendarSnapshotStore();
    final seedRepository = CalendarSnapshotRepository(
      store: MemoryCalendarSnapshotStore(),
    );
    store.values[_identity.storageKey] = seedRepository.encodeCandidate(
      _candidate(events: const ['old'], generation: 1),
    );
    final repository = CalendarSnapshotRepository(store: store);

    final restore = repository.restore(_identity);
    await store.firstReadStarted.future;
    final promoted = await repository.promote(
      _candidate(events: const ['new'], generation: 2),
    );
    store.releaseFirstRead();

    final restored = await restore;
    expect(promoted.generation, 2);
    expect(restored?.generation, 2);
    expect(repository.peek(_identity)?.digest, promoted.digest);
  });
}

CalendarSnapshotCandidate _candidate({
  required List<String> events,
  Set<String> lanes = calendarSnapshotRequiredLanes,
  int generation = 1,
  String source = 'test',
  CalendarSnapshotCoverage? coverage,
  Map<String, dynamic> extraPayload = const <String, dynamic>{},
}) {
  return CalendarSnapshotCandidate(
    identity: _identity,
    coverage: coverage ?? _coverage,
    completedLanes: lanes,
    generation: generation,
    source: source,
    savedAt: DateTime.utc(2026, 7, 13),
    payload: <String, dynamic>{
      'nextFlowId': 2,
      'flows': const <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': 'Flow'},
      ],
      'notes': <String, dynamic>{
        if (events.isNotEmpty)
          '2026-1-1': <Map<String, dynamic>>[
            for (final event in events) <String, dynamic>{'title': event},
          ],
      },
      'calendarSummaries': const <Object?>[],
      'hiddenCalendarIds': const <String>[],
      'personalCalendarId': null,
      'flowTotalEventCounts': const <String, int>{},
      'flowRemainingEventCounts': const <String, int>{},
      ...extraPayload,
    },
  );
}

class _FailingCalendarSnapshotStore extends MemoryCalendarSnapshotStore {
  bool failWrites = false;

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('quota exceeded');
    await super.write(key, value);
  }
}

class _BlockingCalendarSnapshotStore extends MemoryCalendarSnapshotStore {
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> _release = Completer<void>();

  void releaseWrites() {
    if (!_release.isCompleted) _release.complete();
  }

  @override
  Future<void> write(String key, String value) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await _release.future;
    await super.write(key, value);
  }
}

class _FirstReadBlockingCalendarSnapshotStore
    extends MemoryCalendarSnapshotStore {
  final Completer<void> firstReadStarted = Completer<void>();
  final Completer<void> _firstReadRelease = Completer<void>();
  var _readCount = 0;

  @override
  Future<String?> read(String key) async {
    _readCount++;
    if (_readCount != 1) return super.read(key);
    final captured = values[key];
    firstReadStarted.complete();
    await _firstReadRelease.future;
    return captured;
  }

  void releaseFirstRead() {
    if (!_firstReadRelease.isCompleted) _firstReadRelease.complete();
  }
}
