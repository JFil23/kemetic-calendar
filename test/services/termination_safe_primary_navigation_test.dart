import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/navigation_fallback.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/services/app_navigation_restoration_controller.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test-only access to the storage boundary used by shared_preferences.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const String _snapshotKey = 'app_restoration_v1:user-1:window-1';
const String _latestSnapshotKey = 'app_restoration_latest_v2:user-1';

class _BlockingPreferencesStore extends SharedPreferencesStorePlatform {
  _BlockingPreferencesStore(this._delegate);

  final SharedPreferencesStorePlatform _delegate;
  final Completer<void> _writeStarted = Completer<void>();
  final Completer<void> _releaseWrites = Completer<void>();

  Future<void> get writeStarted => _writeStarted.future;
  bool get isReleased => _releaseWrites.isCompleted;

  void release() {
    if (!_releaseWrites.isCompleted) {
      _releaseWrites.complete();
    }
  }

  @override
  Future<bool> clear() => _delegate.clear();

  @override
  Future<Map<String, Object>> getAll() => _delegate.getAll();

  @override
  Future<bool> remove(String key) => _delegate.remove(key);

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!_writeStarted.isCompleted) {
      _writeStarted.complete();
    }
    await _releaseWrites.future;
    return _delegate.setValue(valueType, key, value);
  }
}

