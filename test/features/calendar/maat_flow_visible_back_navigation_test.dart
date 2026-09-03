import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/inbox/shared_flow_details_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'anon-key-0123456789012345678901234567890123456789',
      );
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const scenarios = <({String templateKey, Key backKey})>[
    (
      templateKey: 'track-the-sky',
      backKey: ValueKey<String>('follow-sky-back'),
    ),
    (
      templateKey: 'the-offering-table',
      backKey: ValueKey<String>('offering-table-back'),
    ),
    (
      templateKey: 'the-reading-house',
      backKey: ValueKey<String>('reading-house-back'),
    ),
  ];

  for (final scenario in scenarios) {
    testWidgets(
      '${scenario.templateKey} visible back dismisses detail but keeps Ma’at Flows open',
      (tester) async {
        _setPhoneViewport(tester);
        await _pumpFlowStudio(
          tester,
          Uri(
            path: '/flows',
            queryParameters: const <String, String>{'mode': 'maatFlows'},
          ),
        );

        final card = find.byKey(
          maatFlowCatalogCardKeyForTesting(scenario.templateKey),
        );
        await tester.scrollUntilVisible(
          card,
          280,
          scrollable: find.byType(Scrollable).last,
        );
        final listRoute = ModalRoute.of(tester.element(card));
        expect(listRoute, isNotNull);
        expect(listRoute!.isCurrent, isTrue);

        await tester.tap(card);
        final back = find.byKey(scenario.backKey);
        await _pumpUntilFound(tester, back);
        expect(back, findsOneWidget);
        expect(tester.widget(back), isA<BackButton>());
        final detailRoute = ModalRoute.of(tester.element(back));
        expect(detailRoute, isNotNull);
        expect(detailRoute, isNot(same(listRoute)));
        expect(detailRoute!.isCurrent, isTrue);
        expect(listRoute.isCurrent, isFalse);

        await tester.tap(back);
        await tester.pumpAndSettle();

        expect(find.byKey(scenario.backKey), findsNothing);
        expect(listRoute.isCurrent, isTrue);
        expect(detailRoute.isCurrent, isFalse);
        expect(find.text("Ma'at Flows"), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('outer-route')), findsNothing);
      },
    );
  }

  testWidgets('visible Back never empties a first-route Ma’at detail', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final router = GoRouter(
      initialLocation: '/shared-flow',
      routes: <RouteBase>[
        GoRoute(
          path: '/shared-flow',
          builder: (_, _) => const SharedFlowDetailsPage(
            payloadJson: <String, dynamic>{
              'name': 'The Reading House',
              'notes': 'maat=the-reading-house',
            },
            fallbackLocation: '/inbox',
          ),
        ),
        GoRoute(
          path: '/inbox',
          builder: (_, _) => const Scaffold(
            body: SizedBox(key: ValueKey<String>('inbox-fallback')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    final back = find.byKey(const ValueKey<String>('reading-house-back'));
    expect(back, findsOneWidget);
    expect(tester.widget(back), isA<BackButton>());

    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(back, findsNothing);
    expect(
      find.byKey(const ValueKey<String>('inbox-fallback')),
      findsOneWidget,
    );
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/inbox');
    expect(tester.takeException(), isNull);
  });

  testWidgets('restored detail reconstructs list and detail routes', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await _pumpFlowStudio(
      tester,
      Uri(
        path: '/flows',
        queryParameters: const <String, String>{
          'mode': 'maatTemplate',
          'templateKey': 'the-reading-house',
        },
      ),
    );

    final listAppBar = find.widgetWithText(
      AppBar,
      "Ma'at Flows",
      skipOffstage: false,
    );
    final back = find.byKey(const ValueKey<String>('reading-house-back'));
    expect(listAppBar, findsOneWidget);
    expect(back, findsOneWidget);

    final listRoute = ModalRoute.of(tester.element(listAppBar));
    final detailRoute = ModalRoute.of(tester.element(back));
    expect(listRoute, isNotNull);
    expect(detailRoute, isNotNull);
    expect(detailRoute, isNot(same(listRoute)));
    expect(listRoute!.isCurrent, isFalse);
    expect(detailRoute!.isCurrent, isTrue);

    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(listRoute.isCurrent, isTrue);
    expect(detailRoute.isCurrent, isFalse);
    expect(find.text("Ma'at Flows"), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('outer-route')), findsNothing);
  });

  testWidgets('system Back pops the detail route and leaves Flow Studio open', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await _pumpFlowStudio(
      tester,
      Uri(
        path: '/flows',
        queryParameters: const <String, String>{
          'mode': 'maatTemplate',
          'templateKey': 'the-offering-table',
        },
      ),
    );

    final listAppBar = find.widgetWithText(
      AppBar,
      "Ma'at Flows",
      skipOffstage: false,
    );
    final listRoute = ModalRoute.of(tester.element(listAppBar));
    expect(
      find.byKey(const ValueKey<String>('offering-table-back')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(listRoute, isNotNull);
    expect(listRoute!.isCurrent, isTrue);
    expect(
      find.byKey(const ValueKey<String>('offering-table-back')),
      findsNothing,
    );
    expect(find.text("Ma'at Flows"), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('outer-route')), findsNothing);
  });
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpFlowStudio(WidgetTester tester, Uri initialUri) async {
  final router = GoRouter(
    initialLocation: initialUri.toString(),
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const SizedBox(key: ValueKey<String>('outer-route')),
      ),
      GoRoute(
        path: '/flows',
        builder: (_, state) =>
            CalendarPage.buildFlowStudioRoutePage(routeUri: state.uri),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}
