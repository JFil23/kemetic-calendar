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

    await tester.tap(find.byKey(app.globalMenuButtonKey));
    await tester.pump(const Duration(milliseconds: 260));

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

  testWidgets('drawer closes after primary route selection', (tester) async {
    final router = _testRouter();

    await _pumpShell(tester, router);
    await tester.tap(find.byKey(app.globalMenuButtonKey));
    await tester.pump(const Duration(milliseconds: 260));

    await tester.tap(find.text('Planner'));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/rhythm/today',
    );
    expect(find.text('Planner'), findsNothing);
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
    await tester.tap(find.byKey(app.globalMenuButtonKey));
    await tester.pump(globalSideDrawerTransitionDuration);
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
    await tester.tap(find.byKey(app.globalMenuButtonKey));
    await tester.pump(globalSideDrawerTransitionDuration);
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

    await tester.tap(find.byKey(app.globalMenuButtonKey));
    await tester.pump(globalSideDrawerTransitionDuration);
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

GoRouter _testRouter({String initialLocation = '/'}) {
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
            Text(label),
            if (closeLabel != null)
              TextButton(onPressed: onClose, child: Text(closeLabel!)),
          ],
        ),
      ),
    );
  }
}
