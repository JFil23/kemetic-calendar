import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/hydration/calendar_hydration_controller.dart';
import 'package:mobile/features/calendar/hydration/calendar_hydration_models.dart';
import 'package:mobile/features/calendar/hydration/calendar_hydration_scheduler.dart';

void main() {
  CalendarHydrationInterval interval(int start, int end) =>
      CalendarHydrationInterval(
        startUtc: DateTime.utc(2026, 8, start),
        endUtc: DateTime.utc(2026, 8, end),
      );

  late CalendarHydrationScheduler scheduler;
  late CalendarHydrationController controller;

  setUp(() {
    scheduler = CalendarHydrationScheduler(isMounted: () => true);
    controller = CalendarHydrationController(scheduler: scheduler);
    controller.beginSession('user');
  });

  tearDown(() => controller.dispose());

  test(
    'cache to provisional to server-current without duplicate lane fetch',
    () {
      final viewport = interval(1, 4);
      controller.restoreCache(
        catalogFingerprint: 'catalog-a',
        applyPreparedState: () {},
      );
      controller.reportViewport(viewport);
      var commits = 0;
      final token = controller.beginViewportCommit(
        catalogFingerprint: 'catalog-a',
        catalogIsFresh: false,
      );

      expect(
        controller.commitViewport(
          token: token,
          applyPreparedState: () => commits++,
        ),
        isTrue,
      );
      expect(
        controller.state.authority,
        CalendarViewportAuthority.viewportRefreshed,
      );
      expect(controller.state.stale, isTrue);
      expect(controller.promoteMatchingFreshCatalog('catalog-a'), isTrue);
      expect(
        controller.state.authority,
        CalendarViewportAuthority.serverCurrent,
      );
      expect(controller.state.stale, isFalse);
      expect(
        commits,
        1,
        reason: 'matching catalog must not refetch both lanes',
      );
    },
  );

  test('stale viewport token cannot commit', () {
    controller.restoreCache(
      catalogFingerprint: 'catalog-a',
      applyPreparedState: () {},
    );
    controller.reportViewport(interval(1, 4));
    final stale = controller.beginViewportCommit(
      catalogFingerprint: 'catalog-a',
      catalogIsFresh: false,
    );
    controller.reportViewport(interval(4, 7));
    var applied = false;

    expect(
      controller.commitViewport(
        token: stale,
        applyPreparedState: () => applied = true,
      ),
      isFalse,
    );
    expect(applied, isFalse);
  });

  test('authority is derived and demotes on uncovered viewport', () {
    controller.restoreCache(
      catalogFingerprint: 'catalog-a',
      applyPreparedState: () {},
    );
    controller.reportViewport(interval(1, 4));
    final token = controller.beginViewportCommit(
      catalogFingerprint: 'catalog-a',
      catalogIsFresh: true,
    );
    controller.commitViewport(token: token, applyPreparedState: () {});
    expect(controller.state.authority, CalendarViewportAuthority.serverCurrent);

    controller.reportViewport(interval(7, 9));
    expect(controller.state.authority, CalendarViewportAuthority.cacheVisible);
  });

  test(
    'full horizon and cache eligibility require fresh matching coverage',
    () {
      final horizon = interval(1, 10);
      controller.restoreCache(
        catalogFingerprint: 'catalog-a',
        applyPreparedState: () {},
      );
      controller.reportViewport(horizon);
      controller.setFullHorizon(horizon);
      final token = controller.beginViewportCommit(
        catalogFingerprint: 'catalog-a',
        catalogIsFresh: true,
      );
      controller.commitViewport(token: token, applyPreparedState: () {});

      expect(controller.state.authority, CalendarViewportAuthority.fullHorizon);
      expect(controller.state.mayPersistWarmCache, isTrue);
      expect(
        controller.validateCacheWrite(
          sessionGeneration: controller.state.sessionGeneration,
          catalogFingerprint: 'catalog-a',
        ),
        isTrue,
      );
    },
  );

  test(
    'fresh server-current viewport permits an explicit cache checkpoint',
    () {
      final viewport = interval(1, 4);
      controller.restoreCache(
        catalogFingerprint: 'catalog-a',
        applyPreparedState: () {},
      );
      controller.reportViewport(viewport);
      final token = controller.beginViewportCommit(
        catalogFingerprint: 'catalog-a',
        catalogIsFresh: true,
      );
      controller.commitViewport(token: token, applyPreparedState: () {});

      expect(
        controller.state.authority,
        CalendarViewportAuthority.serverCurrent,
      );
      expect(controller.state.mayPersistWarmCache, isFalse);
      expect(controller.state.mayPersistServerCurrentViewport, isTrue);
      expect(
        controller.validateCacheWrite(
          sessionGeneration: controller.state.sessionGeneration,
          catalogFingerprint: 'catalog-a',
        ),
        isFalse,
        reason: 'ordinary cache writes remain full-horizon only',
      );
      expect(
        controller.validateCacheWrite(
          sessionGeneration: controller.state.sessionGeneration,
          catalogFingerprint: 'catalog-a',
          allowServerCurrentViewport: true,
          requiredViewportRevision: controller.state.viewportRevision,
        ),
        isTrue,
      );
    },
  );

  test('viewport checkpoint rejects a later viewport revision', () {
    controller.restoreCache(
      catalogFingerprint: 'catalog-a',
      applyPreparedState: () {},
    );
    controller.reportViewport(interval(1, 4));
    final token = controller.beginViewportCommit(
      catalogFingerprint: 'catalog-a',
      catalogIsFresh: true,
    );
    controller.commitViewport(token: token, applyPreparedState: () {});
    final committedRevision = controller.state.viewportRevision;
    controller.reportViewport(interval(4, 7));

    expect(
      controller.validateCacheWrite(
        sessionGeneration: controller.state.sessionGeneration,
        catalogFingerprint: 'catalog-a',
        allowServerCurrentViewport: true,
        requiredViewportRevision: committedRevision,
      ),
      isFalse,
    );
  });

  test('provisional viewport cannot authorize a cache checkpoint', () {
    controller.restoreCache(
      catalogFingerprint: 'catalog-a',
      applyPreparedState: () {},
    );
    controller.reportViewport(interval(1, 4));
    final token = controller.beginViewportCommit(
      catalogFingerprint: 'catalog-a',
      catalogIsFresh: false,
    );
    controller.commitViewport(token: token, applyPreparedState: () {});

    expect(
      controller.state.authority,
      CalendarViewportAuthority.viewportRefreshed,
    );
    expect(controller.state.mayPersistServerCurrentViewport, isFalse);
    expect(
      controller.validateCacheWrite(
        sessionGeneration: controller.state.sessionGeneration,
        catalogFingerprint: 'catalog-a',
        allowServerCurrentViewport: true,
        requiredViewportRevision: controller.state.viewportRevision,
      ),
      isFalse,
    );
  });

  test('sign-out rejects a prepared commit from the prior user', () {
    controller.restoreCache(
      catalogFingerprint: 'catalog-a',
      applyPreparedState: () {},
    );
    controller.reportViewport(interval(1, 4));
    final token = controller.beginViewportCommit(
      catalogFingerprint: 'catalog-a',
      catalogIsFresh: false,
    );
    controller.signOut();
    var applied = false;

    expect(
      controller.commitViewport(
        token: token,
        applyPreparedState: () => applied = true,
      ),
      isFalse,
    );
    expect(applied, isFalse);
  });
  for (final activeKind in <CalendarHydrationIntentKind>[
    CalendarHydrationIntentKind.catalogReconcile,
    CalendarHydrationIntentKind.viewport,
  ]) {
    test(
      'catalog rebase preserves a newer data refresh behind ${activeKind.name}',
      () async {
        final viewport = interval(1, 4);
        controller.restoreCache(
          catalogFingerprint: 'catalog-a',
          applyPreparedState: () {},
        );
        controller.reportViewport(viewport);
        var visibleEvents = <String>['authored'];
        var externalEvents = <String>[];
        final started = Completer<void>();
        final release = Completer<void>();
        final active = scheduler.schedule(
          CalendarHydrationJob(
            key: CalendarHydrationJobKey(
              kind: activeKind,
              reason: 'catalog_changed',
              interval: viewport,
              catalogFingerprint: 'catalog-a',
            ),
            priority: activeKind == CalendarHydrationIntentKind.viewport
                ? 100
                : 90,
            run: (context) async {
              final token = controller.beginViewportCommit(
                catalogFingerprint: 'catalog-b',
                catalogIsFresh: true,
              );
              final capturedEvents = <String>['authored', ...externalEvents];
              started.complete();
              await release.future;
              context.throwIfCancelled();
              expect(
                controller.commitViewport(
                  token: token,
                  applyPreparedState: () => visibleEvents = capturedEvents,
                ),
                isTrue,
              );
            },
          ),
        );
        await started.future;
        final staleBackground = scheduler.schedule(
          CalendarHydrationJob(
            key: CalendarHydrationJobKey(
              kind: CalendarHydrationIntentKind.horizonChunk,
              reason: 'old_catalog_horizon',
              interval: viewport,
              catalogFingerprint: 'catalog-a',
            ),
            priority: 50,
            run: (_) async => fail('old catalog work must be cancelled'),
          ),
        );
        externalEvents = <String>['late imported event'];
        var freshEventReads = 0;
        final refresh = scheduler.schedule(
          CalendarHydrationJob(
            key: CalendarHydrationJobKey(
              kind: CalendarHydrationIntentKind.eventDataRefresh,
              reason: 'calendarImportSynced',
              interval: viewport,
              catalogFingerprint: 'catalog-a',
            ),
            priority: 90,
            run: (context) async {
              context.throwIfCancelled();
              // A data refresh refetches the catalog before reading its lanes.
              expect(controller.state.catalogFingerprint, 'catalog-b');
              final token = controller.beginViewportCommit(
                catalogFingerprint: 'catalog-b',
                catalogIsFresh: true,
              );
              freshEventReads++;
              expect(
                controller.commitViewport(
                  token: token,
                  applyPreparedState: () =>
                      visibleEvents = <String>['authored', ...externalEvents],
                ),
                isTrue,
              );
            },
          ),
          supersedeKind: true,
          preemptLowerPriority: true,
        );
        release.complete();

        expect(await active, CalendarHydrationJobDisposition.completed);
        expect(
          await staleBackground,
          CalendarHydrationJobDisposition.cancelled,
        );
        expect(await refresh, CalendarHydrationJobDisposition.completed);
        expect(freshEventReads, 1);
        expect(visibleEvents, <String>['authored', 'late imported event']);
        expect(controller.state.catalogFingerprint, 'catalog-b');
        expect(
          controller.state.authority,
          CalendarViewportAuthority.serverCurrent,
        );
      },
    );
  }

  for (final replaceAccount in <bool>[false, true]) {
    test(
      '${replaceAccount ? 'account replacement' : 'sign-out'} cancels queued data refresh',
      () async {
        final viewport = interval(1, 4);
        controller.reportViewport(viewport);
        final started = Completer<void>();
        final release = Completer<void>();
        final active = scheduler.schedule(
          CalendarHydrationJob(
            key: CalendarHydrationJobKey(
              kind: CalendarHydrationIntentKind.viewport,
              reason: 'old_account_viewport',
              interval: viewport,
            ),
            priority: 100,
            run: (context) async {
              started.complete();
              await release.future;
              context.throwIfCancelled();
              fail('the prior account must not commit');
            },
          ),
        );
        await started.future;
        final refresh = scheduler.schedule(
          CalendarHydrationJob(
            key: CalendarHydrationJobKey(
              kind: CalendarHydrationIntentKind.eventDataRefresh,
              reason: 'calendarImportSynced',
              interval: viewport,
            ),
            priority: 90,
            run: (_) async => fail('the prior account must not read events'),
          ),
          supersedeKind: true,
          preemptLowerPriority: true,
        );
        if (replaceAccount) {
          controller.beginSession('next-user');
        } else {
          controller.signOut();
        }
        release.complete();

        expect(await active, CalendarHydrationJobDisposition.cancelled);
        expect(await refresh, CalendarHydrationJobDisposition.cancelled);
        expect(controller.state.authority, CalendarViewportAuthority.none);
      },
    );
  }
  test(
    'catalog rebase retains an external range without moving the viewport',
    () async {
      final viewport = interval(1, 4);
      final outsideRange = interval(7, 9);
      controller.restoreCache(
        catalogFingerprint: 'catalog-a',
        applyPreparedState: () {},
      );
      controller.reportViewport(viewport);
      final started = Completer<void>();
      final release = Completer<void>();
      final active = scheduler.schedule(
        CalendarHydrationJob(
          key: CalendarHydrationJobKey(
            kind: CalendarHydrationIntentKind.catalogReconcile,
            reason: 'catalog_changed',
            interval: viewport,
            catalogFingerprint: 'catalog-a',
          ),
          priority: 90,
          run: (context) async {
            final token = controller.beginViewportCommit(
              catalogFingerprint: 'catalog-b',
              catalogIsFresh: true,
            );
            started.complete();
            await release.future;
            context.throwIfCancelled();
            expect(
              controller.commitViewport(
                token: token,
                applyPreparedState: () {},
              ),
              isTrue,
            );
          },
        ),
      );
      await started.future;
      var outsideEventVisible = false;
      final refresh = scheduler.schedule(
        CalendarHydrationJob(
          key: CalendarHydrationJobKey(
            kind: CalendarHydrationIntentKind.externalRangeRefresh,
            reason: 'late_external_range',
            interval: outsideRange,
            catalogFingerprint: 'catalog-a',
          ),
          priority: 85,
          run: (context) async {
            context.throwIfCancelled();
            // Match the production range runner: resolve the fresh catalog
            // after queueing, not from the superseded job-key fingerprint.
            final fingerprint = controller.state.freshCatalogFingerprint!;
            expect(fingerprint, 'catalog-b');
            expect(
              controller.commitBackgroundInterval(
                sessionGeneration: controller.state.sessionGeneration,
                catalogFingerprint: fingerprint,
                interval: outsideRange,
                applyPreparedState: () => outsideEventVisible = true,
              ),
              isTrue,
            );
          },
        ),
        supersedeActiveKey: true,
      );
      release.complete();

      expect(await active, CalendarHydrationJobDisposition.completed);
      expect(await refresh, CalendarHydrationJobDisposition.completed);
      expect(outsideEventVisible, isTrue);
      expect(controller.state.viewport, viewport);
      expect(controller.state.coverage.covers(viewport), isTrue);
      expect(controller.state.coverage.covers(outsideRange), isTrue);
      expect(controller.state.catalogFingerprint, 'catalog-b');
    },
  );
  test(
    'preempted data refresh commits the latest viewport and changed catalog together',
    () async {
      final originalViewport = interval(1, 4);
      final currentViewport = interval(7, 9);
      controller.restoreCache(
        catalogFingerprint: 'catalog-a',
        applyPreparedState: () {},
      );
      controller.reportViewport(originalViewport);
      final catalogStarted = Completer<void>();
      final releaseCatalog = Completer<void>();
      final readWindows = <CalendarHydrationInterval>[];
      var catalogReads = 0;
      var eventApplied = false;
      final refresh = scheduler.schedule(
        CalendarHydrationJob(
          key: CalendarHydrationJobKey(
            kind: CalendarHydrationIntentKind.eventDataRefresh,
            reason: 'calendarImportSynced',
            interval: originalViewport,
            catalogFingerprint: 'catalog-a',
          ),
          priority: 90,
          run: (context) async {
            catalogReads++;
            if (catalogReads == 1) {
              catalogStarted.complete();
              await releaseCatalog.future;
            }
            context.throwIfCancelled('after_catalog_fetch');
            final token = controller.beginViewportCommit(
              catalogFingerprint: 'catalog-b',
              catalogIsFresh: true,
            );
            readWindows.add(token.interval);
            expect(
              controller.commitViewport(
                token: token,
                applyPreparedState: () => eventApplied = true,
              ),
              isTrue,
            );
          },
        ),
        supersedeKind: true,
        preemptLowerPriority: true,
      );
      await catalogStarted.future;
      controller.reportViewport(currentViewport);
      final viewport = scheduler.schedule(
        CalendarHydrationJob(
          key: CalendarHydrationJobKey(
            kind: CalendarHydrationIntentKind.viewport,
            reason: 'navigation',
            interval: currentViewport,
            catalogFingerprint: 'catalog-a',
          ),
          priority: 100,
          run: (context) async {
            context.throwIfCancelled();
            final token = controller.beginViewportCommit(
              catalogFingerprint: 'catalog-a',
              catalogIsFresh: false,
            );
            expect(
              controller.commitViewport(
                token: token,
                applyPreparedState: () {},
              ),
              isTrue,
            );
          },
        ),
        supersedeKind: true,
        preemptLowerPriority: true,
      );
      releaseCatalog.complete();

      expect(await viewport, CalendarHydrationJobDisposition.completed);
      expect(await refresh, CalendarHydrationJobDisposition.completed);
      expect(catalogReads, 2);
      expect(readWindows, <CalendarHydrationInterval>[currentViewport]);
      expect(eventApplied, isTrue);
      expect(controller.state.viewport, currentViewport);
      expect(controller.state.catalogFingerprint, 'catalog-b');
      expect(controller.state.coverage.covers(currentViewport), isTrue);
      expect(controller.state.coverage.covers(originalViewport), isFalse);
      expect(
        controller.state.authority,
        CalendarViewportAuthority.serverCurrent,
      );
    },
  );
}
