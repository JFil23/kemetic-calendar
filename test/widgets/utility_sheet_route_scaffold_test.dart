import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/navigation_fallback.dart';
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';

void main() {
  Widget buildHarness({
    required VoidCallback onClose,
    Widget child = const Center(child: Text('Utility sheet body')),
  }) {
    return MaterialApp(
      home: UtilitySheetRouteScaffold(
        semanticLabel: 'Test Sheet',
        onClose: onClose,
        child: child,
      ),
    );
  }

  testWidgets('dragging down from the header past threshold dismisses', (
    tester,
  ) async {
    var closeCount = 0;
    await tester.pumpWidget(buildHarness(onClose: () => closeCount++));

    await tester.drag(
      find.byKey(utilitySheetRouteDragHandleKey),
      const Offset(0, 140),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(closeCount, 1);
  });

  testWidgets('short downward drag snaps back without dismissing', (
    tester,
  ) async {
    var closeCount = 0;
    await tester.pumpWidget(buildHarness(onClose: () => closeCount++));

    await tester.drag(
      find.byKey(utilitySheetRouteDragHandleKey),
      const Offset(0, 60),
    );
    await tester.pump(const Duration(milliseconds: 220));

    expect(closeCount, 0);
    expect(find.text('Utility sheet body'), findsOneWidget);
  });

  testWidgets('upward drag from the header does not dismiss', (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(buildHarness(onClose: () => closeCount++));

    await tester.drag(
      find.byKey(utilitySheetRouteDragHandleKey),
      const Offset(0, -160),
    );
    await tester.pump(const Duration(milliseconds: 220));

    expect(closeCount, 0);
  });

  testWidgets('tapping outside still dismisses', (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(buildHarness(onClose: () => closeCount++));

    await tester.tapAt(const Offset(24, 24));
    await tester.pump(const Duration(milliseconds: 20));

    expect(closeCount, 1);
  });

  testWidgets('close button still dismisses', (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(buildHarness(onClose: () => closeCount++));

    await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey));
    await tester.pump(const Duration(milliseconds: 20));

    expect(closeCount, 1);
  });

  testWidgets('system back dismisses once through the close handler', (
    tester,
  ) async {
    var closeCount = 0;
    await tester.pumpWidget(buildHarness(onClose: () => closeCount++));

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(closeCount, 1);
  });

  testWidgets('system back can pop a nested route before dismissing', (
    tester,
  ) async {
    var closeCount = 0;
    final nestedNavigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: UtilitySheetRouteScaffold(
          semanticLabel: 'Nested Sheet',
          onClose: () => closeCount++,
          onBackPressed: () {
            final nestedNavigator = nestedNavigatorKey.currentState;
            if (nestedNavigator != null && nestedNavigator.canPop()) {
              nestedNavigator.pop();
              return true;
            }
            return false;
          },
          child: Navigator(
            key: nestedNavigatorKey,
            onGenerateInitialRoutes: (navigator, initialRoute) => [
              MaterialPageRoute<void>(
                builder: (_) => const Center(child: Text('Nested root')),
              ),
              MaterialPageRoute<void>(
                builder: (_) => const Center(child: Text('Nested detail')),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Nested detail'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(closeCount, 0);
    expect(find.text('Nested root'), findsOneWidget);
    expect(find.text('Nested detail'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(closeCount, 1);
  });

  testWidgets('close button can pop a pushed utility route', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/sheet'),
                child: const Text('Open sheet'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/sheet',
          builder: (context, state) => UtilitySheetRouteScaffold(
            semanticLabel: 'Route Sheet',
            onClose: () => closeOrReturn(context, '/'),
            child: const Center(child: Text('Route sheet body')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Route sheet body'), findsOneWidget);

    await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(find.text('Open sheet'), findsOneWidget);
    expect(find.text('Route sheet body'), findsNothing);
  });

  testWidgets('body scrolling does not dismiss the route sheet', (
    tester,
  ) async {
    var closeCount = 0;
    await tester.pumpWidget(
      buildHarness(
        onClose: () => closeCount++,
        child: ListView.builder(
          key: const Key('utility-sheet-body-list'),
          itemCount: 40,
          itemBuilder: (context, index) =>
              SizedBox(height: 56, child: Text('Row $index')),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('utility-sheet-body-list')),
      const Offset(0, 180),
    );
    await tester.pump(const Duration(milliseconds: 220));

    expect(closeCount, 0);
  });
}
