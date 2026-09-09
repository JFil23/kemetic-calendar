import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
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

  const scenarios = <({String templateKey, String backKey})>[
    (templateKey: 'track-the-sky', backKey: 'follow-sky-back'),
    (templateKey: 'the-offering-table', backKey: 'offering-table-back'),
    (templateKey: 'the-reading-house', backKey: 'reading-house-back'),
    (templateKey: 'the-djed', backKey: 'djed-back'),
  ];

  for (final scenario in scenarios) {
    testWidgets(
      '${scenario.templateKey} discovery Back swaps the shared sheet back to Ma’at Flows',
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

        final openButton = find.byKey(
          ValueKey<String>('maat-flow-discovery-card-${scenario.templateKey}'),
        );
        await _scrollDiscoveryControlIntoViewport(tester, openButton);
        await tester.tap(openButton);
        await tester.pumpAndSettle();
        final back = find.byKey(ValueKey<String>(scenario.backKey));
        expect(back, findsOneWidget);
        expect(
          find.byKey(
            ValueKey<String>(
              'maat-flow-discovery-detail-${scenario.templateKey}',
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('Carry this flow'), findsNothing);
        final detailRoute = ModalRoute.of(tester.element(back));
        expect(detailRoute, isNotNull);
        expect(detailRoute, same(listRoute));
        expect(detailRoute!.isCurrent, isTrue);
        expect(listRoute.isCurrent, isTrue);
        expect(
          find.byKey(
            const ValueKey<String>('maat-flow-discovery-view'),
            skipOffstage: false,
          ),
          findsNothing,
        );
        final surfaceHost = find.byKey(kMaatFlowDetailSurfaceHostKey);
        expect(surfaceHost, findsOneWidget);
        expect(tester.getTopLeft(surfaceHost), Offset.zero);
        expect(tester.getSize(surfaceHost), const Size(390, 844));

        await tester.tap(back);
        await tester.pumpAndSettle();

        expect(back, findsNothing);
        expect(
          find.byKey(
            ValueKey<String>(
              'maat-flow-discovery-detail-${scenario.templateKey}',
            ),
          ),
          findsNothing,
        );
        expect(surfaceHost, findsNothing);
        expect(detailRoute.isCurrent, isTrue);
        expect(
          find.byKey(const ValueKey<String>('maat-flow-discovery-view')),
          findsOneWidget,
        );
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
    expect(tester.widget(back), isA<MaatFlowDetailBackButton>());

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

  testWidgets(
    'restored detail reconstructs one list route with selected content',
    (tester) async {
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

      final discoverySurface = find.byKey(
        const ValueKey<String>('maat-flow-discovery-view'),
        skipOffstage: false,
      );
      final back = find.byKey(const ValueKey<String>('reading-house-back'));
      expect(discoverySurface, findsNothing);
      expect(back, findsOneWidget);
      expect(find.byKey(kMaatFlowDetailSurfaceHostKey), findsOneWidget);

      final detailRoute = ModalRoute.of(tester.element(back));
      expect(detailRoute, isNotNull);
      expect(detailRoute!.isCurrent, isTrue);

      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(detailRoute.isCurrent, isTrue);
      expect(find.byKey(kMaatFlowDetailSurfaceHostKey), findsNothing);
      expect(find.text('Flows'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('outer-route')), findsNothing);
    },
  );

  testWidgets('system Back swaps selected content back to Discovery', (
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

    final back = find.byKey(const ValueKey<String>('offering-table-back'));
    expect(back, findsOneWidget);
    final sharedRoute = ModalRoute.of(tester.element(back));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(sharedRoute, isNotNull);
    expect(sharedRoute!.isCurrent, isTrue);
    expect(
      find.byKey(const ValueKey<String>('offering-table-back')),
      findsNothing,
    );
    expect(find.text('Flows'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('outer-route')), findsNothing);
  });

  testWidgets('flow detail cannot create or dismiss a second sheet', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    await _pumpFlowStudio(
      tester,
      Uri(
        path: '/flows',
        queryParameters: const <String, String>{'mode': 'maatFlows'},
      ),
    );

    final openButton = find.byKey(
      const ValueKey<String>('maat-flow-discovery-card-track-the-sky'),
    );
    await _scrollDiscoveryControlIntoViewport(tester, openButton);
    await tester.tap(openButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final surfaceHost = find.byKey(kMaatFlowDetailSurfaceHostKey);
    expect(surfaceHost, findsOneWidget);
    expect(tester.getTopLeft(surfaceHost), Offset.zero);

    await tester.drag(surfaceHost, const Offset(0, 420));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(surfaceHost, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('follow-sky-back')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('follow-sky-back')));
    await tester.pumpAndSettle();

    expect(surfaceHost, findsNothing);
    expect(
      find.byKey(const ValueKey<String>('maat-flow-discovery-view')),
      findsOneWidget,
    );
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

Future<void> _scrollDiscoveryControlIntoViewport(
  WidgetTester tester,
  Finder control,
) async {
  final scroll = find.byKey(
    const ValueKey<String>('maat-flow-discovery-scroll'),
  );
  for (var attempt = 0; attempt < 12; attempt++) {
    final rect = tester.getRect(control);
    if (rect.top >= 64 && rect.bottom <= 820) return;
    await tester.drag(scroll, Offset(0, rect.top < 64 ? 260 : -260));
    await tester.pump();
  }
  expect(tester.getRect(control).bottom, lessThanOrEqualTo(820));
}
