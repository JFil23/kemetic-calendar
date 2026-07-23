import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/services/navigation_trace.dart';
import 'package:mobile/widgets/global_side_drawer.dart';
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
    app.resetGlobalFloatingMenuShellForTesting();
    NavigationTrace.instance.resetForTesting();
  });

  tearDown(() {
    app.resetGlobalFloatingMenuShellForTesting();
    NavigationTrace.instance.resetForTesting();
  });

  group('navigation trace guard', () {
    testWidgets(
      'production drawer tap emits ordered route and overlay state trace',
      (tester) async {
        await NavigationTrace.instance.setEnabled(true);
        final router = _traceRouter();
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            builder: (context, child) =>
                app.buildGlobalFloatingMenuShellForTesting(
                  router: router,
                  child: child ?? const SizedBox.shrink(),
                ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(app.globalMenuButtonKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(globalSideDrawerTransitionDuration);

        expect(find.byKey(globalSideDrawerKey), findsOneWidget);
        await tester.tap(
          find.byKey(
            const ValueKey<String>('global-side-drawer-item-Calendar'),
          ),
        );
        await tester.pump(globalSideDrawerTransitionDuration);
        await tester.pump();

        expect(router.routerDelegate.currentConfiguration.uri.path, '/');
        expect(find.text('Calendar route'), findsOneWidget);
        expect(find.byKey(globalSideDrawerKey), findsNothing);

        final entries = NavigationTrace.instance.entries;
        int traceIndex(String label) =>
            entries.indexWhere((entry) => entry.contains(label));

        final bubbleIndex = traceIndex('global drawer bubble tapped');
        final mountedIndex = traceIndex('global drawer mounted closed');
        final openedIndex = traceIndex('global drawer opened');
        final tapIndex = traceIndex('drawer navigation tap target');
        final requestIndex = traceIndex('drawer navigation route requested');
        final committedIndex = traceIndex('drawer route committed');
        final closeStartedIndex = traceIndex('menu close started');
        final closeCompletedIndex = traceIndex('menu close completed');

        expect(bubbleIndex, greaterThanOrEqualTo(0));
        expect(mountedIndex, greaterThan(bubbleIndex));
        expect(openedIndex, greaterThan(mountedIndex));
        expect(tapIndex, greaterThan(openedIndex));
        expect(requestIndex, greaterThan(tapIndex));
        expect(committedIndex, greaterThan(requestIndex));
        expect(closeStartedIndex, greaterThan(committedIndex));
        expect(closeCompletedIndex, greaterThan(closeStartedIndex));

        expect(
          entries[bubbleIndex],
          allOf(
            contains('_menuMounted=false'),
            contains('_menuOpen=false'),
            contains('route=/nodes'),
          ),
        );
        expect(
          entries[mountedIndex],
          allOf(
            contains('_menuMounted=true'),
            contains('_menuOpen=false'),
            contains('route=/nodes'),
          ),
        );
        expect(
          entries[openedIndex],
          allOf(
            contains('_menuMounted=true'),
            contains('_menuOpen=true'),
            contains('route=/nodes'),
          ),
        );
        expect(
          entries[tapIndex],
          allOf(
            contains('target=Calendar'),
            contains('generation=1'),
            contains('route=/'),
          ),
        );
        expect(
          entries[committedIndex],
          allOf(
            contains('target=Calendar'),
            contains('generation=1'),
            contains('route=/'),
          ),
        );
        expect(
          entries[closeCompletedIndex],
          allOf(
            contains('_menuMounted=false'),
            contains('_menuOpen=false'),
            contains('route=/'),
          ),
        );
        expect(entries.join('\n'), isNot(contains('stale')));
        expect(entries.join('\n'), isNot(contains('error')));
      },
    );

    test(
      'Settings build marker is the hidden persisted activation path',
      () async {
        final settingsSource = await File(
          'lib/features/settings/settings_page.dart',
        ).readAsString();

        expect(settingsSource, contains('_buildMarkerTapCount < 7'));
        expect(settingsSource, contains('_handleBuildMarkerTap'));
        expect(settingsSource, contains('NavigationTrace.instance.setEnabled'));
        expect(settingsSource, contains('Navigation Trace enabled'));
        expect(settingsSource, contains('Navigation Trace disabled'));
      },
    );

    testWidgets('overlay is visible when enabled and does not intercept taps', (
      tester,
    ) async {
      var tapCount = 0;
      await NavigationTrace.instance.setEnabled(true);
      NavigationTrace.instance.record('global drawer bubble tapped');

      await tester.pumpWidget(
        NavigationTraceOverlay(
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: TextButton(
                  onPressed: () {
                    tapCount += 1;
                  },
                  child: const Text('Tap target'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Navigation Trace'), findsOneWidget);
      expect(
        find.textContaining('global drawer bubble tapped'),
        findsOneWidget,
      );

      await tester.tap(find.text('Tap target'));
      expect(tapCount, 1);
    });

    test(
      'recordError stores runtime type, message, and stack frames',
      () async {
        await NavigationTrace.instance.setEnabled(true);

        try {
          throw StateError('profile route failed');
        } catch (error, stackTrace) {
          NavigationTrace.instance.recordError(
            'profile route go error',
            error,
            stackTrace,
            state: const <String, Object?>{'route': '/profile/me'},
          );
        }

        final joinedEntries = NavigationTrace.instance.entries.join('\n');
        expect(joinedEntries, contains('profile route go error'));
        expect(joinedEntries, contains('StateError'));
        expect(joinedEntries, contains('profile route failed'));
        expect(joinedEntries, contains('stack1'));
      },
    );

    test('trace source does not expose runtime secret config names', () async {
      final traceSource = await File(
        'lib/services/navigation_trace.dart',
      ).readAsString();

      for (final secretKey in <String>[
        'SUPABASE_URL',
        'SUPABASE_ANON_KEY',
        'FIREBASE_WEB_API_KEY',
        'FIREBASE_WEB_VAPID_KEY',
        'WEB_PUSH_PUBLIC_KEY',
        'env.json',
      ]) {
        expect(traceSource, isNot(contains(secretKey)));
      }
    });
  });
}

GoRouter _traceRouter() {
  return GoRouter(
    initialLocation: '/nodes',
    observers: <NavigatorObserver>[
      app.globalFloatingMenuRouteObserverForTesting,
    ],
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const _TracePage('Calendar route'),
      ),
      GoRoute(
        path: '/nodes',
        builder: (context, state) => const _TracePage('Library route'),
      ),
    ],
  );
}

class _TracePage extends StatelessWidget {
  const _TracePage(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