class _PrimaryRoutePage extends StatelessWidget {
  const _PrimaryRoutePage(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('$label visible'),
          TextButton(
            key: const ValueKey<String>('select-planner'),
            onPressed: () => openPrimarySection(context, AppSection.planner),
            child: const Text('Select Planner'),
          ),
          TextButton(
            key: const ValueKey<String>('select-library'),
            onPressed: () => openPrimarySection(context, AppSection.library),
            child: const Text('Select Library'),
          ),
        ],
      ),
    );
  }
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: _PrimaryRoutePage('Calendar')),
      ),
      GoRoute(
        path: '/rhythm/today',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: _PrimaryRoutePage('Planner')),
      ),
      GoRoute(
        path: '/nodes',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: _PrimaryRoutePage('Library')),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> criticalSnapshots;
  late Map<String, String> latestCriticalSnapshots;
  String? lastActiveUserId;

  setUp(() {
    AppRestorationService.instance.resetForTesting();
    AppNavigationRestorationController.instance.resetForTesting();
    AppWindowService.instance.resetForTesting();
    SharedPreferences.setMockInitialValues({});

    criticalSnapshots = <String, String>{};
    latestCriticalSnapshots = <String, String>{};
    lastActiveUserId = null;
    AppRestorationService.debugUserIdResolver = () => 'user-1';
    AppWindowService.debugWindowIdResolver = () async => 'window-1';
    AppRestorationService.debugCriticalSnapshotReader = (windowId) =>
        criticalSnapshots[windowId];
    AppRestorationService.debugCriticalSnapshotWriter = (windowId, serialized) {
      if (serialized == null || serialized.trim().isEmpty) {
        criticalSnapshots.remove(windowId);
      } else {
        criticalSnapshots[windowId] = serialized;
      }
    };
    AppRestorationService.debugLatestCriticalSnapshotReader = (userId) =>
        latestCriticalSnapshots[userId];
    AppRestorationService.debugLatestCriticalSnapshotWriter =
        (userId, serialized) {
          if (serialized == null || serialized.trim().isEmpty) {
            latestCriticalSnapshots.remove(userId);
          } else {
            latestCriticalSnapshots[userId] = serialized;
          }
        };
    AppRestorationService.debugPlatformLastActiveUserIdReader = () =>
        lastActiveUserId;
    AppRestorationService.debugPlatformLastActiveUserIdWriter = (userId) =>
        lastActiveUserId = userId;
    AppRestorationService.debugRemoteSnapshotWriter =
        (userId, deviceId, windowId, snapshot) async {};
  });

  tearDown(() {
    AppRestorationService.instance.resetForTesting();
    AppNavigationRestorationController.instance.resetForTesting();
    AppWindowService.instance.resetForTesting();
    AppRestorationService.debugUserIdResolver = null;
    AppWindowService.debugWindowIdResolver = null;
    AppRestorationService.debugCriticalSnapshotReader = null;
    AppRestorationService.debugCriticalSnapshotWriter = null;
    AppRestorationService.debugLatestCriticalSnapshotReader = null;
    AppRestorationService.debugLatestCriticalSnapshotWriter = null;
    AppRestorationService.debugPlatformLastActiveUserIdReader = null;
    AppRestorationService.debugPlatformLastActiveUserIdWriter = null;
    AppRestorationService.debugRemoteSnapshotWriter = null;
  });

  Future<
    ({
      _BlockingPreferencesStore store,
      Future<void> Function() cleanup,
      bool Function() queueSettled,
    })
  >
  blockMutationQueue() async {
    final delegate = SharedPreferencesStorePlatform.instance;
    final store = _BlockingPreferencesStore(delegate);
    SharedPreferencesStorePlatform.instance = store;
    var queueSettled = false;
    unawaited(
      AppRestorationService.instance
          .saveCacheHints(const <String, dynamic>{'ticket': 'UX-RESTORE-002'})
          .whenComplete(() => queueSettled = true),
    );
    await store.writeStarted.timeout(const Duration(seconds: 2));

    return (
      store: store,
      queueSettled: () => queueSettled,
      cleanup: () async {
        store.release();
        await AppRestorationService.instance.flushPendingWrites().timeout(
          const Duration(seconds: 2),
        );
        SharedPreferencesStorePlatform.instance = delegate;
      },
    );
  }

  Future<LaunchDestination> restoreFromCriticalOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snapshotKey);
    await prefs.remove(_latestSnapshotKey);
    AppNavigationRestorationController.instance.resetForTesting();
    return AppNavigationRestorationController.instance.restoreLaunchDestination(
      isAuthenticated: true,
    );
  }

  testWidgets(
    'UX-RESTORE-001/003 Planner is critical before the shared queue settles',
    (tester) async {
      await tester.runAsync(
        () => AppNavigationRestorationController.instance
            .recordPrimaryTabSelection(AppSection.calendar),
      );
      final router = _buildRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      expect(find.text('Calendar visible'), findsOneWidget);

      final blocked = (await tester.runAsync(blockMutationQueue))!;
      addTearDown(() async {
        blocked.store.release();
        await tester.runAsync(blocked.cleanup);
      });

      await tester.tap(find.byKey(const ValueKey<String>('select-planner')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('Planner visible'), findsOneWidget);
      expect(blocked.store.isReleased, isFalse);
      expect(blocked.queueSettled(), isFalse);

      final restored = (await tester.runAsync(restoreFromCriticalOnly))!;
      expect(restored.route, '/rhythm/today');
      expect(blocked.store.isReleased, isFalse);
      expect(blocked.queueSettled(), isFalse);
    },
  );

  testWidgets(
    'UX-RESTORE-002 latest primary selection wins while persistence is blocked',
    (tester) async {
      await tester.runAsync(
        () => AppNavigationRestorationController.instance
            .recordPrimaryTabSelection(AppSection.calendar),
      );
      final router = _buildRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      final blocked = (await tester.runAsync(blockMutationQueue))!;
      addTearDown(() async {
        blocked.store.release();
        await tester.runAsync(blocked.cleanup);
      });

      await tester.tap(find.byKey(const ValueKey<String>('select-planner')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Planner visible'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('select-library')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Library visible'), findsOneWidget);
      expect(blocked.store.isReleased, isFalse);
      expect(blocked.queueSettled(), isFalse);

      final restored = (await tester.runAsync(restoreFromCriticalOnly))!;
      expect(restored.route, '/nodes');
      expect(blocked.store.isReleased, isFalse);
      expect(blocked.queueSettled(), isFalse);
    },
  );
}
