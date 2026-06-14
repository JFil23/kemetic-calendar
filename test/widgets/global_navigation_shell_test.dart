import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/navigation_fallback.dart';
import 'package:mobile/main.dart' as app;
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

  testWidgets('calendar root suppresses the floating menu bubble', (
    tester,
  ) async {
    final router = _testRouter(initialLocation: '/');

    await _pumpShell(tester, router);

    expect(find.byKey(app.globalMenuButtonKey), findsNothing);
    expect(find.byKey(globalSideDrawerKey), findsNothing);
  });

  testWidgets('drawer is an underlay beneath the translated foreground', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _testRouter();

    await _pumpShell(tester, router);

    final closedForegroundRect = tester.getRect(
      find.byKey(globalSideDrawerForegroundKey),
    );
    final closedBubbleRect = tester.getRect(
      find.byKey(app.globalMenuButtonKey),
    );
    final closedPageRect = tester.getRect(
      find.byKey(const ValueKey<String>('page-Nodes')),
    );
    expect(closedForegroundRect.left, closeTo(0, 0.1));

    await _openDrawer(tester);

    final drawerRect = tester.getRect(find.byKey(globalSideDrawerKey));
    final openForegroundRect = tester.getRect(
      find.byKey(globalSideDrawerForegroundKey),
    );
    final openBubbleRect = tester.getRect(find.byKey(app.globalMenuButtonKey));
    final openPageRect = tester.getRect(
      find.byKey(const ValueKey<String>('page-Nodes')),
    );

    expect(drawerRect.left, closeTo(0, 0.1));
    expect(openForegroundRect.left, closeTo(drawerRect.width, 0.5));
    expect(
      openForegroundRect.left,
      greaterThanOrEqualTo(drawerRect.right - 0.5),
    );
    expect(
      openPageRect.left - closedPageRect.left,
      closeTo(drawerRect.width, 0.5),
    );
    expect(
      openBubbleRect.left - closedBubbleRect.left,
      closeTo(drawerRect.width, 0.5),
    );
  });

  testWidgets('outside foreground tap closes the underlay drawer', (
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

  for (final viewport in <Size>[
    Size(390, 844),
    Size(844, 390),
    Size(820, 1180),
    Size(1180, 820),
  ]) {
    testWidgets(
      'drawer foreground structural smoke ${viewport.width.toInt()}x${viewport.height.toInt()}',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = _testRouter();

        await _pumpShell(tester, router);
        final closedBubbleRect = tester.getRect(
          find.byKey(app.globalMenuButtonKey),
        );

        await _openDrawer(tester);

        final drawerRect = tester.getRect(find.byKey(globalSideDrawerKey));
        final foregroundRect = tester.getRect(
          find.byKey(globalSideDrawerForegroundKey),
        );
        final openBubbleRect = tester.getRect(
          find.byKey(app.globalMenuButtonKey),
        );

        expect(drawerRect.left, closeTo(0, 0.1));
        expect(drawerRect.width, lessThan(viewport.width));
        expect(foregroundRect.left, closeTo(drawerRect.width, 0.6));
        expect(drawerRect.right, lessThanOrEqualTo(foregroundRect.left + 0.6));
        expect(
          openBubbleRect.left - closedBubbleRect.left,
          closeTo(drawerRect.width, 0.6),
        );
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

  testWidgets('drawer route dispatch does not wait for close animation', (
    tester,
  ) async {
    final router = _testRouter();

    await _pumpShell(tester, router);
    await _openDrawer(tester);

    await tester.tap(find.text('Planner'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/rhythm/today',
    );
    expect(find.text('Planner route'), findsOneWidget);
    expect(find.byKey(globalSideDrawerKey), findsOneWidget);

    await tester.pump(globalSideDrawerTransitionDuration);
    await tester.pump();
    expect(find.byKey(globalSideDrawerKey), findsNothing);
  });

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
  await tester.pump(globalSideDrawerTransitionDuration);
}

GoRouter _testRouter({String initialLocation = '/nodes'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _Page('Calendar')),
      GoRoute(
        path: '/rhythm/today',
        builder: (context, state) => const _Page('Planner route'),
      ),
      GoRoute(
        path: '/nodes',
        builder: (context, state) => const _Page('Nodes'),
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
