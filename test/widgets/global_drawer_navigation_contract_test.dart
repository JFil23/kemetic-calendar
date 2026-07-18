import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/services/app_navigation_restoration_controller.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/services/navigation_trace.dart';
import 'package:mobile/widgets/global_side_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Map<String, String> _criticalSnapshots = <String, String>{};
final Map<String, String> _latestCriticalSnapshots = <String, String>{};
int _remoteWriteCount = 0;

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

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    app.resetGlobalFloatingMenuShellForTesting();
    NavigationTrace.instance.resetForTesting();
    await NavigationTrace.instance.setEnabled(true);

    _criticalSnapshots.clear();
    _latestCriticalSnapshots.clear();
    _remoteWriteCount = 0;
    AppRestorationService.instance.resetForTesting();
    AppNavigationRestorationController.instance.resetForTesting();
    AppWindowService.instance.resetForTesting();
    AppRestorationService.debugUserIdResolver = () => 'contract-user';
    AppWindowService.debugWindowIdResolver = () async => 'window-contract';
    AppRestorationService.debugCriticalSnapshotReader = (windowId) =>
        _criticalSnapshots[windowId];
    AppRestorationService.debugCriticalSnapshotWriter = (windowId, serialized) {
      if (serialized == null || serialized.trim().isEmpty) {
        _criticalSnapshots.remove(windowId);
      } else {
        _criticalSnapshots[windowId] = serialized;
      }
    };
    AppRestorationService.debugLatestCriticalSnapshotReader = (userId) =>
        _latestCriticalSnapshots[userId];
    AppRestorationService.debugLatestCriticalSnapshotWriter =
        (userId, serialized) {
          if (serialized == null || serialized.trim().isEmpty) {
            _latestCriticalSnapshots.remove(userId);
          } else {
            _latestCriticalSnapshots[userId] = serialized;
          }
        };
    AppRestorationService.debugRemoteWindowSnapshotReader =
        (userId, deviceId, windowId) async => null;
    AppRestorationService.debugRemoteLatestSnapshotReader = (userId) async =>
        null;
    AppRestorationService.debugRemoteSnapshotWriter =
        (userId, deviceId, windowId, snapshot) async {
          _remoteWriteCount += 1;
        };
    await AppWindowService.instance.ensureInitialized();
  });

  tearDown(() {
    app.resetGlobalFloatingMenuShellForTesting();
    NavigationTrace.instance.resetForTesting();
    AppRestorationService.instance.resetForTesting();
    AppNavigationRestorationController.instance.resetForTesting();
    AppRestorationService.debugUserIdResolver = null;
    AppRestorationService.debugCriticalSnapshotReader = null;
    AppRestorationService.debugCriticalSnapshotWriter = null;
    AppRestorationService.debugLatestCriticalSnapshotReader = null;
    AppRestorationService.debugLatestCriticalSnapshotWriter = null;
    AppRestorationService.debugRemoteWindowSnapshotReader = null;
    AppRestorationService.debugRemoteLatestSnapshotReader = null;
    AppRestorationService.debugRemoteSnapshotWriter = null;
    AppWindowService.debugWindowIdResolver = null;
    AppWindowService.instance.resetForTesting();
    _criticalSnapshots.clear();
    _latestCriticalSnapshots.clear();
    _remoteWriteCount = 0;
  });

  const exactRoots = <_PrimaryCase>[
    _PrimaryCase(drawerLabel: 'Calendar', root: '/', detail: '/calendar/day'),
    _PrimaryCase(drawerLabel: 'Library', root: '/nodes', detail: '/nodes/maat'),
    _PrimaryCase(
      drawerLabel: 'Journal',
      root: '/journal',
      detail: '/journal/entry/entry-1',
    ),
  ];

  for (final spec in exactRoots) {
    testWidgets(
      'Rule 1 exact ${spec.drawerLabel} root closes without route or durable mutation',
      (tester) async {
        final key = GlobalKey<_PrimaryViewportPageState>();
        final router = _contractRouter(
          initialLocation: spec.root,
          primaryBuilders: <String, WidgetBuilder>{
            spec.root: (context) => _PrimaryViewportPage(
              key: key,
              label: '${spec.drawerLabel} base',
            ),
          },
        );
        await _pumpShell(tester, router);
        key.currentState!.jumpTo(480);
        await tester.pump();
        final state = key.currentState;
        final element = tester.element(
          find.byKey(ValueKey<String>('primary-${spec.drawerLabel} base')),
        );
        final offset = state!.offset;
        final criticalBefore = Map<String, String>.from(_criticalSnapshots);
        final latestBefore = Map<String, String>.from(_latestCriticalSnapshots);
        final remoteWritesBefore = _remoteWriteCount;

        await _selectDrawerRow(tester, spec.drawerLabel);
        expect(_visibleRouterPath(router), spec.root);
        expect(key.currentState, same(state));
        expect(
          tester.element(
            find.byKey(ValueKey<String>('primary-${spec.drawerLabel} base')),
          ),
          same(element),
        );
        expect(key.currentState!.offset, offset);
        expect(find.byKey(globalSideDrawerKey), findsNothing);
        expect(router.canPop(), isFalse);
        expect(_criticalSnapshots, criticalBefore);
        expect(_latestCriticalSnapshots, latestBefore);
        expect(_remoteWriteCount, remoteWritesBefore);
        expect(
          NavigationTrace.instance.entries.join('\n'),
          isNot(contains('drawer navigation route requested')),
        );
      },
    );
  }

  const mountedDetailCases = <_PrimaryCase>[
    _PrimaryCase(drawerLabel: 'Library', root: '/nodes', detail: '/nodes/maat'),
    _PrimaryCase(
      drawerLabel: 'Journal',
      root: '/journal',
      detail: '/journal/entry/entry-1',
    ),
    _PrimaryCase(
      drawerLabel: 'Inbox',
      root: '/inbox',
      detail: '/inbox/conversation/thread-1',
    ),
    _PrimaryCase(
      drawerLabel: 'Reflections',
      root: '/reflections',
      detail: '/reflections/reflection-1',
    ),
    _PrimaryCase(
      drawerLabel: 'Planner',
      root: '/rhythm/today',
      detail: '/rhythm/decan/kaherka-1-1',
    ),
  ];

  for (final spec in mountedDetailCases) {
    testWidgets(
      'Rule 2 matching ${spec.drawerLabel} detail exposes its mounted canonical base',
      (tester) async {
        final key = GlobalKey<_PrimaryViewportPageState>();
        final router = _contractRouter(
          initialLocation: spec.root,
          primaryBuilders: <String, WidgetBuilder>{
            spec.root: (context) => _PrimaryViewportPage(
              key: key,
              label: '${spec.drawerLabel} base',
            ),
          },
        );
        await _pumpShell(tester, router);
        key.currentState!.jumpTo(560);
        await tester.pump();
        final state = key.currentState;
        final element = tester.element(
          find.byKey(ValueKey<String>('primary-${spec.drawerLabel} base')),
        );
        final offset = state!.offset;

        unawaited(router.push<void>(spec.detail));
        await tester.pumpAndSettle();
        expect(_visibleRouterPath(router), spec.detail);
        expect(key.currentState, same(state));

        await _selectDrawerRow(tester, spec.drawerLabel);
        expect(_visibleRouterPath(router), spec.root);
        expect(key.currentState, same(state));
        expect(
          tester.element(
            find.byKey(ValueKey<String>('primary-${spec.drawerLabel} base')),
          ),
          same(element),
        );
        expect(key.currentState!.offset, offset);
        // No imperative overlay remains above the matching canonical base.
        expect(router.canPop(), isFalse);
        // System/app-stack back cannot return the removed detail. This widget
        // call does not simulate browser Back or Forward history traversal.
        expect(await router.routerDelegate.popRoute(), isFalse);
        expect(_visibleRouterPath(router), spec.root);
        // An explicit matching-primary drawer selection is still durable.
        expect(_durablePrimaryRoute(), spec.root);
        expect(
          NavigationTrace.instance.entries.join('\n'),
          isNot(contains('drawer navigation route requested')),
        );
      },
    );
  }

  testWidgets(
    'Rule 2 deep-linked Library detail without a base uses primary replacement',
    (tester) async {
      final router = _contractRouter(initialLocation: '/nodes/maat');
      await _pumpShell(tester, router);

      await _selectDrawerRow(tester, 'Library');
      expect(_visibleRouterPath(router), '/nodes');
      expect(router.canPop(), isFalse);
      expect(_durablePrimaryRoute(), '/nodes');
      _expectCentralizedPrimaryReplacementRequest(
        target: 'Library',
        route: '/nodes',
      );
    },
  );

  testWidgets('Rule 2 Journal detail over Calendar rejects the foreign base', (
    tester,
  ) async {
    var calendarDisposals = 0;
    final calendarKey = GlobalKey<_PrimaryViewportPageState>();
    final router = _contractRouter(
      initialLocation: '/',
      primaryBuilders: <String, WidgetBuilder>{
        '/': (context) => _PrimaryViewportPage(
          key: calendarKey,
          label: 'Calendar foreign base',
          onDisposed: () => calendarDisposals += 1,
        ),
      },
    );
    await _pumpShell(tester, router);
    final calendarState = calendarKey.currentState;
    unawaited(router.push<void>('/journal/entry/entry-1'));
    await tester.pumpAndSettle();
    expect(calendarKey.currentState, same(calendarState));

    await _selectDrawerRow(tester, 'Journal');
    expect(_visibleRouterPath(router), '/journal');
    expect(router.canPop(), isFalse);
    expect(calendarKey.currentState, isNull);
    expect(calendarDisposals, 1);
    expect(_durablePrimaryRoute(), '/journal');
    _expectCentralizedPrimaryReplacementRequest(
      target: 'Journal',
      route: '/journal',
    );
  });

  testWidgets('Rule 2 Inbox detail over Library rejects the foreign base', (
    tester,
  ) async {
    var libraryDisposals = 0;
    final libraryKey = GlobalKey<_PrimaryViewportPageState>();
    final router = _contractRouter(
      initialLocation: '/nodes',
      primaryBuilders: <String, WidgetBuilder>{
        '/nodes': (context) => _PrimaryViewportPage(
          key: libraryKey,
          label: 'Library foreign base',
          onDisposed: () => libraryDisposals += 1,
        ),
      },
    );
    await _pumpShell(tester, router);
    final libraryState = libraryKey.currentState;
    unawaited(router.push<void>('/inbox/conversation/thread-1'));
    await tester.pumpAndSettle();
    expect(libraryKey.currentState, same(libraryState));

    await _selectDrawerRow(tester, 'Inbox');
    expect(_visibleRouterPath(router), '/inbox');
    expect(router.canPop(), isFalse);
    expect(libraryKey.currentState, isNull);
    expect(libraryDisposals, 1);
    expect(_durablePrimaryRoute(), '/inbox');
    _expectCentralizedPrimaryReplacementRequest(
      target: 'Inbox',
      route: '/inbox',
    );
  });

  testWidgets(
    'Rule 2 multi-detail app stack is fully removed above the mounted base',
    (tester) async {
      final key = GlobalKey<_PrimaryViewportPageState>();
      final router = _contractRouter(
        initialLocation: '/nodes',
        primaryBuilders: <String, WidgetBuilder>{
          '/nodes': (context) =>
              _PrimaryViewportPage(key: key, label: 'Library stacked base'),
        },
      );
      await _pumpShell(tester, router);
      key.currentState!.jumpTo(640);
      await tester.pump();
      final state = key.currentState;
      final element = tester.element(
        find.byKey(const ValueKey<String>('primary-Library stacked base')),
      );
      final offset = state!.offset;

      unawaited(router.push<void>('/nodes/maat'));
      await tester.pumpAndSettle();
      unawaited(router.push<void>('/nodes/maat/notes/note-1'));
      await tester.pumpAndSettle();
      expect(_visibleRouterPath(router), '/nodes/maat/notes/note-1');
      expect(router.canPop(), isTrue);

      await _selectDrawerRow(tester, 'Library');
      expect(_visibleRouterPath(router), '/nodes');
      expect(key.currentState, same(state));
      expect(
        tester.element(
          find.byKey(const ValueKey<String>('primary-Library stacked base')),
        ),
        same(element),
      );
      expect(key.currentState!.offset, offset);
      // Both app-stack detail overlays are gone; another system/app-stack pop
      // cannot return either. This widget call does not simulate browser
      // history traversal.
      expect(router.canPop(), isFalse);
      expect(await router.routerDelegate.popRoute(), isFalse);
      expect(_visibleRouterPath(router), '/nodes');
      expect(_durablePrimaryRoute(), '/nodes');
    },
  );

  testWidgets(
    'Rule 2 durable surface restoration partial in-process proof rejects the discarded detail',
    (tester) async {
      final router = _contractRouter(initialLocation: '/nodes');
      await _pumpShell(tester, router);
      unawaited(router.push<void>('/nodes/maat'));
      await tester.pumpAndSettle();
      expect(_visibleRouterPath(router), '/nodes/maat');

      await _selectDrawerRow(tester, 'Library');
      expect(_visibleRouterPath(router), '/nodes');

      final serialized = _criticalSnapshots['window-contract'];
      expect(serialized, isNotNull);
      final durable = jsonDecode(serialized!) as Map<String, dynamic>;
      expect(durable['routeLocation'], '/nodes');
      final primary =
          durable[navigationPrimarySelectionMetadataKey]
              as Map<String, dynamic>?;
      expect(primary?['canonicalRoute'], '/nodes');

      AppNavigationRestorationController.instance.resetForTesting();
      final restored = await AppNavigationRestorationController.instance
          .restoreLaunchDestination(isAuthenticated: true);
      expect(restored.route, '/nodes');
      expect(restored.route, isNot('/nodes/maat'));
    },
  );

  const utilityCases = <_UtilityCase>[
    _UtilityCase(drawerLabel: 'Flows', target: '/flows'),
    _UtilityCase(drawerLabel: 'Calendars', target: '/calendars'),
    _UtilityCase(drawerLabel: 'Profile', target: '/profile/me'),
  ];

  for (final spec in utilityCases) {
    testWidgets(
      'Rule 5 classification-only: ${spec.drawerLabel} is a history-preserving utility push',
      (tester) async {
        // Classification-only coverage: this begins on a primary base and
        // verifies the drawer row is a history-preserving push, not a Rule 2
        // primary replacement. It deliberately does not open a utility child
        // or claim that utility-child canonicalization is implemented.
        final key = GlobalKey<_PrimaryViewportPageState>();
        final router = _contractRouter(
          initialLocation: '/nodes',
          primaryBuilders: <String, WidgetBuilder>{
            '/nodes': (context) =>
                _PrimaryViewportPage(key: key, label: 'Library utility base'),
          },
        );
        await _pumpShell(tester, router);
        key.currentState!.jumpTo(400);
        await tester.pump();
        final state = key.currentState;
        final offset = state!.offset;

        await _selectDrawerRow(tester, spec.drawerLabel);
        expect(_visibleRouterPath(router), spec.target);
        expect(router.canPop(), isTrue);
        expect(key.currentState, same(state));
        expect(key.currentState!.offset, offset);
        expect(_durablePrimaryRoute(), isNull);

        router.pop();
        await tester.pumpAndSettle();
        expect(_visibleRouterPath(router), '/nodes');
        expect(key.currentState, same(state));
        expect(key.currentState!.offset, offset);
      },
    );
  }
}

