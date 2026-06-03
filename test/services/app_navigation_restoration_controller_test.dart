import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/services/app_navigation_restoration_controller.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _snapshotKey({String userId = 'user-1', String windowId = 'window-1'}) {
  return 'app_restoration_v1:$userId:$windowId';
}

Map<String, dynamic> _durableRouteFields(String route) {
  final metadata = const NavigationPersistencePolicy()
      .classifyRoute(route, NavigationSource.userPrimaryTab)
      .metadata;
  return <String, dynamic>{
    'routeLocation': route,
    navigationLaunchRouteMetadataKey: metadata.toJson(),
  };
}

Future<void> _writeRawSnapshot(Map<String, dynamic> fields) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _snapshotKey(),
    jsonEncode(<String, dynamic>{
      'schemaVersion': AppRestorationService.schemaVersion,
      'userId': 'user-1',
      'windowId': 'window-1',
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      ...fields,
    }),
  );
}

Future<String?> _durableRoute() async {
  await AppRestorationService.instance.flushPendingWrites();
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_snapshotKey());
  if (raw == null) return null;
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return (decoded['routeLocation'] as String?)?.trim();
}

Future<Map<String, dynamic>?> _durableMetadataJson() async {
  await AppRestorationService.instance.flushPendingWrites();
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_snapshotKey());
  if (raw == null) return null;
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final metadata = decoded[navigationLaunchRouteMetadataKey];
  if (metadata is! Map) return null;
  return Map<String, dynamic>.from(metadata);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRestorationService.debugUserIdResolver = () => 'user-1';
    AppWindowService.debugWindowIdResolver = () async => 'window-1';
    AppWindowService.instance.resetForTesting();
    AppNavigationRestorationController.instance.resetForTesting();
  });

  tearDown(() {
    AppRestorationService.debugUserIdResolver = null;
    AppWindowService.debugWindowIdResolver = null;
    AppWindowService.instance.resetForTesting();
    AppNavigationRestorationController.instance.resetForTesting();
  });

  test(
    'stale legacy inbox plus valid calendar state launches Calendar',
    () async {
      await _writeRawSnapshot(<String, dynamic>{
        'routeLocation': '/inbox',
        'calendar': <String, dynamic>{
          'kYear': 6267,
          'kMonth': 4,
          'kDay': 12,
          'showGregorian': true,
          'expansion': 'details',
          'anchorTarget': 'monthBody',
          'anchorAlignment': 0.44,
          'viewportHeight': 812.0,
          'layoutRevision': 1,
          'scrollOffset': 4200.0,
        },
      });

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);

      expect(destination.route, '/');
      expect(destination.reason, 'no_durable_launch_route');
      expect(await _durableRoute(), isNull);

      final calendar = await AppRestorationService.instance.readCalendarState();
      expect(calendar, isNotNull);
      expect(calendar!.kMonth, 4);
      expect(calendar.scrollOffset, 4200.0);
    },
  );

  test('explicit user primary Inbox metadata launches Inbox', () async {
    await AppNavigationRestorationController.instance.recordPrimaryTabSelection(
      AppSection.inbox,
    );

    final destination = await AppNavigationRestorationController.instance
        .restoreLaunchDestination(isAuthenticated: true);

    expect(await _durableRoute(), '/inbox');
    expect(destination.route, '/inbox');
    expect(destination.reason, 'valid_durable_metadata');
  });

  test('explicit user primary Library metadata launches Library', () async {
    await AppNavigationRestorationController.instance.recordPrimaryTabSelection(
      AppSection.library,
    );

    final destination = await AppNavigationRestorationController.instance
        .restoreLaunchDestination(isAuthenticated: true);

    expect(await _durableRoute(), '/nodes');
    expect(await _durableMetadataJson(), containsPair('section', 'library'));
    expect(
      await _durableMetadataJson(),
      containsPair('canonicalRoute', '/nodes'),
    );
    expect(destination.route, '/nodes');
    expect(destination.reason, 'valid_durable_metadata');
  });

  test('explicit user primary Calendar metadata launches Calendar', () async {
    await AppNavigationRestorationController.instance.recordPrimaryTabSelection(
      AppSection.calendar,
    );

    final destination = await AppNavigationRestorationController.instance
        .restoreLaunchDestination(isAuthenticated: true);

    expect(await _durableRoute(), '/');
    expect(destination.route, '/');
    expect(destination.reason, 'valid_durable_metadata');
  });

  test(
    'calendar page-state writes preserve the durable Library launch route',
    () async {
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.library);
      await AppRestorationService.instance.saveCalendarState(
        const CalendarRestorationState(
          kYear: 6267,
          kMonth: 4,
          kDay: 12,
          showGregorian: true,
          expansion: 'details',
          anchorTarget: 'monthBody',
          anchorAlignment: 0.44,
          viewportHeight: 812,
          layoutRevision: 1,
          scrollOffset: 4200,
        ),
      );
      await AppRestorationService.instance.saveDayViewState(
        const DayViewRestorationState(
          isOpen: true,
          kYear: 6267,
          kMonth: 4,
          kDay: 12,
          showGregorian: true,
          firstVisibleMinute: 480,
        ),
      );

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);
      final snapshot = await AppRestorationService.instance.readSnapshot();

      expect(await _durableRoute(), '/nodes');
      expect(destination.route, '/nodes');
      expect(snapshot?.calendar?.scrollOffset, 4200);
      expect(snapshot?.dayView?.isOpen, isTrue);
      expect(snapshot?.dayView?.kDay, 12);
    },
  );

  test(
    'calendar Day View state restores with the durable Calendar launch route',
    () async {
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.calendar);
      await AppRestorationService.instance.saveCalendarState(
        const CalendarRestorationState(
          kYear: 6267,
          kMonth: 3,
          kDay: 15,
          showGregorian: false,
          expansion: 'details',
          anchorTarget: 'dayChip',
          anchorAlignment: 0.5,
          viewportHeight: 700,
          layoutRevision: 1,
          scrollOffset: 1800,
        ),
      );
      await AppRestorationService.instance.saveDayViewState(
        const DayViewRestorationState(
          isOpen: true,
          kYear: 6267,
          kMonth: 3,
          kDay: 15,
          showGregorian: false,
          firstVisibleMinute: 540,
          scrollOffset: 120,
        ),
      );

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);
      final snapshot = await AppRestorationService.instance.readSnapshot();

      expect(destination.route, '/');
      expect(snapshot?.calendar?.kDay, 15);
      expect(snapshot?.calendar?.scrollOffset, 1800);
      expect(snapshot?.dayView?.isOpen, isTrue);
      expect(snapshot?.dayView?.firstVisibleMinute, 540);
      expect(snapshot?.dayView?.scrollOffset, 120);
    },
  );

  test('calendar didPushNext and dispose cannot persist Inbox', () async {
    for (final source in const <NavigationSource>[
      NavigationSource.calendarDidPushNext,
      NavigationSource.calendarDispose,
    ]) {
      await AppRestorationService.instance.clearCurrentSnapshot();
      await AppNavigationRestorationController.instance.recordNavigationAttempt(
        route: '/inbox',
        source: source,
      );
      expect(await _durableRoute(), isNull, reason: source.wireName);
    }
  });

  test(
    'one-shot taps navigate once without altering durable launch route',
    () async {
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.library);

      final intents = <PendingNavigationIntent>[
        const PendingNavigationIntent(
          key: 'notification:event-1',
          requestedRoute: '/shared-flow/by-flow/42',
          source: NavigationSource.notificationTap,
        ),
        const PendingNavigationIntent(
          key: 'search:event-1',
          requestedRoute: '/nodes/human_emergence',
          source: NavigationSource.searchResultTap,
        ),
        const PendingNavigationIntent(
          key: 'shared-calendar:event-1',
          requestedRoute: '/event-invite/invite-1',
          source: NavigationSource.sharedCalendarEventTap,
        ),
      ];

      for (final intent in intents) {
        final resolution = await AppNavigationRestorationController.instance
            .consumeOneShotIntent(intent);
        expect(resolution?.route, isNotNull, reason: intent.key);
        expect(await _durableRoute(), '/nodes', reason: intent.key);
      }
    },
  );

  test('node action URLs are one-shot and sanitize to stable routes', () async {
    final resolution = await AppNavigationRestorationController.instance
        .consumeOneShotIntent(
          const PendingNavigationIntent(
            key: 'node:human-emergence:add-insight',
            requestedRoute: '/nodes/human_emergence?action=add_insight',
            source: NavigationSource.nodeActionUrl,
          ),
        );

    expect(resolution, isNotNull);
    expect(resolution!.route, '/nodes/human_emergence');
    expect(resolution.reason, 'one_shot_intent_sanitized');
    expect(await _durableRoute(), isNull);
  });

  test('auth callbacks do not become durable launch routes', () async {
    final resolution = await AppNavigationRestorationController.instance
        .consumeOneShotIntent(
          const PendingNavigationIntent(
            key: 'auth:recovery',
            requestedRoute: '/?type=recovery&code=abc',
            source: NavigationSource.authCallback,
          ),
        );

    expect(resolution, isNotNull);
    expect(resolution!.route, '/');
    expect(await _durableRoute(), isNull);
  });

  test('one-shot intents are consumed once and never durable', () async {
    const intent = PendingNavigationIntent(
      key: 'notification:dedupe',
      requestedRoute: '/shared-flow/by-flow/42',
      source: NavigationSource.notificationTap,
    );

    final first = await AppNavigationRestorationController.instance
        .consumeOneShotIntent(intent);
    final second = await AppNavigationRestorationController.instance
        .consumeOneShotIntent(intent);

    expect(first, isNotNull);
    expect(second, isNull);
    expect(await _durableRoute(), isNull);
  });

  test('unknown, edit, detail, modal, and query routes are rejected', () async {
    const policy = NavigationPersistencePolicy();
    const unsafeRoutes = <String>[
      '/unknown',
      '/flows/42/edit',
      '/inbox/conversation/friend-1',
      '/shared-flow/by-flow/42',
      '/event-invite/invite-1',
      '/nodes/human_emergence',
      '/nodes?focus=human_emergence',
      '/inbox?filter=unread',
      '/settings#privacy',
    ];

    for (final route in unsafeRoutes) {
      final classification = policy.classifyRoute(
        route,
        NavigationSource.userPrimaryTab,
      );
      expect(classification.accepted, isFalse, reason: route);
      expect(
        classification.routeClass,
        isNot(NavigationRouteClass.durablePrimary),
        reason: route,
      );
    }
  });

  test(
    'generic navigation attempts from every source never persist durable state',
    () async {
      for (final source in NavigationSource.values) {
        await AppRestorationService.instance.clearCurrentSnapshot();
        await AppNavigationRestorationController.instance
            .recordNavigationAttempt(route: '/inbox', source: source);

        expect(await _durableRoute(), isNull, reason: source.wireName);
      }
    },
  );

  test('legacy route without current durable metadata is ignored', () async {
    await _writeRawSnapshot(<String, dynamic>{'routeLocation': '/inbox'});

    final destination = await AppNavigationRestorationController.instance
        .restoreLaunchDestination(isAuthenticated: true);

    expect(destination.route, '/');
    expect(await _durableRoute(), isNull);
  });

  test(
    'saved Inbox requires current userPrimaryTab durable metadata',
    () async {
      for (final metadata in <NavigationLaunchRouteMetadata>[
        const NavigationLaunchRouteMetadata(
          schemaVersion: navigationPersistenceSchemaVersion - 1,
          source: NavigationSource.userPrimaryTab,
          routeClass: NavigationRouteClass.durablePrimary,
          section: AppSection.inbox,
          canonicalRoute: '/inbox',
        ),
        const NavigationLaunchRouteMetadata(
          schemaVersion: navigationPersistenceSchemaVersion,
          source: NavigationSource.programmatic,
          routeClass: NavigationRouteClass.durablePrimary,
          section: AppSection.inbox,
          canonicalRoute: '/inbox',
        ),
        const NavigationLaunchRouteMetadata(
          schemaVersion: navigationPersistenceSchemaVersion,
          source: NavigationSource.userPrimaryTab,
          routeClass: NavigationRouteClass.transient,
          section: AppSection.inbox,
          canonicalRoute: '/inbox',
        ),
        const NavigationLaunchRouteMetadata(
          schemaVersion: navigationPersistenceSchemaVersion,
          source: NavigationSource.userPrimaryTab,
          routeClass: NavigationRouteClass.durablePrimary,
          canonicalRoute: '/inbox',
        ),
        const NavigationLaunchRouteMetadata(
          schemaVersion: navigationPersistenceSchemaVersion,
          source: NavigationSource.userPrimaryTab,
          routeClass: NavigationRouteClass.durablePrimary,
          section: AppSection.inbox,
        ),
        const NavigationLaunchRouteMetadata(
          schemaVersion: navigationPersistenceSchemaVersion,
          source: NavigationSource.userPrimaryTab,
          routeClass: NavigationRouteClass.durablePrimary,
          section: AppSection.library,
          canonicalRoute: '/nodes',
        ),
      ]) {
        await AppRestorationService.instance.clearCurrentSnapshot();
        await _writeRawSnapshot(<String, dynamic>{
          'routeLocation': '/inbox',
          navigationLaunchRouteMetadataKey: metadata.toJson(),
        });

        final destination = await AppNavigationRestorationController.instance
            .restoreLaunchDestination(isAuthenticated: true);
        expect(destination.route, '/', reason: metadata.toJson().toString());
      }
    },
  );

  test('valid durable metadata survives raw snapshot restoration', () async {
    await _writeRawSnapshot(_durableRouteFields('/inbox'));

    final destination = await AppNavigationRestorationController.instance
        .restoreLaunchDestination(isAuthenticated: true);

    expect(destination.route, '/inbox');
    expect(await _durableRoute(), '/inbox');
  });

  test(
    'valid durable Library metadata survives raw snapshot restoration',
    () async {
      await _writeRawSnapshot(_durableRouteFields('/nodes'));

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);

      expect(destination.route, '/nodes');
      expect(await _durableRoute(), '/nodes');
    },
  );
}
