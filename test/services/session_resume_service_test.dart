import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/session_resume_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionResumeService.debugUserIdResolver = () => 'user-1';
  });

  tearDown(() {
    SessionResumeService.debugUserIdResolver = null;
  });

  test('stores route, scoped state, and resumable entry', () async {
    await SessionResumeService.saveRouteLocation('/inbox');
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

    expect(await SessionResumeService.readRouteLocation(), '/inbox');
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

  test('stores legitimate edit flow routes unchanged', () async {
    const route = '/flows/42/edit?calendarId=shared-1';
    await SessionResumeService.saveRouteLocation(route);

    expect(await SessionResumeService.readRouteLocation(), route);
  });

  test('clears expired snapshots', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'session_resume_state_v1',
      jsonEncode({
        'updatedAtMs': DateTime.now()
            .subtract(SessionResumeService.ttl + const Duration(minutes: 1))
            .millisecondsSinceEpoch,
        'routeLocation': '/rhythm/today',
      }),
    );

    expect(await SessionResumeService.readRouteLocation(), isNull);
    expect(prefs.getString('session_resume_state_v1'), isNull);
  });

  test('clears snapshots from another signed-in user', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'session_resume_state_v1',
      jsonEncode({
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        'userId': 'user-2',
        'routeLocation': '/inbox',
      }),
    );

    expect(await SessionResumeService.readRouteLocation(), isNull);
    expect(prefs.getString('session_resume_state_v1'), isNull);
  });

  test('persists node action routes as stable one-shot-free routes', () async {
    await SessionResumeService.saveRouteLocation(
      '/nodes/human_emergence?action=add_insight',
    );

    expect(
      await SessionResumeService.readRouteLocation(),
      '/nodes/human_emergence',
    );

    final prefs = await SharedPreferences.getInstance();
    final raw =
        jsonDecode(prefs.getString('session_resume_state_v1')!)
            as Map<String, dynamic>;
    expect(raw['routeLocation'], '/nodes/human_emergence');
    expect(raw['routeLocation'], isNot(contains('add_insight')));
  });

  test(
    'cleans stale one-shot route intents when reading old snapshots',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'session_resume_state_v1',
        jsonEncode({
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
          'userId': 'user-1',
          'routeLocation': '/nodes/human_emergence?action=add_insight',
        }),
      );

      expect(
        await SessionResumeService.readRouteLocation(),
        '/nodes/human_emergence',
      );
      final raw =
          jsonDecode(prefs.getString('session_resume_state_v1')!)
              as Map<String, dynamic>;
      expect(raw['routeLocation'], '/nodes/human_emergence');
    },
  );
}
