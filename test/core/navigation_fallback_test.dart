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

  testWidgets('popOrGo pops when a route exists below the current page', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/journal'),
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
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('restored page'), findsOneWidget);

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.text('restored page'), findsNothing);
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
