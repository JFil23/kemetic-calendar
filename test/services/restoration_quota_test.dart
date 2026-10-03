import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/root_boot.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise the pinned preferences adapter contract without altering production IO.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class StorageQuota {
  String get name => 'QuotaExceededError';
}

class QuotaPreferences extends InMemorySharedPreferencesStore {
  QuotaPreferences(super.data) : super.withData();
  bool full = true;
  Object failure = StorageQuota();
  int rejected = 0;
  int deletes = 0;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (full) {
      rejected++;
      throw failure;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    deletes++;
    return super.remove(key);
  }

  @override
  Future<bool> clear() async {
    throw StateError('Blanket deletion is forbidden');
  }
}

Map<String, dynamic> quotaSnapshot({
  String window = 'window-1',
  String user = 'user-1',
}) {
  final metadata = const NavigationPersistencePolicy()
      .classifyRoute('/nodes', NavigationSource.userPrimaryTab)
      .metadata;
  return {
    'schemaVersion': 1, 'userId': user, 'windowId': window, 'updatedAtMs': 9000,
    'routeLocation': '/nodes',
    navigationLaunchRouteMetadataKey: metadata.toJson(),
    // Old persisted fixtures have no primary-selection field; reading migrates it.
    'surfaces': {
      'profile:user-1': {'feedRevealed': true},
    },
  };
}

const quotaProtectedData = <String, Object>{
  'planner_account:v1:user-1': 'pending-authored-write',
  'journal-content': 'keep-journal',
  'unrelated-preference': 'keep-preference',
};

QuotaPreferences quotaStore(Map<String, Object> values) {
  SharedPreferences.setMockInitialValues({});
  final store = QuotaPreferences({
    for (final entry in {...quotaProtectedData, ...values}.entries)
      'flutter.${entry.key}': entry.value,
  });
  SharedPreferencesStorePlatform.instance = store;
  return store;
}

void configureQuotaRestoration() {
  AppRestorationService.debugUserIdResolver = () => 'user-1';
  AppWindowService.debugWindowIdResolver = () async => 'window-1';
  AppWindowService.instance.resetForTesting();
  AppRestorationService.debugCriticalSnapshotReader = (_) => null;
  AppRestorationService.debugLatestCriticalSnapshotReader = (_) => null;
  AppRestorationService.debugCriticalSnapshotWriter = (_, value) {};
  AppRestorationService.debugLatestCriticalSnapshotWriter = (_, value) {};
  AppRestorationService.debugPlatformLastActiveUserIdReader = () => null;
  AppRestorationService.debugPlatformLastActiveUserIdWriter = (_) {};
  AppRestorationService.debugRemoteWindowSnapshotReader =
      (_, device, window) async => null;
  AppRestorationService.debugRemoteLatestSnapshotReader = (_) async => null;
  AppRestorationService.debugRemoteSnapshotWriter =
      (_, device, window, raw) async {};
}

