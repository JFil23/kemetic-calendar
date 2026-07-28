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

Future<Map<String, dynamic>?> _primarySelectionMetadataJson() async {
  await AppRestorationService.instance.flushPendingWrites();
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_snapshotKey());
  if (raw == null) return null;
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final metadata = decoded[navigationPrimarySelectionMetadataKey];
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

  test('explicit user primary Planner metadata launches Planner', () async {
    await AppNavigationRestorationController.instance.recordPrimaryTabSelection(
      AppSection.planner,
    );

    final destination = await AppNavigationRestorationController.instance
        .restoreLaunchDestination(isAuthenticated: true);

    expect(await _durableRoute(), '/rhythm/today');
    expect(await _durableMetadataJson(), containsPair('section', 'planner'));
    expect(
      await _durableMetadataJson(),
      containsPair('canonicalRoute', '/rhythm/today'),
    );
    expect(destination.route, '/rhythm/today');
    expect(destination.reason, 'valid_durable_metadata');
  });

  test(
    'programmatic Calendar snapshot restores explicit non-root primary selection',
    () async {
      const policy = NavigationPersistencePolicy();
      final calendarMetadata = policy
          .classifyRoute('/', NavigationSource.programmatic)
          .metadata;
      final plannerMetadata = policy
          .classifyRoute('/rhythm/today', NavigationSource.userPrimaryTab)
          .metadata;
      await _writeRawSnapshot(<String, dynamic>{
        'routeLocation': '/',
        navigationLaunchRouteMetadataKey: calendarMetadata.toJson(),
        navigationPrimarySelectionMetadataKey: plannerMetadata.toJson(),
      });

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);

      expect(destination.route, '/rhythm/today');
      expect(destination.decisionSource, 'primarySelectionOverride');
      expect(
        destination.reason,
        'programmatic_root_overridden_by_primary_selection',
      );
      expect(await _durableRoute(), '/');
      expect(
        await _primarySelectionMetadataJson(),
        containsPair('canonicalRoute', '/rhythm/today'),
      );
    },
  );

  test(
    'approved AppSection durable primary commands restore canonical routes',
    () async {
      const policy = NavigationPersistencePolicy();
      const expectedRoutes = <AppSection, String>{
        AppSection.calendar: '/',
        AppSection.inbox: '/inbox',
        AppSection.library: '/nodes',
        AppSection.journal: '/journal',
        AppSection.planner: '/rhythm/today',
        AppSection.settings: '/settings',
        AppSection.reflections: '/reflections',
      };
      expect(AppSection.values.toSet(), {
        ...expectedRoutes.keys,
        AppSection.profile,
      });

      for (final entry in expectedRoutes.entries) {
        await AppRestorationService.instance.clearCurrentSnapshot();

        await AppNavigationRestorationController.instance
            .recordPrimaryTabSelection(entry.key);
        final destination = await AppNavigationRestorationController.instance
            .restoreLaunchDestination(isAuthenticated: true);
        final metadata = await _durableMetadataJson();

        expect(policy.routeForSection(entry.key), entry.value);
        expect(await _durableRoute(), entry.value, reason: entry.key.wireName);
        expect(destination.route, entry.value, reason: entry.key.wireName);
        expect(destination.reason, 'valid_durable_metadata');
        expect(metadata, containsPair('section', entry.key.wireName));
        expect(metadata, containsPair('canonicalRoute', entry.value));
        expect(metadata, containsPair('source', 'userPrimaryTab'));
        expect(metadata, containsPair('routeClass', 'durablePrimary'));
        expect(metadata, containsPair('canRecordPrimarySelection', true));
        expect(metadata, containsPair('canRestoreAsSurface', true));
        expect(
          await _primarySelectionMetadataJson(),
          containsPair('section', entry.key.wireName),
        );
      }

      await AppRestorationService.instance.clearCurrentSnapshot();
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.settings);
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.profile);
      final profileDestination = await AppNavigationRestorationController
          .instance
          .restoreLaunchDestination(isAuthenticated: true);
      expect(policy.routeForSection(AppSection.profile), '/');
      expect(await _durableRoute(), '/settings');
      expect(profileDestination.route, '/settings');
    },
  );

  test(
    'Journal then Planner restores Planner instead of stale Journal',
    () async {
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.journal);
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.planner);

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);

      expect(await _durableRoute(), '/rhythm/today');
      expect(destination.route, '/rhythm/today');
      expect(await _durableMetadataJson(), containsPair('section', 'planner'));
    },
  );

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

  test(
    'auth initialSession replays deferred Library route after root boot default',
    () async {
      await AppNavigationRestorationController.instance.recordVisibleSurface(
        route: '/nodes',
      );

      final destination = await AppNavigationRestorationController.instance
          .restoreDeferredLaunchDestinationAfterAuth(
            currentRoute: '/',
            restoreWasDeferredForAuth: true,
            hasExplicitBootIntent: false,
          );

      expect(destination, isNotNull);
      expect(destination!.route, '/nodes');
      expect(destination.reason, 'valid_durable_metadata');
      expect(await _durableRoute(), '/nodes');
    },
  );

  test(
    'auth initialSession replays deferred Flow Studio utility route',
    () async {
      await AppNavigationRestorationController.instance.recordVisibleSurface(
        route: '/flows?mode=maatFlows',
      );

      final destination = await AppNavigationRestorationController.instance
          .restoreDeferredLaunchDestinationAfterAuth(
            currentRoute: '/',
            restoreWasDeferredForAuth: true,
            hasExplicitBootIntent: false,
          );

      expect(destination, isNotNull);
      expect(destination!.route, '/flows?mode=maatFlows');
      expect(
        await _durableMetadataJson(),
        containsPair('routeClass', 'utility'),
      );
    },
  );

  test(
    'warm cache and calendar restore do not replace deferred durable page',
    () async {
      await AppNavigationRestorationController.instance.recordVisibleSurface(
        route: '/rhythm/today',
      );
      await AppRestorationService.instance.saveCalendarState(
        const CalendarRestorationState(
          kYear: 6267,
          kMonth: 3,
          kDay: 24,
          showGregorian: false,
          expansion: 'details',
          anchorTarget: 'dayChip',
          anchorAlignment: 0.5,
          viewportHeight: 700,
          layoutRevision: 1,
          scrollOffset: 2400,
        ),
      );
      await AppRestorationService.instance.saveDayViewState(
        const DayViewRestorationState(
          isOpen: false,
          kYear: 6267,
          kMonth: 3,
          kDay: 24,
          showGregorian: false,
        ),
      );

      final destination = await AppNavigationRestorationController.instance
          .restoreDeferredLaunchDestinationAfterAuth(
            currentRoute: '/',
            restoreWasDeferredForAuth: true,
            hasExplicitBootIntent: false,
          );
      final snapshot = await AppRestorationService.instance.readSnapshot();

      expect(destination, isNotNull);
      expect(destination!.route, '/rhythm/today');
      expect(snapshot?.routeLocation, '/rhythm/today');
      expect(snapshot?.calendar?.kMonth, 3);
      expect(snapshot?.calendar?.kDay, 24);
    },
  );

  test(
    'auth deferred replay does not override explicit or user-changed routes',
    () async {
      await AppNavigationRestorationController.instance.recordVisibleSurface(
        route: '/nodes',
      );

      final explicit = await AppNavigationRestorationController.instance
          .restoreDeferredLaunchDestinationAfterAuth(
            currentRoute: '/',
            restoreWasDeferredForAuth: true,
            hasExplicitBootIntent: true,
          );
      final userChanged = await AppNavigationRestorationController.instance
          .restoreDeferredLaunchDestinationAfterAuth(
            currentRoute: '/rhythm/today',
            restoreWasDeferredForAuth: true,
            hasExplicitBootIntent: false,
          );

      expect(explicit, isNull);
      expect(userChanged, isNull);
      expect(await _durableRoute(), '/nodes');
    },
  );

  test(
    'root Ma’at Flow Studio overlay survives deferred auth replay',
    () async {
      await AppNavigationRestorationController.instance.recordVisibleSurface(
        route: '/',
      );
      await AppRestorationService.instance.saveOverlayStack(
        const <Map<String, dynamic>>[
          <String, dynamic>{
            'kind': 'calendar.flowStudio',
            'parentRoute': '/',
            'mode': 'maatFlows',
          },
        ],
      );

      final destination = await AppNavigationRestorationController.instance
          .restoreDeferredLaunchDestinationAfterAuth(
            currentRoute: '/',
            restoreWasDeferredForAuth: true,
            hasExplicitBootIntent: false,
          );
      final snapshot = await AppRestorationService.instance.readSnapshot();

      expect(destination, isNull);
      expect(snapshot?.routeLocation, '/');
      expect(snapshot?.overlayStack.single, containsPair('mode', 'maatFlows'));
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

  test(
    'one-shot taps from Planner do not replace the Planner durable route',
    () async {
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.planner);

      final intents = <PendingNavigationIntent>[
        const PendingNavigationIntent(
          key: 'notification:event-from-planner',
          requestedRoute: '/shared-flow/by-flow/42',
          source: NavigationSource.notificationTap,
        ),
        const PendingNavigationIntent(
          key: 'search:event-from-planner',
          requestedRoute: '/nodes/human_emergence',
          source: NavigationSource.searchResultTap,
        ),
        const PendingNavigationIntent(
          key: 'shared-calendar:event-from-planner',
          requestedRoute: '/event-invite/invite-1',
          source: NavigationSource.sharedCalendarEventTap,
        ),
      ];

      for (final intent in intents) {
        final resolution = await AppNavigationRestorationController.instance
            .consumeOneShotIntent(intent);
        final destination = await AppNavigationRestorationController.instance
            .restoreLaunchDestination(isAuthenticated: true);

        expect(resolution?.route, isNotNull, reason: intent.key);
        expect(await _durableRoute(), '/rhythm/today', reason: intent.key);
        expect(destination.route, '/rhythm/today', reason: intent.key);
        expect(
          await _durableMetadataJson(),
          containsPair('section', 'planner'),
        );
      }
    },
  );

  test(
    'Planner subpages and detail routes do not replace the Planner primary route',
    () async {
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.planner);

      for (final route in const <String>[
        '/rhythm/todo?date=2026-06-03&source=make_todo',
        '/rhythm/tracker',
        '/rhythm/decan/6267-01-01',
        '/rhythm/editor/timed',
      ]) {
        await AppNavigationRestorationController.instance
            .recordNavigationAttempt(
              route: route,
              source: NavigationSource.programmatic,
            );
        final classification = const NavigationPersistencePolicy()
            .classifyRoute(route, NavigationSource.userPrimaryTab);

        expect(classification.accepted, isFalse, reason: route);
        expect(await _durableRoute(), '/rhythm/today', reason: route);
      }

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);
      expect(destination.route, '/rhythm/today');
      expect(await _durableMetadataJson(), containsPair('section', 'planner'));
    },
  );

  test('visible utility surface persists without primary selection', () async {
    await AppNavigationRestorationController.instance.recordVisibleSurface(
      route: '/flows',
    );

    final destination = await AppNavigationRestorationController.instance
        .restoreLaunchDestination(isAuthenticated: true);

    expect(await _durableRoute(), '/flows');
    expect(destination.route, '/flows');
    expect(await _durableMetadataJson(), containsPair('routeClass', 'utility'));
    expect(
      await _durableMetadataJson(),
      containsPair('canRecordPrimarySelection', false),
    );
    expect(await _primarySelectionMetadataJson(), isNull);
  });

  test(
    'visible Flow Studio submodes persist as route-backed utility surfaces',
    () async {
      for (final route in const <String>[
        '/flows?mode=myFlows',
        '/flows?mode=maatFlows',
      ]) {
        SharedPreferences.setMockInitialValues({});
        AppWindowService.instance.resetForTesting();
        AppNavigationRestorationController.instance.resetForTesting();

        await AppNavigationRestorationController.instance.recordVisibleSurface(
          route: route,
        );

        final destination = await AppNavigationRestorationController.instance
            .restoreLaunchDestination(isAuthenticated: true);

        expect(await _durableRoute(), route, reason: route);
        expect(destination.route, route, reason: route);
        expect(
          await _durableMetadataJson(),
          containsPair('routeClass', 'utility'),
          reason: route,
        );
        expect(await _primarySelectionMetadataJson(), isNull, reason: route);
      }
    },
  );

  test(
    'visible detail surface persists while primary selection remains owner',
    () async {
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.library);
      await AppNavigationRestorationController.instance.recordVisibleSurface(
        route: '/nodes/abydos',
      );

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);

      expect(await _durableRoute(), '/nodes/abydos');
      expect(destination.route, '/nodes/abydos');
      expect(await _durableMetadataJson(), containsPair('section', 'library'));
      expect(
        await _durableMetadataJson(),
        containsPair('canRecordPrimarySelection', false),
      );
      expect(
        await _primarySelectionMetadataJson(),
        containsPair('section', 'library'),
      );
      expect(
        await _primarySelectionMetadataJson(),
        containsPair('canonicalRoute', '/nodes'),
      );
    },
  );

  test('user back from detail persists the parent surface', () async {
    await AppNavigationRestorationController.instance.recordVisibleSurface(
      route: '/nodes/abydos',
    );

    await AppNavigationRestorationController.instance.recordSurfaceDismissal(
      dismissedRoute: '/nodes/abydos',
      fallbackRoute: '/nodes',
      source: NavigationSource.userBack,
    );

    final destination = await AppNavigationRestorationController.instance
        .restoreLaunchDestination(isAuthenticated: true);

    expect(await _durableRoute(), '/nodes');
    expect(destination.route, '/nodes');
    expect(await _durableMetadataJson(), containsPair('source', 'userBack'));
    expect(await _durableMetadataJson(), containsPair('section', 'library'));
  });

  test(
    'user dismissals from restorable details persist named parent surfaces',
    () async {
      const cases =
          <
            ({
              String dismissedRoute,
              String fallbackRoute,
              NavigationSource source,
            })
          >[
            (
              dismissedRoute: '/inbox/conversation/friend-1',
              fallbackRoute: '/inbox',
              source: NavigationSource.userBack,
            ),
            (
              dismissedRoute: '/journal/entry/entry-1',
              fallbackRoute: '/journal',
              source: NavigationSource.userBack,
            ),
            (
              dismissedRoute: '/nodes/abydos',
              fallbackRoute: '/nodes',
              source: NavigationSource.userBack,
            ),
            (
              dismissedRoute: '/reflections/reflection-1',
              fallbackRoute: '/reflections',
              source: NavigationSource.userDismissal,
            ),
            (
              dismissedRoute: '/flow-post/post-1',
              fallbackRoute: '/profile/me',
              source: NavigationSource.userDismissal,
            ),
            (
              dismissedRoute: '/maat-guidance/delivery-1',
              fallbackRoute: '/',
              source: NavigationSource.userDismissal,
            ),
          ];

      for (final detailCase in cases) {
        await AppRestorationService.instance.clearCurrentSnapshot();

        await AppNavigationRestorationController.instance.recordVisibleSurface(
          route: detailCase.dismissedRoute,
        );
        expect(
          await _durableRoute(),
          detailCase.dismissedRoute,
          reason: detailCase.dismissedRoute,
        );

        await AppNavigationRestorationController.instance
            .recordSurfaceDismissal(
              dismissedRoute: detailCase.dismissedRoute,
              fallbackRoute: detailCase.fallbackRoute,
              source: detailCase.source,
            );

        final destination = await AppNavigationRestorationController.instance
            .restoreLaunchDestination(isAuthenticated: true);

        expect(
          await _durableRoute(),
          detailCase.fallbackRoute,
          reason: detailCase.dismissedRoute,
        );
        expect(
          destination.route,
          detailCase.fallbackRoute,
          reason: detailCase.dismissedRoute,
        );
        expect(
          await _durableMetadataJson(),
          containsPair('source', detailCase.source.wireName),
          reason: detailCase.dismissedRoute,
        );
      }
    },
  );

  test(
    'user dismissal from detail to Calendar evicts saved detail route',
    () async {
      await AppNavigationRestorationController.instance.recordVisibleSurface(
        route: '/maat-guidance/delivery-1',
      );

      await AppNavigationRestorationController.instance.recordSurfaceDismissal(
        dismissedRoute: '/maat-guidance/delivery-1',
        fallbackRoute: '/',
        source: NavigationSource.userDismissal,
      );

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);

      expect(await _durableRoute(), '/');
      expect(destination.route, '/');
      expect(
        await _durableMetadataJson(),
        containsPair('source', 'userDismissal'),
      );
    },
  );

  test(
    'user back from Library primary to Calendar clears stale primary selection',
    () async {
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.library);
      expect(await _durableRoute(), '/nodes');
      expect(
        await _primarySelectionMetadataJson(),
        containsPair('canonicalRoute', '/nodes'),
      );

      await AppNavigationRestorationController.instance.recordSurfaceDismissal(
        dismissedRoute: '/nodes',
        fallbackRoute: '/',
        source: NavigationSource.userBack,
      );

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);

      expect(await _durableRoute(), '/');
      expect(destination.route, '/');
      expect(await _durableMetadataJson(), containsPair('source', 'userBack'));
      expect(await _primarySelectionMetadataJson(), isNull);
    },
  );

  test(
    'user dismissal from Journal primary to Calendar clears stale primary selection',
    () async {
      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.journal);
      expect(await _durableRoute(), '/journal');
      expect(
        await _primarySelectionMetadataJson(),
        containsPair('canonicalRoute', '/journal'),
      );

      await AppNavigationRestorationController.instance.recordSurfaceDismissal(
        dismissedRoute: '/journal',
        fallbackRoute: '/',
        source: NavigationSource.userDismissal,
      );

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);

      expect(await _durableRoute(), '/');
      expect(destination.route, '/');
      expect(
        await _durableMetadataJson(),
        containsPair('source', 'userDismissal'),
      );
      expect(await _primarySelectionMetadataJson(), isNull);
    },
  );

  test('passive root mounts cannot evict a saved detail surface', () async {
    for (final source in const <NavigationSource>[
      NavigationSource.programmatic,
      NavigationSource.authGate,
      NavigationSource.launchPlaceholder,
      NavigationSource.restoreReplay,
      NavigationSource.lifecycle,
    ]) {
      await AppRestorationService.instance.clearCurrentSnapshot();

      await AppNavigationRestorationController.instance.recordVisibleSurface(
        route: '/journal/entry/entry-1',
      );

      await AppNavigationRestorationController.instance.recordVisibleSurface(
        route: '/',
        source: source,
      );

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);

      expect(
        await _durableRoute(),
        '/journal/entry/entry-1',
        reason: source.wireName,
      );
      expect(
        destination.route,
        '/journal/entry/entry-1',
        reason: source.wireName,
      );
    }
  });

  test(
    'explicit Calendar primary command evicts a saved detail surface',
    () async {
      await AppNavigationRestorationController.instance.recordVisibleSurface(
        route: '/inbox/conversation/friend-1',
      );

      await AppNavigationRestorationController.instance
          .recordPrimaryTabSelection(AppSection.calendar);

      final destination = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);

      expect(await _durableRoute(), '/');
      expect(destination.route, '/');
      expect(
        await _durableMetadataJson(),
        containsPair('source', 'userPrimaryTab'),
      );
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

  test('one-shot launch intent beats stored durable surface', () async {
    await AppNavigationRestorationController.instance.recordVisibleSurface(
      route: '/profile/me',
    );

    final destination = await AppNavigationRestorationController.instance
        .restoreLaunchDestination(
          isAuthenticated: true,
          intent: const PendingNavigationIntent(
            key: 'search:abydos',
            requestedRoute: '/nodes/abydos',
            source: NavigationSource.searchResultTap,
          ),
        );

    expect(destination.route, '/nodes/abydos');
    expect(destination.decisionSource, 'oneShotIntent');
    expect(await _durableRoute(), '/profile/me');
  });

  test('unknown modal and unsafe subroutes are not restorable surfaces', () {
    const policy = NavigationPersistencePolicy();
    const unsafeRoutes = <String>[
      '/unknown',
      '/rhythm/todo',
      '/rhythm/tracker',
      '/rhythm/decan/6267-01-01',
      '/rhythm/editor/timed',
      '/profile-search',
    ];

    for (final route in unsafeRoutes) {
      final classification = policy.classifyRoute(
        route,
        NavigationSource.programmatic,
      );
      expect(classification.accepted, isFalse, reason: route);
      expect(classification.canRestoreAsSurface, isFalse, reason: route);
    }
  });

  test('utility routes restore as surfaces without primary selection', () {
    const policy = NavigationPersistencePolicy();
    for (final route in const <String>[
      '/flows',
      '/flows?mode=myFlows',
      '/flows?mode=maatFlows',
      '/calendars',
    ]) {
      final classification = policy.classifyRoute(
        route,
        NavigationSource.programmatic,
      );
      expect(classification.accepted, isTrue, reason: route);
      expect(classification.canRestoreAsSurface, isTrue, reason: route);
      expect(classification.canRecordPrimarySelection, isFalse, reason: route);
      expect(
        classification.routeClass,
        NavigationRouteClass.utility,
        reason: route,
      );
      expect(classification.canonicalRoute, route, reason: route);
    }
  });

  test('Profile route restores as surface without primary selection', () {
    const policy = NavigationPersistencePolicy();
    final classification = policy.classifyRoute(
      '/profile/me',
      NavigationSource.programmatic,
    );

    expect(classification.accepted, isTrue);
    expect(classification.canRestoreAsSurface, isTrue);
    expect(classification.canRecordPrimarySelection, isFalse);
    expect(classification.routeClass, NavigationRouteClass.transient);
    expect(classification.canonicalRoute, '/profile/me');
  });

  test('Profile persistence is source-aware', () async {
    await AppNavigationRestorationController.instance.recordVisibleSurface(
      route: '/profile/me',
      source: NavigationSource.userExplicitOpen,
    );

    expect(await _durableRoute(), '/profile/me');
    expect(
      await _durableMetadataJson(),
      containsPair('source', 'userExplicitOpen'),
    );

    await AppNavigationRestorationController.instance.recordSurfaceDismissal(
      dismissedRoute: '/profile/me',
      fallbackRoute: '/nodes',
      source: NavigationSource.userBack,
    );

    expect(await _durableRoute(), '/nodes');
    expect(await _durableMetadataJson(), containsPair('source', 'userBack'));

    await AppNavigationRestorationController.instance.recordVisibleSurface(
      route: '/profile/me',
      source: NavigationSource.authGate,
    );

    expect(await _durableRoute(), '/nodes');
  });

  test('detail routes restore as surfaces with owning sections', () {
    const policy = NavigationPersistencePolicy();
    const expected = <String, AppSection?>{
      '/nodes/abydos': AppSection.library,
      '/journal/entry/entry-1': AppSection.journal,
      '/inbox/conversation/friend-1': AppSection.inbox,
      '/reflections/reflection-1': AppSection.reflections,
      '/flows/42/edit': null,
      '/flow-post/post-1': AppSection.profile,
      '/insight-post/post-1': AppSection.profile,
      '/shared-flow/share-1': null,
      '/event-invite/invite-1': null,
      '/maat-guidance/delivery-1': null,
    };

    for (final entry in expected.entries) {
      final classification = policy.classifyRoute(
        entry.key,
        NavigationSource.programmatic,
      );
      expect(classification.accepted, isTrue, reason: entry.key);
      expect(classification.canRestoreAsSurface, isTrue, reason: entry.key);
      expect(
        classification.canRecordPrimarySelection,
        isFalse,
        reason: entry.key,
      );
      expect(classification.canonicalRoute, entry.key, reason: entry.key);
      expect(classification.section, entry.value, reason: entry.key);
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

  test('saved Inbox validates durable surface metadata', () async {
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

    await AppRestorationService.instance.clearCurrentSnapshot();
    await _writeRawSnapshot(<String, dynamic>{
      'routeLocation': '/inbox',
      navigationLaunchRouteMetadataKey: const NavigationLaunchRouteMetadata(
        schemaVersion: navigationPersistenceSchemaVersion,
        source: NavigationSource.programmatic,
        routeClass: NavigationRouteClass.durablePrimary,
        section: AppSection.inbox,
        canonicalRoute: '/inbox',
        canRecordPrimarySelection: false,
        canRestoreAsSurface: true,
      ).toJson(),
    });
    final destination = await AppNavigationRestorationController.instance
        .restoreLaunchDestination(isAuthenticated: true);
    expect(destination.route, '/inbox');
  });

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
