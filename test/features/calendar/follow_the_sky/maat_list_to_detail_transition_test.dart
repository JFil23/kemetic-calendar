import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
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

  testWidgets('discovery opens its authored inline detail on the same route', (
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

    final card = find.byKey(maatFlowCatalogCardKeyForTesting('track-the-sky'));
    await tester.scrollUntilVisible(
      card,
      280,
      scrollable: find.byType(Scrollable).last,
    );
    final listRoute = ModalRoute.of(tester.element(card));
    expect(listRoute, isA<MaterialPageRoute<dynamic>>());
    expect(listRoute!.isCurrent, isTrue);

    final openButton = find.byKey(
      const ValueKey<String>('maat-flow-discovery-open-track-the-sky'),
    );
    await tester.ensureVisible(openButton);
    await tester.tap(openButton);
    await tester.pumpAndSettle();
    final detailBack = find.byKey(const ValueKey<String>('follow-sky-back'));
    expect(detailBack, findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('maat-flow-discovery-detail-track-the-sky'),
      ),
      findsNothing,
    );
    expect(find.text('Carry this flow'), findsNothing);

    final detailRoute = ModalRoute.of(tester.element(detailBack));
    expect(detailRoute, isA<MaterialPageRoute<dynamic>>());
    expect(detailRoute, isNot(same(listRoute)));
    expect(detailRoute!.isCurrent, isTrue);
    expect(listRoute.isCurrent, isFalse);
  });

  testWidgets(
    'restored detail route preserves a discoverable list route beneath it',
    (tester) async {
      _setPhoneViewport(tester);
      await _pumpFlowStudio(
        tester,
        Uri(
          path: '/flows',
          queryParameters: const <String, String>{
            'mode': 'maatTemplate',
            'templateKey': 'track-the-sky',
          },
        ),
      );

      final listSurface = find.byKey(
        const ValueKey<String>('maat-flow-discovery-view'),
        skipOffstage: false,
      );
      final detailBack = find.byKey(const ValueKey<String>('follow-sky-back'));
      expect(listSurface, findsOneWidget);
      expect(detailBack, findsOneWidget);

      final listRoute = ModalRoute.of(tester.element(listSurface));
      final detailRoute = ModalRoute.of(tester.element(detailBack));
      expect(listRoute, isA<MaterialPageRoute<dynamic>>());
      expect(detailRoute, isA<MaterialPageRoute<dynamic>>());
      expect(detailRoute, isNot(same(listRoute)));
      expect(listRoute!.isCurrent, isFalse);
      expect(detailRoute!.isCurrent, isTrue);

      await tester.tap(detailBack);
      await tester.pumpAndSettle();

      expect(listRoute.isCurrent, isTrue);
      expect(detailRoute.isCurrent, isFalse);
      expect(find.text('Flows'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('outer-route')), findsNothing);
    },
  );
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
