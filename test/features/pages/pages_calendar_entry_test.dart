import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart' show routeObserver;
import 'package:mobile/features/pages/pages_page.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/pages/pages_layout.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages_resource_test.dart' show session;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response(
          r.url.path.endsWith('get_together_inbox') ||
                  r.url.path.endsWith('get_commons_together_home_cards')
              ? '{}'
              : '[]',
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.recoverSession(session());
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  for (final level in [
    MonthExpansionLevel.compact,
    MonthExpansionLevel.details,
  ]) {
    testWidgets(
      'direct Pages entry and Calendar round trips preserve rendering ${level.name}',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = CalendarBoundaryHarnessController(
          expansionLevel: level,
          content: CalendarBoundaryHarnessContent.eventHeavy,
          instrumentation: CalendarBoundaryInstrumentation.timingOnly,
        );
        final router = GoRouter(
          initialLocation: '/pages',
          observers: [routeObserver],
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (c, s) => NoTransitionPage(
                key: s.pageKey,
                child: CalendarPage(calendarBoundaryHarnessController: harness),
              ),
            ),
            GoRoute(
              path: '/pages',
              pageBuilder: (c, s) => NoTransitionPage(
                key: s.pageKey,
                name: '/pages',
                child: const PagesPage(),
              ),
            ),
          ],
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          if (i > 0) {
            unawaited(router.push<void>('/pages'));
            await tester.pumpAndSettle();
          }
          tester
              .widget<PagesLayout>(find.byType(PagesLayout))
              .onOpen(PagesDestination.calendar);
          await tester.pumpAndSettle();
        }
        final lastError = tester.takeException();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        router.dispose();
        expect(lastError, isNull);
      },
    );
  }
}
