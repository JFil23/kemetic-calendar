import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/main.dart' show createAppRouterForTesting;
import 'package:mobile/features/calendar/decan_reflection_badge.dart';
import 'package:mobile/features/calendar/decan_reflection_window.dart';
import 'package:mobile/features/reflections/decan_review_controller.dart';
import 'package:mobile/features/reflections/decan_review_context.dart';
import 'package:mobile/data/decan_reflection_prompt_state.dart';
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import '../pages/pages_resource_test.dart' show session, uid;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  final w = latestCompletedDecanReflectionWindow(
    DateTime.now(),
    availableOnly: true,
  )!;
  var failLookup = false;
  Completer<void>? delayedRead;
  final review = {
    'id': 'saved-review',
    'user_id': uid,
    'decan_name': w.decanName,
    'decan_start': DecanReviewWindow.date(w.start),
    'decan_end': DecanReviewWindow.date(w.end),
    'review_revision': 1,
    'review_context': const DecanReviewContext(
      questionId: 'carry',
      question: 'What would you like to carry forward?',
      moments: [],
    ).toJson(),
    'created_at': '2026-01-01T00:00:00Z',
  };
  late Directory hiveDirectory;
  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('haw_badge_route.');
    Hive.init(hiveDirectory.path);
    await calendarSnapshotStore.initialize();
    SharedPreferences.setMockInitialValues({
      'onboarding_v2_progress:$uid': jsonEncode(
        const OnboardingProgress(completedOnboarding: true).toJson(),
      ),
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
      'receive_sharing_intent/messages',
      'receive_sharing_intent/events-media',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (name.contains('/events') && call.method == 'listen') {
          scheduleMicrotask(
            () => messenger.handlePlatformMessage(name, null, (_) {}),
          );
        }
        return null;
      });
    }
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        final table = r.url.path.split('/').last;
        Object? data = [];
        if (table == 'decan_reflections') {
          await delayedRead?.future;
          if (failLookup) {
            return http.Response(
              '{"message":"unavailable"}',
              503,
              headers: {'content-type': 'application/json'},
            );
          }
          data = review;
        } else if (table == 'read_decan_activity_v1') {
          data = {'items': [], 'next_cursor': null};
        } else if (['decan_journal_sources', 'insight_posts'].contains(table)) {
          data = null;
        }
        return http.Response(
          jsonEncode(data),
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.recoverSession(session());
    await DecanReflectionPromptState(
      Supabase.instance.client,
    ).markInteracted(w.start);
  });

  testWidgets(
    'Settings repeatedly shows seen badge and opens the existing review; errors and account departure are fenced',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = createAppRouterForTesting();
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(path: '/', builder: (_, _) => CalendarPage()),
          ...app.configuration.routes.whereType<GoRoute>().where(
            (route) => [
              '/settings',
              '/reflections/:reflectionId',
            ].contains(route.path),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        router.dispose();
        app.dispose();
      });
      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData.dark(useMaterial3: true),
          routerConfig: router,
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      Future<void> requestBadge() async {
        router.go('/settings');
        await settle();
        await tester.ensureVisible(find.text('Show reflection badge'));
        await tester.tap(find.text('Show reflection badge'));
        await settle();
        expect(router.state.uri.path, '/');
      }

      for (var i = 0; i < 2; i++) {
        await requestBadge();
        expect(find.byKey(decanReflectionLowerThirdBadgeKey), findsOneWidget);
        await tester.tap(find.byKey(decanReflectionLowerThirdBadgeKey));
        await settle();
        expect(router.state.uri.path, '/reflections/saved-review');
        expect(find.text('These ten days'), findsOneWidget);
        expect(
          find.text('What would you like to carry forward?'),
          findsOneWidget,
        );
      }
      expect(
        requests.where((r) => r.url.path.endsWith('apply_decan_review_v1')),
        isEmpty,
      );
      expect(
        await DecanReflectionPromptState(
          Supabase.instance.client,
        ).hasInteracted(w.start),
        isTrue,
      );

      failLookup = true;
      await requestBadge();
      expect(find.byKey(decanReflectionLowerThirdBadgeKey), findsNothing);
      expect(
        find.text(
          'Could not load your reflection badge. Try again from Settings.',
        ),
        findsOneWidget,
      );
      failLookup = false;
      delayedRead = Completer<void>();
      await requestBadge();
      await tester.runAsync(
        () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
      );
      delayedRead!.complete();
      await settle();
      expect(find.byKey(decanReflectionLowerThirdBadgeKey), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle();
      // Calendar's queued Hive commits originate in the widget-test clock.
      // Drain both that clock and disk IO while closing the isolated fixture.
      var cleanupStage = 'warm writes';
      final cleanup = () async {
        await WarmSnapshotStore.instance.flushed;
        cleanupStage = 'auth';
        await Supabase.instance.dispose();
        cleanupStage = 'calendar storage';
        await Hive.close();
        cleanupStage = 'temporary directory';
        await hiveDirectory.delete(recursive: true);
        cleanupStage = 'complete';
      }();
      for (var i = 0; i < 100 && cleanupStage != 'complete'; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(cleanupStage, 'complete');
      await cleanup;
    },
  );
}
