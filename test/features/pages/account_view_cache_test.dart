import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/account_view_cache.dart';

void main() {
  test(
    'a new bounded background cycle can recover after the retry cap',
    () async {
      final cache = AccountViewCache()..enterAccount('a');
      for (var i = 0; i < 3; i++) {
        cache.beginVisibleEntry();
        await cache.load<int>(
          'a',
          'value',
          () async => throw StateError('offline'),
          mayFetch: () => true,
        );
      }
      cache.beginRefreshCycle();
      expect(
        await cache.load<int>(
          'a',
          'value',
          () async => 42,
          mayFetch: () => true,
        ),
        42,
      );
    },
  );

  test('fresh revisit and concurrent requests reuse one read', () async {
    final cache = AccountViewCache()
      ..enterAccount('u')
      ..beginVisibleEntry();
    final done = Completer<int>();
    var calls = 0;
    Future<int> fetch() {
      calls++;
      return done.future;
    }

    final first = cache.load('u', 'slice', fetch, mayFetch: () => true);
    final second = cache.load('u', 'slice', fetch, mayFetch: () => true);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    done.complete(7);
    expect(await first, 7);
    expect(await second, 7);
    cache.beginVisibleEntry();
    expect(await cache.load('u', 'slice', fetch, mayFetch: () => true), 7);
    expect(calls, 1);
  });
  test('failures stop and retry only on two later entries', () async {
    final cache = AccountViewCache()..enterAccount('u');
    var calls = 0;
    Future<int> fetch() async {
      calls++;
      throw StateError('offline');
    }

    for (var entry = 0; entry < 5; entry++) {
      cache.beginVisibleEntry();
      for (var rebuild = 0; rebuild < 4; rebuild++) {
        await cache.load('u', 'slice', fetch, mayFetch: () => true);
      }
    }
    expect(calls, 3);
    expect(cache.failed('slice'), isTrue);
  });
  test(
    'hidden view starts no request and account changes reject old response',
    () async {
      final cache = AccountViewCache()
        ..enterAccount('u')
        ..beginVisibleEntry();
      var calls = 0;
      final done = Completer<int>();
      Future<int> fetch() {
        calls++;
        return done.future;
      }

      await cache.load('u', 'slice', fetch, mayFetch: () => false);
      expect(calls, 0);
      final old = cache.load('u', 'slice', fetch, mayFetch: () => true);
      await Future<void>.delayed(Duration.zero);
      cache.enterAccount('other');
      done.complete(9);
      expect(await old, isNull);
      expect(cache.peek<int>('other', 'slice'), isNull);
    },
  );
  test(
    'mutation cannot be overwritten by an older in-flight response',
    () async {
      final cache = AccountViewCache()
        ..enterAccount('u')
        ..beginVisibleEntry();
      final done = Completer<int>();
      final old = cache.load(
        'u',
        'slice',
        () => done.future,
        mayFetch: () => true,
      );
      await Future<void>.delayed(Duration.zero);
      cache.publish('u', 'slice', 11);
      done.complete(7);
      expect(await old, isNull);
      expect(cache.peek<int>('u', 'slice'), 11);
    },
  );
  test('leaving before dispatch does not consume a failure retry', () async {
    final cache = AccountViewCache()
      ..enterAccount('u')
      ..beginVisibleEntry();
    var visible = true, calls = 0;
    final read = cache.load('u', 'slice', () async {
      calls++;
      return 1;
    }, mayFetch: () => visible);
    visible = false;
    await read;
    expect(calls, 0);
    expect(cache.failed('slice'), isFalse);
  });
}
