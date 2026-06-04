import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/navigation_fallback.dart';

void main() {
  testWidgets('popOrGo leaves a restored root route via fallback location', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/journal',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _NamedPage(label: 'home'),
        ),
        GoRoute(
          path: '/journal',
          builder: (context, state) =>
              const _FallbackClosePage(fallbackLocation: '/'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('restored page'), findsOneWidget);

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('restored page'), findsNothing);
  });

  testWidgets('popOrGo pops when a page exists below', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    unawaited(openDetailRoute<void>(context, '/journal')),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/journal',
          builder: (context, state) =>
              const _FallbackClosePage(fallbackLocation: '/missing'),
        ),
        GoRoute(
          path: '/missing',
          builder: (context, state) => const _NamedPage(label: 'missing'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('restored page'), findsOneWidget);

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.text('missing'), findsNothing);
    expect(find.text('restored page'), findsNothing);
  });

  testWidgets('from /nodes pushed profile close returns to /nodes', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/nodes',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _NamedPage(label: 'home'),
        ),
        GoRoute(
          path: '/nodes',
          builder: (context, state) => _OpenDetailPage(
            label: 'nodes',
            buttonLabel: 'open profile',
            location: '/profile/me',
          ),
        ),
        GoRoute(
          path: '/profile/:userId',
          builder: (context, state) =>
              const _FallbackClosePage(fallbackLocation: '/'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('open profile'));
    await tester.pumpAndSettle();
    expect(find.text('restored page'), findsOneWidget);

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/nodes');
    expect(find.text('nodes'), findsOneWidget);
  });

  testWidgets('from /profile/me pushed node reader close returns to profile', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/profile/me',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _NamedPage(label: 'home'),
        ),
        GoRoute(
          path: '/profile/:userId',
          builder: (context, state) => _OpenDetailPage(
            label: 'profile',
            buttonLabel: 'open node',
            location: '/nodes/seshat',
          ),
        ),
        GoRoute(
          path: '/nodes/:nodeId',
          builder: (context, state) =>
              const _FallbackClosePage(fallbackLocation: '/nodes'),
        ),
        GoRoute(
          path: '/nodes',
          builder: (context, state) => const _NamedPage(label: 'nodes'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('open node'));
    await tester.pumpAndSettle();
    expect(find.text('restored page'), findsOneWidget);

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/profile/me');
    expect(find.text('profile'), findsOneWidget);
  });

  testWidgets('direct /profile/me close falls back to /', (tester) async {
    final router = GoRouter(
      initialLocation: '/profile/me',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _NamedPage(label: 'home'),
        ),
        GoRoute(
          path: '/profile/:userId',
          builder: (context, state) =>
              const _FallbackClosePage(fallbackLocation: '/'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('Flow Studio route pops when pushed and falls back when direct', (
    tester,
  ) async {
    GoRouter buildRouter(String initialLocation) {
      return GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const _NamedPage(label: 'home'),
          ),
          GoRoute(
            path: '/nodes',
            builder: (context, state) => _OpenDetailPage(
              label: 'nodes',
              buttonLabel: 'open flows',
              location: '/flows',
            ),
          ),
          GoRoute(
            path: '/flows',
            builder: (context, state) =>
                const _FallbackClosePage(fallbackLocation: '/'),
          ),
        ],
      );
    }

    final pushedRouter = buildRouter('/nodes');
    await tester.pumpWidget(MaterialApp.router(routerConfig: pushedRouter));
    await tester.tap(find.text('open flows'));
    await tester.pumpAndSettle();
    expect(find.text('restored page'), findsOneWidget);

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(pushedRouter.routerDelegate.currentConfiguration.uri.path, '/nodes');
    expect(find.text('nodes'), findsOneWidget);

    final directRouter = buildRouter('/flows');
    await tester.pumpWidget(MaterialApp.router(routerConfig: directRouter));
    await tester.pumpAndSettle();
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(directRouter.routerDelegate.currentConfiguration.uri.path, '/');
    expect(find.text('home'), findsOneWidget);
  });
}

class _NamedPage extends StatelessWidget {
  const _NamedPage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

class _FallbackClosePage extends StatelessWidget {
  const _FallbackClosePage({required this.fallbackLocation});

  final String fallbackLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('restored page'),
            TextButton(
              onPressed: () => popOrGo(context, fallbackLocation),
              child: const Text('close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenDetailPage extends StatelessWidget {
  const _OpenDetailPage({
    required this.label,
    required this.buttonLabel,
    required this.location,
  });

  final String label;
  final String buttonLabel;
  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            TextButton(
              onPressed: () =>
                  unawaited(openDetailRoute<void>(context, location)),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
