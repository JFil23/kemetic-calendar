import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/inbox/inbox_page.dart';
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';

void main() {
  testWidgets('Inbox is a bounded route sheet that closes to its parent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const contentKey = ValueKey<String>('inbox-sheet-test-content');
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/inbox'),
                child: const Text('Open Inbox'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/inbox',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            opaque: false,
            barrierColor: Colors.transparent,
            child: const InboxSheetRoutePage(
              childForTesting: SizedBox.expand(
                key: contentKey,
                child: ColoredBox(color: Color(0xFF0D0B07)),
              ),
            ),
            transitionsBuilder: (context, animation, secondary, child) => child,
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open Inbox'));
    await tester.pumpAndSettle();

    expect(find.byKey(inboxSheetRouteKey), findsOneWidget);
    expect(find.byKey(utilitySheetRouteDragHandleKey), findsOneWidget);
    expect(find.byKey(utilitySheetRouteCloseButtonKey), findsOneWidget);
    expect(find.byKey(utilitySheetRouteBackdropKey), findsOneWidget);
    expect(find.byTooltip('Close Inbox'), findsOneWidget);

    final contentRect = tester.getRect(find.byKey(contentKey));
    expect(contentRect.left, 0);
    expect(contentRect.right, 390);
    expect(contentRect.top, greaterThan(44));
    expect(contentRect.bottom, 844);

    await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(find.text('Open Inbox'), findsOneWidget);
    expect(find.byKey(inboxSheetRouteKey), findsNothing);
  });

  testWidgets('a restored standalone Inbox sheet closes to Calendar', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/inbox',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Calendar fallback'))),
        ),
        GoRoute(
          path: '/inbox',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            opaque: false,
            barrierColor: Colors.transparent,
            child: const InboxSheetRoutePage(
              childForTesting: SizedBox.expand(),
            ),
            transitionsBuilder: (context, animation, secondary, child) => child,
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.byKey(inboxSheetRouteKey), findsOneWidget);

    await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(find.text('Calendar fallback'), findsOneWidget);
  });
}
