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

  test(
    'event data refresh cannot join a catalog-only read for the same window',
    () async {
      final catalogStarted = Completer<void>();
      final releaseCatalog = Completer<void>();
      final scheduler = CalendarHydrationScheduler(isMounted: () => true);
      var eventReads = 0;
      final catalog = scheduler.schedule(
        job(
          kind: CalendarHydrationIntentKind.catalogReconcile,
          priority: 90,
          day: 1,
          run: (_) async {
            catalogStarted.complete();
            await releaseCatalog.future;
          },
        ),
      );
      await catalogStarted.future;
      final refresh = scheduler.schedule(
        job(
          kind: CalendarHydrationIntentKind.eventDataRefresh,
          priority: 90,
          day: 1,
          run: (context) async {
            context.throwIfCancelled('before_event_read');
            eventReads++;
          },
        ),
        supersedeKind: true,
        preemptLowerPriority: true,
      );
      releaseCatalog.complete();
      expect(await catalog, CalendarHydrationJobDisposition.completed);
      expect(await refresh, CalendarHydrationJobDisposition.completed);
      expect(eventReads, 1);
      scheduler.dispose();
    },
  );

  test(
    'a newer same-window data invalidation supersedes an already captured event read',
    () async {
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final scheduler = CalendarHydrationScheduler(isMounted: () => true);
      final committed = <int>[];
      final first = scheduler.schedule(
        job(
          kind: CalendarHydrationIntentKind.eventDataRefresh,
          priority: 90,
          day: 1,
          run: (context) async {
            const capturedVersion = 1;
            firstStarted.complete();
            await releaseFirst.future;
            context.throwIfCancelled('before_event_commit');
            committed.add(capturedVersion);
          },
        ),
        supersedeKind: true,
        preemptLowerPriority: true,
      );
      await firstStarted.future;
      final latest = scheduler.schedule(
        job(
          kind: CalendarHydrationIntentKind.eventDataRefresh,
          priority: 90,
          day: 1,
          run: (context) async {
            context.throwIfCancelled('before_event_commit');
            committed.add(2);
          },
        ),
        supersedeKind: true,
        preemptLowerPriority: true,
      );
      releaseFirst.complete();
      expect(await first, CalendarHydrationJobDisposition.cancelled);
      expect(await latest, CalendarHydrationJobDisposition.completed);
      expect(committed, [2]);
      scheduler.dispose();
    },
  );

  test(
    'queued data invalidations execute only the latest read while preserving serialization',
    () async {
      final viewportStarted = Completer<void>();
      final releaseViewport = Completer<void>();
      final scheduler = CalendarHydrationScheduler(isMounted: () => true);
      final committed = <int>[];
      final viewport = scheduler.schedule(
        job(
          kind: CalendarHydrationIntentKind.viewport,
          priority: 100,
          day: 1,
          run: (context) async {
            viewportStarted.complete();
            await releaseViewport.future;
            context.throwIfCancelled('before_viewport_commit');
          },
        ),
      );
      await viewportStarted.future;
      Future<CalendarHydrationJobDisposition> refresh(int version) =>
          scheduler.schedule(
            job(
              kind: CalendarHydrationIntentKind.eventDataRefresh,
              priority: 90,
              day: 1,
              run: (context) async {
                context.throwIfCancelled('before_event_commit');
                committed.add(version);
              },
            ),
            supersedeKind: true,
            preemptLowerPriority: true,
          );
      final first = refresh(1);
      final latest = refresh(2);
      expect(await first, CalendarHydrationJobDisposition.cancelled);
      expect(committed, isEmpty);
      releaseViewport.complete();
      expect(await viewport, CalendarHydrationJobDisposition.completed);
      expect(await latest, CalendarHydrationJobDisposition.completed);
      expect(committed, [2]);
      scheduler.dispose();
    },
  );
  test(
    'a newer external range retires only its matching active read',
    () async {
      final scheduler = CalendarHydrationScheduler(isMounted: () => true);
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final committed = <String>[];
      final first = scheduler.schedule(
        job(
          kind: CalendarHydrationIntentKind.externalRangeRefresh,
          priority: 85,
          day: 1,
          run: (context) async {
            firstStarted.complete();
            await releaseFirst.future;
            context.throwIfCancelled();
            committed.add('old range 1');
          },
        ),
        supersedeActiveKey: true,
      );
      await firstStarted.future;
      final otherRange = scheduler.schedule(
        job(
          kind: CalendarHydrationIntentKind.externalRangeRefresh,
          priority: 85,
          day: 2,
          run: (_) async => committed.add('range 2'),
        ),
        supersedeActiveKey: true,
      );
      final latest = scheduler.schedule(
        job(
          kind: CalendarHydrationIntentKind.externalRangeRefresh,
          priority: 85,
          day: 1,
          run: (_) async => committed.add('new range 1'),
        ),
        supersedeActiveKey: true,
      );
      releaseFirst.complete();

      expect(await first, CalendarHydrationJobDisposition.cancelled);
      expect(await otherRange, CalendarHydrationJobDisposition.completed);
      expect(await latest, CalendarHydrationJobDisposition.completed);
      expect(committed, <String>['range 2', 'new range 1']);
      scheduler.dispose();
    },
  );

  test(
    'queued external range duplicates use the latest reader without losing other ranges',
    () async {
      final scheduler = CalendarHydrationScheduler(isMounted: () => true);
      final started = Completer<void>();
      final release = Completer<void>();
      final blocker = scheduler.schedule(
        job(
          kind: CalendarHydrationIntentKind.viewport,
          priority: 100,
          day: 1,
          run: (_) async {
            started.complete();
            await release.future;
          },
        ),
      );
      await started.future;
      final committed = <String>[];
      final requests = <Future<CalendarHydrationJobDisposition>>[];
      for (final version in <int>[1, 2]) {
        requests.add(
          scheduler.schedule(
            job(
              kind: CalendarHydrationIntentKind.externalRangeRefresh,
              priority: 85,
              day: 1,
              run: (_) async => committed.add('range 1 version $version'),
            ),
            supersedeActiveKey: true,
          ),
        );
      }
      requests.add(
        scheduler.schedule(
          job(
            kind: CalendarHydrationIntentKind.externalRangeRefresh,
            priority: 85,
            day: 2,
            run: (_) async => committed.add('range 2'),
          ),
          supersedeActiveKey: true,
        ),
      );
      release.complete();

      expect(await blocker, CalendarHydrationJobDisposition.completed);
      expect(
        await Future.wait(requests),
        everyElement(CalendarHydrationJobDisposition.completed),
      );
      expect(committed, <String>['range 1 version 2', 'range 2']);
      scheduler.dispose();
    },
  );
  for (final refreshKind in <CalendarHydrationIntentKind>[
    CalendarHydrationIntentKind.externalRangeRefresh,
    CalendarHydrationIntentKind.eventDataRefresh,
  ]) {
    final refreshPriority =
        refreshKind == CalendarHydrationIntentKind.eventDataRefresh ? 90 : 85;
    test(
      'foreground preemption reruns ${refreshKind.name} and retains other windows',
      () async {
        final scheduler = CalendarHydrationScheduler(isMounted: () => true);
        final started = Completer<void>();
        final release = Completer<void>();
        var attempts = 0;
        var providerVersion = 1;
        final committed = <String>[];
        final activeRange = scheduler.schedule(
          job(
            kind: refreshKind,
            priority: refreshPriority,
            day: 1,
            run: (context) async {
              attempts++;
              final capturedVersion = providerVersion;
              if (attempts == 1) {
                started.complete();
                await release.future;
              }
              context.throwIfCancelled();
              committed.add('range 1 version $capturedVersion');
            },
          ),
          supersedeKind:
              refreshKind == CalendarHydrationIntentKind.eventDataRefresh,
          supersedeActiveKey:
              refreshKind == CalendarHydrationIntentKind.externalRangeRefresh,
        );
        await started.future;
        final otherRange = scheduler.schedule(
          job(
            kind: CalendarHydrationIntentKind.externalRangeRefresh,
            priority: 85,
            day: 2,
            run: (_) async => committed.add('range 2'),
          ),
          supersedeActiveKey: true,
        );
        providerVersion = 2;
        final viewport = scheduler.schedule(
          job(
            kind: CalendarHydrationIntentKind.viewport,
            priority: 100,
            day: 3,
            run: (_) async => committed.add('viewport'),
          ),
          supersedeKind: true,
          preemptLowerPriority: true,
        );
        release.complete();

        expect(await viewport, CalendarHydrationJobDisposition.completed);
        expect(await activeRange, CalendarHydrationJobDisposition.completed);
        expect(await otherRange, CalendarHydrationJobDisposition.completed);
        expect(attempts, 2);
        expect(
          committed,
          refreshKind == CalendarHydrationIntentKind.externalRangeRefresh
              ? <String>['viewport', 'range 2', 'range 1 version 2']
              : <String>['viewport', 'range 1 version 2', 'range 2'],
        );
        scheduler.dispose();
      },
    );
    test('account invalidation cancels requeued ${refreshKind.name}', () async {
      final scheduler = CalendarHydrationScheduler(isMounted: () => true);
      final started = Completer<void>();
      final release = Completer<void>();
      var rangeReads = 0;
      final range = scheduler.schedule(
        job(
          kind: refreshKind,
          priority: refreshPriority,
          day: 1,
          run: (context) async {
            rangeReads++;
            started.complete();
            await release.future;
            context.throwIfCancelled();
            fail('the departed account must not commit');
          },
        ),
        supersedeKind:
            refreshKind == CalendarHydrationIntentKind.eventDataRefresh,
        supersedeActiveKey:
            refreshKind == CalendarHydrationIntentKind.externalRangeRefresh,
      );
      await started.future;
      final viewport = scheduler.schedule(
        job(
          kind: CalendarHydrationIntentKind.viewport,
          priority: 100,
          day: 3,
          run: (_) async => fail('the departed account must not read'),
        ),
        supersedeKind: true,
        preemptLowerPriority: true,
      );
      scheduler.invalidateAll(reason: 'session_changed');
      release.complete();

      expect(await range, CalendarHydrationJobDisposition.cancelled);
      expect(await viewport, CalendarHydrationJobDisposition.cancelled);
      expect(rangeReads, 1);
      scheduler.dispose();
    });
  }
}
