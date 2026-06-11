import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/navigation_fallback.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/widgets/kemetic_app_bar_action.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _expectedDetachedGlobalMenuOrder = <String>[
  'Planner',
  'Flow Studio',
  'Library',
  'Journal',
  'Inbox',
  'Calendars',
  'Reflections',
  'Home',
  'Settings',
];

final Map<String, String> _debugCriticalSnapshots = <String, String>{};
final Map<String, String> _debugLatestCriticalSnapshots = <String, String>{};
final Map<String, Map<String, dynamic>> _debugRemoteWindowSnapshots =
    <String, Map<String, dynamic>>{};
final Map<String, Map<String, dynamic>> _debugRemoteLatestSnapshots =
    <String, Map<String, dynamic>>{};
String? _debugPlatformLastActiveUserId;

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}

  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key-0123456789012345678901234567890123456789',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _ensureSupabaseInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _clearRestorationDebugHooks();
  });

  group('app bar action guard', () {
    testWidgets('detached menu renders global actions in grid order', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CalendarPage.buildDetachedActionsMenuPanel(
                context,
                includeNewNote: false,
                closeMenu: () async {},
              ),
            ),
          ),
        ),
      );

      expect(_detachedMenuLabels(tester), _expectedDetachedGlobalMenuOrder);
    });

    testWidgets('detached menu respects tablet landscape safe area inset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      const safeAreaKey = ValueKey<String>('test-tablet-safe-area');
      const gridKey = ValueKey<String>('calendar-actions-grid');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CalendarPage.buildDetachedActionsMenuPanel(
                      context,
                      includeNewNote: false,
                      closeMenu: () async {},
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: MediaQuery.paddingOf(context).bottom,
                      child: const ColoredBox(
                        key: safeAreaKey,
                        color: Colors.black,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final gridRect = tester.getRect(find.byKey(gridKey));
      final safeAreaTop = tester.getTopLeft(find.byKey(safeAreaKey)).dy;
      final scaffoldWidth = tester.getSize(find.byType(Scaffold)).width;

      expect(gridRect.bottom, lessThanOrEqualTo(safeAreaTop));
      expect(gridRect.center.dx, closeTo(scaffoldWidth / 2, 0.5));
    });

    testWidgets('detached menu buttons close and dispatch in every path', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigations = <String>[];
      final launchedSheets = <String>[];
      var closeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CalendarPage.buildDetachedActionsMenuPanel(
                context,
                includeNewNote: true,
                onNavigate: navigations.add,
                onOpenCalendars: () async => launchedSheets.add('Calendars'),
                onOpenFlowStudio: () async => launchedSheets.add('Flow Studio'),
                onOpenNewNote: () async => launchedSheets.add('New note'),
                closeMenu: () async {
                  closeCount += 1;
                },
              ),
            ),
          ),
        ),
      );

      const expectedRoutes = <String, String>{
        'Planner': '/rhythm/today',
        'Library': '/nodes',
        'Journal': '/journal',
        'Inbox': '/inbox',
        'Reflections': '/reflections',
        'Home': '/',
        'Settings': '/settings',
      };

      for (final entry in expectedRoutes.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pump();
        expect(
          navigations.last,
          entry.value,
          reason: '${entry.key} should route to ${entry.value}',
        );
      }
      expect(navigations, expectedRoutes.values.toList(growable: false));

      const sheetActions = <String>['Flow Studio', 'Calendars'];
      for (final label in sheetActions) {
        await tester.tap(find.text(label));
        await tester.pump();
        expect(
          launchedSheets.last,
          label,
          reason: '$label should dispatch its sheet/action callback',
        );
      }
      await tester.tap(find.text('New note'));
      await tester.pump();
      expect(
        launchedSheets.last,
        'New note',
        reason: 'New note should dispatch its separate callback',
      );

      expect(closeCount, expectedRoutes.length + sheetActions.length + 1);
      expect(launchedSheets, <String>['Flow Studio', 'Calendars', 'New note']);
    });

    testWidgets('landscape detached menu is bounded and scrollable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2532, 1170);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigations = <String>[];
      var closeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CalendarPage.buildDetachedActionsMenuPanel(
                context,
                includeNewNote: true,
                onNavigate: navigations.add,
                closeMenu: () async {
                  closeCount += 1;
                },
              ),
            ),
          ),
        ),
      );

      const panelKey = ValueKey<String>('calendar-actions-menu-panel');
      const gridKey = ValueKey<String>('calendar-actions-grid');
      final logicalWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final logicalHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      final panelSize = tester.getSize(find.byKey(panelKey));
      expect(panelSize.width, lessThan(logicalWidth * 0.9));
      expect(panelSize.height, greaterThan(logicalHeight * 0.75));
      expect(panelSize.height, lessThan(logicalHeight * 0.85));

      final grid = tester.widget<GridView>(find.byKey(gridKey));
      expect(grid.physics, isA<ClampingScrollPhysics>());

      await tester.drag(find.byKey(gridKey), const Offset(0, -180));
      await tester.pump();
      await tester.tap(find.text('Settings'));
      await tester.pump();

      expect(navigations, <String>['/settings']);
      expect(closeCount, 1);
    });

    test(
      'detached calendar action panel does not reserve old bottom bar',
      () async {
        final source = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();
        final panel = _sourceBetween(
          source,
          'class _CalendarActionsMenuPanel extends StatelessWidget',
          '/* ─────────── Flows (routines): palette + gloss-from-color',
        );

        expect(panel, contains('media.padding.bottom + 16'));
        expect(panel, isNot(contains('globalBottomMenuHeight')));
      },
    );

    testWidgets('detached primary routes close before navigation dispatch', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigations = <String>[];
      var closeStarted = false;
      final closeCompleter = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CalendarPage.buildDetachedActionsMenuPanel(
                context,
                includeNewNote: false,
                onNavigate: navigations.add,
                closeMenu: () async {
                  closeStarted = true;
                  await closeCompleter.future;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Home'));
      await tester.pump();

      expect(closeStarted, isTrue);
      expect(navigations, isEmpty);

      closeCompleter.complete();
      await tester.pump();
      expect(navigations, <String>['/']);
    });

    testWidgets('detached sheet actions close before dispatching sheets', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final launchedSheets = <String>[];
      var closeFinished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CalendarPage.buildDetachedActionsMenuPanel(
                context,
                includeNewNote: true,
                onOpenCalendars: () async {
                  if (closeFinished) launchedSheets.add('Calendars');
                },
                closeMenu: () async {
                  closeFinished = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Calendars'));
      await tester.pump();

      expect(closeFinished, isTrue);
      expect(launchedSheets, <String>['Calendars']);
    });

    testWidgets('global drawer routes Flows to /flows', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(app.resetGlobalFloatingMenuShellForTesting);

      CalendarPage.debugOpenFlowStudioFromAnyContext = (context) async {
        fail('Global menu should not open Flow Studio from the shell context.');
      };
      CalendarPage.debugOpenSharedCalendarsFromAnyContext = (context) async {
        fail('Global menu should not open Calendars from the shell context.');
      };
      addTearDown(() {
        CalendarPage.debugOpenFlowStudioFromAnyContext = null;
        CalendarPage.debugOpenSharedCalendarsFromAnyContext = null;
      });

      final router = GoRouter(
        navigatorKey: app.rootNavigatorKeyForTesting,
        initialLocation: '/profile/me',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Text('Calendar route')),
          ),
          GoRoute(
            path: '/flows',
            builder: (context, state) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Flow Studio route'),
                    TextButton(
                      onPressed: () => closeOrReturn(context, '/'),
                      child: const Text('close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/profile/:userId',
            builder: (context, state) =>
                const Scaffold(body: Text('Profile route')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              app.buildGlobalFloatingMenuShellForTesting(
                router: router,
                child: child ?? const SizedBox.shrink(),
              ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      await tester.tap(find.byKey(app.globalMenuButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      await tester.tap(find.text('Flows'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Flow Studio route'), findsOneWidget);
      expect(find.text('Calendar route'), findsNothing);

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/profile/me',
        reason: 'Utility route close should return to the previous route.',
      );
      expect(find.text('Flow Studio route'), findsNothing);
      expect(find.text('Profile route'), findsOneWidget);
    });

    testWidgets('global drawer routes Calendars to /calendars', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(app.resetGlobalFloatingMenuShellForTesting);

      CalendarPage.debugOpenFlowStudioFromAnyContext = (context) async {
        fail('Global menu should not open Flow Studio from the shell context.');
      };
      CalendarPage.debugOpenSharedCalendarsFromAnyContext = (context) async {
        fail('Global menu should not open Calendars from the shell context.');
      };
      addTearDown(() {
        CalendarPage.debugOpenFlowStudioFromAnyContext = null;
        CalendarPage.debugOpenSharedCalendarsFromAnyContext = null;
      });

      final router = GoRouter(
        navigatorKey: app.rootNavigatorKeyForTesting,
        initialLocation: '/nodes',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Text('Calendar route')),
          ),
          GoRoute(
            path: '/calendars',
            builder: (context, state) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Calendars route'),
                    TextButton(
                      onPressed: () => closeOrReturn(context, '/'),
                      child: const Text('close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/nodes',
            builder: (context, state) =>
                const Scaffold(body: Text('Nodes route')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              app.buildGlobalFloatingMenuShellForTesting(
                router: router,
                child: child ?? const SizedBox.shrink(),
              ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      await tester.tap(find.byKey(app.globalMenuButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      await tester.tap(find.text('Calendars'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Calendars route'), findsOneWidget);
      expect(find.text('Calendar route'), findsNothing);

      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/nodes',
        reason: 'Utility route close should return to the previous route.',
      );
      expect(find.text('Calendars route'), findsNothing);
      expect(find.text('Nodes route'), findsOneWidget);
    });

    testWidgets('detached Today app bar action routes home', (tester) async {
      CalendarPage.debugDisableTodayNavigationRetry = true;
      addTearDown(() {
        CalendarPage.debugDisableTodayNavigationRetry = false;
      });
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/profile/other-user',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Text('Calendar route')),
          ),
          GoRoute(
            path: '/profile/:userId',
            builder: (context, state) => Scaffold(
              appBar: AppBar(
                actions: [
                  KemeticAppBarAction(
                    tooltip: 'Today',
                    icon: const KemeticAppBarTodayIcon(),
                    onPressed: () =>
                        CalendarPage.openMainCalendarAtToday(context),
                  ),
                ],
              ),
              body: const Text('Profile route'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(_currentRouterLocation(router), '/profile/other-user');

      await tester.tap(find.byTooltip('Today'));
      await tester.pump();
      await _waitForRouterLocation(tester, router, '/');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('profile app bar action uses canonical /profile/me route', (
      tester,
    ) async {
      _installRestorationDebugHooks();
      addTearDown(_clearRestorationDebugHooks);
      await _recoverTestSession();

      final router = GoRouter(
        initialLocation: '/rhythm/today',
        routes: [
          GoRoute(
            path: '/rhythm/today',
            builder: (context, state) => Scaffold(
              appBar: AppBar(
                actions: [
                  KemeticAppBarAction(
                    tooltip: 'My Profile',
                    icon: const KemeticAppBarProfileIcon(),
                    onPressed: () {
                      unawaited(
                        CalendarPage.openProfileFromAnyContext(context),
                      );
                    },
                  ),
                ],
              ),
              body: const Text('Planner route'),
            ),
          ),
          GoRoute(
            path: '/profile/:userId',
            builder: (context, state) => Scaffold(
              body: Text('Profile ${state.pathParameters['userId']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(_currentRouterLocation(router), '/rhythm/today');

      await tester.tap(find.byTooltip('My Profile'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Profile me'), findsOneWidget);
    });

    test('shared Today helper records today before routing home', () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final openToday = _sourceBetween(
        source,
        'static void openMainCalendarAtToday(',
        '  // Static method for parsing rules from JSON',
      );
      final recordToday = _sourceBetween(
        source,
        'static Future<void> _recordCalendarTodayCommandState(',
        'static void openMainCalendarAtToday(',
      );
      final loadPersisted = _sourceBetween(
        source,
        'Future<void> _loadPersistedViewState({String trigger = \'startup\'})',
        '  /// ✅ Helper: Calculate max days in a Kemetic month',
      );

      expect(openToday, contains('_pendingTodayNavigationCommand = true'));
      expect(openToday, contains('_recordCalendarTodayCommandState'));
      expect(openToday, contains("router.go('/')"));
      expect(
        openToday.indexOf('_recordCalendarTodayCommandState'),
        lessThan(openToday.indexOf("router.go('/')")),
      );
      expect(recordToday, contains('saveCalendarState'));
      expect(recordToday, contains('_calendarRestorationStateForToday'));
      expect(loadPersisted, contains('_consumePendingTodayNavigationCommand'));
      expect(loadPersisted, contains('return;'));
    });

    test('calendar-host menu buttons keep expected handlers', () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final actions = _sourceBetween(
        source,
        'List<_CalendarAction> _calendarActions(',
        'Future<void> _showActionsMenu(',
      );

      _expectCalendarMenuOrder(actions, <String>[
        ..._expectedDetachedGlobalMenuOrder,
        'New note',
      ]);
      _expectCalendarMenuAction(actions, 'Planner', '_openPlannerPage');
      _expectCalendarMenuAction(
        actions,
        'Flow Studio',
        '_getFlowStudioCallback',
      );
      _expectCalendarMenuAction(actions, 'Library', '_openKemeticNodes');
      _expectCalendarMenuAction(actions, 'Journal', '_openJournalFromAppBar');
      _expectCalendarMenuAction(actions, 'Inbox', '_openInboxFromMenu');
      _expectCalendarMenuAction(
        actions,
        'Calendars',
        '_openSharedCalendarsSheet',
      );
      _expectCalendarMenuAction(
        actions,
        'Reflections',
        '_openReflectionsFromMenu',
      );
      _expectCalendarMenuAction(actions, 'Home', "context.go('/')");
      _expectCalendarMenuAction(actions, 'Settings', '_openSettingsFromMenu');
      _expectCalendarMenuAction(actions, 'New note', '_openQuickAddSheet');
    });

    test('main calendar app bar actions keep expected handlers', () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final appBar = _sourceBetween(
        source,
        'return AppBar(\n      backgroundColor: Colors.black,\n      elevation: 0.5,\n      centerTitle: false,',
        'Future<void> _openProfile(',
      );

      _expectTooltipAction(appBar, 'New note', <String>[
        'onPressed: _openQuickAddSheet',
      ]);
      _expectTooltipAction(appBar, 'Search notes', <String>[
        'KemeticAppBarSearchIcon',
        'onPressed: _openSearch',
      ]);
      _expectTooltipAction(appBar, 'Today', <String>[
        'KemeticAppBarTodayIcon',
        '_handleCalendarAppBarToday',
      ]);
      _expectTooltipAction(appBar, 'My Profile', <String>[
        'KemeticAppBarProfileIcon',
        'CalendarPage.openProfileFromAnyContext(context)',
      ]);
    });

    test(
      'calendar profile navigation schedules feed continuity without blocking routing',
      () async {
        final source = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();
        final openProfile = _sourceBetween(
          source,
          'Future<void> _openProfile(',
          'Future<void> openProfileFromOutside',
        );

        expect(
          openProfile,
          contains('_clearProfileFeedContinuityWithoutBlocking(userId)'),
        );
        expect(
          openProfile,
          isNot(
            contains(
              'await RestorationCoordinator.instance.clearProfileFeedContinuity',
            ),
          ),
        );
        expect(
          openProfile.indexOf('_clearProfileFeedContinuityWithoutBlocking'),
          lessThan(
            openProfile.indexOf(
              "openDetailRoute<void>(context, '/profile/me')",
            ),
          ),
        );
        expect(
          openProfile,
          isNot(contains("openDetailRoute<void>(context, '/profile/\${")),
        );
      },
    );

    test('planner app bar actions keep expected handlers', () async {
      final source = await File(
        'lib/features/rhythm/pages/todays_alignment_page.dart',
      ).readAsString();
      final appBar = _sourceBetween(
        source,
        'PreferredSizeWidget _buildAppBar()',
        '@override\n  Widget build(BuildContext context)',
      );

      _expectTooltipAction(appBar, 'New note', <String>[
        '_openCalendarQuickAdd()',
      ]);
      _expectTooltipAction(appBar, 'Search notes', <String>[
        'KemeticAppBarSearchIcon',
        'CalendarPage.openSearchFromAnyContext(context)',
      ]);
      _expectTooltipAction(appBar, 'Today', <String>[
        'KemeticAppBarTodayIcon',
        'CalendarPage.openMainCalendarAtToday(context)',
      ]);
      _expectTooltipAction(appBar, 'My Profile', <String>[
        'KemeticAppBarProfileIcon',
        '_openProfilePage',
      ]);
    });

    test('planner profile action delegates to shared profile helper', () async {
      final source = await File(
        'lib/features/rhythm/pages/todays_alignment_page.dart',
      ).readAsString();
      final openProfilePage = _sourceBetween(
        source,
        'void _openProfilePage()',
        'void _onTodoPageChanged(',
      );

      expect(
        openProfilePage,
        contains('CalendarPage.openProfileFromAnyContext(context)'),
      );
      expect(openProfilePage, isNot(contains("context.go('/profile/")));
    });

    test('profile app bar actions keep expected handlers', () async {
      final source = await File(
        'lib/features/profile/profile_page.dart',
      ).readAsString();
      final appBar = _sourceBetween(source, 'appBar: AppBar(', 'body: Stack(');

      expect(appBar, isNot(contains("tooltip: 'Menu'")));
      expect(appBar, isNot(contains('_openCalendarMenu')));
      expect(appBar, contains("popOrGo(context, '/')"));
      _expectTooltipAction(appBar, 'New note', <String>[
        '_openCalendarQuickAdd()',
      ]);
      _expectTooltipAction(appBar, 'Search notes', <String>[
        'KemeticAppBarSearchIcon',
        'CalendarPage.openSearchFromAnyContext(context)',
      ]);
      _expectTooltipAction(appBar, 'Today', <String>[
        'KemeticAppBarTodayIcon',
        'CalendarPage.openMainCalendarAtToday(context)',
      ]);
      _expectTooltipAction(appBar, 'Profile', <String>['_closeFeed()']);
      _expectTooltipAction(appBar, 'My Profile', <String>[
        'KemeticAppBarProfileIcon',
        '_openMyProfileAction',
      ]);
    });

    test('shared profile helper uses canonical profile route', () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      final helper = _sourceBetween(
        source,
        'static Future<void> openProfileFromAnyContext(',
        'static Future<void> _showDetachedActionsMenu(',
      );

      expect(helper, contains('clearProfileFeedContinuity'));
      expect(helper, contains('_clearProfileFeedContinuityWithoutBlocking'));
      expect(helper, contains('unawaited('));
      expect(source, contains('profile feed continuity clear skipped'));
      expect(helper, contains("openDetailRoute<void>(context, '/profile/me')"));
      expect(
        helper,
        isNot(contains("openDetailRoute<void>(context, '/profile/\${")),
      );
    });

    test(
      'calendar overlay persistence is best effort for action sheets',
      () async {
        final source = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();
        final saveOverlayState = _sourceBetween(
          source,
          'Future<void> _saveCalendarOverlayState(',
          'Future<void> _clearCalendarOverlayState',
        );
        final saveDetachedOverlayState = _sourceBetween(
          source,
          'static Future<void> _saveDetachedCalendarOverlayState(',
          'static Future<void> _clearDetachedCalendarOverlayState',
        );

        expect(
          saveOverlayState,
          contains('AppRestorationService.instance.saveOverlayStack'),
        );
        expect(saveOverlayState, contains('catch (error)'));
        expect(
          saveOverlayState,
          contains('calendar overlay state save skipped'),
        );
        expect(
          saveDetachedOverlayState,
          contains(
            'RestorationCoordinator.instance.recordOverlayStackPageState',
          ),
        );
        expect(saveDetachedOverlayState, contains('catch (error)'));
        expect(
          saveDetachedOverlayState,
          contains('detached calendar overlay state save skipped'),
        );
        expect(saveDetachedOverlayState, contains("parentPath == '/flows'"));
        expect(
          saveDetachedOverlayState,
          contains("parentPath == '/calendars'"),
        );
      },
    );

    test('global drawer utility rows use route-backed callbacks', () async {
      final source = await File('lib/main.dart').readAsString();
      final items = _sourceBetween(
        source,
        'List<GlobalSideDrawerItem> _buildGlobalSideDrawerItems()',
        'void _openMaatGuidance(MaatGuidanceDelivery delivery)',
      );
      final flowStudioCallback = _sourceBetween(
        source,
        'Future<void> _openFlowsFromDrawer()',
        'Future<void> _openCalendarsFromDrawer()',
      );
      final calendarsCallback = _sourceBetween(
        source,
        'Future<void> _openCalendarsFromDrawer()',
        'void _openMaatGuidance(MaatGuidanceDelivery delivery)',
      );

      expect(items, contains("label: 'Flows'"));
      expect(items, contains('_openFlowsFromDrawer()'));
      expect(items, contains("label: 'Calendars'"));
      expect(items, contains('_openCalendarsFromDrawer()'));
      expect(flowStudioCallback, contains('unawaited(_closeFloatingMenu())'));
      expect(flowStudioCallback, isNot(contains('await _closeFloatingMenu()')));
      expect(
        flowStudioCallback,
        contains("global drawer utility route push('/flows') requested"),
      );
      expect(flowStudioCallback, contains('openUtilityRoute<void>('));
      expect(flowStudioCallback, contains("'/flows'"));
      expect(
        flowStudioCallback,
        contains('navigationContext: _rootNavigatorKey.currentContext'),
      );
      expect(flowStudioCallback, contains('router: widget.router'));
      expect(flowStudioCallback, isNot(contains("widget.router.go('/flows')")));
      expect(flowStudioCallback, isNot(contains(".go('/flows')")));
      expect(
        flowStudioCallback.indexOf('unawaited(_closeFloatingMenu())'),
        lessThan(flowStudioCallback.indexOf('openUtilityRoute<void>(')),
      );
      expect(calendarsCallback, contains('unawaited(_closeFloatingMenu())'));
      expect(calendarsCallback, isNot(contains('await _closeFloatingMenu()')));
      expect(
        calendarsCallback,
        contains("global drawer utility route push('/calendars') requested"),
      );
      expect(calendarsCallback, contains('openUtilityRoute<void>('));
      expect(calendarsCallback, contains("'/calendars'"));
      expect(
        calendarsCallback,
        contains('navigationContext: _rootNavigatorKey.currentContext'),
      );
      expect(calendarsCallback, contains('router: widget.router'));
      expect(
        calendarsCallback,
        isNot(contains("widget.router.go('/calendars')")),
      );
      expect(calendarsCallback, isNot(contains(".go('/calendars')")));
      expect(
        calendarsCallback.indexOf('unawaited(_closeFloatingMenu())'),
        lessThan(calendarsCallback.indexOf('openUtilityRoute<void>(')),
      );
      expect(source, contains("path: '/flows'"));
      expect(source, contains('CalendarPage.buildFlowStudioRoutePage()'));
      expect(source, contains("path: '/calendars'"));
      expect(source, contains('CalendarPage.buildSharedCalendarsRoutePage()'));
      expect(
        source,
        isNot(contains('CalendarPage.openDetachedFlowStudioFromGlobalMenu')),
      );
      expect(
        source,
        isNot(
          contains('CalendarPage.openDetachedSharedCalendarsFromGlobalMenu'),
        ),
      );
      expect(source, isNot(contains("context.go('/flows')")));
      expect(source, isNot(contains("context.go('/calendars')")));
      expect(
        flowStudioCallback,
        isNot(contains('CalendarPage.enqueueOpenFlowStudioFromGlobalMenu')),
      );
      expect(
        calendarsCallback,
        isNot(contains('CalendarPage.enqueueOpenCalendarsFromGlobalMenu')),
      );
      expect(
        source,
        isNot(contains('_routeToCalendarForGlobalMenuSheetCommand')),
      );
      expect(source, isNot(contains('_buildFloatingActionsPanel')));
      expect(source, isNot(contains('_navigateFromMenu')));
      expect(source, isNot(contains('global menu detached sheet open')));
    });

    test('CalendarPage legacy global sheet commands stay removed', () async {
      final source = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();

      final staleCommandPattern = RegExp(
        r'enqueueOpenFlowStudioFromGlobalMenu|'
        r'enqueueOpenCalendarsFromGlobalMenu|'
        r'_pendingOpenFlowStudioFromGlobalMenu|'
        r'_pendingOpenCalendarsFromGlobalMenu|'
        r'_CalendarGlobalMenuSheetCommand|'
        r'_schedulePendingGlobalMenuSheetCommandIfAny|'
        r'_consumePendingGlobalMenuSheetCommand|'
        r'CalendarPage global menu sheet command',
      );
      expect(staleCommandPattern.hasMatch(source), isFalse);
    });

    test(
      'global Flow Studio route uses route-backed sheet body without modal host',
      () async {
        final calendarSource = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();
        final flowPagesSource = await File(
          'lib/features/calendar/calendar_flow_pages.dart',
        ).readAsString();
        final routeSource = _sourceBetween(
          calendarSource,
          'class _FlowStudioRoutePage extends StatefulWidget',
          'class _SharedCalendarsRoutePage extends StatelessWidget',
        );
        final flowHubSource = _sourceBetween(
          flowPagesSource,
          'class _FlowHubPage extends StatefulWidget',
          'class _FlowHubCell extends StatelessWidget',
        );

        expect(routeSource, contains('UtilitySheetRouteScaffold'));
        expect(routeSource, contains("semanticLabel: 'Flow Studio'"));
        expect(routeSource, contains('onClose: _closeRoute'));
        expect(routeSource, contains('_buildDetachedFlowStudioRoot'));
        expect(routeSource, contains("parentRoute: '/flows'"));
        expect(routeSource, contains("closeOrReturn(context, '/')"));
        expect(routeSource, isNot(contains("GoRouter.of(context).go('/')")));
        expect(routeSource, isNot(contains('showModalBottomSheet')));
        expect(routeSource, isNot(contains('CalendarPage.globalKey')));
        expect(flowHubSource, contains('this.onClose'));
        expect(flowHubSource, contains('widget.onClose'));
        expect(flowHubSource, contains('automaticallyImplyLeading'));
      },
    );

    test(
      'utility Flow Studio and Calendars routes are sheet-backed pages',
      () async {
        final mainSource = await File('lib/main.dart').readAsString();

        final utilitySheetRoute = _sourceBetween(
          mainSource,
          'GoRoute _utilitySheetRoute({',
          'GoRouter _createRouter',
        );
        expect(utilitySheetRoute, contains('CustomTransitionPage<dynamic>'));
        expect(utilitySheetRoute, contains('opaque: false'));
        expect(utilitySheetRoute, contains('barrierColor: Colors.transparent'));
        expect(utilitySheetRoute, contains('FadeTransition'));
        expect(utilitySheetRoute, contains('SlideTransition'));
        expect(utilitySheetRoute, isNot(contains('NoTransitionPage')));

        expect(
          mainSource,
          contains("_utilitySheetRoute(\n      path: '/flows'"),
        );
        expect(
          mainSource,
          contains("_utilitySheetRoute(\n      path: '/calendars'"),
        );
        expect(
          mainSource,
          isNot(contains("_calmRoute(\n      path: '/flows'")),
        );
        expect(
          mainSource,
          isNot(contains("_calmRoute(\n      path: '/calendars'")),
        );

        final routeScaffold = await File(
          'lib/widgets/utility_sheet_route_scaffold.dart',
        ).readAsString();
        expect(routeScaffold, contains('class UtilitySheetRouteScaffold'));
        expect(routeScaffold, contains('State<UtilitySheetRouteScaffold>'));
        expect(routeScaffold, contains('dismissDistance = 120'));
        expect(routeScaffold, contains('dismissVelocity = 700'));
        expect(routeScaffold, contains('onVerticalDragStart'));
        expect(routeScaffold, contains('onVerticalDragUpdate'));
        expect(routeScaffold, contains('onVerticalDragEnd'));
        expect(routeScaffold, contains('onVerticalDragCancel'));
        expect(routeScaffold, contains('_dragOffset'));
        expect(routeScaffold, contains('_snapBack'));
        expect(routeScaffold, contains('_requestClose'));
        expect(routeScaffold, contains('utilitySheetRouteDragHandleKey'));
        expect(routeScaffold, contains('BorderRadius.vertical'));
        expect(routeScaffold, contains('top: Radius.circular(24)'));
        expect(routeScaffold, contains('Close \${widget.semanticLabel}'));
        expect(routeScaffold, contains('GestureDetector'));
        expect(routeScaffold, contains('FractionallySizedBox'));
      },
    );

    test(
      'CalendarPage sheet helpers expose modal future diagnostics',
      () async {
        final source = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();
        final calendarsSource = _sourceBetween(
          source,
          'Future<void> _openSharedCalendarsSheet(',
          'Future<bool> _openCalendarScopedNoteDialog',
        );
        final flowStudioSource = _sourceBetween(
          source,
          'Future<void> _openFlowStudioSheet(',
          '// Directly open My Flows list',
        );

        for (final fragment in <String>[
          'calendars sheet helper entered',
          'calendars sheet show requested',
          'calendars sheet future created',
          'calendars sheet future completed',
        ]) {
          expect(calendarsSource, contains(fragment));
        }
        expect(calendarsSource, contains('recordError'));

        for (final fragment in <String>[
          'flow studio sheet helper entered',
          'flow studio sheet show requested',
          'flow studio sheet future created',
          'flow studio sheet future completed',
        ]) {
          expect(flowStudioSource, contains(fragment));
        }
        expect(flowStudioSource, contains('recordError'));
      },
    );

    test('global drawer is available on profile and feed routes', () async {
      final source = await File('lib/main.dart').readAsString();
      final shell = _sourceBetween(
        source,
        'class _GlobalFloatingMenuShellState',
        'class PushIntentBridge',
      );

      expect(shell, contains('GlobalSideDrawer('));
      expect(shell, contains('GlobalMenuBubble('));
      expect(shell, contains('if (supabase.auth.currentSession == null'));
      expect(shell, isNot(contains('_usesProfileAppBarMenu')));
      expect(shell, isNot(contains("segments.first != 'profile'")));
      expect(shell, isNot(contains("segments.first == 'profile'")));
    });

    test('global drawer uses foreground tap dismiss layer', () async {
      final source = await File('lib/main.dart').readAsString();
      final shell = _sourceBetween(
        source,
        'class _GlobalFloatingMenuShellState',
        'class PushIntentBridge',
      );
      final drawer = await File(
        'lib/widgets/global_side_drawer.dart',
      ).readAsString();

      expect(shell, contains('globalSideDrawerScrimKey'));
      expect(shell, contains('HitTestBehavior.opaque'));
      expect(shell, contains('onTap: () => unawaited(_closeFloatingMenu())'));
      expect(
        shell.indexOf('GlobalSideDrawer('),
        lessThan(shell.indexOf('GlobalSideDrawerForeground(')),
      );
      expect(drawer, contains('globalSideDrawerScrimKey'));
      expect(drawer, contains('globalSideDrawerForegroundKey'));
      expect(drawer, contains('class GlobalSideDrawerForeground'));
      expect(drawer, contains('AnimatedSlide'));
    });

    test('global bubble hit area matches the visible circle', () async {
      final drawer = await File(
        'lib/widgets/global_side_drawer.dart',
      ).readAsString();
      final bubble = _sourceBetween(
        drawer,
        'class GlobalMenuBubble extends StatelessWidget',
        'class GlobalSideDrawer extends StatelessWidget',
      );

      expect(bubble, contains('width: kGlobalMenuBubbleSize'));
      expect(bubble, contains('height: kGlobalMenuBubbleSize'));
      expect(bubble, contains('customBorder: const CircleBorder()'));
      expect(bubble, contains('onTap: onPressed'));
      expect(bubble, isNot(contains('hitHeight')));
      expect(bubble, isNot(contains('onPointerUp')));
    });

    test(
      'global drawer bubble does not absorb taps while keyboard is visible',
      () async {
        final source = await File('lib/main.dart').readAsString();
        final shell = _sourceBetween(
          source,
          'class _GlobalFloatingMenuShellState',
          'class PushIntentBridge',
        );

        expect(shell, contains('MediaQuery.viewInsetsOf(context).bottom == 0'));
        expect(shell, contains('final keyboardVisible ='));
        expect(shell, contains('final menuOpenForInteraction ='));
        expect(shell, contains('visible: shouldActivateFloatingMenu'));
        expect(shell, contains('_resetFloatingMenuStateAfterFrame'));
      },
    );

    test(
      'route changes dismiss only calendar-owned transient overlays',
      () async {
        final main = await File('lib/main.dart').readAsString();
        final calendar = await File(
          'lib/features/calendar/calendar_page.dart',
        ).readAsString();
        final shell = _sourceBetween(
          main,
          'class _GlobalFloatingMenuShellState',
          'class PushIntentBridge',
        );
        final cleanup = _sourceBetween(
          calendar,
          'static Future<void> dismissAppOwnedTransientOverlaysForRouteChange',
          'static List<String> _stringListFromRestorationValue',
        );

        expect(
          shell,
          contains('dismissAppOwnedTransientOverlaysForRouteChange'),
        );
        expect(
          cleanup,
          contains('_hasCalendarOwnedTransientOverlayOpenOrOpening'),
        );
        expect(cleanup, contains('CalendarEventDetailSheetCoordinator'));
        expect(cleanup, contains('_kCalendarOverlayKindFlowStudio'));
        expect(cleanup, contains('_kFlowStudioDraftEditorKey'));
        expect(cleanup, contains('Navigator.of(context, rootNavigator: true)'));
        expect(cleanup, isNot(contains('showDialog')));
      },
    );

    test('inbox list avoids duplicate route bottom inset', () async {
      final source = await File(
        'lib/features/inbox/inbox_page.dart',
      ).readAsString();
      final body = _sourceBetween(
        source,
        'Widget _buildBody()',
        'ConversationUser _resolveOtherProfile',
      );

      expect(body, contains('const listBottomPadding = 16.0;'));
      expect(
        body,
        contains('EdgeInsets.fromLTRB(16, 16, 16, listBottomPadding)'),
      );
      expect(body, isNot(contains('bottomPaddingAboveGlobalChrome')));
      expect(body, isNot(contains('padding: const EdgeInsets.all(16)')));
    });

    test(
      'inbox conversation composer stays above menu without double lift',
      () async {
        final source = await File(
          'lib/features/inbox/inbox_conversation_page.dart',
        ).readAsString();
        final body = _sourceBetween(
          source,
          'body: SafeArea(',
          'Widget _buildComposer()',
        );
        final composer = _sourceBetween(
          source,
          'Widget _buildComposer()',
          'class _FlowBubble',
        );

        expect(body, contains('bottom: false'));
        expect(body, contains('const listBottomPadding = 24.0;'));
        expect(body, contains('listBottomPadding'));
        expect(body, isNot(contains('bottomPaddingAboveGlobalChrome(')));
        expect(composer, contains('padding: EdgeInsets.zero'));
        expect(composer, isNot(contains('globalBottomMenuHeight(context)')));
        expect(composer, isNot(contains('bottomPaddingAboveGlobalChrome')));
      },
    );

    test(
      'inbox conversation sends optimistically without button spinner',
      () async {
        final source = await File(
          'lib/features/inbox/inbox_conversation_page.dart',
        ).readAsString();
        final send = _sourceBetween(
          source,
          'Future<void> _sendMessage()',
          'Future<void> _leaveConversation()',
        );
        final composer = _sourceBetween(
          source,
          'Widget _buildComposer()',
          'class _PendingDmMessage',
        );

        expect(
          source,
          contains('final List<_PendingDmMessage> _pendingMessages'),
        );
        expect(send, contains('_pendingMessages.add(pending)'));
        expect(send, contains('_messageController.clear()'));
        expect(send, contains('await _inboxRepo.sendTextMessage'));
        expect(composer, contains('onPressed: _sendMessage'));
        expect(composer, contains('child: const Icon(Icons.send)'));
        expect(composer, isNot(contains('CircularProgressIndicator')));
        expect(source, isNot(contains('_sendingMessage')));
      },
    );

    test('inbox conversation clears resume before intentional back', () async {
      final source = await File(
        'lib/features/inbox/inbox_conversation_page.dart',
      ).readAsString();
      final leave = _sourceBetween(
        source,
        'Future<void> _leaveConversation()',
        'List<_PendingDmMessage> _visiblePendingMessages',
      );
      final persist = _sourceBetween(
        source,
        'void _persistResumeState()',
        'void _scrollToBottom()',
      );
      final inbox = await File(
        'lib/features/inbox/inbox_page.dart',
      ).readAsString();
      final resume = _sourceBetween(
        inbox,
        'Future<void> _resumeConversationIfNeeded()',
        'void _openConversation',
      );

      expect(persist, contains('SessionResumeService.clearResumeEntry'));
      expect(source, contains('return PopScope('));
      expect(source, contains('unawaited(_leaveConversation())'));
      expect(leave, contains('suppressRestoreForUserNavigation'));
      expect(leave, contains('await SessionResumeService.clearResumeEntry'));
      expect(leave, contains("popOrGo(context, '/inbox')"));
      expect(resume, contains('RestorationRestoreReason.userNavigation'));
      expect(resume, contains('claimRestoreSurface(_resumeKind)'));
    });

    test('shared flow route accepts conversation fallback extra', () async {
      final conversation = await File(
        'lib/features/inbox/inbox_conversation_page.dart',
      ).readAsString();
      final main = await File('lib/main.dart').readAsString();
      final route = _sourceBetween(
        main,
        'class _SharedFlowRoutePageState',
        'class EditProfileRoutePage',
      );
      final entry = await File(
        'lib/features/inbox/shared_flow_details_entry.dart',
      ).readAsString();

      expect(conversation, contains("'fallbackLocation':"));
      expect(conversation, contains('_conversationLocation'));
      expect(route, contains("extra['fallbackLocation']"));
      expect(route, contains("extra['share']"));
      expect(route, contains('fallbackLocation: _fallbackLocation'));
      expect(entry, contains('final String fallbackLocation'));
      expect(entry, contains('fallbackLocation: widget.fallbackLocation'));
    });

    test(
      'planner embedded mode keeps menu space while routed lists do not',
      () async {
        final planner = await File(
          'lib/features/rhythm/pages/todays_alignment_page.dart',
        ).readAsString();
        final reflections = await File(
          'lib/features/reflections/decan_reflection_archive_page.dart',
        ).readAsString();

        expect(planner, contains('final listBottomPadding = embedded'));
        expect(
          planner,
          contains('? bottomPaddingAboveGlobalChrome(context, 32)'),
        );
        expect(planner, contains(': 32.0'));
        expect(planner, contains('keyboardInsetOf(context)'));
        expect(reflections, contains('const listBottomPadding = 16.0;'));
        expect(reflections, isNot(contains('bottomPaddingAboveGlobalChrome')));
        expect(
          reflections,
          contains('padding: EdgeInsets.fromLTRB(0, 0, 0, listBottomPadding)'),
        );
      },
    );

    test('expired sessions refresh before restored pages load data', () async {
      final source = await File('lib/main.dart').readAsString();

      expect(source, contains("await _refreshSessionIfNeeded('boot')"));
      expect(source, contains("_refreshSessionIfNeeded('web boot')"));
      expect(source, contains("'resume'"));
      expect(source, contains('whenComplete'));
      expect(source, contains('session == null || !session.isExpired'));
      expect(source, contains('refreshSession()'));
    });

    test(
      'restored data pages retry once after expired JWT responses',
      () async {
        final rhythmRepo = await File(
          'lib/features/rhythm/data/rhythm_repo.dart',
        ).readAsString();
        final decanRepo = await File(
          'lib/data/decan_reflection_repo.dart',
        ).readAsString();
        final profileRepo = await File(
          'lib/data/profile_repo.dart',
        ).readAsString();

        expect(rhythmRepo, contains('withSupabaseAuthRetry'));
        expect(decanRepo, contains('withSupabaseAuthRetry'));
        expect(profileRepo, contains('withSupabaseAuthRetry'));
        expect(profileRepo, contains("'get_profile_feed'"));
        expect(profileRepo, contains("'get_flow_post_feed'"));
      },
    );

    test(
      'decan reflections distinguish load errors from empty state',
      () async {
        final repo = await File(
          'lib/data/decan_reflection_repo.dart',
        ).readAsString();
        final page = await File(
          'lib/features/reflections/decan_reflection_archive_page.dart',
        ).readAsString();

        expect(repo, contains('class DecanReflectionListResult'));
        expect(
          repo,
          contains('Future<DecanReflectionListResult> listMineResult'),
        );
        expect(repo, contains('errorMessage: _friendlyReadError(e)'));
        expect(repo, isNot(contains('return []')));
        expect(page, contains('String? _errorMessage'));
        expect(page, contains('decanReflectionArchiveVisibleError'));
        expect(page, contains('hasVisibleItems: entries.isNotEmpty'));
        expect(page, contains('Reflections could not load'));
        expect(page, contains('No reflections yet'));
      },
    );

    test('community feed distinguishes load errors from empty state', () async {
      final repo = await File('lib/data/profile_repo.dart').readAsString();
      final page = await File(
        'lib/features/profile/profile_page.dart',
      ).readAsString();

      expect(repo, contains('class ProfileFeedResult'));
      expect(repo, contains('Future<ProfileFeedResult> getProfileFeedResult'));
      expect(repo, contains('_getProfileFeedFallbackResult'));
      expect(repo, contains('errorMessage: _friendlyFeedError'));
      expect(
        repo,
        isNot(
          contains('Future<List<ProfileFeedItem>> _getProfileFeedFallback'),
        ),
      );
      expect(page, contains('String? _feedErrorMessage'));
      expect(page, contains('_feedErrorMessage = result.errorMessage'));
      expect(page, contains('Community Feed could not load'));
      expect(page, contains('No feed posts available yet'));
    });

    test('inbox summary cells stay visible without recent activity', () async {
      final source = await File(
        'lib/features/inbox/inbox_page.dart',
      ).readAsString();
      final summaries = _sourceBetween(
        source,
        'bool get _hasSummaries',
        'Widget _buildSummaryGlyphAvatar',
      );

      expect(summaries, contains('bool get _hasSummaries => true'));
      expect(summaries, contains('int get _summaryTileCount => 3'));
      expect(summaries, contains('_buildCommunitySummaryTile()'));
      expect(summaries, contains('_buildMovementSummaryTile()'));
      expect(summaries, contains("'Followers and profile activity'"));
      expect(summaries, contains("glyph: '𓀀𓁐'"));
      expect(summaries, contains("'People'"));
      expect(summaries, isNot(contains("glyph: '𓉐'")));
      expect(summaries, isNot(contains("'House'")));
      expect(summaries, contains("'Flow comments and likes'"));
      expect(summaries, isNot(contains('if (_latestFollow != null)')));
      expect(summaries, isNot(contains('if (_latestEngagement != null)')));
    });

    test('rhythm route retirement only removes my cycle page', () async {
      final source = await File('lib/main.dart').readAsString();
      final redirect = _sourceBetween(
        source,
        'String? _redirectRetiredRhythmRoute',
        'GoRouter _createRouter({required String initialLocation}) => GoRouter(',
      );

      expect(redirect, contains("path == '/rhythm/mycycle'"));
      expect(redirect, isNot(contains("path.startsWith('/rhythm/editor/')")));
      expect(source, contains("path: '/rhythm/editor/timed'"));
      expect(source, contains("path: '/rhythm/editor/untimed'"));
      expect(source, contains("path: '/rhythm/editor/custom'"));
      expect(source, contains('TimedRhythmEditorPage'));
      expect(source, contains('UntimedRhythmEditorPage'));
      expect(source, contains('CustomRhythmEditorPage'));
    });

    test('inbox app bars keep expected handlers', () async {
      final inbox = await File(
        'lib/features/inbox/inbox_page.dart',
      ).readAsString();
      final inboxAppBar = _sourceBetween(
        inbox,
        'appBar: AppBar(',
        'body: _buildBody()',
      );

      expect(inboxAppBar, contains("popOrGo(context, '/')"));
      _expectTooltipAction(inboxAppBar, 'Search people', <String>[
        'KemeticAppBarSearchIcon',
        '_openUserSearch',
      ]);
      expect(inboxAppBar, isNot(contains("tooltip: 'New message'")));
      expect(inboxAppBar, isNot(contains('Icons.person_search')));
      expect(inbox, contains("'?select=conversation'"));
      expect(inbox, contains('Search people to message'));

      final conversation = await File(
        'lib/features/inbox/inbox_conversation_page.dart',
      ).readAsString();
      final conversationAppBar = _sourceBetween(
        conversation,
        'appBar: AppBar(',
        'body: SafeArea(',
      );

      expect(conversationAppBar, contains('_leaveConversation'));
      expect(conversation, contains("popOrGo(context, '/inbox')"));
      expect(
        conversation,
        contains('await SessionResumeService.clearResumeEntry'),
      );
      _expectTooltipAction(conversationAppBar, 'View profile', <String>[
        'openDetailRoute<void>(',
        "'/profile/",
        'Uri.encodeComponent(widget.otherUserId)',
      ]);
    });

    test(
      'raw context.push usage stays centralized or explicitly local',
      () async {
        final offenders = <String>[];

        await for (final entity in Directory('lib').list(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;

          final path = _normalizePath(entity.path);
          final source = await entity.readAsString();
          final lines = source.split('\n');
          for (var index = 0; index < lines.length; index += 1) {
            final line = lines[index];
            if (!line.contains('context.push')) continue;
            final isExplicitPicker =
                path.endsWith(
                  'lib/features/calendars/shared_calendars_sheet.dart',
                ) &&
                source.contains('&select=picker');
            final isFeedAuthorProfilePush =
                path.endsWith('lib/features/profile/profile_page.dart') &&
                line.contains("context.push('/profile/") &&
                source.contains('Future<void> _openFeedAuthorProfile');
            final start = index > 1 ? index - 2 : 0;
            final end = index + 3 < lines.length ? index + 3 : lines.length;
            final nearbyLines = lines.sublist(start, end).join('\n');
            final isLivingTextLibraryCtaPush =
                path.endsWith('lib/features/calendar/day_view.dart') &&
                nearbyLines.contains('/nodes');
            final isSharedNavigationHelper = path.endsWith(
              'lib/core/navigation_fallback.dart',
            );
            if (!isExplicitPicker &&
                !isFeedAuthorProfilePush &&
                !isLivingTextLibraryCtaPush &&
                !isSharedNavigationHelper) {
              offenders.add('$path:${index + 1}: ${line.trim()}');
            }
          }
        }

        expect(offenders, isEmpty);
      },
    );

    test('popOrGo pops existing history before fallback routing', () async {
      final source = await File(
        'lib/core/navigation_fallback.dart',
      ).readAsString();

      expect(source, contains('router.canPop()'));
      expect(source, contains('router.pop(result)'));
      expect(source, contains('navigator.canPop()'));
      expect(source, contains('navigator.pop(result)'));
      expect(source, contains('context.go(fallbackLocation)'));
      expect(source, contains('suppressRestoreForUserNavigation'));
      expect(source, contains('navigation close_or_return fallback'));
    });

    test(
      'top-level close buttons keep fallbacks and rows use detail history',
      () async {
        final sharePreview = await File(
          'lib/features/sharing/share_preview_page.dart',
        ).readAsString();
        final closePreview = _sourceBetween(
          sharePreview,
          'void _closePreview()',
          'Map<String, dynamic>? _resolvedFlowData()',
        );
        expect(closePreview, contains("context.go('/')"));
        expect(closePreview, isNot(contains('canPop')));
        expect(closePreview, isNot(contains('.pop()')));

        final followList = await File(
          'lib/features/profile/follow_list_page.dart',
        ).readAsString();
        final rowTap = _sourceBetween(
          followList,
          'trailing: KemeticGold.icon(Icons.chevron_right),',
          ');',
        );
        expect(rowTap, contains('openDetailRoute<void>'));
        expect(rowTap, contains("'/profile/"));
        expect(rowTap, isNot(contains('canPop')));
        expect(rowTap, isNot(contains('.pop(')));
      },
    );

    test(
      'top-level app bar close buttons route to explicit fallbacks',
      () async {
        const expectedFallbacks = <String, List<String>>{
          'lib/features/settings/settings_page.dart': ["popOrGo(context, '/')"],
          'lib/features/profile/profile_page.dart': ["popOrGo(context, '/')"],
          'lib/features/inbox/inbox_page.dart': ["popOrGo(context, '/')"],
          'lib/features/inbox/inbox_conversation_page.dart': [
            '_leaveConversation',
            "popOrGo(context, '/inbox')",
          ],
          'lib/features/invites/event_invite_details_page.dart': [
            "popOrGo(context, '/inbox')",
          ],
          'lib/features/reflections/decan_reflection_archive_page.dart': [
            "popOrGo(context, '/')",
          ],
          'lib/features/reflections/decan_reflection_detail_page.dart': [
            "popOrGo(context, '/reflections')",
          ],
          'lib/features/journal/journal_entry_detail_page.dart': [
            "popOrGo(context, '/journal')",
          ],
          'lib/features/profile/profile_search_page.dart': [
            'popOrGo(context, widget.fallbackLocation)',
          ],
          'lib/features/profile/edit_profile_page.dart': [
            "popOrGo(context, '/profile/me')",
          ],
          'lib/features/profile/follow_list_page.dart': ['popOrGo('],
          'lib/features/profile/flow_post_picker_page.dart': [
            "popOrGo(context, '/profile/me')",
          ],
          'lib/features/profile/insight_post_picker_page.dart': [
            "popOrGo(context, '/profile/me')",
          ],
          'lib/features/rhythm/pages/commitment_tracker_page.dart': [
            "popOrGo(context, '/rhythm/today')",
          ],
          'lib/features/inbox/shared_flow_details_page.dart': [
            'popOrGo(context, widget.fallbackLocation)',
          ],
          'lib/features/sharing/share_preview_page.dart': ["context.go('/')"],
        };

        for (final entry in expectedFallbacks.entries) {
          final source = await File(entry.key).readAsString();
          for (final expected in entry.value) {
            expect(source, contains(expected), reason: entry.key);
          }
        }
      },
    );

    test('day view chrome action row keeps expected handlers', () async {
      final source = await File(
        'lib/features/calendar/day_view_chrome.dart',
      ).readAsString();
      final header = _sourceBetween(
        source,
        'child: Row(',
        'SizedBox(\n              height: miniCalendarHeight,',
      );

      expect(header, contains('onPressed: onClose ?? () {}'));
      _expectTooltipAction(header, 'New note', <String>[
        'await onOpenQuickAdd!(btnCtx)',
      ]);
      _expectTooltipAction(header, 'Search notes', <String>[
        'KemeticAppBarSearchIcon',
        'await onOpenSearch!(context)',
      ]);
      _expectTooltipAction(header, 'Today', <String>[
        'KemeticAppBarTodayIcon',
        'onPressed: onJumpToToday ?? () {}',
      ]);
      _expectTooltipAction(header, 'My Profile', <String>[
        'KemeticAppBarProfileIcon',
        'await onOpenProfile!(context)',
      ]);

      final dayView = await File(
        'lib/features/calendar/day_view.dart',
      ).readAsString();
      expect(
        dayView,
        contains(
          'final Future<void> Function(BuildContext context)? onOpenSearch;',
        ),
      );
      expect(
        dayView,
        contains('await CalendarPage.openSearchFromAnyContext(btnCtx);'),
      );

      final calendarPage = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      expect(
        calendarPage,
        contains('onOpenSearch: (ctx) async => _openSearchForContext(ctx),'),
      );
    });

    test('shared app bar new-note actions never route home', () async {
      final files = <String>[
        'lib/features/rhythm/pages/todays_alignment_page.dart',
        'lib/features/profile/profile_page.dart',
      ];

      for (final path in files) {
        final source = await File(path).readAsString();
        for (final action in _tooltipActions(source, 'New note')) {
          expect(
            action,
            isNot(contains('_routeHomeForDetachedLaunch')),
            reason: '$path new-note action must not route home first',
          );
          expect(
            action,
            isNot(contains("context.go('/')")),
            reason: '$path new-note action must not route home',
          );
          expect(
            action,
            anyOf(
              contains('openQuickAddFromAnyContext'),
              contains('_openCalendarQuickAdd'),
            ),
            reason: '$path new-note action must open quick add in place',
          );
        }
      }

      final calendarSource = await File(
        'lib/features/calendar/calendar_page.dart',
      ).readAsString();
      expect(
        calendarSource,
        contains(
          'await _openDetachedQuickAddSheet(context);\n  }\n\n  static DateTime _nextWeekdayForQuickAdd',
        ),
        reason: 'Detached quick add should open on the current route',
      );
    });

    test('shared app bar search actions never route home', () async {
      final files = <String>[
        'lib/features/calendar/calendar_page.dart',
        'lib/features/calendar/day_view_chrome.dart',
        'lib/features/rhythm/pages/todays_alignment_page.dart',
        'lib/features/profile/profile_page.dart',
      ];

      for (final path in files) {
        final source = await File(path).readAsString();
        for (final action in _tooltipActions(source, 'Search notes')) {
          expect(
            action,
            isNot(contains('openMainCalendarAtToday')),
            reason: '$path search action must not behave like Today/Home',
          );
          expect(
            action,
            isNot(contains("popOrGo(context, '/')")),
            reason: '$path search action must not route home',
          );
          expect(
            action,
            anyOf(
              contains('openSearchFromAnyContext'),
              contains('onPressed: _openSearch'),
              contains('onOpenSearch'),
            ),
            reason: '$path search action must open search',
          );
        }
      }
    });

    test('every app bar button declares an enabled handler', () async {
      final offenders = <String>[];
      var appBarCount = 0;
      var buttonCount = 0;

      await for (final entity in Directory('lib').list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final path = _normalizePath(entity.path);
        final source = await entity.readAsString();
        var appBarIndex = 0;
        for (final appBar in _callBlocks(source, 'AppBar(')) {
          appBarIndex += 1;
          appBarCount += 1;

          for (final marker in <String>[
            'IconButton(',
            'KemeticAppBarAction(',
          ]) {
            for (final button in _callBlocks(appBar, marker)) {
              buttonCount += 1;
              final label = '$path AppBar#$appBarIndex ${marker.trim()}';
              if (!button.contains('onPressed:')) {
                offenders.add('$label is missing onPressed');
              }
              if (RegExp(r'onPressed:\s*null\b').hasMatch(button)) {
                offenders.add('$label has disabled onPressed:null');
              }
            }
          }
        }
      }

      expect(appBarCount, greaterThan(0));
      expect(buttonCount, greaterThan(0));
      expect(offenders, isEmpty);
    });
  });
}

void _expectTooltipAction(
  String source,
  String tooltip,
  List<String> expectedNeedles,
) {
  final matches = _tooltipActions(source, tooltip);
  expect(matches, isNotEmpty, reason: 'Missing app bar tooltip "$tooltip"');
  expect(
    matches.any((match) => expectedNeedles.every(match.contains)),
    isTrue,
    reason:
        'No "$tooltip" action contained all expected markers: '
        '${expectedNeedles.join(', ')}',
  );
}

List<String> _detachedMenuLabels(WidgetTester tester) {
  const gridKey = ValueKey<String>('calendar-actions-grid');
  return tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(gridKey), matching: find.byType(Text)),
      )
      .map((text) => text.data)
      .whereType<String>()
      .where(_expectedDetachedGlobalMenuOrder.contains)
      .toList(growable: false);
}

Future<void> _recoverTestSession() async {
  const userId = '4d2583da-8de4-49d3-9cd1-37a9a74f55bd';
  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
      1000;
  await Supabase.instance.client.auth.recoverSession(
    jsonEncode(<String, Object?>{
      'access_token': 'test-access-token-$expiresAt',
      'expires_in': 31536000,
      'refresh_token': 'test-refresh-token',
      'token_type': 'bearer',
      'user': <String, Object?>{
        'id': userId,
        'app_metadata': <String, Object?>{
          'provider': 'email',
          'providers': <String>['email'],
        },
        'user_metadata': <String, Object?>{},
        'aud': 'authenticated',
        'email': 'profile-test@example.com',
        'phone': '',
        'created_at': '2026-01-01T00:00:00.000000Z',
        'email_confirmed_at': '2026-01-01T00:00:00.000000Z',
        'role': 'authenticated',
        'updated_at': '2026-01-01T00:00:00.000000Z',
      },
      'expiresAt': expiresAt,
    }),
  );
}

void _installRestorationDebugHooks() {
  _debugCriticalSnapshots.clear();
  _debugLatestCriticalSnapshots.clear();
  _debugRemoteWindowSnapshots.clear();
  _debugRemoteLatestSnapshots.clear();
  _debugPlatformLastActiveUserId = null;
  AppWindowService.debugWindowIdResolver = () async => 'app-bar-window';
  AppWindowService.instance.resetForTesting();
  AppRestorationService.debugUserIdResolver = () => 'app-bar-user';
  AppRestorationService.debugRemoteWindowSnapshotReader =
      (userId, deviceId, windowId) async =>
          _debugRemoteWindowSnapshots['$userId:$deviceId:$windowId'];
  AppRestorationService.debugRemoteLatestSnapshotReader = (userId) async =>
      _debugRemoteLatestSnapshots[userId];
  AppRestorationService.debugRemoteSnapshotWriter =
      (userId, deviceId, windowId, snapshot) async {
        _debugRemoteWindowSnapshots['$userId:$deviceId:$windowId'] =
            Map<String, dynamic>.from(snapshot);
        _debugRemoteLatestSnapshots[userId] = Map<String, dynamic>.from(
          snapshot,
        );
      };
  AppRestorationService.debugCriticalSnapshotReader = (windowId) =>
      _debugCriticalSnapshots[windowId];
  AppRestorationService.debugCriticalSnapshotWriter = (windowId, serialized) {
    if (serialized == null || serialized.trim().isEmpty) {
      _debugCriticalSnapshots.remove(windowId);
    } else {
      _debugCriticalSnapshots[windowId] = serialized;
    }
  };
  AppRestorationService.debugLatestCriticalSnapshotReader = (userId) =>
      _debugLatestCriticalSnapshots[userId];
  AppRestorationService.debugLatestCriticalSnapshotWriter =
      (userId, serialized) {
        if (serialized == null || serialized.trim().isEmpty) {
          _debugLatestCriticalSnapshots.remove(userId);
        } else {
          _debugLatestCriticalSnapshots[userId] = serialized;
        }
      };
  AppRestorationService.debugPlatformLastActiveUserIdReader = () =>
      _debugPlatformLastActiveUserId;
  AppRestorationService.debugPlatformLastActiveUserIdWriter = (userId) {
    _debugPlatformLastActiveUserId = userId;
  };
}

void _clearRestorationDebugHooks() {
  _debugCriticalSnapshots.clear();
  _debugLatestCriticalSnapshots.clear();
  _debugRemoteWindowSnapshots.clear();
  _debugRemoteLatestSnapshots.clear();
  _debugPlatformLastActiveUserId = null;
  AppWindowService.debugWindowIdResolver = null;
  AppWindowService.instance.resetForTesting();
  AppRestorationService.debugUserIdResolver = null;
  AppRestorationService.debugRemoteWindowSnapshotReader = null;
  AppRestorationService.debugRemoteLatestSnapshotReader = null;
  AppRestorationService.debugRemoteSnapshotWriter = null;
  AppRestorationService.debugCriticalSnapshotReader = null;
  AppRestorationService.debugCriticalSnapshotWriter = null;
  AppRestorationService.debugLatestCriticalSnapshotReader = null;
  AppRestorationService.debugLatestCriticalSnapshotWriter = null;
  AppRestorationService.debugPlatformLastActiveUserIdReader = null;
  AppRestorationService.debugPlatformLastActiveUserIdWriter = null;
}

String _currentRouterLocation(GoRouter router) {
  return router.routerDelegate.currentConfiguration.uri.toString();
}

Future<void> _waitForRouterLocation(
  WidgetTester tester,
  GoRouter router,
  String expected,
) async {
  for (var i = 0; i < 20; i += 1) {
    if (_currentRouterLocation(router) == expected) return;
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(_currentRouterLocation(router), expected);
}

void _expectCalendarMenuOrder(String source, List<String> expectedLabels) {
  final labels = RegExp(
    r"label: '([^']+)'",
  ).allMatches(source).map((match) => match.group(1)!).toList(growable: false);

  expect(labels, expectedLabels);
}

void _expectCalendarMenuAction(
  String source,
  String label,
  String expectedNeedle,
) {
  final labelIndex = source.indexOf("label: '$label'");
  expect(labelIndex, isNot(-1), reason: 'Missing menu action "$label"');

  final actionStart = source.lastIndexOf('_CalendarAction(', labelIndex);
  expect(actionStart, isNot(-1), reason: 'Missing action block for "$label"');
  final nextActionStart = source.indexOf(
    '_CalendarAction(',
    labelIndex + label.length,
  );
  final block = source.substring(
    actionStart,
    nextActionStart == -1 ? source.length : nextActionStart,
  );

  expect(
    block,
    contains(expectedNeedle),
    reason: 'Menu action "$label" must keep expected handler',
  );
}

List<String> _tooltipActions(String source, String tooltip) {
  final needle = "tooltip: '$tooltip'";
  final matches = <String>[];
  var searchStart = 0;
  while (true) {
    final tooltipIndex = source.indexOf(needle, searchStart);
    if (tooltipIndex == -1) break;
    final actionStart = source.lastIndexOf('IconButton(', tooltipIndex);
    final kemeticStart = source.lastIndexOf(
      'KemeticAppBarAction(',
      tooltipIndex,
    );
    final start = actionStart > kemeticStart ? actionStart : kemeticStart;
    final safeStart = start == -1 ? tooltipIndex : start;
    matches.add(
      source.substring(
        safeStart,
        _nextActionStart(source, tooltipIndex + needle.length),
      ),
    );
    searchStart = tooltipIndex + needle.length;
  }
  return matches;
}

int _nextActionStart(String source, int searchStart) {
  final candidates = <int>[
    source.indexOf('KemeticAppBarAction(', searchStart),
    source.indexOf('IconButton(', searchStart),
  ].where((index) => index != -1).toList();
  if (candidates.isEmpty) {
    return source.length;
  }
  candidates.sort();
  return candidates.first;
}

String _sourceBetween(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNot(-1), reason: 'Missing source marker: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNot(-1), reason: 'Missing source marker: $end');
  return source.substring(startIndex, endIndex);
}

List<String> _callBlocks(String source, String marker) {
  final blocks = <String>[];
  var searchStart = 0;
  while (true) {
    final start = source.indexOf(marker, searchStart);
    if (start == -1) break;
    final openParen = source.indexOf('(', start);
    final end = _matchingParen(source, openParen);
    if (end == -1) {
      searchStart = start + marker.length;
      continue;
    }
    blocks.add(source.substring(start, end + 1));
    searchStart = end + 1;
  }
  return blocks;
}

int _matchingParen(String source, int openParen) {
  var depth = 0;
  for (var i = openParen; i < source.length; i += 1) {
    final char = source.codeUnitAt(i);
    if (char == 0x28) {
      depth += 1;
    } else if (char == 0x29) {
      depth -= 1;
      if (depth == 0) return i;
    }
  }
  return -1;
}

String _normalizePath(String path) => path.replaceAll('\\', '/');
