import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/navigation_fallback.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/services/app_navigation_restoration_controller.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Map<String, String> _criticalSnapshots = <String, String>{};
final Map<String, String> _latestCriticalSnapshots = <String, String>{};
String? _activeUserId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _criticalSnapshots.clear();
    _latestCriticalSnapshots.clear();
    _activeUserId = 'utility-user-a';
    AppRestorationService.instance.resetForTesting();
    AppNavigationRestorationController.instance.resetForTesting();
    AppWindowService.instance.resetForTesting();
    AppRestorationService.debugUserIdResolver = () => _activeUserId;
    AppWindowService.debugWindowIdResolver = () async => 'utility-window';
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
        (userId, deviceId, windowId, snapshot) async {};
    await AppWindowService.instance.ensureInitialized();
  });

  tearDown(() {
    AppRestorationService.instance.resetForTesting();
    AppNavigationRestorationController.instance.resetForTesting();
    AppWindowService.instance.resetForTesting();
    AppRestorationService.debugUserIdResolver = null;
    AppRestorationService.debugCriticalSnapshotReader = null;
    AppRestorationService.debugCriticalSnapshotWriter = null;
    AppRestorationService.debugLatestCriticalSnapshotReader = null;
    AppRestorationService.debugLatestCriticalSnapshotWriter = null;
    AppRestorationService.debugRemoteWindowSnapshotReader = null;
    AppRestorationService.debugRemoteLatestSnapshotReader = null;
    AppRestorationService.debugRemoteSnapshotWriter = null;
    AppWindowService.debugWindowIdResolver = null;
    _criticalSnapshots.clear();
    _latestCriticalSnapshots.clear();
    _activeUserId = null;
  });

  const cases = <({String utility, AppSection primary, String primaryRoute})>[
    (utility: '/flows', primary: AppSection.library, primaryRoute: '/nodes'),
    (utility: '/calendars', primary: AppSection.inbox, primaryRoute: '/inbox'),
  ];

  for (final spec in cases) {
    testWidgets(
      'Rule 6 direct ${spec.utility} close returns to the identity-matching durable primary',
      (tester) async {
        _seedSnapshot(
          userId: 'utility-user-a',
          primary: spec.primary,
          utility: spec.utility,
        );
        final router = _router(initialLocation: spec.utility);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();

        expect(router.canPop(), isFalse);
        expect(_visiblePath(router), spec.utility);

        await tester.tap(find.byKey(const Key('close-utility')));
        await _pumpUntilPathAndStoredRoute(
          tester,
          router,
          expected: spec.primaryRoute,
          userId: 'utility-user-a',
        );

        expect(_visiblePath(router), spec.primaryRoute);
        final snapshot = _latestSnapshot('utility-user-a');
        expect(snapshot?['routeLocation'], spec.primaryRoute);
        final primaryMetadata =
            snapshot?[navigationPrimarySelectionMetadataKey]
                as Map<String, dynamic>?;
        expect(primaryMetadata?['canonicalRoute'], spec.primaryRoute);
      },
    );
  }

  testWidgets(
    'Rule 6 rejects a foreign primary and uses Calendar only as the final fallback',
    (tester) async {
      _seedSnapshot(
        userId: 'utility-user-a',
        primary: AppSection.library,
        utility: '/flows',
      );
      expect(_latestCriticalSnapshots, contains('utility-user-a'));

      _activeUserId = 'utility-user-b';
      final router = _router(initialLocation: '/flows');
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      expect(router.canPop(), isFalse);
      await tester.tap(find.byKey(const Key('close-utility')));
      await _pumpUntilPath(tester, router, '/');

      expect(_visiblePath(router), '/');
      expect(_latestCriticalSnapshots, contains('utility-user-a'));
    },
  );
}

void _seedSnapshot({
  required String userId,
  required AppSection primary,
  required String utility,
}) {
  const policy = NavigationPersistencePolicy();
  final primaryRoute = policy.routeForSection(primary);
  final primaryMetadata = policy
      .classifyRoute(primaryRoute, NavigationSource.userPrimaryTab)
      .metadata;
  final utilityMetadata = policy
      .classifyRoute(utility, NavigationSource.userExplicitOpen)
      .metadata;
  final serialized = jsonEncode(<String, Object?>{
    'schemaVersion': AppRestorationService.schemaVersion,
    'userId': userId,
    'windowId': 'utility-window',
    'updatedAtMs': 1000,
    'routeLocation': utility,
    navigationLaunchRouteMetadataKey: utilityMetadata.toJson(),
    navigationPrimarySelectionMetadataKey: primaryMetadata.toJson(),
  });
  _criticalSnapshots['utility-window'] = serialized;
  _latestCriticalSnapshots[userId] = serialized;
}

GoRouter _router({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const _Page('Calendar')),
      GoRoute(
        path: '/nodes',
        builder: (context, state) => const _Page('Library'),
      ),
      GoRoute(
        path: '/inbox',
        builder: (context, state) => const _Page('Inbox'),
      ),
      GoRoute(
        path: '/flows',
        builder: (context, state) => _UtilityPage(label: state.uri.path),
      ),
      GoRoute(
        path: '/calendars',
        builder: (context, state) => _UtilityPage(label: state.uri.path),
      ),
    ],
  );
}

String _visiblePath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

Future<void> _pumpUntilPath(
  WidgetTester tester,
  GoRouter router,
  String expected,
) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 25)),
  );
  for (var attempt = 0; attempt < 20; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 10));
    if (_visiblePath(router) == expected) return;
  }
}

Future<void> _pumpUntilPathAndStoredRoute(
  WidgetTester tester,
  GoRouter router, {
  required String expected,
  required String userId,
}) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 25)),
  );
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 10));
    if (_visiblePath(router) == expected &&
        _latestSnapshot(userId)?['routeLocation'] == expected) {
      return;
    }
  }
}

Map<String, dynamic>? _latestSnapshot(String userId) {
  final serialized = _latestCriticalSnapshots[userId];
  if (serialized == null) return null;
  return jsonDecode(serialized) as Map<String, dynamic>;
}

class _Page extends StatelessWidget {
  const _Page(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

class _UtilityPage extends StatelessWidget {
  const _UtilityPage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('close-utility'),
          onPressed: () => closeOrReturn(context, '/'),
          child: Text('Close $label'),
        ),
      ),
    );
  }
}
