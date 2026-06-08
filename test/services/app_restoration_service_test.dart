import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/services/restoration_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _snapshotKey({String userId = 'user-1', String windowId = 'window-1'}) {
  return 'app_restoration_v1:$userId:$windowId';
}

Map<String, dynamic> _durableRouteFields(String route) {
  final metadata = const NavigationPersistencePolicy()
      .classifyRoute(route, NavigationSource.userPrimaryTab)
      .metadata;
  return <String, dynamic>{
    'routeLocation': route,
    navigationLaunchRouteMetadataKey: metadata.toJson(),
  };
}

Future<void> _saveDurableRoute(String route) {
  final metadata = const NavigationPersistencePolicy()
      .classifyRoute(route, NavigationSource.userPrimaryTab)
      .metadata;
  return AppRestorationService.instance.saveDurableLaunchRoute(
    route,
    metadata: metadata,
  );
}

final Map<String, String> _debugCriticalSnapshots = <String, String>{};
final Map<String, String> _debugLatestCriticalSnapshots = <String, String>{};
final Map<String, Map<String, dynamic>> _debugRemoteWindowSnapshots =
    <String, Map<String, dynamic>>{};
final Map<String, Map<String, dynamic>> _debugRemoteLatestSnapshots =
    <String, Map<String, dynamic>>{};
