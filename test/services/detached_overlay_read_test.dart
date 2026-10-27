import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/services/restoration_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (r) async => http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        ),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final state in ['absent', 'root', 'parent pending', 'suppressed']) {
    testWidgets('detached launch restoration treats $state correctly', (
      tester,
    ) async {
      final overlay = <String, Object?>{
        'kind': 'calendar.flowStudio',
        'parentRoute': state == 'root' ? '/' : '/pages',
        'mode': 'hub',
      };
      SharedPreferences.setMockInitialValues({
        'app_restoration_v1:user-1:window-1': jsonEncode({
          'schemaVersion': 1,
          'userId': 'user-1',
          'windowId': 'window-1',
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
          'routeLocation': '/pages',
          'overlayStack': state == 'absent' ? [] : [overlay],
        }),
      });
      AppRestorationService.debugUserIdResolver = () => 'user-1';
      AppWindowService.debugWindowIdResolver = () async => 'window-1';
      AppWindowService.instance.resetForTesting();
      addTearDown(() {
        AppRestorationService.debugUserIdResolver = null;
        AppWindowService.debugWindowIdResolver = null;
        AppWindowService.instance.resetForTesting();
      });
      final coordinator = RestorationCoordinator.instance;
      coordinator.beginLaunchRestore(
        reason: RestorationRestoreReason.coldLaunch,
        targetLocation: '/pages',
      );
      if (state == 'suppressed') {
        coordinator.suppressRestoreForUserNavigation(reason: 'user moved');
      }
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final handled = await tester.runAsync(
        () => CalendarPage.restoreDetachedCalendarOverlayFromAnyContext(
          context,
          currentLocation: state == 'parent pending' ? '/' : '/pages',
        ),
      );
      expect(
        handled,
        state != 'parent pending',
        reason: 'Only a pending parent needs another launch attempt',
      );
      expect(find.byType(Navigator), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
