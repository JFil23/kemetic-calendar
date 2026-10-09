import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/warm_state/warm_work_queue.dart';

void main() {
  test(
    'bounded workers deduplicate; pause fences running work and clears queued work',
    () async {
      final queue = WarmWorkQueue(concurrency: 2)..resume();
      final pending = <Completer<void>>[];
      final guards = <bool Function()>[];
      var runs = 0;
      Future<void> job() async {
        runs++;
        guards.add(Zone.current[warmReadGuard] as bool Function());
        final done = Completer<void>();
        pending.add(done);
        await done.future;
      }

      queue.enqueue('a', job);
      queue.enqueue('a', job);
      queue.enqueue('b', job);
      queue.enqueue('c', job);
      expect(runs, 2);
      expect(guards.every((g) => g()), isTrue);
      queue.pause();
      expect(guards.every((g) => !g()), isTrue);
      for (final done in pending) {
        done.complete();
      }
      await Future<void>.delayed(Duration.zero);
      expect(runs, 2);
      queue.resume();
      queue.enqueue('d', () async {
        runs++;
      });
      await Future<void>.delayed(Duration.zero);
      expect(runs, 3);
      queue.pause();
    },
  );
  test('a failed job frees its worker without dropping later jobs', () async {
    final queue = WarmWorkQueue(concurrency: 1)..resume();
    final calls = <int>[];
    queue.enqueue('failed', () async {
      calls.add(1);
      throw StateError('offline');
    });
    queue.enqueue('next', () async {
      calls.add(2);
    });
    await Future<void>.delayed(Duration.zero);
    expect(calls, [1, 2]);
    queue.pause();
  });

  test(
    'priority promotes queued work without more workers or duplicate reads',
    () async {
      final queue = WarmWorkQueue(concurrency: 2)..resume();
      final first = Completer<void>(), second = Completer<void>();
      final order = <String>[];
      queue.enqueue('first', () async {
        order.add('first');
        await first.future;
      });
      queue.enqueue('second', () async {
        order.add('second');
        await second.future;
      });
      queue.enqueue('archive', () async {
        order.add('archive');
      });
      queue.enqueue('flow', () async {
        order.add('flow');
      });
      queue.prioritize('flow');
      queue.prioritize('missing');
      queue.enqueue('first', () async {
        fail('Do not duplicate a running read');
      }, priority: true);
      expect(order, ['first', 'second']);
      first.complete();
      await Future<void>.delayed(Duration.zero);
      expect(order, ['first', 'second', 'flow', 'archive']);
      second.complete();
      await Future<void>.delayed(Duration.zero);
      queue.pause();
    },
  );

  test(
    'resume queues a fresh generation behind its departed in-flight read',
    () async {
      final queue = WarmWorkQueue(concurrency: 2)..resume();
      final held = Completer<void>();
      final order = <String>[];
      late bool Function() oldGuard;
      queue.enqueue('flow', () async {
        oldGuard = Zone.current[warmReadGuard] as bool Function();
        order.add('departed');
        await held.future;
      }, priority: true);
      queue.enqueue('discarded', () async {
        await held.future;
      });
      queue.enqueue('old-pending', () async {
        fail('Paused work must be cleared');
      }, priority: true);
      queue.pause();
      queue.resume();
      queue.enqueue('flow', () async {
        expect((Zone.current[warmReadGuard] as bool Function())(), isTrue);
        order.add('current');
      }, priority: true);
      expect(oldGuard(), isFalse);
      expect(order, ['departed']);
      held.complete();
      await Future<void>.delayed(Duration.zero);
      expect(order, ['departed', 'current']);
      queue.pause();
    },
  );
}
