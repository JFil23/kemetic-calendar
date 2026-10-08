import 'dart:async';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/calendar_epoch_viewport.dart';
import 'package:mobile/features/inbox/inbox_page.dart';
import 'package:mobile/main.dart' show createAppRouterForTesting;
import 'package:mobile/widgets/calendar_floating_shortcuts.dart';
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/pages_resource_test.dart' show session;
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      "haw-inbox-backdrop.",
    );
    Hive.init(hiveDirectory.path);
    await calendarSnapshotStore.initialize();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (name.endsWith('/events') && call.method == 'listen') {
          scheduleMicrotask(
            () => messenger.handlePlatformMessage(name, null, (_) {}),
          );
        }
        return null;
      });
    }

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
    await loadMaatFlowVisualTestFonts();
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets(
    'real Inbox route keeps Calendar painted through reopen and rotation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = createAppRouterForTesting();
      final inboxRoute = app.configuration.routes
          .whereType<GoRoute>()
          .singleWhere((route) => route.path == '/inbox');
      app.dispose();
      final harness = CalendarBoundaryHarnessController(
        expansionLevel: MonthExpansionLevel.compact,
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
          inboxRoute,
          GoRoute(
            path: '/cover',
            builder: (_, _) => const Scaffold(body: Text('Opaque cover')),
          ),
        ],
      );
      const capture = Key('capture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp.router(
            theme: AppTheme.dark,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final calendarState = tester.state(find.byType(CalendarPage));
      final scrollElement = tester.element(
        find.byType(CalendarEpochScrollView),
      );
      for (var cycle = 0; cycle < 2; cycle++) {
        await tester.tap(find.byKey(calendarFloatingInboxButtonKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byKey(inboxSheetRouteKey), findsOneWidget);
        expect(
          find.byType(CalendarEpochScrollView),
          findsOneWidget,
          reason:
              'A transparent sheet still exposes the real Calendar background.',
        );
        if (cycle == 0) {
          expect(
            tester.element(find.byType(CalendarEpochScrollView)),
            same(scrollElement),
          );
        }
        if (cycle == 0 &&
            const bool.fromEnvironment('CAPTURE_INBOX_BACKDROP')) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await tester.runAsync(
            () => File(
              '/tmp/haw-inbox-calendar-backdrop.png',
            ).writeAsBytes(bytes!.buffer.asUint8List()),
          );
          image.dispose();
        }
        tester.view.physicalSize = const Size(844, 390);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('landscape-today')), findsOneWidget);
        tester.view.physicalSize = const Size(390, 844);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.state(find.byType(CalendarPage)), same(calendarState));
      }
      unawaited(router.push<void>('/cover'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const ValueKey('landscape-today'), skipOffstage: false),
        findsNothing,
        reason:
            'Opaque routes retain the existing hidden-grid work suppression.',
      );
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('landscape-today')), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Match the existing rotation suite's portrait disposal boundary.
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      router.dispose();
      await tester.runAsync(() async {
        final client = Supabase.instance.client;
        await client.removeAllChannels();
        await client.realtime.disconnect();
        client.realtime.reconnectTimer.reset();
      });
      await tester.pump(const Duration(seconds: 11));
    },
  );
}
