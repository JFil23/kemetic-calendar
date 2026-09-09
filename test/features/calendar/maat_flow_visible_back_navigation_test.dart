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
    // Keep this identity stable for the release comparison gate; the
    // assertions below now prove the replacement is a non-opaque sheet.
    testWidgets(
      '${scenario.templateKey} discovery Back dismisses its inline detail but keeps Ma’at Flows open',
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
          findsNothing,
        );
        expect(find.text('Carry this flow'), findsNothing);
        final detailRoute = ModalRoute.of(tester.element(back));
        expect(detailRoute, isNotNull);
        expect(detailRoute, isNot(same(listRoute)));
        expect(detailRoute, isA<PopupRoute<int?>>());
        expect(detailRoute!.opaque, isFalse);
        expect(detailRoute.isCurrent, isTrue);
        expect(listRoute.isCurrent, isFalse);
        expect(
          find.byKey(
            const ValueKey<String>('maat-flow-discovery-view'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        final sheetHost = find.byKey(kMaatFlowDetailSheetHostKey);
        expect(sheetHost, findsOneWidget);
        expect(tester.getTopLeft(sheetHost).dy, greaterThan(0));
        expect(
          tester.getSize(sheetHost).height,
          closeTo(844 * kMaatFlowDetailSheetHeightFactor, 1),
        );

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
        expect(listRoute.isCurrent, isTrue);
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

    final listSurface = find.byKey(
      const ValueKey<String>('maat-flow-discovery-view'),
      skipOffstage: false,
    );
    final back = find.byKey(const ValueKey<String>('reading-house-back'));
    expect(listSurface, findsOneWidget);
    expect(back, findsOneWidget);

    final listRoute = ModalRoute.of(tester.element(listSurface));
    final detailRoute = ModalRoute.of(tester.element(back));
    expect(listRoute, isNotNull);
    expect(detailRoute, isNotNull);
    expect(detailRoute, isNot(same(listRoute)));
    expect(detailRoute, isA<PopupRoute<int?>>());
    expect(detailRoute!.opaque, isFalse);
    expect(listRoute!.isCurrent, isFalse);
    expect(detailRoute.isCurrent, isTrue);

    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(listRoute.isCurrent, isTrue);
    expect(detailRoute.isCurrent, isFalse);
    expect(find.text('Flows'), findsOneWidget);
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

    final listSurface = find.byKey(
      const ValueKey<String>('maat-flow-discovery-view'),
      skipOffstage: false,
    );
    final listRoute = ModalRoute.of(tester.element(listSurface));
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
    expect(find.text('Flows'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('outer-route')), findsNothing);
  });

  testWidgets('detail sheet dismisses without dismissing Discovery', (
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

    final sheetHost = find.byKey(kMaatFlowDetailSheetHostKey);
    expect(sheetHost, findsOneWidget);
    expect(tester.getTopLeft(sheetHost).dy, greaterThan(0));

    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(sheetHost, findsNothing);
    expect(
      find.byKey(const ValueKey<String>('maat-flow-discovery-view')),
      findsOneWidget,
    );

    await _scrollDiscoveryControlIntoViewport(tester, openButton);
    await tester.tap(openButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(sheetHost, findsOneWidget);

    final sheetTop = tester.getTopLeft(sheetHost).dy;
    await tester.dragFrom(Offset(195, sheetTop + 12), const Offset(0, 420));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(sheetHost, findsNothing);
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
