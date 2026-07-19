import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
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
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _ensureSupabaseInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'NAV-FLOW-STACK-001 Flow Studio submodes preserve the mounted primary base through back and close',
    (tester) async {
      final primaryKey = GlobalKey<_PrimaryViewportState>();
      final router = GoRouter(
        initialLocation: '/nodes',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Calendar fallback'))),
          ),
          GoRoute(
            path: '/nodes',
            builder: (context, state) => _PrimaryViewport(key: primaryKey),
          ),
          GoRoute(
            path: '/flows',
            builder: (context, state) =>
                CalendarPage.buildFlowStudioRoutePage(routeUri: state.uri),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        router.dispose();
      });

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      primaryKey.currentState!.jumpTo(720);
      await tester.pump();
      final primaryState = primaryKey.currentState;
      final primaryElement = primaryKey.currentContext;
      final primaryOffset = primaryState!.offset;

      unawaited(router.push<void>('/flows'));
      await _pumpUntilLocation(tester, router, '/flows');
      await tester.pumpAndSettle();
      expect(primaryKey.currentState, same(primaryState));
      expect(primaryKey.currentContext, same(primaryElement));
      expect(primaryKey.currentState!.offset, primaryOffset);

      await tester.tap(find.text('My Flows'));
      await _pumpUntilLocation(tester, router, '/flows?mode=myFlows');
      await tester.pump(const Duration(milliseconds: 400));
      expect(primaryKey.currentState, same(primaryState));
      expect(primaryKey.currentContext, same(primaryElement));
      expect(primaryKey.currentState!.offset, primaryOffset);
      expect(router.canPop(), isTrue);

      await tester.binding.handlePopRoute();
      await _pumpUntilLocation(tester, router, '/flows');
      await tester.pump(const Duration(milliseconds: 400));
      expect(primaryKey.currentState, same(primaryState));
      expect(primaryKey.currentContext, same(primaryElement));
      expect(primaryKey.currentState!.offset, primaryOffset);

      await tester.tap(find.text("Ma'at Flows"));
      await _pumpUntilLocation(tester, router, '/flows?mode=maatFlows');
      await tester.pump(const Duration(milliseconds: 400));
      expect(primaryKey.currentState, same(primaryState));
      expect(primaryKey.currentContext, same(primaryElement));
      expect(primaryKey.currentState!.offset, primaryOffset);
      expect(router.canPop(), isTrue);

      await tester.binding.handlePopRoute();
      await _pumpUntilLocation(tester, router, '/flows');
      await tester.pump(const Duration(milliseconds: 400));
      expect(primaryKey.currentState, same(primaryState));
      expect(primaryKey.currentContext, same(primaryElement));
      expect(primaryKey.currentState!.offset, primaryOffset);

      await tester.tap(find.byTooltip('Close'));
      await _pumpUntilLocation(tester, router, '/nodes');
      expect(primaryKey.currentState, same(primaryState));
      expect(primaryKey.currentContext, same(primaryElement));
      expect(primaryKey.currentState!.offset, primaryOffset);
      expect(router.canPop(), isFalse);
    },
  );
}

Future<void> _pumpUntilLocation(
  WidgetTester tester,
  GoRouter router,
  String expected,
) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (_visibleLocation(router) == expected) {
      return;
    }
  }
  expect(_visibleLocation(router), expected);
}

String _visibleLocation(GoRouter router) {
  final configuration = router.routerDelegate.currentConfiguration;
  final topMatch = configuration.lastOrNull;
  if (topMatch is ImperativeRouteMatch) {
    return topMatch.matches.uri.toString();
  }
  return configuration.uri.toString();
}

class _PrimaryViewport extends StatefulWidget {
  const _PrimaryViewport({super.key});

  @override
  State<_PrimaryViewport> createState() => _PrimaryViewportState();
}

class _PrimaryViewportState extends State<_PrimaryViewport> {
  late final ScrollController _controller = ScrollController();

  double get offset => _controller.offset;

  void jumpTo(double value) => _controller.jumpTo(value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView.builder(
      controller: _controller,
      itemExtent: 80,
      itemCount: 40,
      itemBuilder: (context, index) => Text('Library row $index'),
    ),
  );
}