void resetQuotaRestoration() {
  AppRestorationService.debugUserIdResolver = null;
  AppWindowService.debugWindowIdResolver = null;
  AppWindowService.instance.resetForTesting();
  AppRestorationService.debugCriticalSnapshotReader = null;
  AppRestorationService.debugLatestCriticalSnapshotReader = null;
  AppRestorationService.debugCriticalSnapshotWriter = null;
  AppRestorationService.debugLatestCriticalSnapshotWriter = null;
  AppRestorationService.debugPlatformLastActiveUserIdReader = null;
  AppRestorationService.debugPlatformLastActiveUserIdWriter = null;
  AppRestorationService.debugRemoteWindowSnapshotReader = null;
  AppRestorationService.debugRemoteLatestSnapshotReader = null;
  AppRestorationService.debugRemoteSnapshotWriter = null;
  SharedPreferences.setMockInitialValues({});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(configureQuotaRestoration);
  tearDown(resetQuotaRestoration);

  for (final key in [
    'app_restoration_v1:user-1:window-1',
    'app_restoration_latest_v2:user-1',
  ]) {
    testWidgets('quota during migration of $key does not prevent ready boot', (
      tester,
    ) async {
      final raw = jsonEncode(quotaSnapshot());
      final store = quotaStore({key: raw});
      final original = await store.getAll();
      final service = AppRestorationService.forTesting();
      final coordinator = BootCoordinator();
      await tester.pumpWidget(RootBootApp(coordinator: coordinator));
      coordinator.start((attempt) async {
        final restored = await attempt.run(
          'saved navigation',
          () => service.readBestSnapshot(includeRemote: true),
        );
        return MaterialApp(
          home: Text('Restored ${restored.snapshot?.routeLocation}'),
        );
      });
      await tester.pumpAndSettle();
      expect(
        coordinator.phase,
        RootBootPhase.ready,
        reason: coordinator.error?.diagnostic,
      );
      expect(find.text('Restored /nodes'), findsOneWidget);
      expect(store.rejected, greaterThan(0));
      expect(await store.getAll(), original);
      expect(store.deletes, 0);
      // The production boot path reads again for its detailed restoration state.
      expect(
        (await service.readBestSnapshot(
          includeRemote: true,
        )).snapshot?.routeLocation,
        '/nodes',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      coordinator.dispose();
    });
  }

  test(
    'quota during remote adoption preserves the remote result and existing data',
    () async {
      final store = quotaStore({'app_restoration_device_id_v1': 'device-1'});
      final original = await store.getAll();
      AppRestorationService.debugRemoteLatestSnapshotReader = (_) async =>
          quotaSnapshot(window: 'remote-window');
      final service = AppRestorationService.forTesting();
      final restored = await service.readBestSnapshot(includeRemote: true);
      expect(restored.snapshot?.routeLocation, '/nodes');
      expect(
        restored.snapshot?.surfaces['profile:user-1']?['feedRevealed'],
        true,
      );
      expect(restored.snapshot?.windowId, 'window-1');
      expect(store.rejected, greaterThan(0));
      expect(await store.getAll(), original);
      expect(store.deletes, 0);
    },
  );

  test(
    'failed device identity persistence skips window lookup and retries after capacity returns',
    () async {
      final store = quotaStore({});
      final original = await store.getAll();
      final seenDeviceIds = <String>[];
      AppRestorationService.debugRemoteWindowSnapshotReader =
          (_, device, window) async {
            seenDeviceIds.add(device);
            return null;
          };
      AppRestorationService.debugRemoteLatestSnapshotReader = (_) async =>
          quotaSnapshot(window: 'remote-window');
      final service = AppRestorationService.forTesting();
      expect(
        (await service.readBestSnapshot(
          includeRemote: true,
        )).snapshot?.routeLocation,
        '/nodes',
      );
      expect(seenDeviceIds, isEmpty);
      expect(await store.getAll(), original);
      store.full = false;
      // Simulate a fresh read of durable storage after capacity returns.
      await (await SharedPreferences.getInstance()).reload();
      expect(
        (await service.readBestSnapshot(
          includeRemote: true,
        )).snapshot?.routeLocation,
        '/nodes',
      );
      final persistedId = (await store
          .getAll())['flutter.app_restoration_device_id_v1'];
      expect(persistedId, isA<String>());
      expect(seenDeviceIds, [persistedId]);
      expect(store.deletes, 0);
    },
  );

  test('non-quota read-repair failures remain visible', () async {
    final store = quotaStore({
      'app_restoration_v1:user-1:window-1': jsonEncode(quotaSnapshot()),
    });
    store.failure = StateError('unexpected implementation failure');
    await expectLater(
      AppRestorationService.forTesting().readBestSnapshot(),
      throwsStateError,
    );
    expect(store.deletes, 0);
  });

  test(
    'failed user mutation is not acknowledged and can be saved after quota recovery',
    () async {
      final store = quotaStore({
        'app_restoration_device_id_v1': 'device-1',
        'app_restoration_v1:user-1:window-1': jsonEncode(quotaSnapshot()),
      });
      final original = await store.getAll();
      var remoteWrites = 0;
      AppRestorationService.debugRemoteSnapshotWriter =
          (_, device, window, raw) async {
            remoteWrites++;
          };
      final service = AppRestorationService.forTesting();
      await expectLater(
        service.saveSurfaceState('quota-test', {'value': 'saved'}),
        throwsA(isA<StorageQuota>()),
      );
      expect(remoteWrites, 0);
      expect(await store.getAll(), original);
      store.full = false;
      await service.saveSurfaceState('quota-test', {'value': 'saved'});
      await service.flushPendingWrites();
      expect(remoteWrites, 1);
      final raw =
          jsonDecode(
                (await store
                        .getAll())['flutter.app_restoration_v1:user-1:window-1']!
                    as String,
              )
              as Map;
      expect(raw['surfaces']['quota-test']['value'], 'saved');
      for (final entry in quotaProtectedData.entries) {
        expect((await store.getAll())['flutter.${entry.key}'], entry.value);
      }
      expect(store.deletes, 0);
    },
  );

  test('quota handling never restores another account snapshot', () async {
    quotaStore({
      'app_restoration_latest_v2:user-1': jsonEncode(quotaSnapshot()),
    });
    AppRestorationService.debugUserIdResolver = () => 'user-2';
    AppRestorationService.debugRemoteLatestSnapshotReader = (_) async =>
        quotaSnapshot();
    final result = await AppRestorationService.forTesting().readBestSnapshot(
      includeRemote: true,
    );
    expect(result.activeUserId, 'user-2');
    expect(result.snapshot, isNull);
  });
}
