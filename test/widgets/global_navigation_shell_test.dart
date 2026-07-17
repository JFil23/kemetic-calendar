import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/navigation_fallback.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/global_side_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    app.resetGlobalFloatingMenuShellForTesting();
  });

  tearDown(app.resetGlobalFloatingMenuShellForTesting);

  testWidgets('shell shows bubble and opens partial drawer', (tester) async {
    final router = _testRouter();

    await _pumpShell(tester, router);

    expect(find.byKey(app.globalMenuButtonKey), findsOneWidget);
    expect(find.bySemanticsLabel('Open navigation menu'), findsOneWidget);

    await _openDrawer(tester);

    expect(find.byKey(globalSideDrawerKey), findsOneWidget);
    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Flows'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Flow Studio'), findsNothing);

    final drawerWidth = tester.getSize(find.byKey(globalSideDrawerKey)).width;
    final shellWidth = tester.getSize(find.byType(Stack).first).width;
    expect(drawerWidth, lessThan(shellWidth));
  });

  testWidgets('calendar root keeps the floating menu bubble available', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/');

    await _pumpShell(tester, router);

    expect(find.byKey(app.globalMenuButtonKey), findsOneWidget);
    expect(find.bySemanticsLabel('Open navigation menu'), findsOneWidget);
    expect(find.byKey(globalSideDrawerKey), findsNothing);
  });

  testWidgets(
    'Library list and reader keep the floating menu bubble available',
    (tester) async {
      final router = _testRouter(initialLocation: '/nodes');

      await _pumpShell(tester, router);

      expect(find.byKey(app.globalMenuButtonKey), findsOneWidget);
      expect(find.bySemanticsLabel('Open navigation menu'), findsOneWidget);

      router.go('/nodes/maat');
      await tester.pumpAndSettle();

      expect(find.text('Node reader route'), findsOneWidget);
      expect(find.byKey(app.globalMenuButtonKey), findsOneWidget);
      expect(find.bySemanticsLabel('Open navigation menu'), findsOneWidget);
    },
  );

  testWidgets(
    'primary and detail routes share the transparent menu bubble skin',
    (tester) async {
      const routes = <String, String>{
        '/': 'Calendar route',
        '/rhythm/today': 'Planner route',
        '/nodes': 'Library route',
        '/nodes/maat': 'Node reader route',
        '/journal': 'Journal route',
        '/inbox': 'Inbox route',
        '/settings': 'Settings route',
        '/reflections': 'Reflections route',
        '/profile/me': 'Profile route',
      };

      for (final route in routes.entries) {
        app.resetGlobalFloatingMenuShellForTesting();
        final router = _testRouter(initialLocation: route.key);

        await _pumpShell(tester, router);

        expect(find.byKey(app.globalMenuButtonKey), findsOneWidget);
        expect(
          find.bySemanticsLabel('Open navigation menu'),
          findsOneWidget,
          reason: route.value,
        );
        _expectSharedTransparentMenuBubble(tester, route.value);

        await _openDrawer(tester);

        expect(
          find.byKey(globalSideDrawerKey),
          findsOneWidget,
          reason: route.value,
        );
        expect(
          find.bySemanticsLabel('Close navigation menu'),
          findsNWidgets(2),
          reason: route.value,
        );
        expect(
          find.byType(GlobalMenuBubble),
          findsOneWidget,
          reason: '${route.value}: the menu bubble stays on the foreground',
        );
        expect(
          find.descendant(
            of: find.byKey(app.globalMenuButtonKey),
            matching: find.bySemanticsLabel('Close navigation menu'),
          ),
          findsOneWidget,
          reason: '${route.value}: the persistent bubble closes the drawer',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets('full-screen search route suppresses global menu bubble', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.reset);

    final router = _testRouter(
      initialLocation: '/nodes',
      nodesBuilder: (context) => const _SearchLauncherPage(),
    );

    await _pumpShell(tester, router);

    expect(find.byKey(app.globalMenuButtonKey), findsNothing);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    expect(find.byKey(app.globalMenuButtonKey), findsOneWidget);

    await tester.tap(find.byKey(_SearchLauncherPage.openSearchKey));
    await tester.pumpAndSettle();

    expect(find.text('Search suggestions'), findsOneWidget);
    expect(find.byKey(app.globalMenuButtonKey), findsNothing);
    expect(find.byKey(globalSideDrawerKey), findsNothing);
    expect(app.globalFloatingMenuModalDepthValue, greaterThan(0));

    await tester.tapAt(const Offset(48, 780));
    await tester.pumpAndSettle();
    expect(find.byKey(globalSideDrawerKey), findsNothing);

    await tester.tap(find.byKey(_TestSearchDelegate.closeSearchKey));
    await tester.pumpAndSettle();
    await tester.pump(_floatingMenuModalSettleDelayForTesting);

    expect(find.text('Search suggestions'), findsNothing);
    expect(app.globalFloatingMenuModalDepthValue, 0);
    expect(find.byKey(app.globalMenuButtonKey), findsOneWidget);

    await _openDrawer(tester);
    expect(find.byKey(globalSideDrawerKey), findsOneWidget);
  });

  testWidgets(
    'UX-DRAWER-001/002 reveal opaque drawer behind one translated foreground',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ScrollController();
      addTearDown(controller.dispose);
      final router = _testRouter(
        initialLocation: '/',
        calendarBuilder: (context) =>
            _ScrollableTestPage(controller: controller),
      );

      await _pumpShell(tester, router);

      final closedForegroundRect = tester.getRect(
        find.byKey(globalSideDrawerForegroundKey),
      );
      final closedHeaderRect = tester.getRect(find.byType(AppBar));
      final closedCalendarRect = tester.getRect(find.byType(ListView));
      final routedElement = tester.element(find.byType(_ScrollableTestPage));
      final menuBubbleElement = tester.element(
        find.byKey(app.globalMenuButtonKey),
      );
      final closedBubbleRect = tester.getRect(
        find.byKey(app.globalMenuButtonKey),
      );
      expect(find.byKey(app.globalMenuButtonKey), findsOneWidget);
      expect(closedForegroundRect.left, closeTo(0, 0.1));

      await _openDrawer(tester);

      final drawerRect = tester.getRect(find.byKey(globalSideDrawerKey));
      final openForegroundRect = tester.getRect(
        find.byKey(globalSideDrawerForegroundKey),
      );
      final openHeaderRect = tester.getRect(find.byType(AppBar));
      final openCalendarRect = tester.getRect(find.byType(ListView));
      final drawerMaterial = tester.widget<Material>(
        find.byKey(globalSideDrawerKey),
      );

      expect(drawerRect.left, closeTo(0, 0.1));
      expect(drawerMaterial.color, const Color(0xFF000000));
      expect(openForegroundRect.left, closeTo(drawerRect.width, 0.5));
      expect(openForegroundRect.left, closeTo(drawerRect.right, 0.5));
      expect(
        openHeaderRect.left - closedHeaderRect.left,
        closeTo(drawerRect.width, 0.5),
      );
      expect(
        openCalendarRect.left - closedCalendarRect.left,
        closeTo(drawerRect.width, 0.5),
      );
      expect(
        tester.element(find.byType(_ScrollableTestPage)),
        same(routedElement),
      );
      expect(
        tester.element(find.byKey(app.globalMenuButtonKey)),
        same(menuBubbleElement),
      );
      expect(
        tester.getRect(find.byKey(app.globalMenuButtonKey)).left -
            closedBubbleRect.left,
        closeTo(drawerRect.width, 0.5),
      );
    },
  );

  testWidgets('UX-DRAWER-003 foreground animates out and back intact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _testRouter();
    await _pumpShell(tester, router);
    final foregroundBefore = tester.getRect(
      find.byKey(globalSideDrawerForegroundKey),
    );
    final routedElement = tester.element(
      find.byKey(const ValueKey<String>('page-Nodes')),
    );

    await tester.tap(find.byKey(app.globalMenuButtonKey));
    await tester.pump();

    final drawer = find.byKey(globalSideDrawerKey);
    expect(drawer, findsOneWidget);
    final drawerWidth = tester.getSize(drawer).width;
    expect(tester.getTopLeft(drawer).dx, closeTo(0, 0.1));
    expect(
      tester.getRect(find.byKey(globalSideDrawerForegroundKey)),
      foregroundBefore,
    );

    await tester.pump();
    await tester.pump(globalSideDrawerTransitionDuration * 0.5);
    final openingMidpoint = tester
        .getRect(find.byKey(globalSideDrawerForegroundKey))
        .left;
    expect(openingMidpoint, greaterThan(0));
    expect(openingMidpoint, lessThan(drawerWidth));

    await tester.pump(globalSideDrawerTransitionDuration * 0.5);
    expect(
      tester.getRect(find.byKey(globalSideDrawerForegroundKey)).left,
      closeTo(drawerWidth, 0.5),
    );
    expect(
      tester.element(find.byKey(const ValueKey<String>('page-Nodes'))),
      same(routedElement),
    );

    await tester.tapAt(Offset(drawerWidth + 24, 120));
    await tester.pump();
    await tester.pump(globalSideDrawerTransitionDuration * 0.5);
    final closingMidpoint = tester
        .getRect(find.byKey(globalSideDrawerForegroundKey))
        .left;
    expect(closingMidpoint, greaterThan(0));
    expect(closingMidpoint, lessThan(drawerWidth));

    await tester.pump(globalSideDrawerTransitionDuration * 0.5);
    await tester.pump();
    expect(find.byKey(globalSideDrawerKey), findsNothing);
    expect(
      tester.getRect(find.byKey(globalSideDrawerForegroundKey)),
      foregroundBefore,
    );
    expect(
      tester.element(find.byKey(const ValueKey<String>('page-Nodes'))),
      same(routedElement),
    );
  });

  testWidgets('outside foreground tap closes the revealed drawer', (
    tester,
  ) async {
    final router = _testRouter();

    await _pumpShell(tester, router);
    await _openDrawer(tester);

    final drawerRect = tester.getRect(find.byKey(globalSideDrawerKey));
    expect(find.byKey(globalSideDrawerScrimKey), findsOneWidget);

    await tester.tapAt(Offset(drawerRect.right + 24, 120));
    await tester.pump(globalSideDrawerTransitionDuration);
    await tester.pump();

    expect(find.byKey(globalSideDrawerKey), findsNothing);
  });

  testWidgets(
    'open drawer exposes one non-overlapping close action on the scrim',
    (tester) async {
      final router = _testRouter();

      await _pumpShell(tester, router);
      await _openDrawer(tester);

      expect(
        find.byKey(app.globalMenuButtonKey),
        findsOneWidget,
        reason:
            'The floating bubble stays attached to the translated foreground.',
      );
      expect(
        find.descendant(
          of: find.byKey(globalSideDrawerScrimKey),
          matching: find.bySemanticsLabel('Close navigation menu'),
        ),
        findsOneWidget,
        reason:
            'The unobscured outside scrim owns the accessible close action.',
      );
    },
  );

  for (final viewport in <Size>[
    Size(390, 844),
    Size(844, 390),
    Size(820, 1180),
    Size(1180, 820),
  ]) {
    testWidgets(
      'drawer reveal structural smoke ${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = _testRouter();

        await _pumpShell(tester, router);
        expect(find.byKey(app.globalMenuButtonKey), findsOneWidget);

        await _openDrawer(tester);

        final drawerRect = tester.getRect(find.byKey(globalSideDrawerKey));
        final foregroundRect = tester.getRect(
          find.byKey(globalSideDrawerForegroundKey),
        );
        expect(drawerRect.left, closeTo(0, 0.1));
        expect(drawerRect.width, lessThan(viewport.width));
        expect(foregroundRect.left, closeTo(drawerRect.width, 0.6));
        expect(drawerRect.right, lessThanOrEqualTo(foregroundRect.left + 0.6));
        expect(find.byKey(app.globalMenuButtonKey), findsOneWidget);
      },
    );
  }

  testWidgets('drawer closes after primary route selection', (tester) async {
    final router = _testRouter();

    await _pumpShell(tester, router);
    await _openDrawer(tester);

    await tester.tap(find.text('Planner'));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/rhythm/today',
    );
    expect(find.text('Planner'), findsNothing);
  });

  testWidgets(
    'UX-DRAWER-006 route dispatches during close without rebuilding foreground state',
    (tester) async {
      var calendarMounts = 0;
      var calendarDisposals = 0;
      var plannerMounts = 0;
      var plannerDisposals = 0;
      final router = _testRouter(
        initialLocation: '/',
        calendarBuilder: (context) => _RetainedCalendarTestPage(
          onMounted: () => calendarMounts += 1,
          onDisposed: () => calendarDisposals += 1,
          onOffsetChanged: (_) {},
        ),
        plannerBuilder: (context) => _LifecycleTestPage(
          label: 'Planner route',
          onMounted: () => plannerMounts += 1,
          onDisposed: () => plannerDisposals += 1,
        ),
      );

      await _pumpShell(tester, router);
      final menuBubbleElement = tester.element(
        find.byKey(app.globalMenuButtonKey),
      );
      final calendarElement = tester.element(
        find.byType(_RetainedCalendarTestPage),
      );
      await _openDrawer(tester);

      expect(
        tester.element(find.byKey(app.globalMenuButtonKey)),
        same(menuBubbleElement),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('global-side-drawer-item-Planner')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(_visibleRouterPath(router), '/rhythm/today');
      expect(find.text('Planner route'), findsOneWidget);
      expect(find.byKey(globalSideDrawerKey), findsOneWidget);
      final drawerWidth = tester.getSize(find.byKey(globalSideDrawerKey)).width;
      final closingForegroundLeft = tester
          .getRect(find.byKey(globalSideDrawerForegroundKey))
          .left;
      expect(closingForegroundLeft, greaterThan(0));
      expect(closingForegroundLeft, lessThan(drawerWidth));
      expect(
        tester.element(find.byKey(app.globalMenuButtonKey)),
        same(menuBubbleElement),
      );
      expect(
        tester.element(find.byType(_RetainedCalendarTestPage)),
        same(calendarElement),
      );
      expect(calendarMounts, 1);
      expect(calendarDisposals, 0);
      expect(plannerMounts, 1);
      expect(plannerDisposals, 0);

      await tester.pump(globalSideDrawerTransitionDuration);
      await tester.pump();

      expect(_visibleRouterPath(router), '/rhythm/today');
      expect(find.byKey(globalSideDrawerKey), findsNothing);
      expect(
        tester.element(find.byKey(app.globalMenuButtonKey)),
        same(menuBubbleElement),
      );
      expect(calendarMounts, 1);
      expect(calendarDisposals, 0);
      expect(plannerMounts, 1);
      expect(plannerDisposals, 0);
    },
  );

  testWidgets('drawer close and current selection retain foreground state', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final router = _testRouter(
      nodesBuilder: (context) => _ScrollableTestPage(controller: controller),
    );

    await _pumpShell(tester, router);
    controller.jumpTo(480);
    await tester.pump();
    final beforeOpen = controller.offset;
    final routedElement = tester.element(find.byType(_ScrollableTestPage));

    await _openDrawer(tester);
    expect(controller.offset, beforeOpen);
    expect(
      tester.element(find.byType(_ScrollableTestPage)),
      same(routedElement),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('global-side-drawer-item-Library')),
    );
    await tester.pump(globalSideDrawerTransitionDuration);
    await tester.pump();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
    expect(controller.offset, beforeOpen);
    expect(
      tester.element(find.byType(_ScrollableTestPage)),
      same(routedElement),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(globalSideDrawerKey), findsNothing);
  });

  testWidgets(
    'drawer round-trip keeps the mounted Calendar surface and exact offset',
    (tester) async {
      var calendarMounts = 0;
      var calendarDisposals = 0;
      double? calendarOffset;
      final router = _testRouter(
        initialLocation: '/',
        calendarBuilder: (context) => _RetainedCalendarTestPage(
          onMounted: () => calendarMounts += 1,
          onDisposed: () => calendarDisposals += 1,
          onOffsetChanged: (offset) => calendarOffset = offset,
        ),
      );

      await _pumpShell(tester, router);
      await tester.drag(find.byType(ListView), const Offset(0, -480));
      await tester.pumpAndSettle();
      final beforeRouteChange = calendarOffset;
      expect(beforeRouteChange, isNotNull);
      expect(beforeRouteChange, greaterThan(0));
      expect(calendarMounts, 1);

      await _openDrawer(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('global-side-drawer-item-Settings')),
      );
      await tester.pump(globalSideDrawerTransitionDuration);
      await tester.pumpAndSettle();

      expect(_visibleRouterPath(router), '/settings');
      expect(calendarDisposals, 0);

      await _openDrawer(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('global-side-drawer-item-Calendar')),
      );
      await tester.pump(globalSideDrawerTransitionDuration);
      await tester.pumpAndSettle();

      expect(_visibleRouterPath(router), '/');
      expect(calendarMounts, 1);
      expect(calendarDisposals, 0);
      expect(calendarOffset, beforeRouteChange);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byType(BackButton),
        findsNothing,
        reason:
            'The primary Calendar surface must not expose an automatic route '
            'back affordance after a drawer round-trip.',
      );
    },
  );

  testWidgets(
    'drawer destination switches retain one Calendar beneath the top route',
    (tester) async {
      var calendarMounts = 0;
      var calendarDisposals = 0;
      double? calendarOffset;
      final router = _testRouter(
        initialLocation: '/',
        calendarBuilder: (context) => _RetainedCalendarTestPage(
          onMounted: () => calendarMounts += 1,
          onDisposed: () => calendarDisposals += 1,
          onOffsetChanged: (offset) => calendarOffset = offset,
        ),
      );

      await _pumpShell(tester, router);
      await tester.drag(find.byType(ListView), const Offset(0, -480));
      await tester.pumpAndSettle();
      final beforeRouteChanges = calendarOffset;

      await _openDrawer(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('global-side-drawer-item-Settings')),
      );
      await tester.pump(globalSideDrawerTransitionDuration);
      await tester.pumpAndSettle();
      expect(_visibleRouterPath(router), '/settings');
      expect(calendarMounts, 1, reason: 'Settings must retain Calendar.');
      expect(calendarDisposals, 0, reason: 'Settings must retain Calendar.');

      await _openDrawer(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('global-side-drawer-item-Planner')),
      );
      await tester.pump(globalSideDrawerTransitionDuration);
      await tester.pumpAndSettle();
      expect(_visibleRouterPath(router), '/rhythm/today');
      expect(calendarMounts, 1, reason: 'Planner must replace only Settings.');
      expect(
        calendarDisposals,
        0,
        reason: 'Planner must not dispose the retained Calendar.',
      );

      await _openDrawer(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('global-side-drawer-item-Calendar')),
      );
      await tester.pump(globalSideDrawerTransitionDuration);
      await tester.pumpAndSettle();

      expect(_visibleRouterPath(router), '/');
      expect(calendarMounts, 1);
      expect(calendarDisposals, 0);
      expect(calendarOffset, beforeRouteChanges);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(BackButton), findsNothing);
    },
  );

  testWidgets('back with closed drawer opens drawer on primary route', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/nodes');

    await _pumpShell(tester, router);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 260));

    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
    expect(find.byKey(globalSideDrawerKey), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('back with open drawer closes drawer on primary route', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/nodes');

    await _pumpShell(tester, router);
    await tester.binding.handlePopRoute();
    await tester.pump(globalSideDrawerTransitionDuration);

    final popRoute = tester.binding.handlePopRoute();
    await tester.pump(globalSideDrawerTransitionDuration);
    await popRoute;
    await tester.pump();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
    expect(find.byKey(globalSideDrawerKey), findsNothing);
  });

  testWidgets('predictive back with open drawer closes before route changes', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/nodes');

    await _pumpShell(tester, router);
    await _openDrawer(tester);

    await _startPredictiveBackGesture(tester);
    await _commitPredictiveBackGesture(tester);
    await tester.pump(globalSideDrawerTransitionDuration);
    await tester.pump();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
    expect(find.byKey(globalSideDrawerKey), findsNothing);
    expect(find.text('Nodes'), findsOneWidget);
  });

  testWidgets('drawer predictive back consumes follow-up pop route', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/nodes');

    await _pumpShell(tester, router);
    await _openDrawer(tester);

    await _startPredictiveBackGesture(tester);
    await _commitPredictiveBackGesture(tester);
    final handled = await tester.binding.handlePopRoute();
    await tester.pump(globalSideDrawerTransitionDuration);
    await tester.pump();

    expect(handled, isTrue);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
    expect(find.byKey(globalSideDrawerKey), findsNothing);
    expect(find.text('Nodes'), findsOneWidget);
  });

  testWidgets('native Android back channel closes open drawer first', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/nodes');

    await _pumpShell(tester, router);
    await _openDrawer(tester);

    final handledFuture = _sendShellBack(tester);
    await tester.pump(globalSideDrawerTransitionDuration);
    await tester.pump();
    final handled = await handledFuture;

    expect(handled, isTrue);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
    expect(find.byKey(globalSideDrawerKey), findsNothing);
    expect(find.text('Nodes'), findsOneWidget);
  });

  testWidgets('native Android back channel does not open closed drawer', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/nodes');

    await _pumpShell(tester, router);

    final handled = await _sendShellBack(tester);

    expect(handled, isFalse);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
    expect(find.byKey(globalSideDrawerKey), findsNothing);
    expect(find.text('Nodes'), findsOneWidget);
  });

  testWidgets('predictive back keeps closed drawer behavior on primary route', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/nodes');

    await _pumpShell(tester, router);

    await _startPredictiveBackGesture(tester);
    await _commitPredictiveBackGesture(tester);
    await tester.pump(globalSideDrawerTransitionDuration);

    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
    expect(find.byKey(globalSideDrawerKey), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('repeated back toggles drawer without leaving primary route', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/journal');

    await _pumpShell(tester, router);

    await tester.binding.handlePopRoute();
    await tester.pump(globalSideDrawerTransitionDuration);
    expect(find.byKey(globalSideDrawerKey), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/journal');

    final closeDrawer = tester.binding.handlePopRoute();
    await tester.pump(globalSideDrawerTransitionDuration);
    await closeDrawer;
    await tester.pump();
    expect(find.byKey(globalSideDrawerKey), findsNothing);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/journal');

    await tester.binding.handlePopRoute();
    await tester.pump(globalSideDrawerTransitionDuration);
    expect(find.byKey(globalSideDrawerKey), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/journal');
  });

  testWidgets('drawer does not intercept closed back on detail route', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/nodes');

    await _pumpShell(tester, router);
    router.push('/profile/me');
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
    expect(find.byKey(globalSideDrawerKey), findsNothing);
    expect(find.text('Nodes'), findsOneWidget);
  });

  testWidgets('search route back still closes search before drawer handling', (
    tester,
  ) async {
    final router = _testRouter(
      initialLocation: '/nodes',
      nodesBuilder: (context) => const _SearchLauncherPage(),
    );

    await _pumpShell(tester, router);
    await tester.tap(find.byKey(_SearchLauncherPage.openSearchKey));
    await tester.pumpAndSettle();

    expect(find.text('Search suggestions'), findsOneWidget);
    expect(find.byKey(globalSideDrawerKey), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pump(_floatingMenuModalSettleDelayForTesting);

    expect(find.text('Search suggestions'), findsNothing);
    expect(find.byKey(globalSideDrawerKey), findsNothing);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
    expect(find.text('Open search'), findsOneWidget);
  });

  testWidgets('profile opens as detail route from the drawer', (tester) async {
    final router = _testRouter(initialLocation: '/nodes');

    await _pumpShell(tester, router);
    await _openDrawer(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('global-side-drawer-item-Profile')),
    );
    await tester.pump(globalSideDrawerTransitionDuration);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_visibleRouterPath(router), '/profile/me');
    expect(find.text('Profile route'), findsOneWidget);
  });

  testWidgets('flows and calendars remain pushed utility routes', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/nodes');

    await _pumpShell(tester, router);
    await _openDrawer(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('global-side-drawer-item-Flows')),
    );
    await tester.pump(globalSideDrawerTransitionDuration);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_visibleRouterPath(router), '/flows');
    await tester.tap(find.text('close flows'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');

    await _openDrawer(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('global-side-drawer-item-Calendars')),
    );
    await tester.pump(globalSideDrawerTransitionDuration);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_visibleRouterPath(router), '/calendars');
    await tester.tap(find.text('close calendars'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
  });
}

