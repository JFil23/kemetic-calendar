import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/features/rhythm/pages/todays_alignment_page.dart';
import 'package:mobile/features/rhythm/widgets/planner/planner_nutrition_section.dart';
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
    // Keep the account-restoration writer outside these widget-owned navigation
    // checks; its durable storage contract has a separate behavioral suite.
    AppRestorationService.debugUserIdResolver = () => null;
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
    AppRestorationService.debugUserIdResolver = null;
    await Supabase.instance.dispose();
  });
  testWidgets(
    'Pages and sheets retain independent state across internal navigation',
    (tester) async {
      for (final destination in [
        ("Ma'at Flows", 'maatFlows', false),
        ("Ma'at Flows", 'maatFlows', true),
        ('My Flows', 'myFlows', false),
        ('My Flows', 'myFlows', true),
      ]) {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final appRouter = createAppRouterForTesting();
        final studioRoute = appRouter.configuration.routes
            .whereType<GoRoute>()
            .singleWhere((r) => r.path == '/flows');
        final router = GoRouter(
          initialLocation: '/pages',
          observers: [routeObserver],
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Text('Calendar fallback'),
            ),
            GoRoute(path: '/pages', builder: (_, _) => const PagesPage()),
            studioRoute,
          ],
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        final pages = tester.state(find.byType(PagesPage));
        final layout = tester.state(find.byType(PagesLayout));
        final tile = find.byWidgetPredicate(
          (w) =>
              w is PagesTile && w.card.destination == PagesDestination.studio,
        );
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        final tilePosition = tester.getTopLeft(tile);
        if (destination.$3) {
          unawaited(router.push<void>('/flows?mode=${destination.$2}'));
        } else {
          await tester.tap(tile);
        }
        await tester.pumpAndSettle();
        final sheet = tester.state(find.byType(UtilitySheetRouteScaffold));
        final nestedNavigator = tester.state<NavigatorState>(
          find.descendant(
            of: find.byType(UtilitySheetRouteScaffold),
            matching: find.byType(Navigator),
          ),
        );
        if (!destination.$3) {
          await tester.tap(find.text(destination.$1));
          await tester.pumpAndSettle();
        }
        expect(router.state.uri.toString(), '/flows?mode=${destination.$2}');
        expect(find.byType(PagesPage, skipOffstage: false), findsOneWidget);
        expect(
          tester.state(find.byType(PagesPage, skipOffstage: false)),
          same(pages),
        );
        expect(
          tester.state(find.byType(PagesLayout, skipOffstage: false)),
          same(layout),
        );
        expect(
          tester.state(find.byType(UtilitySheetRouteScaffold)),
          same(sheet),
        );
        expect(nestedNavigator.canPop(), isTrue);
        expect(router.canPop(), isTrue);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.text('Flow Studio'), findsOneWidget);
        expect(router.state.uri.toString(), '/flows');
        expect(nestedNavigator.canPop(), isFalse);
        expect(
          tester.state(find.byType(PagesPage, skipOffstage: false)),
          same(pages),
        );

        await tester.tap(find.text(destination.$1));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/pages');
        expect(tester.state(find.byType(PagesPage)), same(pages));
        expect(tester.state(find.byType(PagesLayout)), same(layout));
        expect(tester.getTopLeft(tile), tilePosition);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        router.dispose();
        appRouter.dispose();
      }
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final appRouter = createAppRouterForTesting();
      final plannerRoute = appRouter.configuration.routes
          .whereType<GoRoute>()
          .singleWhere((r) => r.path == '/rhythm/today');
      final router = GoRouter(
        initialLocation: '/pages',
        observers: [routeObserver],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Text('Calendar fallback'),
          ),
          GoRoute(path: '/pages', builder: (_, _) => const PagesPage()),
          plannerRoute,
          GoRoute(
            path: '/rhythm/decan/:dayKey',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Close decan details'),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final pages = tester.state(find.byType(PagesPage));
      await tester.tap(find.text('Notes').first);
      await tester.enterText(find.byType(TextField), 'retained search');
      final layout = tester.state(find.byType(PagesLayout));
      tester
          .widget<PagesLayout>(find.byType(PagesLayout))
          .onOpen(PagesDestination.planner);
      await tester.pumpAndSettle();
      final planner = tester.state(find.byType(TodaysAlignmentPage));
      final nutrition = tester.widget<PlannerNutritionSection>(
        find.byType(PlannerNutritionSection),
      );
      nutrition.nutritionSourceController.text = 'Unsaved source';
      nutrition.onOpenDecanInfo();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, startsWith('/rhythm/decan/'));
      expect(find.byType(PagesPage, skipOffstage: false), findsOneWidget);
      expect(
        tester.state(find.byType(PagesPage, skipOffstage: false)),
        same(pages),
      );
      expect(
        tester.state(find.byType(TodaysAlignmentPage, skipOffstage: false)),
        same(planner),
      );
      await tester.tap(find.text('Close decan details'));
      await tester.pumpAndSettle();
      expect(nutrition.nutritionSourceController.text, 'Unsaved source');
      await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/pages');
      expect(tester.state(find.byType(PagesLayout)), same(layout));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'retained search',
      );
      expect(
        tester
            .widget<PagesLayout>(find.byType(PagesLayout))
            .collectionState
            .collection,
        PagesCollection.notes,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      router.dispose();
      appRouter.dispose();
    },
  );

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
    expect(find.byType(SharedFlowDetailsPage), findsOneWidget);
    expect(detail.fallbackLocation, '/pages');
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  {
    for (final restored in [false, true]) {
      testWidgets('flow detail Back returns to Pages: restored=$restored', (
        tester,
      ) async {
        final router = GoRouter(
          initialLocation: restored ? '/detail' : '/pages',
          routes: [
            GoRoute(
              path: '/pages',
              builder: (_, _) => const Scaffold(body: Text('Pages return')),
            ),
            GoRoute(
              path: '/detail',
              builder: (_, _) => CalendarPage.buildCanonicalFlowDetail(
                name: 'Navigation fixture',
                color: 0xffd4af37,
                isSaved: true,
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
      });
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
