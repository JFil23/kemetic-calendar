import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/services/restoration_coordinator.dart';
import 'package:mobile/services/session_resume_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionResumeService.debugUserIdResolver = () => 'user-1';
    AppRestorationService.debugUserIdResolver = () => 'user-1';
    AppRestorationService.debugRemoteSnapshotWriter =
        (userId, deviceId, windowId, snapshot) async {};
    AppWindowService.debugWindowIdResolver = () async => 'window-1';
    AppWindowService.instance.resetForTesting();
  });

  tearDown(() {
    SessionResumeService.debugUserIdResolver = null;
    AppRestorationService.debugUserIdResolver = null;
    AppRestorationService.debugRemoteSnapshotWriter = null;
    AppWindowService.debugWindowIdResolver = null;
    AppWindowService.instance.resetForTesting();
    RestorationCoordinator.instance.beginLaunchRestore(
      reason: RestorationRestoreReason.coldLaunch,
      targetLocation: '/',
    );
  });

  test('stores scoped state and resumable entry', () async {
    await SessionResumeService.saveScopedState('calendar_view', {
      'kYear': 12,
      'kMonth': 4,
      'kDay': 7,
    });
    await SessionResumeService.saveResumeEntry(
      baseRoute: '/inbox',
      kind: 'inbox_conversation',
      payload: {'otherUserId': 'friend-1', 'draftText': 'still typing'},
    );

    expect(
      await SessionResumeService.readScopedState('calendar_view'),
      containsPair('kMonth', 4),
    );

    final entry = await SessionResumeService.consumeResumeEntry(
      kind: 'inbox_conversation',
      baseRoute: '/inbox',
    );
    expect(entry, isNotNull);
    expect(entry!.payload['draftText'], 'still typing');
    expect(
      await SessionResumeService.readResumeEntry(
        kind: 'inbox_conversation',
        baseRoute: '/inbox',
      ),
      isNull,
    );
  });

  test('clears expired snapshots', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'session_resume_state_v1',
      jsonEncode({
        'updatedAtMs': DateTime.now()
            .subtract(SessionResumeService.ttl + const Duration(minutes: 1))
            .millisecondsSinceEpoch,
        'scopedStates': {
          'calendar_view': {'kYear': 12},
        },
      }),
    );

    expect(await SessionResumeService.readScopedState('calendar_view'), isNull);
    expect(prefs.getString('session_resume_state_v1'), isNull);
  });

  test('clears snapshots from another signed-in user', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'session_resume_state_v1',
      jsonEncode({
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        'userId': 'user-2',
        'scopedStates': {
          'calendar_view': {'kYear': 12},
        },
      }),
    );

    expect(await SessionResumeService.readScopedState('calendar_view'), isNull);
    expect(prefs.getString('session_resume_state_v1'), isNull);
  });

  testWidgets(
    'default root route does not overwrite pending non-root launch restore',
    (tester) async {
      RestorationCoordinator.instance.beginLaunchRestore(
        reason: RestorationRestoreReason.coldLaunch,
        targetLocation: '/inbox',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SessionTrackedRoute(location: '/', child: Text('calendar')),
        ),
      );
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('session_resume_state_v1');
      if (raw != null) {
        expect(jsonDecode(raw), isNot(containsPair('routeLocation', anything)));
      }
      expect(
        (await AppRestorationService.instance.readSnapshot())?.routeLocation,
        isNull,
      );
    },
  );

  testWidgets(
    'auth-resume root rebuild does not overwrite deferred durable page',
    (tester) async {
      final metadata = const NavigationPersistencePolicy()
          .classifyRoute('/nodes', NavigationSource.programmatic)
          .metadata;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'app_restoration_v1:user-1:window-1',
        jsonEncode(<String, dynamic>{
          'schemaVersion': AppRestorationService.schemaVersion,
          'userId': 'user-1',
          'windowId': 'window-1',
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
          'routeLocation': '/nodes',
          navigationLaunchRouteMetadataKey: metadata.toJson(),
        }),
      );

      RestorationCoordinator.instance.beginLaunchRestore(
        reason: RestorationRestoreReason.authResume,
        targetLocation: '/nodes',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SessionTrackedRoute(location: '/', child: Text('calendar')),
        ),
      );
      await tester.pump();

      expect(
        (await AppRestorationService.instance.readSnapshot())?.routeLocation,
        '/nodes',
      );
    },
  );

  test(
    'session tracked route records visible surfaces through the controller',
    () async {
      final source = await File(
        'lib/services/session_resume_service.dart',
      ).readAsString();
      final start = source.indexOf('  void _persistRoute()');
      final end = source.indexOf('  @override\n  Widget build', start);
      expect(start, isNot(-1));
      expect(end, isNot(-1));
      final persistRoute = source.substring(start, end);
      expect(persistRoute, contains('durable_launch_route_centralized'));
      expect(
        persistRoute,
        contains('shouldDeferRootRoutePersistenceForLaunch'),
      );
      expect(persistRoute, contains('recordVisibleSurface'));
      expect(persistRoute, isNot(contains('recordRouteLocation')));
      expect(persistRoute, isNot(contains('saveRouteLocation')));
    },
  );
}