Future<void> _pumpShell(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => app.buildGlobalFloatingMenuShellForTesting(
        router: router,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(app.globalMenuButtonKey));
  await tester.pump();
  await tester.pump();
  await tester.pump(globalSideDrawerTransitionDuration);
}

void _expectSharedTransparentMenuBubble(
  WidgetTester tester,
  String routeLabel,
) {
  expect(find.byType(GlobalMenuBubble), findsOneWidget, reason: routeLabel);
  expect(
    find.byKey(globalMenuBubbleSurfaceKey),
    findsOneWidget,
    reason: routeLabel,
  );
  expect(
    find.byWidgetPredicate(
      (widget) => widget is Material && widget.color == const Color(0xF6000000),
    ),
    findsNothing,
    reason: routeLabel,
  );

  final surface = tester.widget<DecoratedBox>(
    find.byKey(globalMenuBubbleSurfaceKey),
  );
  final decoration = surface.decoration as BoxDecoration;
  final border = decoration.border! as Border;

  expect(decoration.shape, BoxShape.circle, reason: routeLabel);
  expect(
    decoration.gradient,
    same(globalTransparentMenuBubbleStyle.background),
    reason: routeLabel,
  );
  expect(
    border.top.color,
    globalTransparentMenuBubbleStyle.borderColor,
    reason: routeLabel,
  );
  expect(
    decoration.boxShadow,
    same(globalTransparentMenuBubbleStyle.boxShadow),
    reason: routeLabel,
  );

  final glyphFinder = find.descendant(
    of: find.byKey(globalMenuBubbleSurfaceKey),
    matching: find.byType(GlossyGlyph),
  );
  expect(glyphFinder, findsOneWidget, reason: routeLabel);

  final glyph = tester.widget<GlossyGlyph>(glyphFinder);
  expect(glyph.glyph, '𓉹', reason: routeLabel);
  expect(
    glyph.gradient,
    same(globalTransparentMenuBubbleStyle.glyphGradient),
    reason: routeLabel,
  );
  expect(
    glyph.size,
    globalTransparentMenuBubbleStyle.glyphSize,
    reason: routeLabel,
  );
}

