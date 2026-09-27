import 'package:mobile/services/session_resume_service.dart';
import 'package:mobile/main.dart' show createAppRouterForTesting;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart' show routeObserver, TelemetryRouteObserver;
import 'package:mobile/features/pages/pages_page.dart';
import 'package:mobile/features/pages/pages_layout.dart';
import 'package:mobile/features/pages/pages_board.dart';
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
  test(
    'Pages open revisit pop and replacement do not write telemetry',
    () async {
      requests.clear();
      final observer = TelemetryRouteObserver();
      final calendar = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/'),
        builder: (_) => const SizedBox(),
      );
      final pages = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/pages'),
        builder: (_) => const SizedBox(),
      );
      for (var i = 0; i < 3; i++) {
        observer.didPush(pages, calendar);
        observer.didPop(pages, calendar);
      }
      observer.didReplace(newRoute: calendar, oldRoute: pages);
      await Future<void>.delayed(Duration.zero);
      expect(requests, isEmpty);
    },
  );
  testWidgets('production route builders use canonical feature surfaces', (
    tester,
  ) async {
    final router = createAppRouterForTesting();
    addTearDown(router.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    for (final entry in {
      '/pages': 'PagesPage',
      '/journal': 'JournalRoutePage',
      '/rhythm/today': 'PlannerSheetRoutePage',
      '/inbox': 'InboxSheetRoutePage',
      '/flows': '_FlowStudioRoutePage',
      '/calendars': '_SharedCalendarsRoutePage',
    }.entries) {
      final route = router.configuration.routes
          .whereType<GoRoute>()
          .singleWhere((r) => r.path == entry.key);
      final state = GoRouterState(
        router.configuration,
        uri: Uri.parse(entry.key),
        matchedLocation: entry.key,
        fullPath: entry.key,
        pathParameters: const {},
        pageKey: ValueKey(entry.key),
      );
      final page = route.pageBuilder!(context, state) as CustomTransitionPage;
      expect(page.child, isA<SessionTrackedRoute>());
      expect(
        (page.child as SessionTrackedRoute).child.runtimeType.toString(),
        entry.value,
        reason: entry.key,
      );
    }
  });

  testWidgets(
    'Pages opens existing destinations and sheets preserve Pages and scroll',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        observers: [routeObserver],
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(context.push('/pages')),
                child: const Text('Calendar home'),
              ),
            ),
          ),
          GoRoute(
            path: '/pages',
            builder: (context, state) => const PagesPage(),
          ),
          GoRoute(
            path: '/profile/:id',
            builder: (context, state) => Scaffold(
              body: Text('Profile feed=${state.uri.queryParameters['feed']}'),
            ),
          ),
          GoRoute(
            path: '/nodes',
            builder: (context, state) =>
                const Scaffold(body: Text('Library destination')),
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
              pageBuilder: (context, state) => CustomTransitionPage(
                opaque: false,
                barrierDismissible: false,
                transitionsBuilder: (context, animation, secondary, child) =>
                    child,
                child: UtilitySheetRouteScaffold(
                  semanticLabel: path,
                  onClose: () => context.pop(),
                  child: Text('Sheet $path'),
                ),
              ),
            ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Calendar home'));
      await tester.pumpAndSettle();
      expect(find.byType(PagesLayout), findsOneWidget);
      Future<void> open(PagesDestination d) async {
        final finder = find.byWidgetPredicate(
          (w) => w is PagesTile && w.card.destination == d,
        );
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await open(PagesDestination.feed);
      expect(find.text('Profile feed=1'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await open(PagesDestination.library);
      expect(find.text('Library destination'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      for (final pair in [
        (PagesDestination.planner, '/rhythm/today'),
        (PagesDestination.journal, '/journal'),
        (PagesDestination.inbox, '/inbox'),
        (PagesDestination.calendars, '/calendars'),
        (PagesDestination.studio, '/flows'),
      ]) {
        final finder = find.byWidgetPredicate(
          (w) => w is PagesTile && w.card.destination == pair.$1,
        );
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        final before = tester.getTopLeft(finder);
        await open(pair.$1);
        expect(find.text('Sheet ${pair.$2}'), findsOneWidget);
        expect(find.byType(PagesLayout, skipOffstage: false), findsOneWidget);
        await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey));
        await tester.pumpAndSettle();
        expect(find.byType(PagesLayout), findsOneWidget);
        expect(tester.getTopLeft(finder), before);
      }
      await open(PagesDestination.calendar);
      expect(find.text('Calendar home'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );
}
