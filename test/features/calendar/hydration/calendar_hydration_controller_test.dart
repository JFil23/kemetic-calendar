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
        ),
        isTrue,
      );
    },
  );

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
}
