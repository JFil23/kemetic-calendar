import 'package:mobile/services/session_resume_service.dart';
import 'package:mobile/main.dart'
    show createAppRouterForTesting, SharedFlowRoutePage;
import 'package:mobile/features/inbox/shared_flow_details_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart' show routeObserver, TelemetryRouteObserver;
import 'package:mobile/features/pages/pages_page.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/pages/pages_collections.dart';
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
  testWidgets('by-flow route uses the current canonical detail surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SharedFlowRoutePage(
          flowId: 42,
          extra: {'fallbackLocation': '/pages'},
        ),
      ),
    );
    final detail = tester.widget<SharedFlowDetailsPage>(
      find.byType(SharedFlowDetailsPage),
    );
    expect(detail.flowId, 42);
    expect(detail.useCanonicalUserFlowDetail, isTrue);
    expect(detail.fallbackLocation, '/pages');
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  for (final canonicalSurface in [false, true]) {
    for (final restored in [false, true]) {
      testWidgets(
        'flow detail Back returns to Pages: canonical=$canonicalSurface restored=$restored',
        (tester) async {
          final router = GoRouter(
            initialLocation: restored ? '/detail' : '/pages',
            routes: [
              GoRoute(
                path: '/pages',
                builder: (_, _) => const Scaffold(body: Text('Pages return')),
              ),
              GoRoute(
                path: '/detail',
                builder: (_, _) => CalendarPage.buildCanonicalCustomFlowDetail(
                  name: 'Navigation fixture',
                  color: 0xffd4af37,
                  isSaved: true,
                  useMySavedExpansionParity: canonicalSurface,
                  backFallbackLocation: '/pages',
                ),
              ),
            ],
          );
          await tester.pumpWidget(MaterialApp.router(routerConfig: router));
          if (!restored) {
            unawaited(router.push<void>('/detail'));
          }
          await tester.pumpAndSettle();
          final back = find.byTooltip('Back');
          expect(back, findsOneWidget);
          await tester.tap(back);
          await tester.pumpAndSettle();
          expect(find.text('Pages return'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          router.dispose();
        },
      );
    }
  }

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
      '/shared-flow/by-flow/:flowId': 'SharedFlowRoutePage',
    }.entries) {
      final route = router.configuration.routes
          .whereType<GoRoute>()
          .singleWhere((r) => r.path == entry.key);
      final state = GoRouterState(
        router.configuration,
        uri: Uri.parse(entry.key),
        matchedLocation: entry.key,
        fullPath: entry.key,
        pathParameters: entry.key.contains(':flowId')
            ? const {'flowId': '42'}
            : const {},
        pageKey: ValueKey(entry.key),
      );
      final page = route.pageBuilder!(context, state) as CustomTransitionPage;
      final content = page.child is UtilitySheetRouteScaffold
          ? (page.child as UtilitySheetRouteScaffold).child
          : page.child;
      if (entry.key == '/shared-flow/by-flow/:flowId') {
        expect(page.opaque, isFalse);
        expect(page.child, isA<UtilitySheetRouteScaffold>());
      }
      expect(content, isA<SessionTrackedRoute>());
      expect(
        (content as SessionTrackedRoute).child.runtimeType.toString(),
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
          GoRoute(
            path: '/shared-flow/by-flow/:flowId',
            builder: (context, state) {
              expect(state.pathParameters['flowId'], '42');
              expect(state.extra, {'fallbackLocation': '/pages'});
              return const Scaffold(body: Text('Canonical flow detail route'));
            },
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

      tester.widget<PagesLayout>(find.byType(PagesLayout)).onCollectionItem!(
        const PagesCollectionItem(id: 'flow:42', title: 'My flow', flowId: 42),
      );
      await tester.pumpAndSettle();
      expect(find.text('Canonical flow detail route'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(PagesLayout), findsOneWidget);

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
