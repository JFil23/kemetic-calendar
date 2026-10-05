import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/widgets/day_sheet_components.dart';
import 'package:mobile/features/calendar/presentation/maat_flow_detail_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
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
    SharedPreferences.setMockInitialValues({
      'app:has_seen_onboarding': true,
      'app:onboarding:completed': true,
    });
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (r) async => http.Response(
          '[]',
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await loadMaatFlowVisualTestFonts();
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
  });
  testWidgets(
    'nested DayView Flows detail accepts touch drag in short landscape',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 580);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: CalendarPage(debugDaySheetSmokeOnLaunch: true)),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await settle();
      await tester.tap(find.text('Flows').last);
      await settle();
      final maat = find.text("Ma'at Flows");
      await tester.tap(maat);
      await settle();
      await tester.tap(find.text('Follow the Sky').last);
      await settle();
      expect(find.byType(MaatFlowDetailShell), findsOneWidget);
      expect(find.byType(DaySheetTabBar), findsOneWidget);
      expect(
        find
            .ancestor(
              of: find.byType(MaatFlowDetailShell),
              matching: find.byType(Navigator),
            )
            .evaluate()
            .length,
        greaterThanOrEqualTo(2),
      );
      final shell = tester.widget<MaatFlowDetailShell>(
        find.byType(MaatFlowDetailShell),
      );
      final shellBounds = tester.getRect(find.byType(MaatFlowDetailShell));
      final scroll = find.descendant(
        of: find.byType(MaatFlowDetailShell),
        matching: find.byType(Scrollable),
      );
      final scrollState = tester.state<ScrollableState>(scroll.first);
      final before = scrollState.position.pixels;
      // The fixed dock must not intercept drags from either the hero or the
      // exposed body. This path has the extra Day View modal/nested Navigator
      // that is absent from shared-flow route layout tests.
      final dock = find.byWidget(shell.bottomDock!);
      final dockBefore = tester.getRect(dock);
      await tester.dragFrom(
        Offset(shellBounds.center.dx, shellBounds.top + 100),
        const Offset(0, -250),
      );
      await tester.pump();
      expect(scrollState.position.pixels, greaterThan(before));
      expect(tester.getRect(dock), dockBefore);
      final sheet = find.byWidget(shell.sheet);
      final sheetBounds = tester.getRect(sheet);
      expect(sheetBounds.top, lessThan(dockBefore.top - 30));
      final afterHero = scrollState.position.pixels;
      await tester.dragFrom(
        Offset(shellBounds.center.dx, sheetBounds.top + 20),
        const Offset(0, -80),
      );
      await tester.pump();
      expect(scrollState.position.pixels, greaterThan(afterHero));
      expect(tester.getRect(dock), dockBefore);
      expect(tester.takeException(), isNull);
      // Use the existing calendar orientation handoff before disposing its
      // landscape pager, as in landscape_keyboard_ownership_test.dart.
      tester.view.physicalSize = const Size(580, 1024);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    },
  );
}
