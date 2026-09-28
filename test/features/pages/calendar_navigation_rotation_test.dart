import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/calendar_epoch_viewport.dart';
import 'package:mobile/widgets/calendar_floating_shortcuts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages_resource_test.dart' show session;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (r) async => http.Response(
          r.url.path.endsWith('get_together_inbox') ||
                  r.url.path.endsWith('get_commons_together_home_cards')
              ? '{}'
              : '[]',
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await Supabase.instance.client.auth.recoverSession(session());
  });
  tearDownAll(() async => Supabase.instance.dispose());

  for (final level in MonthExpansionLevel.values) {
    testWidgets(
      'Today, rotation, route return and keyboard preserve ${level.name} calendar',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final harness = CalendarBoundaryHarnessController(
          expansionLevel: level,
          content: CalendarBoundaryHarnessContent.eventHeavy,
          instrumentation: CalendarBoundaryInstrumentation.timingOnly,
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) =>
                  CalendarPage(calendarBoundaryHarnessController: harness),
            ),
            GoRoute(
              path: '/cover',
              builder: (_, _) => const Scaffold(body: Text('Covered route')),
            ),
          ],
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        // The original details-mode failure also occurred without rotation.
        await tester.tap(find.byKey(calendarFloatingTodaySurfaceKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (var cycle = 0; cycle < 3; cycle++) {
          await tester.drag(
            find.byType(CalendarEpochScrollView),
            const Offset(0, -400),
          );
          await tester.pumpAndSettle();
          for (final size in [const Size(852, 393), const Size(393, 852)]) {
            tester.view.physicalSize = size;
            await tester.pumpAndSettle();
            expect(find.byKey(calendarFloatingTodaySurfaceKey), findsOneWidget);
            if (size.width > size.height) {
              expect(
                find.byKey(const ValueKey('landscape-today')),
                findsOneWidget,
              );
              expect(find.byTooltip('Calendar actions'), findsNothing);
              expect(
                find.byTooltip('Add note, reminder, or flow'),
                findsOneWidget,
              );
              expect(find.byKey(calendarFloatingShortcutsKey), findsNothing);
            } else {
              expect(find.byKey(calendarFloatingShortcutsKey), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          }
          unawaited(router.push<void>('/cover'));
          await tester.pumpAndSettle();
          tester.view.physicalSize = const Size(852, 393);
          await tester.pumpAndSettle();
          router.pop();
          await tester.pumpAndSettle();
          expect(find.byKey(calendarFloatingTodaySurfaceKey), findsOneWidget);
          tester.view.physicalSize = const Size(393, 852);
          await tester.pumpAndSettle();
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          expect(find.byKey(calendarFloatingTodaySurfaceKey), findsNothing);
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pumpAndSettle();
          expect(find.byKey(calendarFloatingTodaySurfaceKey), findsOneWidget);
        }
        await tester.tap(find.byKey(calendarFloatingTodaySurfaceKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        router.dispose();
      },
    );
  }
}
