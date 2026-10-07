import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/main.dart' show createAppRouterForTesting;
import 'package:mobile/data/warm_state/warm_snapshot_store.dart';
import 'package:mobile/features/reflections/decan_review_screen.dart';
import '../../features/pages/pages_resource_test.dart' show session, uid;

// First creation has a different persistence lifecycle from seeded archive
// routes. Keep its process-wide auth/warm-store fixture in its own test isolate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  Map<String, dynamic>? createdReview;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final name in ['messages', 'events']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('com.llfbandit.app_links/$name'),
            (_) async => null,
          );
    }
    await Supabase.initialize(
      url: 'https://example.supabase.test',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        final table = r.url.path.split('/').last;
        Object? data = [];
        if (table == 'apply_decan_review_v1') {
          final req = jsonDecode(r.body) as Map;
          createdReview = {
            'id': req['p_id'],
            'user_id': uid,
            'decan_name': req['p_name'],
            'decan_start': req['p_start'],
            'decan_end': req['p_end'],
            'review_revision': 1,
            'review_context': req['p_context'],
            'reflection_text': (req['p_context'] as Map)['question'],
            'created_at': DateTime.now().toUtc().toIso8601String(),
          };
          data = {'status': 'applied', 'row': createdReview};
        } else if (table == 'decan_reflections') {
          data = createdReview;
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
  });
  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets('first creation replaces its URL and mounts the saved review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 1150);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = createAppRouterForTesting();
    final routes = app.configuration.routes
        .whereType<GoRoute>()
        .where((r) => r.path == '/reflections/:reflectionId')
        .toList();
    final router = GoRouter(
      initialLocation:
          '/reflections/new?start=2025-03-20&end=2025-03-29&name=First%20decan',
      routes: routes,
    );
    addTearDown(router.dispose);
    addTearDown(app.dispose);
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

    await settle();
    expect(createdReview, isNotNull);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/reflections/${createdReview!['id']}',
    );
    expect(
      requests.where((r) => r.url.path.endsWith('apply_decan_review_v1')),
      hasLength(1),
    );
    expect(find.byType(DecanReviewScreen), findsOneWidget);
    expect(find.text('These ten days'), findsOneWidget);
    expect(find.text('Leave a few words  →'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle();
    await tester.runAsync(() => WarmSnapshotStore.instance.flushed);
  });
}
