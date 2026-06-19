import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/reminder_sync_gate.dart';

void main() {
  group('ReminderSyncGate', () {
    test(
      'defers sync while orientation-critical rendering is active',
      () async {
        final gate = ReminderSyncGate();
        var runs = 0;

        gate.beginOrientationCriticalSection();
        final sync = gate.runCoalesced(() async {
          runs += 1;
        });

        await Future<void>.delayed(Duration.zero);
        expect(runs, 0);

        gate.endOrientationCriticalSection();
        await sync;
        expect(runs, 1);
      },
    );

    test('coalesces duplicate sync requests while blocked', () async {
      final gate = ReminderSyncGate();
      var runs = 0;

      gate.beginOrientationCriticalSection();
      final first = gate.runCoalesced(() async {
        runs += 1;
      });
      final second = gate.runCoalesced(() async {
        runs += 1;
      });

      await Future<void>.delayed(Duration.zero);
      expect(runs, 0);

      gate.endOrientationCriticalSection();
      await Future.wait([first, second]);
      expect(runs, 1);
    });

    test('runs one follow-up pass for requests made during sync', () async {
      final gate = ReminderSyncGate();
      final firstRunEntered = Completer<void>();
      final releaseFirstRun = Completer<void>();
      var runs = 0;

      Future<void> task() async {
        runs += 1;
        if (runs == 1) {
          firstRunEntered.complete();
          await releaseFirstRun.future;
        }
      }

      final first = gate.runCoalesced(task);
      await firstRunEntered.future;
      final second = gate.runCoalesced(task);
      final third = gate.runCoalesced(task);

      releaseFirstRun.complete();
      await Future.wait([first, second, third]);
      expect(runs, 2);
    });
  });
}