String? _debugPlatformLastActiveUserId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppRestorationService.debugUserIdResolver = () => 'user-1';
    AppWindowService.debugWindowIdResolver = () async => 'window-1';
    AppRestorationService.debugRemoteWindowSnapshotReader =
        (userId, deviceId, windowId) async =>
            _debugRemoteWindowSnapshots['$userId:$deviceId:$windowId'];
    AppRestorationService.debugRemoteLatestSnapshotReader = (userId) async =>
        _debugRemoteLatestSnapshots[userId];
    AppRestorationService.debugRemoteSnapshotWriter =
        (userId, deviceId, windowId, snapshot) async {
          _debugRemoteWindowSnapshots['$userId:$deviceId:$windowId'] =
              Map<String, dynamic>.from(snapshot);
          _debugRemoteLatestSnapshots[userId] = Map<String, dynamic>.from(
            snapshot,
          );
        };
    AppRestorationService.debugCriticalSnapshotReader = (windowId) =>
        _debugCriticalSnapshots[windowId];
    AppRestorationService.debugCriticalSnapshotWriter = (windowId, serialized) {
      if (serialized == null || serialized.trim().isEmpty) {
        _debugCriticalSnapshots.remove(windowId);
      } else {
        _debugCriticalSnapshots[windowId] = serialized;
      }
    };
    AppRestorationService.debugLatestCriticalSnapshotReader = (userId) =>
        _debugLatestCriticalSnapshots[userId];
    AppRestorationService.debugLatestCriticalSnapshotWriter =
        (userId, serialized) {
          if (serialized == null || serialized.trim().isEmpty) {
            _debugLatestCriticalSnapshots.remove(userId);
          } else {
            _debugLatestCriticalSnapshots[userId] = serialized;
          }
        };
    AppRestorationService.debugPlatformLastActiveUserIdReader = () =>
        _debugPlatformLastActiveUserId;
    AppRestorationService.debugPlatformLastActiveUserIdWriter = (userId) {
      final normalized = userId?.trim();
      _debugPlatformLastActiveUserId = normalized == null || normalized.isEmpty
          ? null
          : normalized;
    };
    _debugCriticalSnapshots.clear();
    _debugLatestCriticalSnapshots.clear();
    _debugRemoteWindowSnapshots.clear();
    _debugRemoteLatestSnapshots.clear();
    _debugPlatformLastActiveUserId = null;
    AppWindowService.instance.resetForTesting();
  });

  tearDown(() {
    AppRestorationService.debugUserIdResolver = null;
    AppRestorationService.debugRemoteWindowSnapshotReader = null;
    AppRestorationService.debugRemoteLatestSnapshotReader = null;
    AppRestorationService.debugRemoteSnapshotWriter = null;
    AppRestorationService.debugCriticalSnapshotReader = null;
    AppRestorationService.debugCriticalSnapshotWriter = null;
    AppRestorationService.debugLatestCriticalSnapshotReader = null;
    AppRestorationService.debugLatestCriticalSnapshotWriter = null;
    AppRestorationService.debugPlatformLastActiveUserIdReader = null;
    AppRestorationService.debugPlatformLastActiveUserIdWriter = null;
    AppWindowService.debugWindowIdResolver = null;
    _debugCriticalSnapshots.clear();
    _debugLatestCriticalSnapshots.clear();
    _debugRemoteWindowSnapshots.clear();
    _debugRemoteLatestSnapshots.clear();
    _debugPlatformLastActiveUserId = null;
    AppWindowService.instance.resetForTesting();
  });

  test('stores route, calendar, day view, and day sheet per window', () async {
    await _saveDurableRoute('/inbox');
    await AppRestorationService.instance.saveCalendarState(
      const CalendarRestorationState(
        kYear: 6267,
        kMonth: 4,
        kDay: 12,
        showGregorian: true,
        expansion: 'details',
        anchorTarget: 'monthHeader',
        anchorAlignment: 0.32,
        viewportHeight: 812.0,
        layoutRevision: 1,
        scrollOffset: 14320.5,
      ),
    );
    await AppRestorationService.instance.saveDayViewState(
      const DayViewRestorationState(
        isOpen: true,
        kYear: 6267,
        kMonth: 4,
        kDay: 12,
        showGregorian: false,
        firstVisibleMinute: 680,
        scrollOffset: 680.0,
        eventDetail: EventDetailRestorationState(
          kYear: 6267,
          kMonth: 4,
          kDay: 12,
          identityType: eventDetailIdentityClientEventId,
          identityValue: 'event-client-1',
          parentSurface: 'calendar.dayView',
        ),
      ),
    );
    await AppRestorationService.instance.saveDaySheetState({
      'kYear': 6267,
      'kMonth': 4,
      'kDay': 12,
      'title': 'Morning offering',
    });
    await AppRestorationService.instance.saveOverlayStack([
      {'kind': 'calendar.flowStudio', 'mode': 'editor', 'editFlowId': 42},
    ]);
    await AppRestorationService.instance.saveEditorState(
      'calendar.flowStudio.draft',
      {'name': 'Morning discipline', 'selectionBase': 4},
    );

    expect(
      (await AppRestorationService.instance.readSnapshot())?.routeLocation,
      '/inbox',
    );

    final calendar = await AppRestorationService.instance.readCalendarState();
    expect(calendar, isNotNull);
    expect(calendar!.showGregorian, isTrue);
    expect(calendar.anchorTarget, 'monthHeader');
    expect(calendar.anchorAlignment, 0.32);
    expect(calendar.viewportHeight, 812.0);
    expect(calendar.layoutRevision, 1);
    expect(calendar.scrollOffset, 14320.5);

    final dayView = await AppRestorationService.instance.readDayViewState();
    expect(dayView, isNotNull);
    expect(dayView!.isOpen, isTrue);
    expect(dayView.firstVisibleMinute, 680);
    expect(dayView.scrollOffset, 680.0);
    expect(dayView.eventDetail?.identityType, eventDetailIdentityClientEventId);
    expect(dayView.eventDetail?.identityValue, 'event-client-1');
    expect(dayView.eventDetail?.parentSurface, 'calendar.dayView');

    final daySheet = await AppRestorationService.instance.readDaySheetState();
    expect(daySheet, isNotNull);
    expect(daySheet!['title'], 'Morning offering');

    final overlays = await AppRestorationService.instance.readOverlayStack();
    expect(overlays, isEmpty);

    final editor = await AppRestorationService.instance.readEditorState(
      'calendar.flowStudio.draft',
    );
    expect(editor, isNotNull);
    expect(editor!['name'], 'Morning discipline');
  });

  test(
    'falls back to the latest user snapshot for a new window, then prefers that window once it has state',
    () async {
      await _saveDurableRoute('/journal');

      AppWindowService.debugWindowIdResolver = () async => 'window-2';
      AppWindowService.instance.resetForTesting();
      expect(
        (await AppRestorationService.instance.readSnapshot())?.routeLocation,
        '/journal',
      );

      await _saveDurableRoute('/inbox');
      expect(
        (await AppRestorationService.instance.readSnapshot())?.routeLocation,
        '/inbox',
      );

      AppWindowService.debugWindowIdResolver = () async => 'window-1';
      AppWindowService.instance.resetForTesting();
      expect(
        (await AppRestorationService.instance.readSnapshot())?.routeLocation,
        '/journal',
      );
    },
  );

  test(
    'keeps restorable routes and calendar position in the same snapshot',
    () async {
      const routes = <String, String>{
        '/': '/',
        '/inbox': '/inbox',
        '/nodes': '/nodes',
        '/journal': '/journal',
        '/rhythm/today': '/rhythm/today',
        '/reflections': '/reflections',
        '/settings': '/settings',
      };

      for (final entry in routes.entries) {
        await _saveDurableRoute(entry.key);
        expect(
          (await AppRestorationService.instance.readSnapshot())?.routeLocation,
          entry.value,
        );
      }

      await AppRestorationService.instance.saveCalendarState(
        const CalendarRestorationState(
          kYear: 6267,
          kMonth: 4,
          kDay: 12,
          showGregorian: true,
          expansion: 'details',
          anchorTarget: 'monthBody',
          anchorAlignment: 0.44,
          viewportHeight: 812.0,
          layoutRevision: 2,
          scrollOffset: 4200,
        ),
      );
      await AppRestorationService.instance.saveDayViewState(
        const DayViewRestorationState(
          isOpen: false,
          kYear: 6267,
          kMonth: 4,
          kDay: 12,
          showGregorian: true,
        ),
      );

      final snapshot = await AppRestorationService.instance.readSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.routeLocation, '/settings');
      expect(snapshot.calendar?.scrollOffset, 4200);
      expect(snapshot.calendar?.anchorTarget, 'monthBody');
      expect(snapshot.dayView?.isOpen, isFalse);
    },
  );

  test('restores profile at the durable surface boundary', () async {
    await _saveDurableRoute('/profile/me');

    final snapshot = await AppRestorationService.instance.readSnapshot();
    expect(snapshot?.routeLocation, '/profile/me');
    expect(snapshot?.launchRouteMetadata?.canRecordPrimarySelection, isFalse);
    expect(snapshot?.launchRouteMetadata?.canRestoreAsSurface, isTrue);
  });

  test('restores reflection detail at the durable surface boundary', () async {
    await _saveDurableRoute('/reflections/reflection-1');

    final snapshot = await AppRestorationService.instance.readSnapshot();
    expect(snapshot?.routeLocation, '/reflections/reflection-1');
    expect(snapshot?.launchRouteMetadata?.section, AppSection.reflections);
    expect(snapshot?.launchRouteMetadata?.canRecordPrimarySelection, isFalse);
  });

  test('restores utility and detail routes as durable surfaces', () async {
    for (final route in const <String>[
      '/flows',
      '/calendars',
      '/nodes/abydos',
      '/journal/entry/entry-1',
      '/inbox/conversation/friend-1',
      '/flows/42/edit',
    ]) {
      await AppRestorationService.instance.clearCurrentSnapshot();
      await _saveDurableRoute(route);

      final snapshot = await AppRestorationService.instance.readSnapshot();
      expect(snapshot?.routeLocation, route, reason: route);
      expect(
        snapshot?.launchRouteMetadata?.canRestoreAsSurface,
        isTrue,
        reason: route,
      );
      expect(
        snapshot?.launchRouteMetadata?.canRecordPrimarySelection,
        isFalse,
        reason: route,
      );
    }
  });

  test('rejects node action routes at the durable launch boundary', () async {
    await AppRestorationService.instance.saveDurableLaunchRoute(
      '/nodes/human_emergence?action=add_insight',
      metadata: const NavigationLaunchRouteMetadata(
        schemaVersion: navigationPersistenceSchemaVersion,
        source: NavigationSource.nodeActionUrl,
        routeClass: NavigationRouteClass.oneShotIntent,
      ),
    );
    await AppRestorationService.instance.flushPendingWrites();

    expect(
      (await AppRestorationService.instance.readSnapshot())?.routeLocation,
      isNull,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_snapshotKey()), isNull);
  });

  test('cleans stale one-shot route intents from existing snapshots', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _snapshotKey(),
      jsonEncode({
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'window-1',
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        'routeLocation': '/nodes/human_emergence?action=add_insight',
      }),
    );

    final snapshot = await AppRestorationService.instance.readSnapshot();

    expect(snapshot?.routeLocation, isNull);
  });

  test('clears snapshots with unsupported schema versions', () async {
    final prefs = await SharedPreferences.getInstance();
    final key = _snapshotKey();
    await prefs.setString(
      key,
      jsonEncode({
        'schemaVersion': 99,
        'userId': 'user-1',
        'windowId': 'window-1',
        'updatedAtMs': 1234,
        'routeLocation': '/inbox',
      }),
    );

    expect(await AppRestorationService.instance.readSnapshot(), isNull);
    expect(prefs.getString(key), isNull);
  });

  test(
    'drops invalid nested restoration payloads without losing route',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _snapshotKey(),
        jsonEncode({
          'schemaVersion': AppRestorationService.schemaVersion,
          'userId': 'user-1',
          'windowId': 'window-1',
          'updatedAtMs': 1234,
          ..._durableRouteFields('/inbox'),
          'calendar': {
            'kYear': 6267,
            'kMonth': 14,
            'kDay': 12,
            'showGregorian': true,
            'expansion': 'broken',
            'anchorTarget': 'offscreenStar',
            'anchorAlignment': 3.2,
            'scrollOffset': -42,
          },
          'dayView': {
            'isOpen': true,
            'kYear': 6266,
            'kMonth': 13,
            'kDay': 6,
            'showGregorian': false,
            'firstVisibleMinute': 9999,
            'scrollOffset': 120,
          },
        }),
      );

      final snapshot = await AppRestorationService.instance.readSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.routeLocation, '/inbox');
      expect(snapshot.calendar, isNull);
      expect(snapshot.dayView, isNull);
    },
  );

  test(
    'drops invalid event detail payloads without losing day view route state',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _snapshotKey(),
        jsonEncode({
          'schemaVersion': AppRestorationService.schemaVersion,
          'userId': 'user-1',
          'windowId': 'window-1',
          'updatedAtMs': 1234,
          'dayView': {
            'isOpen': true,
            'kYear': 6267,
            'kMonth': 4,
            'kDay': 12,
            'showGregorian': false,
            'firstVisibleMinute': 680,
            'eventDetail': {
              'kYear': 6267,
              'kMonth': 4,
              'kDay': 12,
              'identityType': 'titleFallback',
              'identityValue': 'too-loose',
            },
          },
        }),
      );

      final snapshot = await AppRestorationService.instance.readSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.dayView, isNotNull);
      expect(snapshot.dayView!.isOpen, isTrue);
      expect(snapshot.dayView!.firstVisibleMinute, 680);
      expect(snapshot.dayView!.eventDetail, isNull);
    },
  );

  test(
    'rejects invalid calendar writes before they reach durable storage',
    () async {
      await AppRestorationService.instance.saveCalendarState(
        const CalendarRestorationState(
          kYear: 6266,
          kMonth: 13,
          kDay: 6,
          showGregorian: false,
          expansion: 'details',
          scrollOffset: 300,
        ),
      );

      expect(await AppRestorationService.instance.readCalendarState(), isNull);
      expect(await AppRestorationService.instance.readSnapshot(), isNull);
    },
  );

  test(
    'reads tentative snapshot from the last active user before auth',
    () async {
      await _saveDurableRoute('/inbox');
      await AppRestorationService.instance.saveCalendarState(
        const CalendarRestorationState(
          kYear: 6267,
          kMonth: 4,
          kDay: 12,
          showGregorian: true,
          expansion: 'details',
          anchorTarget: 'monthBody',
          anchorAlignment: 0.32,
          scrollOffset: 14320.5,
        ),
      );

      AppRestorationService.debugUserIdResolver = () => null;

      final result = await AppRestorationService.instance.readBestSnapshot();
      expect(result.status, AppRestorationReadStatus.tentative);
      expect(result.snapshot, isNotNull);
      expect(result.snapshot!.userId, 'user-1');
      expect(result.snapshot!.routeLocation, '/inbox');
      expect(result.snapshot!.calendar?.kMonth, 4);
    },
  );

  test(
    'waits for auth when there is no authenticated or tentative snapshot',
    () async {
      AppRestorationService.debugUserIdResolver = () => null;

      final result = await AppRestorationService.instance.readBestSnapshot();
      expect(result.status, AppRestorationReadStatus.awaitingAuth);
      expect(result.snapshot, isNull);
    },
  );

  test('prefers the newest critical snapshot for the current user', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _snapshotKey(),
      jsonEncode({
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'window-1',
        'updatedAtMs': 1000,
        ..._durableRouteFields('/inbox'),
      }),
    );
    _debugCriticalSnapshots['window-1'] = jsonEncode({
      'schemaVersion': AppRestorationService.schemaVersion,
      'userId': 'user-1',
      'windowId': 'window-1',
      'updatedAtMs': 2000,
      ..._durableRouteFields('/journal'),
    });

    final result = await AppRestorationService.instance.readBestSnapshot();
    expect(result.status, AppRestorationReadStatus.restored);
    expect(result.source, 'critical');
    expect(result.snapshot?.routeLocation, '/journal');
    expect(
      (await AppRestorationService.instance.readSnapshot())?.routeLocation,
      '/journal',
    );
  });

  test('restores the latest snapshot when the window id changes', () async {
    await _saveDurableRoute('/settings');
    await AppRestorationService.instance.saveCalendarState(
      const CalendarRestorationState(
        kYear: 6267,
        kMonth: 4,
        kDay: 12,
        showGregorian: true,
        expansion: 'details',
        anchorTarget: 'monthBody',
        anchorAlignment: 0.44,
        scrollOffset: 4200,
      ),
    );

    AppWindowService.debugWindowIdResolver = () async => 'window-2';
    AppWindowService.instance.resetForTesting();

    final result = await AppRestorationService.instance.readBestSnapshot();
    expect(result.status, AppRestorationReadStatus.restored);
    expect(result.source, anyOf('latest_prefs', 'latest_critical', 'prefs'));
    expect(result.snapshot, isNotNull);
    expect(result.snapshot!.windowId, 'window-1');
    expect(result.snapshot!.routeLocation, '/settings');
    expect(result.snapshot!.calendar?.kMonth, 4);
    expect(
      (await AppRestorationService.instance.readSnapshot())?.routeLocation,
      '/settings',
    );
  });

  test(
    'reads a tentative latest snapshot when auth is not ready and the window id changes',
    () async {
      await _saveDurableRoute('/inbox');
      await AppRestorationService.instance.saveCalendarState(
        const CalendarRestorationState(
          kYear: 6267,
          kMonth: 7,
          kDay: 3,
          showGregorian: false,
          expansion: 'compact',
          anchorTarget: 'monthHeader',
          anchorAlignment: 0.2,
          scrollOffset: 1600,
        ),
      );

      AppWindowService.debugWindowIdResolver = () async => 'window-2';
      AppWindowService.instance.resetForTesting();
      AppRestorationService.debugUserIdResolver = () => null;

      final result = await AppRestorationService.instance.readBestSnapshot();
      expect(result.status, AppRestorationReadStatus.tentative);
      expect(
        result.source,
        anyOf('latest_prefs', 'latest_critical', 'prefs', 'critical'),
      );
      expect(result.snapshot?.userId, 'user-1');
      expect(result.snapshot?.windowId, 'window-1');
      expect(result.snapshot?.routeLocation, '/inbox');
    },
  );

  test(
    'restores from the latest critical snapshot when the window id changes',
    () async {
      AppRestorationService.debugUserIdResolver = () => null;
      _debugPlatformLastActiveUserId = 'user-1';
      _debugLatestCriticalSnapshots['user-1'] = jsonEncode({
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'window-1',
        'updatedAtMs': 2000,
        ..._durableRouteFields('/settings'),
        'calendar': {
          'kYear': 6267,
          'kMonth': 8,
          'kDay': 1,
          'showGregorian': true,
          'expansion': 'details',
        },
      });

      AppWindowService.debugWindowIdResolver = () async => 'window-2';
      AppWindowService.instance.resetForTesting();

      final result = await AppRestorationService.instance.readBestSnapshot();
      expect(result.status, AppRestorationReadStatus.tentative);
      expect(result.source, 'latest_critical');
      expect(result.snapshot?.windowId, 'window-1');
      expect(result.snapshot?.routeLocation, '/settings');
    },
  );

  test('does not restore another user from the critical snapshot', () async {
    _debugCriticalSnapshots['window-1'] = jsonEncode({
      'schemaVersion': AppRestorationService.schemaVersion,
      'userId': 'user-2',
      'windowId': 'window-1',
      'updatedAtMs': 2000,
      'routeLocation': '/wrong-user',
    });

    final result = await AppRestorationService.instance.readBestSnapshot();
    expect(result.status, AppRestorationReadStatus.noSnapshot);
    expect(result.snapshot, isNull);
    expect(_debugCriticalSnapshots.containsKey('window-1'), isFalse);
  });

  test('stores generic surface, overlay, editor, and cache hint state', () async {
    await AppRestorationService.instance.saveSurfaceState('profile:user-1', {
      'feedRevealed': true,
      'profileScrollOffset': 1200.5,
      'expandedFeedItem': 'flow:post-1',
    });
    await AppRestorationService.instance.saveOverlayStack([
      {'kind': 'comment_sheet', 'postId': 'post-1'},
    ]);
    await AppRestorationService.instance.saveEditorState(
      'inbox_conversation:user-2',
      {'text': 'draft', 'selectionBase': 5, 'selectionExtent': 5},
    );
    await AppRestorationService.instance.saveCacheHints({
      'profileUserId': 'user-1',
    });
    await AppRestorationService.instance.flushPendingWrites();

    expect(
      await AppRestorationService.instance.readSurfaceState('profile:user-1'),
      containsPair('expandedFeedItem', 'flow:post-1'),
    );
    expect(
      await AppRestorationService.instance.readOverlayStack(),
      contains(containsPair('kind', 'comment_sheet')),
    );
    expect(
      await AppRestorationService.instance.readEditorState(
        'inbox_conversation:user-2',
      ),
      containsPair('text', 'draft'),
    );
    expect(
      await AppRestorationService.instance.readCacheHints(),
      containsPair('profileUserId', 'user-1'),
    );
    expect(
      _debugRemoteLatestSnapshots['user-1']?['surfaces']?['profile:user-1']?['feedRevealed'],
      isTrue,
    );
  });

  test(
    'clears restored profile feed layer without dropping shell continuity',
    () async {
      await AppRestorationService.instance.saveSurfaceState('profile:user-1', {
        'kind': 'profile',
        'userId': 'user-1',
        'isMyProfile': true,
        'feedRevealed': true,
        'showGregorianFeedDates': true,
        'activePostIndex': 2,
        'activeInsightPostIndex': 1,
        'profileScrollOffset': 320.0,
        'feedScrollOffset': 48.0,
        'expandedFeedItem': 'flow:lego-submarine',
      });

      await RestorationCoordinator.instance.clearProfileFeedContinuity(
        'user-1',
      );

      final state = await AppRestorationService.instance.readSurfaceState(
        'profile:user-1',
      );
      expect(state, isNotNull);
      expect(state, containsPair('feedRevealed', false));
      expect(state, isNot(containsPair('expandedFeedItem', anything)));
      expect(state, isNot(containsPair('feedScrollOffset', anything)));
      expect(state, containsPair('profileScrollOffset', 320.0));
      expect(state, containsPair('activePostIndex', 2));
      expect(state, containsPair('showGregorianFeedDates', true));
    },
  );

  test(
    'adopts a backend latest snapshot when local state is missing',
    () async {
      _debugRemoteLatestSnapshots['user-1'] = {
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'remote-window',
        'updatedAtMs': 9000,
        ..._durableRouteFields('/nodes'),
        'surfaces': {
          'profile:user-1': {'feedRevealed': true, 'feedScrollOffset': 42},
        },
      };

      final result = await AppRestorationService.instance.readBestSnapshot(
        includeRemote: true,
      );
      expect(result.snapshot?.routeLocation, '/nodes');

      final snapshot = await AppRestorationService.instance.readSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.windowId, 'window-1');
      expect(snapshot.surfaces['profile:user-1']?['feedRevealed'], isTrue);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_snapshotKey());
      expect(raw, isNotNull);
      expect(jsonDecode(raw!)['windowId'], 'window-1');
    },
  );

  test(
    'does not prefer a route-only backend latest snapshot over current root',
    () async {
      final staleLocal = {
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'window-1',
        'updatedAtMs': 1000,
        ..._durableRouteFields('/'),
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey(), jsonEncode(staleLocal));
      _debugCriticalSnapshots['window-1'] = jsonEncode(staleLocal);
      _debugRemoteLatestSnapshots['user-1'] = {
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'remote-window',
        'updatedAtMs': 9000,
        'routeLocation': '/profile/user-1',
      };

      final result = await AppRestorationService.instance.readBestSnapshot(
        includeRemote: true,
      );
      expect(result.status, AppRestorationReadStatus.restored);
      expect(result.source, isNot('remote_latest'));
      expect(result.snapshot?.routeLocation, '/');

      final raw = prefs.getString(_snapshotKey());
      expect(raw, isNotNull);
      final adopted = jsonDecode(raw!) as Map<String, dynamic>;
      expect(adopted['windowId'], 'window-1');
      expect(adopted['routeLocation'], '/');
    },
  );

  test(
    'newer local inbox route-only snapshot beats stale current root',
    () async {
      final currentRoot = {
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'window-1',
        'updatedAtMs': 1000,
        ..._durableRouteFields('/'),
      };
      final latestInbox = {
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'window-2',
        'updatedAtMs': 2000,
        'routeLocation': '/inbox',
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey(), jsonEncode(currentRoot));
      _debugCriticalSnapshots['window-1'] = jsonEncode(currentRoot);
      await prefs.setString(
        'app_restoration_latest_v2:user-1',
        jsonEncode(latestInbox),
      );

      final result = await AppRestorationService.instance.readBestSnapshot(
        includeRemote: true,
      );

      expect(result.status, AppRestorationReadStatus.restored);
      expect(result.source, anyOf('critical', 'prefs'));
      expect(result.snapshot?.routeLocation, '/');
    },
  );

  test(
    'local inbox restore does not wait for hanging remote restoration reads',
    () async {
      await _saveDurableRoute('/inbox');
      await AppRestorationService.instance.flushPendingWrites();
      final hangingRemoteWindow = Completer<Map<String, dynamic>?>();
      final hangingRemoteLatest = Completer<Map<String, dynamic>?>();
      AppRestorationService.debugRemoteWindowSnapshotReader =
          (userId, deviceId, windowId) => hangingRemoteWindow.future;
      AppRestorationService.debugRemoteLatestSnapshotReader = (userId) =>
          hangingRemoteLatest.future;

      final result = await AppRestorationService.instance
          .readBestSnapshot(includeRemote: true)
          .timeout(const Duration(milliseconds: 200));

      expect(result.status, AppRestorationReadStatus.restored);
      expect(result.snapshot?.routeLocation, '/inbox');
      expect(hangingRemoteWindow.isCompleted, isFalse);
      expect(hangingRemoteLatest.isCompleted, isFalse);
    },
  );

  test(
    'newer local inbox snapshot beats boot root without consulting remote',
    () async {
      final currentRoot = {
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'window-1',
        'updatedAtMs': 1000,
        ..._durableRouteFields('/'),
      };
      final latestInbox = {
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'window-2',
        'updatedAtMs': 2000,
        ..._durableRouteFields('/inbox'),
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey(), jsonEncode(currentRoot));
      _debugCriticalSnapshots['window-1'] = jsonEncode(currentRoot);
      await prefs.setString(
        'app_restoration_latest_v2:user-1',
        jsonEncode(latestInbox),
      );
      AppRestorationService.debugRemoteWindowSnapshotReader =
          (userId, deviceId, windowId) {
            fail('remote window read should not block local inbox restore');
          };
      AppRestorationService.debugRemoteLatestSnapshotReader = (userId) {
        fail('remote latest read should not block local inbox restore');
      };

      final result = await AppRestorationService.instance.readBestSnapshot(
        includeRemote: true,
      );

      expect(result.status, AppRestorationReadStatus.restored);
      expect(result.source, 'latest_prefs');
      expect(result.snapshot?.routeLocation, '/inbox');
    },
  );

  test(
    'newer local Library snapshot beats boot root without consulting remote',
    () async {
      final currentRoot = {
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'window-1',
        'updatedAtMs': 1000,
        ..._durableRouteFields('/'),
      };
      final latestLibrary = {
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'window-2',
        'updatedAtMs': 2000,
        ..._durableRouteFields('/nodes'),
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey(), jsonEncode(currentRoot));
      _debugCriticalSnapshots['window-1'] = jsonEncode(currentRoot);
      await prefs.setString(
        'app_restoration_latest_v2:user-1',
        jsonEncode(latestLibrary),
      );
      AppRestorationService.debugRemoteWindowSnapshotReader =
          (userId, deviceId, windowId) {
            fail('remote window read should not block local Library restore');
          };
      AppRestorationService.debugRemoteLatestSnapshotReader = (userId) {
        fail('remote latest read should not block local Library restore');
      };

      final result = await AppRestorationService.instance.readBestSnapshot(
        includeRemote: true,
      );

      expect(result.status, AppRestorationReadStatus.restored);
      expect(result.source, 'latest_prefs');
      expect(result.snapshot?.routeLocation, '/nodes');
    },
  );

  test(
    'calendar default root does not beat newer local inbox conversation route',
    () async {
      final currentRoot = {
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'window-1',
        'updatedAtMs': 1000,
        ..._durableRouteFields('/'),
      };
      final latestConversation = {
        'schemaVersion': AppRestorationService.schemaVersion,
        'userId': 'user-1',
        'windowId': 'window-2',
        'updatedAtMs': 2000,
        ..._durableRouteFields('/inbox/conversation/friend-1'),
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey(), jsonEncode(currentRoot));
      _debugCriticalSnapshots['window-1'] = jsonEncode(currentRoot);
      await prefs.setString(
        'app_restoration_latest_v2:user-1',
        jsonEncode(latestConversation),
      );

      final result = await AppRestorationService.instance.readBestSnapshot(
        includeRemote: true,
      );

      expect(result.snapshot?.routeLocation, '/inbox/conversation/friend-1');
    },
  );

  test(
    'stores route and overlay stack atomically for sheet continuity',
    () async {
      final criticalWrites = <Map<String, dynamic>>[];
      AppRestorationService
          .debugCriticalSnapshotWriter = (windowId, serialized) {
        if (serialized == null || serialized.trim().isEmpty) {
          _debugCriticalSnapshots.remove(windowId);
          return;
        }
        _debugCriticalSnapshots[windowId] = serialized;
        criticalWrites.add(Map<String, dynamic>.from(jsonDecode(serialized)));
      };

      await AppRestorationService.instance.saveOverlayStack(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'kind': 'calendar.flowStudio',
            'parentRoute': '/rhythm/today',
            'mode': 'hub',
          },
        ],
      );
      await AppRestorationService.instance.flushPendingWrites();

      expect(criticalWrites, hasLength(1));
      expect(criticalWrites.single['routeLocation'], isNull);
      expect(
        criticalWrites.single['overlayStack'],
        contains(
          allOf(
            containsPair('kind', 'calendar.flowStudio'),
            containsPair('parentRoute', '/rhythm/today'),
          ),
        ),
      );

      final result = await AppRestorationService.instance.readBestSnapshot();
      expect(result.snapshot?.routeLocation, isNull);
      expect(
        result.snapshot?.overlayStack.single['kind'],
        'calendar.flowStudio',
      );
    },
  );

  test('stores inbox invites sheet overlay with parent route', () async {
    await AppRestorationService.instance.saveOverlayStack(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'kind': 'inbox.invites',
          'parentRoute': '/inbox',
          'updatedAtMs': 2000,
        },
      ],
    );

    final result = await AppRestorationService.instance.readBestSnapshot();

    expect(result.snapshot?.routeLocation, isNull);
    expect(
      result.snapshot?.overlayStack.single,
      allOf(
        containsPair('kind', 'inbox.invites'),
        containsPair('parentRoute', '/inbox'),
      ),
    );
  });

  test('does not persist transient Flow Studio editor overlays', () async {
    await AppRestorationService.instance.saveOverlayStack(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'kind': 'calendar.flowStudio',
          'parentRoute': '/',
          'mode': 'editor',
          'editFlowId': 42,
        },
      ],
    );

    final result = await AppRestorationService.instance.readBestSnapshot();

    expect(result.snapshot?.routeLocation, isNull);
    expect(result.snapshot?.overlayStack, isEmpty);
  });

  test(
    'best snapshot can recover a newer latest overlay when current window is stale',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _snapshotKey(),
        jsonEncode(<String, dynamic>{
          'schemaVersion': AppRestorationService.schemaVersion,
          'userId': 'user-1',
          'windowId': 'window-1',
          'updatedAtMs': 1000,
          ..._durableRouteFields('/'),
        }),
      );
      await prefs.setString(
        'app_restoration_latest_v2:user-1',
        jsonEncode(<String, dynamic>{
          'schemaVersion': AppRestorationService.schemaVersion,
          'userId': 'user-1',
          'windowId': 'window-1',
          'updatedAtMs': 2000,
          ..._durableRouteFields('/'),
          'overlayStack': <Map<String, dynamic>>[
            <String, dynamic>{
              'kind': 'calendar.sharedCalendars',
              'parentRoute': '/rhythm/today',
            },
          ],
        }),
      );

      final result = await AppRestorationService.instance.readBestSnapshot(
        includeRemote: true,
      );

      expect(result.snapshot?.updatedAtMs, 2000);
      expect(
        result.snapshot?.overlayStack.single['kind'],
        'calendar.sharedCalendars',
      );
    },
  );
}
