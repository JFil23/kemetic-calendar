import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/daily_cosmic_context_badge.dart';
import 'package:mobile/features/settings/settings_page.dart';
import 'package:mobile/features/settings/settings_prefs.dart';
import 'package:mobile/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
// Exercise failed platform writes, including the optimistic preference cache.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

class _Preferences extends InMemorySharedPreferencesStore {
  _Preferences() : super.withData({});
  bool reject = false;
  bool throwFailure = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith(SettingsPrefs.dailyCosmicContextBadgeEnabledKey) &&
        reject) {
      if (throwFailure) throw StateError('storage unavailable');
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    app.resetGlobalOverlayShellForTesting();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final row = find.widgetWithText(SwitchListTile, 'The Day’s Rhythm badge');
  final captureKey = GlobalKey();
  late GoRouter router;
  var now = DateTime(2026, 10, 9);
  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Calendar')),
        ),
      ],
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          routerConfig: router,
          builder: (_, child) => app.buildGlobalOverlayShellForTesting(
            router: router,
            child: child!,
            dailyCosmicContextUserId: 'rhythm-user',
            dailyCosmicContextAuthenticated: true,
            dailyCosmicContextOnboardingComplete: true,
            dailyCosmicContextNow: () => now,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    router.dispose();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final output = Platform.environment['HAW_RHYTHM_CAPTURE'];
    if (output == null) return;
    final boundary =
        captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'card off persists across restart and Settings can restore automatic cards',
    (tester) async {
      now = DateTime(2026, 10, 9);
      await mount(tester);
      expect(find.byKey(dailyCosmicContextOverlayKey), findsOneWidget);
      await capture(tester, 'card-over-settings');
      await tester.tap(find.byKey(dailyCosmicContextAutomaticToggleKey));
      await settle(tester);
      expect(find.byKey(dailyCosmicContextOverlayKey), findsNothing);
      expect(await SettingsPrefs.dailyCosmicContextBadgeEnabled(), isFalse);
      expect(tester.widget<SwitchListTile>(row).value, isFalse);
      await unmount(tester);
      // Reconstruct both the preference cache and shell from persisted values.
      final saved = await SharedPreferences.getInstance();
      SharedPreferences.setMockInitialValues({
        for (final key in saved.getKeys()) key: saved.get(key)!,
      });
      now = DateTime(2026, 10, 10);
      await mount(tester);
      expect(find.byKey(dailyCosmicContextOverlayKey), findsNothing);
      expect(tester.widget<SwitchListTile>(row).value, isFalse);
      await Scrollable.ensureVisible(
        tester.element(find.text('Calendar Content')),
        alignment: 0.1,
      );
      await tester.pump();
      await capture(tester, 'settings-off');
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester);
      expect(await SettingsPrefs.dailyCosmicContextBadgeEnabled(), isTrue);
      expect(find.byKey(dailyCosmicContextOverlayKey), findsOneWidget);
      await tester.tap(find.byKey(dailyCosmicContextDismissButtonKey));
      await settle(tester);
      expect(await SettingsPrefs.dailyCosmicContextBadgeEnabled(), isTrue);
      expect(tester.widget<SwitchListTile>(row).value, isTrue);
      await capture(tester, 'settings-on');
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester);
      expect(await SettingsPrefs.dailyCosmicContextBadgeEnabled(), isFalse);
      expect(find.byKey(dailyCosmicContextOverlayKey), findsNothing);
      await unmount(tester);
      expect(tester.takeException(), isNull);
    },
  );

  for (final throws in [false, true]) {
    testWidgets(
      'failed save ($throws) keeps card and Settings enabled and permits retry',
      (tester) async {
        final store = _Preferences();
        SharedPreferencesStorePlatform.instance = store;
        now = DateTime(2026, 10, 9);
        await mount(tester);
        final version = SettingsPrefs.dailyCosmicContextBadgeChanges.value;
        store.reject = true;
        store.throwFailure = throws;
        await tester.tap(find.byKey(dailyCosmicContextAutomaticToggleKey));
        await settle(tester);
        expect(find.byKey(dailyCosmicContextOverlayKey), findsOneWidget);
        expect(
          find.text('Could not save your choice. Please try again.'),
          findsOneWidget,
        );
        expect(await SettingsPrefs.dailyCosmicContextBadgeEnabled(), isTrue);
        expect(SettingsPrefs.dailyCosmicContextBadgeChanges.value, version);
        await capture(tester, 'card-save-error');
        // Closing is still a one-day dismissal, even after a failed opt-out.
        await tester.tap(find.byKey(dailyCosmicContextDismissButtonKey));
        await settle(tester);
        await tester.ensureVisible(row);
        await tester.tap(row);
        await settle(tester);
        expect(tester.widget<SwitchListTile>(row).value, isTrue);
        expect(await SettingsPrefs.dailyCosmicContextBadgeEnabled(), isTrue);
        store.reject = false;
        await tester.tap(row);
        await settle(tester);
        expect(tester.widget<SwitchListTile>(row).value, isFalse);
        expect(await SettingsPrefs.dailyCosmicContextBadgeEnabled(), isFalse);
        await unmount(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
