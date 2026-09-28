import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart' show routeObserver;
import 'package:mobile/features/pages/pages_page.dart';
import 'package:mobile/features/pages/pages_layout.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages_resource_test.dart' show session;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response(
          r.url.path.endsWith('get_together_inbox') ||
                  r.url.path.endsWith('get_commons_together_home_cards')
              ? '{}'
              : '[]',
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.recoverSession(session());
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
  });
  for (final back in ['pop', 'restore', 'go']) {
    testWidgets('Pages social return using $back permits every destination', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/pages',
        observers: [routeObserver],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Calendar fixture')),
          ),
          GoRoute(
            path: '/pages',
            pageBuilder: (c, s) =>
                NoTransitionPage(key: s.pageKey, child: const PagesPage()),
          ),
          GoRoute(
            path: '/profile/:id',
            pageBuilder: (c, s) => NoTransitionPage(
              key: s.pageKey,
              child: const Scaffold(body: Text('Social fixture')),
            ),
          ),
          GoRoute(
            path: '/nodes',
            builder: (_, _) => const Scaffold(body: Text('Library fixture')),
          ),
          for (final path in [
            '/rhythm/today',
            '/journal',
            '/inbox',
            '/calendars',
            '/flows',
          ])
            GoRoute(
              path: path,
              pageBuilder: (c, s) => CustomTransitionPage(
                opaque: false,
                transitionsBuilder: (c, a, b, w) => w,
                child: UtilitySheetRouteScaffold(
                  semanticLabel: path,
                  onClose: () => routerClose(c),
                  child: Text('Sheet $path'),
                ),
              ),
            ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final before = router.routerDelegate.currentConfiguration;
      final originalState = tester.state(find.byType(PagesPage));
      final layout = tester.widget<PagesLayout>(find.byType(PagesLayout));
      layout.onOpen(PagesDestination.feed);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/profile/me');
      final socialMatch =
          router.routerDelegate.currentConfiguration.matches.last
              as ImperativeRouteMatch;
      if (back == 'pop') {
        router.pop();
      } else if (back == 'restore') {
        router.restore(before);
      } else {
        router.go('/pages');
      }
      await tester.pumpAndSettle();
      expect(
        identical(originalState, tester.state(find.byType(PagesPage))),
        isTrue,
      );
      for (final size in [const Size(852, 393), const Size(393, 852)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
      }
      if (back != 'pop') {
        expect(socialMatch.completer.isCompleted, isFalse);
        final currentLayout = tester.widget<PagesLayout>(
          find.byType(PagesLayout),
        );
        currentLayout.onOpen(PagesDestination.planner);
        socialMatch.completer.complete(null);
        await tester.pumpAndSettle();
        // A late completion from the removed route cannot unlock a new open.
        currentLayout.onOpen(PagesDestination.journal);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/rhythm/today');
        router.pop();
        await tester.pumpAndSettle();
      }
      for (final destination in [
        PagesDestination.planner,
        PagesDestination.journal,
        PagesDestination.studio,
        PagesDestination.inbox,
        PagesDestination.calendars,
        PagesDestination.library,
        PagesDestination.feed,
      ]) {
        final currentLayout = tester.widget<PagesLayout>(
          find.byType(PagesLayout),
        );
        currentLayout.onOpen(destination);
        currentLayout.onOpen(destination); // Repeated taps must open once.
        await tester.pumpAndSettle();
        final uri = router.state.uri.path;
        expect(
          uri,
          {
            PagesDestination.planner: '/rhythm/today',
            PagesDestination.journal: '/journal',
            PagesDestination.studio: '/flows',
            PagesDestination.inbox: '/inbox',
            PagesDestination.calendars: '/calendars',
            PagesDestination.library: '/nodes',
            PagesDestination.feed: '/profile/me',
          }[destination],
        );
        if (uri != '/pages') {
          router.pop();
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/pages');
        }
      }
      tester
          .widget<PagesLayout>(find.byType(PagesLayout))
          .onOpen(PagesDestination.calendar);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }
}

void routerClose(BuildContext c) => GoRouter.of(c).pop();
