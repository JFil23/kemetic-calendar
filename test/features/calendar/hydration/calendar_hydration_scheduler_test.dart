import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/hydration/calendar_hydration_models.dart';
import 'package:mobile/features/calendar/hydration/calendar_hydration_scheduler.dart';

void main() {
  CalendarHydrationInterval window(int day) => CalendarHydrationInterval(
    startUtc: DateTime.utc(2026, 8, day),
    endUtc: DateTime.utc(2026, 8, day + 1),
  );

  CalendarHydrationJob job({
    required CalendarHydrationIntentKind kind,
    required int priority,
    required int day,
    required CalendarHydrationJobRunner run,
    String reason = 'test',
    CalendarHydrationRetryPolicy retry = CalendarHydrationRetryPolicy.none,
  }) => CalendarHydrationJob(
    key: CalendarHydrationJobKey(
      kind: kind,
      reason: reason,
      interval: window(day),
      catalogFingerprint: 'catalog',
    ),
    priority: priority,
    run: run,
    retryPolicy: retry,
  );

  test('serializes database work', () async {
    var active = 0;
    var maximumActive = 0;
    final firstGate = Completer<void>();
    final scheduler = CalendarHydrationScheduler(isMounted: () => true);

    Future<void> run(CalendarHydrationJobContext context) async {
      active++;
      maximumActive = maximumActive < active ? active : maximumActive;
      if (active == 1 && !firstGate.isCompleted) await firstGate.future;
      active--;
    }

    final first = scheduler.schedule(
      job(
        kind: CalendarHydrationIntentKind.horizonChunk,
        priority: 10,
        day: 1,
        run: run,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final second = scheduler.schedule(
      job(
        kind: CalendarHydrationIntentKind.accounting,
        priority: 5,
        day: 2,
        run: run,
      ),
    );
    firstGate.complete();

    expect(await first, CalendarHydrationJobDisposition.completed);
    expect(await second, CalendarHydrationJobDisposition.completed);
    expect(maximumActive, 1);
    scheduler.dispose();
  });

  test('coalesces duplicate job keys', () async {
    var calls = 0;
    final scheduler = CalendarHydrationScheduler(isMounted: () => true);
    final sameJob = job(
      kind: CalendarHydrationIntentKind.viewport,
      priority: 100,
      day: 1,
      run: (_) async => calls++,
    );

    final first = scheduler.schedule(sameJob);
    final second = scheduler.schedule(sameJob);

    expect(await first, CalendarHydrationJobDisposition.completed);
    expect(await second, CalendarHydrationJobDisposition.completed);
    expect(calls, 1);
    scheduler.dispose();
  });

  test('intent window and fingerprint dedupe across reasons', () async {
    var calls = 0;
    final started = Completer<void>();
    final release = Completer<void>();
    final scheduler = CalendarHydrationScheduler(isMounted: () => true);

    final first = scheduler.schedule(
      job(
        kind: CalendarHydrationIntentKind.horizonChunk,
        priority: 50,
        day: 1,
        reason: 'startup',
        run: (_) async {
          calls++;
          started.complete();
          await release.future;
        },
      ),
    );
    await started.future;
    final second = scheduler.schedule(
      job(
        kind: CalendarHydrationIntentKind.horizonChunk,
        priority: 50,
        day: 1,
        reason: 'foreground_resume',
        run: (_) async => calls++,
      ),
    );
    release.complete();

    expect(await first, CalendarHydrationJobDisposition.completed);
    expect(await second, CalendarHydrationJobDisposition.completed);
    expect(calls, 1);
    scheduler.dispose();
  });

  test('unbounded maintenance reasons remain distinct identities', () {
    const first = CalendarHydrationJobKey(
      kind: CalendarHydrationIntentKind.reminderMaintenance,
      reason: 'verify_pending_cid:first',
    );
    const second = CalendarHydrationJobKey(
      kind: CalendarHydrationIntentKind.reminderMaintenance,
      reason: 'verify_pending_cid:second',
    );

    expect(first, isNot(second));
  });

  test('latest viewport supersedes an active viewport before commit', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    var firstCommitted = false;
    var secondCommitted = false;
    final scheduler = CalendarHydrationScheduler(isMounted: () => true);

    final first = scheduler.schedule(
      job(
        kind: CalendarHydrationIntentKind.viewport,
        priority: 100,
        day: 1,
        run: (context) async {
          firstStarted.complete();
          await releaseFirst.future;
          context.throwIfCancelled('before_merge');
          firstCommitted = true;
        },
      ),
      supersedeKind: true,
    );
    await firstStarted.future;
    final second = scheduler.schedule(
      job(
        kind: CalendarHydrationIntentKind.viewport,
        priority: 100,
        day: 2,
        run: (context) async {
          context.throwIfCancelled('before_merge');
          secondCommitted = true;
        },
      ),
      supersedeKind: true,
    );
    releaseFirst.complete();

    expect(await first, CalendarHydrationJobDisposition.cancelled);
    expect(await second, CalendarHydrationJobDisposition.completed);
    expect(firstCommitted, isFalse);
    expect(secondCommitted, isTrue);
    scheduler.dispose();
  });

  test('does not retry automatically while offline', () async {
    var calls = 0;
    final scheduler = CalendarHydrationScheduler(
      isMounted: () => true,
      isOnline: () => false,
      randomUnit: () => 0.5,
    );

    final result = await scheduler.schedule(
      job(
        kind: CalendarHydrationIntentKind.viewport,
        priority: 100,
        day: 1,
        retry: const CalendarHydrationRetryPolicy(
          maxAttempts: 3,
          initialDelay: Duration.zero,
        ),
        run: (_) async {
          calls++;
          throw StateError('offline');
        },
      ),
    );

    expect(result, CalendarHydrationJobDisposition.failed);
    expect(calls, 1);
    scheduler.dispose();
  });
}
