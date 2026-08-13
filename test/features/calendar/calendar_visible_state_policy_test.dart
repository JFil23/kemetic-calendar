import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_visible_state_policy.dart';

void main() {
  group('progressive hydration authority', () {
    test('only full horizon authorizes cache persistence and sentinel', () {
      for (final scope in <CalendarHydrationAuthorityScope>[
        CalendarHydrationAuthorityScope.none,
        CalendarHydrationAuthorityScope.visibleWindow,
      ]) {
        expect(shouldPersistWarmStartCache(scope), isFalse);
        expect(shouldSetFullServerHydrationSentinel(scope), isFalse);
        expect(shouldClearWarmStartSnapshotVisible(scope), isFalse);
        expect(shouldScheduleCacheSaveOnDataBump(scope), isFalse);
      }

      const full = CalendarHydrationAuthorityScope.fullHorizon;
      expect(shouldPersistWarmStartCache(full), isTrue);
      expect(shouldSetFullServerHydrationSentinel(full), isTrue);
      expect(shouldClearWarmStartSnapshotVisible(full), isTrue);
      expect(shouldScheduleCacheSaveOnDataBump(full), isTrue);
    });
  });

  group('window merge', () {
    final start = DateTime.utc(2026, 1, 2);
    final end = DateTime.utc(2026, 1, 4);
    DateTime? parse(String key) => DateTime.tryParse(key);

    test(
      'replaces the exact window and preserves outside and invalid keys',
      () {
        final merged = mergeHydrationWindowIntoNotes<int>(
          existing: <String, List<int>>{
            '2026-01-01': <int>[1],
            '2026-01-02': <int>[2],
            '2026-01-03': <int>[3],
            '2026-01-04': <int>[4],
            'legacy-key': <int>[5],
          },
          incoming: <String, List<int>>{
            '2026-01-03': <int>[30],
            '2026-01-04': <int>[40],
            'legacy-incoming': <int>[50],
          },
          windowStartInclusive: start,
          windowEndExclusive: end,
          parseKeyToDay: parse,
        );

        expect(merged, <String, List<int>>{
          '2026-01-01': <int>[1],
          '2026-01-04': <int>[4],
          'legacy-key': <int>[5],
          '2026-01-03': <int>[30],
        });
        expect(
          merged['2026-01-02'],
          isNull,
          reason: 'empty incoming removes it',
        );
        expect(
          merged['legacy-incoming'],
          isNull,
          reason: 'unparseable incoming cannot expand server authority',
        );
      },
    );

    test(
      'out-of-window reminder projection cannot replace selected-day rows',
      () {
        final merged = mergeHydrationWindowIntoNotes<String>(
          existing: <String, List<String>>{
            '2025-08-01': <String>['inside-old'],
            '2026-08-12': <String>[
              'selected-flow-1',
              'selected-flow-2',
              'selected-reminder',
            ],
          },
          incoming: <String, List<String>>{
            '2025-08-01': <String>['inside-new'],
            '2026-08-12': <String>['projected-reminder'],
          },
          windowStartInclusive: DateTime.utc(2025, 7, 13),
          windowEndExclusive: DateTime.utc(2025, 9, 26),
          parseKeyToDay: DateTime.tryParse,
        );

        expect(merged['2025-08-01'], <String>['inside-new']);
        expect(merged['2026-08-12'], <String>[
          'selected-flow-1',
          'selected-flow-2',
          'selected-reminder',
        ]);
      },
    );
  });

  group('serialized viewport checkpoint', () {
    test('replaces visible rows while preserving every outside raw bucket', () {
      final outsideBefore = <Object?>[
        <String, Object?>{'clientEventId': 'outside-before', 'legacy': true},
      ];
      final outsideAfter = <Object?>[
        <String, Object?>{'clientEventId': 'outside-after'},
      ];
      final invalid = <Object?>[
        <String, Object?>{'clientEventId': 'legacy-key'},
      ];
      final merged = mergeSerializedWarmCacheViewport(
        previous: <String, dynamic>{
          'userId': 'user',
          'compactionLevel': 'bounded',
          'cacheCenterDay': '2026-01-02T00:00:00.000',
          'cachePastDays': 30,
          'cacheFutureDays': 60,
          'notes': <String, dynamic>{
            '2026-01-01': outsideBefore,
            '2026-01-02': <Object?>[
              <String, Object?>{'clientEventId': 'stale-visible'},
            ],
            '2026-01-04': outsideAfter,
            'legacy-key': invalid,
          },
        },
        fresh: <String, dynamic>{
          'userId': 'user',
          'catalogFingerprint': 'fresh',
          'notes': <String, dynamic>{
            '2026-01-02': <Object?>[
              <String, Object?>{'clientEventId': 'fresh-visible'},
            ],
            '2026-01-04': <Object?>[
              <String, Object?>{'clientEventId': 'must-not-expand'},
            ],
          },
        },
        userId: 'user',
        viewportStartInclusive: DateTime.utc(2026, 1, 2),
        viewportEndExclusive: DateTime.utc(2026, 1, 4),
        parseKeyToDay: DateTime.tryParse,
      );

      expect(merged, isNotNull);
      final notes = merged!['notes'] as Map<String, dynamic>;
      expect(notes['2026-01-01'], same(outsideBefore));
      expect(notes['2026-01-04'], same(outsideAfter));
      expect(notes['legacy-key'], same(invalid));
      expect(
        ((notes['2026-01-02'] as List).single as Map)['clientEventId'],
        'fresh-visible',
      );
      expect(merged['catalogFingerprint'], 'fresh');
      expect(merged['compactionLevel'], 'viewport_checkpoint:bounded');
      expect(merged['cachePastDays'], 30);
      expect(merged['cacheFutureDays'], 60);
    });

    test('successful-empty viewport removes stale visible buckets', () {
      final merged = mergeSerializedWarmCacheViewport(
        previous: <String, dynamic>{
          'userId': 'user',
          'notes': <String, dynamic>{
            '2026-01-01': <Object?>['outside'],
            '2026-01-02': <Object?>['stale-visible'],
          },
        },
        fresh: <String, dynamic>{
          'userId': 'user',
          'notes': <String, dynamic>{},
        },
        userId: 'user',
        viewportStartInclusive: DateTime.utc(2026, 1, 2),
        viewportEndExclusive: DateTime.utc(2026, 1, 3),
        parseKeyToDay: DateTime.tryParse,
      );

      expect((merged!['notes'] as Map).keys, <String>['2026-01-01']);
    });

    test('refuses to merge a cache from another user', () {
      expect(
        mergeSerializedWarmCacheViewport(
          previous: <String, dynamic>{
            'userId': 'other-user',
            'notes': <String, dynamic>{},
          },
          fresh: <String, dynamic>{
            'userId': 'user',
            'notes': <String, dynamic>{},
          },
          userId: 'user',
          viewportStartInclusive: DateTime.utc(2026, 1, 2),
          viewportEndExclusive: DateTime.utc(2026, 1, 3),
          parseKeyToDay: DateTime.tryParse,
        ),
        isNull,
      );
    });
  });

  group('backfill chunks', () {
    test('subtracts focus and covers both sides without gaps or overlap', () {
      final unionStart = DateTime.utc(2026, 1, 1);
      final focusStart = DateTime.utc(2026, 2, 10);
      final focusEnd = DateTime.utc(2026, 3, 5);
      final unionEnd = DateTime.utc(2026, 6, 1);
      final chunks = buildBackfillChunks(
        unionStart: unionStart,
        unionEnd: unionEnd,
        excludeWindow: (startUtc: focusStart, endUtc: focusEnd),
        chunkDays: 20,
      );

      expect(chunks, isNotEmpty);
      expect(chunks.first.startUtc, unionStart);
      expect(chunks.last.endUtc, unionEnd);
      for (final chunk in chunks) {
        expect(chunk.endUtc.isAfter(chunk.startUtc), isTrue);
        expect(
          chunk.endUtc.difference(chunk.startUtc),
          lessThanOrEqualTo(const Duration(days: 20)),
        );
        final overlapsFocus =
            chunk.startUtc.isBefore(focusEnd) &&
            chunk.endUtc.isAfter(focusStart);
        expect(overlapsFocus, isFalse);
      }

      final intervals = <CalendarHydrationWindow>[
        ...chunks.where((chunk) => !chunk.endUtc.isAfter(focusStart)),
        (startUtc: focusStart, endUtc: focusEnd),
        ...chunks.where((chunk) => !chunk.startUtc.isBefore(focusEnd)),
      ];
      for (var index = 1; index < intervals.length; index++) {
        expect(intervals[index - 1].endUtc, intervals[index].startUtc);
      }
    });

    test('returns the whole union when exclusion is disjoint', () {
      final chunks = buildBackfillChunks(
        unionStart: DateTime.utc(2026, 1, 1),
        unionEnd: DateTime.utc(2026, 1, 11),
        excludeWindow: (
          startUtc: DateTime.utc(2027, 1, 1),
          endUtc: DateTime.utc(2027, 1, 2),
        ),
        chunkDays: 75,
      );
      expect(chunks, hasLength(1));
      expect(chunks.single.startUtc, DateTime.utc(2026, 1, 1));
      expect(chunks.single.endUtc, DateTime.utc(2026, 1, 11));
    });

    test('full-horizon retention removes only parseable outside buckets', () {
      final start = DateTime.utc(2026, 1, 2);
      final end = DateTime.utc(2026, 1, 4);
      final retained = retainNotesWithinHydrationWindow<int>(
        notes: <String, List<int>>{
          '2026-01-01': <int>[1],
          '2026-01-02': <int>[2],
          '2026-01-04': <int>[4],
          'legacy-key': <int>[5],
        },
        windowStartInclusive: start,
        windowEndExclusive: end,
        parseKeyToDay: DateTime.tryParse,
      );
      expect(retained, <String, List<int>>{
        '2026-01-02': <int>[2],
        'legacy-key': <int>[5],
      });
    });

    test('DST-spanning UTC chunks preserve exact half-open boundaries', () {
      final unionStart = DateTime(2026, 3, 7).toUtc();
      final focusStart = DateTime(2026, 3, 8).toUtc();
      final focusEnd = DateTime(2026, 3, 10).toUtc();
      final unionEnd = DateTime(2026, 3, 13).toUtc();
      final chunks = buildBackfillChunks(
        unionStart: unionStart,
        unionEnd: unionEnd,
        excludeWindow: (startUtc: focusStart, endUtc: focusEnd),
        chunkDays: 1,
      );

      final reconstructed = <CalendarHydrationWindow>[
        ...chunks.where((chunk) => !chunk.endUtc.isAfter(focusStart)),
        (startUtc: focusStart, endUtc: focusEnd),
        ...chunks.where((chunk) => !chunk.startUtc.isBefore(focusEnd)),
      ];
      expect(reconstructed.first.startUtc, unionStart);
      expect(reconstructed.last.endUtc, unionEnd);
      for (var index = 1; index < reconstructed.length; index++) {
        expect(reconstructed[index].startUtc, reconstructed[index - 1].endUtc);
      }
    });
  });
}
