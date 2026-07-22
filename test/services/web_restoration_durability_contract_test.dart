import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/navigation_fallback.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/services/app_navigation_restoration_controller.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/services/restoration_coordinator.dart';
import 'package:mobile/services/restoration_durable_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _user = 'durability-user';
const String _window = 'durability-window';
const String _snapshotKey = 'app_restoration_v1:$_user:$_window';
const String _latestSnapshotKey = 'app_restoration_latest_v2:$_user';

Map<String, dynamic> _snapshot({
  required int generation,
  required String route,
  required int kYear,
  required int kMonth,
  required int kDay,
  String userId = _user,
  String windowId = _window,
}) {
  final classification = const NavigationPersistencePolicy().classifyRoute(
    route,
    NavigationSource.userPrimaryTab,
  );
  return <String, dynamic>{
    'schemaVersion': AppRestorationService.schemaVersion,
    'userId': userId,
    'windowId': windowId,
    'updatedAtMs': generation,
    'routeLocation': route,
    navigationLaunchRouteMetadataKey: classification.metadata.toJson(),
    navigationPrimarySelectionMetadataKey: classification.metadata.toJson(),
    'calendar': CalendarRestorationState(
      kYear: kYear,
      kMonth: kMonth,
      kDay: kDay,
      showGregorian: true,
      expansion: 'details',
      anchorTarget: 'monthHeader',
      anchorAlignment: 0.34,
      viewportHeight: 844,
      layoutRevision: 4,
      scrollOffset: 18200,
    ).toJson(),
  };
}

DurableRestorationEnvelope _envelope(Map<String, dynamic> snapshot) =>
    DurableRestorationEnvelope.create(
      snapshotSchemaVersion: AppRestorationService.schemaVersion,
      userId: snapshot['userId'] as String,
      windowId: snapshot['windowId'] as String,
      generation: snapshot['updatedAtMs'] as int,
      snapshotJson: jsonEncode(snapshot),
    );

class _ControlledDurableStore implements RestorationDurableStore {
  final Map<String, String> windows = <String, String>{};
  final Map<String, String> latest = <String, String>{};
  final List<DurableRestorationEnvelope> committed =
      <DurableRestorationEnvelope>[];
  String? lastActiveUser;
  bool denyWrites = false;
  Completer<void>? _writeGate;
  Completer<void>? _writeStarted;

  String _windowKey(String userId, String windowId) => '$userId:$windowId';

  void blockWrites() {
    _writeGate = Completer<void>();
    _writeStarted = Completer<void>();
  }

  Future<void> get writeStarted {
    final started = _writeStarted;
    return started == null ? Future<void>.value() : started.future;
  }

  bool get hasWriteStarted => _writeStarted?.isCompleted ?? false;

