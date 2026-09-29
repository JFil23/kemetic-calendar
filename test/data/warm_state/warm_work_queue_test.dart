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
}