Future<void> _startPredictiveBackGesture(WidgetTester tester) async {
  final message = const StandardMethodCodec().encodeMethodCall(
    MethodCall('startBackGesture', <String, Object?>{
      'touchOffset': <double>[5, 300],
      'progress': 0.0,
      'swipeEdge': 0,
    }),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (ByteData? _) {},
  );
  await tester.pump();
}

Future<void> _commitPredictiveBackGesture(WidgetTester tester) async {
  final message = const StandardMethodCodec().encodeMethodCall(
    MethodCall('commitBackGesture'),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (ByteData? _) {},
  );
  await tester.pump();
}

Future<bool> _sendShellBack(WidgetTester tester) async {
  final completer = Completer<ByteData?>();
  final message = const StandardMethodCodec().encodeMethodCall(
    const MethodCall('handleAndroidBack'),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'com.kemetic.calendar/shell_back',
    message,
    completer.complete,
  );
  final response = await completer.future;
  return const StandardMethodCodec().decodeEnvelope(response!) as bool;
}

GoRouter _testRouter({
  String initialLocation = '/nodes',
  WidgetBuilder? calendarBuilder,
  WidgetBuilder? plannerBuilder,
  WidgetBuilder? nodesBuilder,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    observers: <NavigatorObserver>[
      app.globalFloatingMenuRouteObserverForTesting,
    ],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            calendarBuilder?.call(context) ?? const _Page('Calendar'),
      ),
      GoRoute(
        path: '/rhythm/today',
        builder: (context, state) =>
            plannerBuilder?.call(context) ?? const _Page('Planner route'),
      ),
      GoRoute(
        path: '/nodes',
        builder: (context, state) =>
            nodesBuilder?.call(context) ?? const _Page('Nodes'),
      ),
      GoRoute(
        path: '/nodes/:nodeId',
        builder: (context, state) => const _Page('Node reader route'),
      ),
      GoRoute(
        path: '/journal',
        builder: (context, state) => const _Page('Journal route'),
      ),
      GoRoute(
        path: '/inbox',
        builder: (context, state) => const _Page('Inbox'),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const _Page('Settings route'),
      ),
      GoRoute(
        path: '/reflections',
        builder: (context, state) => const _Page('Reflections route'),
      ),
      GoRoute(
        path: '/flows',
        builder: (context, state) => _Page(
          'Flows route',
          closeLabel: 'close flows',
          onClose: () => closeOrReturn(context, '/'),
        ),
      ),
      GoRoute(
        path: '/calendars',
        builder: (context, state) => _Page(
          'Calendars route',
          closeLabel: 'close calendars',
          onClose: () => closeOrReturn(context, '/'),
        ),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) => const _Page('Profile route'),
      ),
    ],
  );
}