class _PrimaryCase {
  const _PrimaryCase({
    required this.drawerLabel,
    required this.root,
    required this.detail,
  });

  final String drawerLabel;
  final String root;
  final String detail;
}

class _UtilityCase {
  const _UtilityCase({required this.drawerLabel, required this.target});

  final String drawerLabel;
  final String target;
}

GoRouter _contractRouter({
  required String initialLocation,
  Map<String, WidgetBuilder> primaryBuilders = const <String, WidgetBuilder>{},
}) {
  Widget primary(BuildContext context, String route, String label) =>
      primaryBuilders[route]?.call(context) ?? _SimplePage(label);

  return GoRouter(
    initialLocation: initialLocation,
    observers: <NavigatorObserver>[
      app.globalFloatingMenuRouteObserverForTesting,
    ],
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => primary(context, '/', 'Calendar base'),
      ),
      GoRoute(
        path: '/rhythm/today',
        builder: (context, state) =>
            primary(context, '/rhythm/today', 'Planner base'),
      ),
      GoRoute(
        path: '/rhythm/decan/:dayKey',
        builder: (context, state) => const _SimplePage('Planner detail'),
      ),
      GoRoute(
        path: '/nodes',
        builder: (context, state) => primary(context, '/nodes', 'Library base'),
      ),
      GoRoute(
        path: '/nodes/:nodeId',
        builder: (context, state) => const _SimplePage('Library detail'),
      ),
      GoRoute(
        path: '/nodes/:nodeId/notes/:noteId',
        builder: (context, state) => const _SimplePage('Library nested detail'),
      ),
      GoRoute(
        path: '/journal',
        builder: (context, state) =>
            primary(context, '/journal', 'Journal base'),
      ),
      GoRoute(
        path: '/journal/entry/:entryId',
        builder: (context, state) => const _SimplePage('Journal detail'),
      ),
      GoRoute(
        path: '/inbox',
        builder: (context, state) => primary(context, '/inbox', 'Inbox base'),
      ),
      GoRoute(
        path: '/inbox/conversation/:conversationId',
        builder: (context, state) => const _SimplePage('Inbox detail'),
      ),
      GoRoute(
        path: '/reflections',
        builder: (context, state) =>
            primary(context, '/reflections', 'Reflections base'),
      ),
      GoRoute(
        path: '/reflections/:reflectionId',
        builder: (context, state) => const _SimplePage('Reflection detail'),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            primary(context, '/settings', 'Settings base'),
      ),
      GoRoute(
        path: '/flows',
        builder: (context, state) => const _SimplePage('Flows utility'),
      ),
      GoRoute(
        path: '/calendars',
        builder: (context, state) => const _SimplePage('Calendars utility'),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) => const _SimplePage('Profile utility'),
      ),
    ],
  );
}