  void releaseWrites() {
    final gate = _writeGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  void seed(DurableRestorationEnvelope envelope) {
    final encoded = envelope.encode();
    windows[_windowKey(envelope.userId, envelope.windowId)] = encoded;
    latest[envelope.userId] = encoded;
    lastActiveUser = envelope.userId;
  }

  @override
  bool get isSupported => true;

  @override
  Future<String?> readWindowEnvelope(String userId, String windowId) async =>
      windows[_windowKey(userId, windowId)];

  @override
  Future<String?> readLatestEnvelope(String userId) async => latest[userId];

  @override
  Future<String?> readLastActiveUserId() async => lastActiveUser;

  @override
  Future<DurableSnapshotWriteStatus> writeEnvelope(
    DurableRestorationEnvelope envelope,
  ) async {
    final started = _writeStarted;
    if (started != null && !started.isCompleted) started.complete();
    final gate = _writeGate;
    if (gate != null) await gate.future;
    if (denyWrites) {
      throw const DurableSnapshotStoreException('QuotaExceededError');
    }
    final existing = DurableRestorationEnvelope.tryDecode(
      latest[envelope.userId],
      expectedUserId: envelope.userId,
    );
    if (existing != null && existing.generation >= envelope.generation) {
      return DurableSnapshotWriteStatus.superseded;
    }
    seed(envelope);
    committed.add(envelope);
    return DurableSnapshotWriteStatus.committed;
  }

  @override
  Future<void> clearWindow(String userId, String windowId) async {
    windows.remove(_windowKey(userId, windowId));
  }

  @override
  Future<void> clearLastActiveUser() async {
    lastActiveUser = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ControlledDurableStore durableStore;
  late Map<String, String> criticalSnapshots;
  late Map<String, String> latestCriticalSnapshots;
  var activeUser = _user;

  setUp(() {
    AppRestorationService.instance.resetForTesting();
    AppNavigationRestorationController.instance.resetForTesting();
    AppWindowService.instance.resetForTesting();
    RestorationCoordinator.instance.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    durableStore = _ControlledDurableStore();
    criticalSnapshots = <String, String>{};
    latestCriticalSnapshots = <String, String>{};
    activeUser = _user;
    AppRestorationService.debugUserIdResolver = () => activeUser;
    AppWindowService.debugWindowIdResolver = () async => _window;
    AppRestorationService.debugDurableSnapshotStore = durableStore;
    AppRestorationService.debugCriticalSnapshotReader = (windowId) =>
        criticalSnapshots[windowId];
    AppRestorationService.debugCriticalSnapshotWriter = (windowId, serialized) {
      if (serialized == null) {
        criticalSnapshots.remove(windowId);
      } else {
        criticalSnapshots[windowId] = serialized;
      }
    };
    AppRestorationService.debugLatestCriticalSnapshotReader = (userId) =>
        latestCriticalSnapshots[userId];
    AppRestorationService.debugLatestCriticalSnapshotWriter =
        (userId, serialized) {
          if (serialized == null) {
            latestCriticalSnapshots.remove(userId);
          } else {
            latestCriticalSnapshots[userId] = serialized;
          }
        };
    AppRestorationService.debugPlatformLastActiveUserIdReader = () => _user;
    AppRestorationService.debugPlatformLastActiveUserIdWriter = (_) {};
    AppRestorationService.debugRemoteSnapshotWriter =
        (userId, deviceId, windowId, snapshot) async {};
  });

  tearDown(() {
    durableStore.releaseWrites();
    AppRestorationService.instance.resetForTesting();
    AppNavigationRestorationController.instance.resetForTesting();
    AppWindowService.instance.resetForTesting();
    RestorationCoordinator.instance.resetForTesting();
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

  test(
    'WEB-RESTORE-DURABILITY-001 live storage visibility is not a durable acknowledgement',
    () async {
      durableStore.blockWrites();
      var completed = false;
      final pending = AppRestorationService.instance
          .saveCalendarState(
            const CalendarRestorationState(
              kYear: 6269,
              kMonth: 5,
              kDay: 3,
              showGregorian: true,
              expansion: 'details',
              anchorTarget: 'monthHeader',
              anchorAlignment: 0.34,
              viewportHeight: 844,
              layoutRevision: 4,
              scrollOffset: 18200,
            ),
          )
          .whenComplete(() => completed = true);

      await durableStore.writeStarted.timeout(const Duration(seconds: 1));
      expect(completed, isFalse);
      durableStore.releaseWrites();
      expect((await pending).status, AppRestorationMutationStatus.persisted);
    },
  );

  test(
    'WEB-RESTORE-DURABILITY-001 Planner stays hidden until route and Calendar share an acknowledgement',
    () async {
      final initial = _snapshot(
        generation: DateTime.now().millisecondsSinceEpoch - 100,
        route: '/',
        kYear: 6269,
        kMonth: 5,
        kDay: 3,
      );
      durableStore.seed(_envelope(initial));
      criticalSnapshots[_window] = jsonEncode(initial);
      latestCriticalSnapshots[_user] = jsonEncode(initial);
      await AppWindowService.instance.ensureInitialized();
      durableStore.blockWrites();
      var visibleRoute = '/';
      final navigation = recordPrimaryTabSelectionAndOpen(
        AppSection.planner,
        navigate: (location) => visibleRoute = location,
      );
      await durableStore.writeStarted.timeout(const Duration(seconds: 1));
      expect(visibleRoute, '/');

      durableStore.releaseWrites();
      await navigation;
      expect(visibleRoute, '/rhythm/today');
    },
  );

  test(
    'WEB-RESTORE-DURABILITY-001 acknowledged generation outranks a newer live-only legacy value',
    () async {
      final acknowledged = _snapshot(
        generation: 200,
        route: '/rhythm/today',
        kYear: 6269,
        kMonth: 5,
        kDay: 3,
      );
      durableStore.seed(_envelope(acknowledged));
      final liveOnly = _snapshot(
        generation: 300,
        route: '/',
        kYear: 6266,
        kMonth: 2,
        kDay: 11,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        _snapshotKey: jsonEncode(liveOnly),
        _latestSnapshotKey: jsonEncode(liveOnly),
      });
      criticalSnapshots[_window] = jsonEncode(liveOnly);
      latestCriticalSnapshots[_user] = jsonEncode(liveOnly);

      final read = await AppRestorationService.instance.readBestSnapshot();
      expect(read.source, 'acknowledged_window');
      expect(read.snapshot?.routeLocation, '/rhythm/today');
      expect(read.snapshot?.calendar?.kMonth, 5);
      expect(read.snapshot?.calendar?.kDay, 3);
    },
  );

  test(
    'WEB-RESTORE-DURABILITY-001 Planner acknowledgement includes the latest mounted Calendar anchor',
    () async {
      final initial = _snapshot(
        generation: 100,
        route: '/',
        kYear: 6266,
        kMonth: 2,
        kDay: 11,
      );
      durableStore.seed(_envelope(initial));
      criticalSnapshots[_window] = jsonEncode(initial);
      latestCriticalSnapshots[_user] = jsonEncode(initial);
      await AppWindowService.instance.ensureInitialized();
      final owner = Object();
      RestorationCoordinator.instance.registerCalendarDurabilityFlush(
        owner: owner,
        flush: () async {
          final result = await AppRestorationService.instance.saveCalendarState(
            const CalendarRestorationState(
              kYear: 6269,
              kMonth: 5,
              kDay: 3,
              showGregorian: true,
              expansion: 'details',
              anchorTarget: 'monthHeader',
              anchorAlignment: 0.34,
              viewportHeight: 844,
              layoutRevision: 4,
              scrollOffset: 18200,
            ),
          );
          expect(result.status, AppRestorationMutationStatus.persisted);
        },
      );

      String? openedRoute;
      await recordPrimaryTabSelectionAndOpen(
        AppSection.planner,
        navigate: (location) => openedRoute = location,
      );

      expect(openedRoute, '/rhythm/today');
      final envelope = DurableRestorationEnvelope.tryDecode(
        durableStore.latest[_user],
        expectedUserId: _user,
      );
      final snapshot =
          jsonDecode(envelope!.snapshotJson) as Map<String, dynamic>;
      expect(snapshot['routeLocation'], '/rhythm/today');
      final calendar = snapshot['calendar'] as Map<String, dynamic>;
      expect(
        <Object?>[calendar['kYear'], calendar['kMonth'], calendar['kDay']],
        <Object?>[6269, 5, 3],
      );
      expect(calendar['anchorAlignment'], 0.34);
      expect(durableStore.committed, hasLength(2));
      expect(
        durableStore.committed[1].generation,
        greaterThan(durableStore.committed[0].generation),
      );
    },
  );

  test(
    'WEB-RESTORE-DURABILITY-001 delayed older envelope cannot overwrite a newer acknowledgement',
    () async {
      final newer = _envelope(
        _snapshot(
          generation: 900,
          route: '/nodes',
          kYear: 6270,
          kMonth: 4,
          kDay: 8,
        ),
      );
      final older = _envelope(
        _snapshot(
          generation: 899,
          route: '/rhythm/today',
          kYear: 6269,
          kMonth: 5,
          kDay: 3,
        ),
      );
      expect(
        await durableStore.writeEnvelope(newer),
        DurableSnapshotWriteStatus.committed,
      );
      expect(
        await durableStore.writeEnvelope(older),
        DurableSnapshotWriteStatus.superseded,
      );
      final retained = DurableRestorationEnvelope.tryDecode(
        await durableStore.readLatestEnvelope(_user),
        expectedUserId: _user,
      );
      expect(retained?.generation, 900);
      expect(jsonDecode(retained!.snapshotJson)['routeLocation'], '/nodes');
    },
  );

  test(
    'WEB-RESTORE-DURABILITY-001 principal and integrity binding reject foreign or mixed snapshots',
    () async {
      final foreign = _envelope(
        _snapshot(
          generation: 400,
          route: '/rhythm/today',
          kYear: 6269,
          kMonth: 5,
          kDay: 3,
          userId: 'user-A',
        ),
      );
      durableStore.latest['user-B'] = foreign.encode();
      activeUser = 'user-B';

      final read = await AppRestorationService.instance.readBestSnapshot();
      expect(read.snapshot, isNull);

      final tampered = jsonDecode(foreign.encode()) as Map<String, dynamic>;
      final mixedSnapshot =
          jsonDecode(tampered['snapshotJson'] as String)
              as Map<String, dynamic>;
      mixedSnapshot['routeLocation'] = '/nodes';
      tampered['snapshotJson'] = jsonEncode(mixedSnapshot);
      expect(
        DurableRestorationEnvelope.tryDecode(jsonEncode(tampered)),
        isNull,
      );
    },
  );

  test(
    'WEB-RESTORE-DURABILITY-001 fresh-process authority returns one internally consistent snapshot',
    () async {
      final acknowledged = _snapshot(
        generation: 501,
        route: '/rhythm/today',
        kYear: 6269,
        kMonth: 5,
        kDay: 3,
      );
      durableStore.seed(_envelope(acknowledged));
      final older = _snapshot(
        generation: 500,
        route: '/',
        kYear: 6266,
        kMonth: 2,
        kDay: 11,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        _snapshotKey: jsonEncode(older),
        _latestSnapshotKey: jsonEncode(older),
      });

      final read = await AppRestorationService.instance.readBestSnapshot();
      expect(
        <Object?>[
          read.snapshot?.routeLocation,
          read.snapshot?.calendar?.kYear,
          read.snapshot?.calendar?.kMonth,
          read.snapshot?.calendar?.kDay,
        ],
        <Object?>['/rhythm/today', 6269, 5, 3],
      );
    },
  );

  test(
    'WEB-RESTORE-DURABILITY-001 denied storage reports failure rather than durable success',
    () async {
      durableStore.denyWrites = true;
      final logs = <String>[];
      AppRestorationService.debugLogWriter = logs.add;
      final result = await AppRestorationService.instance.saveCacheHints(
        const <String, dynamic>{'storage': 'denied'},
      );

      expect(result.status, AppRestorationMutationStatus.storageFailure);
      expect(
        logs.where((entry) => entry.contains('write local done')),
        isEmpty,
      );
    },
  );

  test(
    'WEB-RESTORE-DURABILITY-001 denied Planner write cannot be promoted by a later Calendar save',
    () async {
      final initial = _snapshot(
        generation: 700,
        route: '/',
        kYear: 6269,
        kMonth: 5,
        kDay: 3,
      );
      durableStore.seed(_envelope(initial));
      criticalSnapshots[_window] = jsonEncode(initial);
      latestCriticalSnapshots[_user] = jsonEncode(initial);
      await AppWindowService.instance.ensureInitialized();
      durableStore.denyWrites = true;
      var visibleRoute = '/';

      await recordPrimaryTabSelectionAndOpen(
        AppSection.planner,
        navigate: (location) => visibleRoute = location,
      );
      expect(visibleRoute, '/');

      durableStore.denyWrites = false;
      final saved = await AppRestorationService.instance.saveCalendarState(
        const CalendarRestorationState(
          kYear: 6270,
          kMonth: 1,
          kDay: 1,
          showGregorian: true,
          expansion: 'details',
          anchorTarget: 'monthHeader',
          anchorAlignment: 0.4,
          viewportHeight: 844,
          layoutRevision: 4,
          scrollOffset: 19000,
        ),
      );
      expect(saved.status, AppRestorationMutationStatus.persisted);
      final retained = DurableRestorationEnvelope.tryDecode(
        durableStore.latest[_user],
        expectedUserId: _user,
      );
      final snapshot =
          jsonDecode(retained!.snapshotJson) as Map<String, dynamic>;
      expect(snapshot['routeLocation'], '/');
      final calendar = snapshot['calendar'] as Map<String, dynamic>;
      expect(
        <Object?>[calendar['kYear'], calendar['kMonth'], calendar['kDay']],
        <Object?>[6270, 1, 1],
      );
    },
  );
}