String _visibleRouterPath(GoRouter router) {
  final configuration = router.routerDelegate.currentConfiguration;
  final topMatch = configuration.lastOrNull;
  if (topMatch is ImperativeRouteMatch) return topMatch.matches.uri.path;
  return configuration.uri.path;
}

class _Page extends StatelessWidget {
  const _Page(this.label, {this.closeLabel, this.onClose});

  final String label;
  final String? closeLabel;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, key: ValueKey<String>('page-$label')),
            if (closeLabel != null)
              TextButton(onPressed: onClose, child: Text(closeLabel!)),
          ],
        ),
      ),
    );
  }
}

class _LifecycleTestPage extends StatefulWidget {
  const _LifecycleTestPage({
    required this.label,
    required this.onMounted,
    required this.onDisposed,
  });

  final String label;
  final VoidCallback onMounted;
  final VoidCallback onDisposed;

  @override
  State<_LifecycleTestPage> createState() => _LifecycleTestPageState();
}

class _LifecycleTestPageState extends State<_LifecycleTestPage> {
  @override
  void initState() {
    super.initState();
    widget.onMounted();
  }

  @override
  void dispose() {
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Page(widget.label);
}

class _ScrollableTestPage extends StatelessWidget {
  const _ScrollableTestPage({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: ListView.builder(
        controller: controller,
        itemExtent: 80,
        itemCount: 30,
        itemBuilder: (context, index) => Text('row $index'),
      ),
    );
  }
}

class _RetainedCalendarTestPage extends StatefulWidget {
  const _RetainedCalendarTestPage({
    required this.onMounted,
    required this.onDisposed,
    required this.onOffsetChanged,
  });