Future<void> _pumpShell(WidgetTester tester, GoRouter router) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
  });
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => app.buildGlobalFloatingMenuShellForTesting(
        router: router,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(app.globalMenuButtonKey));
  await tester.pump();
  await tester.pump();
  await tester.pump(globalSideDrawerTransitionDuration);
}

Future<void> _selectDrawerRow(WidgetTester tester, String label) async {
  await _openDrawer(tester);
  await tester.tap(
    find.byKey(ValueKey<String>('global-side-drawer-item-$label')),
  );
  await tester.pump();
  await tester.pump(globalSideDrawerTransitionDuration);
  await tester.pumpAndSettle();
}

String _visibleRouterPath(GoRouter router) {
  final configuration = router.routerDelegate.currentConfiguration;
  final topMatch = configuration.lastOrNull;
  if (topMatch is ImperativeRouteMatch) return topMatch.matches.uri.path;
  return configuration.uri.path;
}

String? _durablePrimaryRoute() {
  final serialized = _criticalSnapshots['window-contract'];
  if (serialized == null) return null;
  final decoded = jsonDecode(serialized) as Map<String, dynamic>;
  return decoded['routeLocation'] as String?;
}

void _expectCentralizedPrimaryReplacementRequest({
  required String target,
  required String route,
}) {
  final trace = NavigationTrace.instance.entries.join('\n');
  expect(trace, contains('drawer navigation route requested'));
  expect(trace, contains('target=$target'));
  expect(trace, contains('route=$route'));
}

class _SimplePage extends StatelessWidget {
  const _SimplePage(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

class _PrimaryViewportPage extends StatefulWidget {
  const _PrimaryViewportPage({super.key, required this.label, this.onDisposed});

  final String label;
  final VoidCallback? onDisposed;

  @override
  State<_PrimaryViewportPage> createState() => _PrimaryViewportPageState();
}

class _PrimaryViewportPageState extends State<_PrimaryViewportPage> {
  late final ScrollController _controller = ScrollController();

  double get offset => _controller.offset;

  void jumpTo(double value) => _controller.jumpTo(value);

  @override
  void dispose() {
    widget.onDisposed?.call();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: ValueKey<String>('primary-${widget.label}'),
    body: ListView.builder(
      controller: _controller,
      itemExtent: 80,
      itemCount: 40,
      itemBuilder: (context, index) => Text('${widget.label} row $index'),
    ),
  );
}
