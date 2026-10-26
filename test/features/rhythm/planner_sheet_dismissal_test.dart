import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/rhythm/pages/todays_alignment_page.dart';
import 'package:mobile/data/account_storage/planner_account_store.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/main.dart' show createAppRouterForTesting;
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise storage rejection through the deployed preferences adapter boundary.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/pages_resource_test.dart' show session, uid;
import '../../support/maat_flow_visual_test_fonts.dart';

class _CheckpointPreferences extends InMemorySharedPreferencesStore {
  _CheckpointPreferences()
    : super.withData({
        'flutter.planner_account:v1:$uid': jsonEncode({
          'schema': 1,
          'userId': uid,
          'rows': {
            'notes': [
              {
                'id': '10000000-0000-4000-8000-000000000001',
                'body': 'Say no to burnout',
                'position': 0,
                'planner_revision': 1,
                'created_at': '2026-10-26T12:00:00Z',
              },
            ],
            'nutrition': [],
          },
          'legacyIds': {},
          'pending': [],
          'conflicts': [],
          'migrated': [],
        }),
      });
  bool rejectCheckpoint = false;
  int rejected = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (rejectCheckpoint && key == 'flutter.session_resume_state_v1') {
      rejected++;
      throw StateError('Session checkpoint storage unavailable');
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _CheckpointPreferences preferences;

  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
    SharedPreferences.setMockInitialValues({});
    AppRestorationService.debugUserIdResolver = () => null;
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        return http.Response(
          request.url.path.endsWith('/alignment_notes')
              ? jsonEncode([
                  {
                    'id': '10000000-0000-4000-8000-000000000001',
                    'user_id': uid,
                    'body': 'Say no to burnout',
                    'position': 0,
                    'planner_revision': 1,
                    'created_at': '2026-10-26T12:00:00Z',
                  },
                ])
              : '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.recoverSession(session());
  });

  setUp(() {
    PlannerAccountStore.of(Supabase.instance.client).dispose();
    SharedPreferences.setMockInitialValues({});
    preferences = _CheckpointPreferences();
    SharedPreferencesStorePlatform.instance = preferences;
  });

  tearDownAll(() async {
    AppRestorationService.debugUserIdResolver = null;
    SharedPreferences.setMockInitialValues({});
    await Supabase.instance.dispose();
  });

  for (final restored in [false, true]) {
    for (final dismissal in ['close', 'drag', 'backdrop', 'back']) {
      testWidgets(
        'Planner $dismissal exits after checkpoint rejection: restored=$restored',
        (tester) async {
          expect(Supabase.instance.client.auth.currentUser?.id, uid);
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final appRouter = createAppRouterForTesting();
          final plannerRoute = appRouter.configuration.routes
              .whereType<GoRoute>()
              .singleWhere((route) => route.path == '/rhythm/today');
          final router = GoRouter(
            initialLocation: restored ? '/rhythm/today' : '/pages',
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) =>
                    const Scaffold(body: Text('Calendar return')),
              ),
              GoRoute(
                path: '/pages',
                builder: (_, _) => const Scaffold(body: Text('Pages return')),
              ),
              plannerRoute,
            ],
          );
          await tester.pumpWidget(
            MaterialApp.router(
              theme: AppTheme.dark,
              debugShowCheckedModeBanner: false,
              routerConfig: router,
            ),
          );
          if (!restored) unawaited(router.push<void>('/rhythm/today'));
          await tester.pumpAndSettle();

          expect(find.text('Say no to burnout'), findsOneWidget);

          const reference = String.fromEnvironment('PLANNER_VISUAL_REFERENCE');
          if (reference.isNotEmpty && dismissal == 'close' && !restored) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(Uri.file(reference)),
            );
          }

          final saved = await preferences.getAll();
          final accountKey = 'flutter.planner_account:v1:$uid';
          expect(saved[accountKey], isNotNull);
          preferences.rejectCheckpoint = true;
          switch (dismissal) {
            case 'close':
              await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey));
            case 'drag':
              await tester.drag(
                find.byKey(utilitySheetRouteDragHandleKey),
                const Offset(0, 180),
              );
            case 'backdrop':
              await tester.tapAt(const Offset(12, 12));
            case 'back':
              await tester.binding.handlePopRoute();
          }
          await tester.pumpAndSettle();
          expect(preferences.rejected, greaterThan(0));
          expect(router.state.uri.path, restored ? '/' : '/pages');
          expect(find.byType(PlannerSheetRoutePage), findsNothing);
          expect((await preferences.getAll())[accountKey], saved[accountKey]);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          router.dispose();
          appRouter.dispose();
        },
      );
    }
  }
}