  final VoidCallback onMounted;
  final VoidCallback onDisposed;
  final ValueChanged<double> onOffsetChanged;

  @override
  State<_RetainedCalendarTestPage> createState() =>
      _RetainedCalendarTestPageState();
}

class _RetainedCalendarTestPageState extends State<_RetainedCalendarTestPage> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    widget.onMounted();
    _controller = ScrollController()..addListener(_reportOffset);
  }

  void _reportOffset() {
    widget.onOffsetChanged(_controller.offset);
  }

  @override
  void dispose() {
    widget.onDisposed();
    _controller
      ..removeListener(_reportOffset)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        controller: _controller,
        itemExtent: 80,
        itemCount: 30,
        itemBuilder: (context, index) => Text('calendar row $index'),
      ),
    );
  }
}

const Duration _floatingMenuModalSettleDelayForTesting = Duration(
  milliseconds: 80,
);

class _SearchLauncherPage extends StatelessWidget {
  const _SearchLauncherPage();

  static const openSearchKey = ValueKey<String>('open-shell-search');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: openSearchKey,
          onPressed: () => showSearch<String?>(
            context: context,
            delegate: _TestSearchDelegate(),
          ),
          child: const Text('Open search'),
        ),
      ),
    );
  }
}

class _TestSearchDelegate extends SearchDelegate<String?> {
  static const closeSearchKey = ValueKey<String>('close-shell-search');

  @override
  List<Widget>? buildActions(BuildContext context) => const <Widget>[];

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      key: closeSearchKey,
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return const Center(child: Text('Search results'));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(child: Text('Search suggestions'));
  }
}
