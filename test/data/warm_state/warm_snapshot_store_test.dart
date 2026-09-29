import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('artwork yields storage to primary destinations', () async {
    final store = WarmSnapshotStore(maxEntries: 2);
    for (final key in ['pages.flows', 'image.art', 'flow.detail.1']) {
      await store.refresh('a', key, () async => [1], isCurrent: () => true);
      await store.flushed;
    }
    expect(store.peek('a', 'pages.flows'), isNotNull);
    expect(store.peek('a', 'image.art'), isNull);
    expect(await WarmSnapshotStore().cached('a', 'pages.flows'), [1]);
  });

  test('complete empty survives restart; absence stays a miss', () async {
    final store = WarmSnapshotStore();
    await store.refresh(
      'a',
      'notes.page.0',
      () async => [],
      isCurrent: () => true,
    );
    await store.flushed;
    final restart = WarmSnapshotStore();
    expect(await restart.cached('a', 'notes.page.0'), isEmpty);
    expect(
      () => restart.cached('b', 'notes.page.0'),
      throwsA(isA<WarmCacheMiss>()),
    );
  });

  test(
    'slow refresh preserves the previous snapshot and coalesces reads',
    () async {
      final store = WarmSnapshotStore();
      await store.refresh(
        'a',
        'flow',
        () async => {'title': 'Before'},
        isCurrent: () => true,
      );
      final reply = Completer<Object?>();
      var requests = 0;
      Future<Object?> read() {
        requests++;
        return reply.future;
      }

      final first = store.refresh('a', 'flow', read, isCurrent: () => true);
      final second = store.refresh('a', 'flow', read, isCurrent: () => true);
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
      expect((store.peek('a', 'flow')!.data as Map)['title'], 'Before');
      reply.complete({'title': 'After'});
      await Future.wait([first, second]);
      expect((store.peek('a', 'flow')!.data as Map)['title'], 'After');
    },
  );

  test('failed refresh cannot persist empty over good content', () async {
    final store = WarmSnapshotStore();
    await store.refresh('a', 'events', () async => [1], isCurrent: () => true);
    await expectLater(
      store.refresh(
        'a',
        'events',
        () async => throw StateError('offline'),
        isCurrent: () => true,
      ),
      throwsStateError,
    );
    expect(store.peek('a', 'events')!.data, [1]);
    await store.flushed;
    expect(await WarmSnapshotStore().cached('a', 'events'), [1]);
  });

  test(
    'account departure rejects late reads and deletes persisted data',
    () async {
      final store = WarmSnapshotStore();
      await store.refresh(
        'a',
        'events',
        () async => [1],
        isCurrent: () => true,
      );
      final reply = Completer<Object?>();
      final read = store.refresh(
        'a',
        'events',
        () => reply.future,
        isCurrent: () => true,
      );
      final expectation = expectLater(read, throwsA(isA<WarmReadCancelled>()));
      await Future<void>.delayed(Duration.zero);
      await store.forgetAccount('a');
      reply.complete([2]);
      await expectation;
      await store.flushed;
      expect(store.peek('a', 'events'), isNull);
      expect(
        () => WarmSnapshotStore().cached('a', 'events'),
        throwsA(isA<WarmCacheMiss>()),
      );
    },
  );

  test('mutation invalidation rejects an older request', () async {
    final store = WarmSnapshotStore();
    final reply = Completer<Object?>();
    final read = store.refresh(
      'a',
      'flow.1',
      () => reply.future,
      isCurrent: () => true,
    );
    final expectation = expectLater(read, throwsA(isA<WarmReadCancelled>()));
    await Future<void>.delayed(Duration.zero);
    store.invalidate('a', prefix: 'flow.');
    reply.complete({'deleted': false});
    await expectation;
    expect(store.peek('a', 'flow.1'), isNull);
  });

  test(
    'working set evicts oldest resources and remains bounded after restart',
    () async {
      var time = DateTime(2026);
      final store = WarmSnapshotStore(maxEntries: 2, now: () => time);
      for (var i = 0; i < 3; i++) {
        time = time.add(const Duration(seconds: 1));
        await store.refresh('a', '$i', () async => [i], isCurrent: () => true);
        await store.flushed;
      }
      expect(store.peek('a', '0'), isNull);
      expect(await WarmSnapshotStore(maxEntries: 2).cached('a', '2'), [2]);
    },
  );
}
