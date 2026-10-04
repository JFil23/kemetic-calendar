import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../support/maat_flow_visual_test_fonts.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/external_calendar_repository.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';
import 'package:mobile/features/auth/login_screen.dart'
    show PasswordRecoveryScreen;
import 'package:mobile/features/settings/device_calendar_panel.dart';
import 'package:mobile/features/settings/device_calendar_settings.dart';
import 'package:mobile/features/settings/external_calendar_panel.dart';
import 'package:mobile/features/settings/external_calendar_settings.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';
import 'package:mobile/features/onboarding/onboarding_overlay.dart';
import 'package:mobile/features/onboarding/haw_calendar_connection.dart';
import 'package:mobile/main.dart'
    show AuthGate, MyApp, createAppRouterForTesting;
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/device_calendar_controller.dart';
import 'package:mobile/services/external_calendar_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/pages/pages_resource_test.dart' show session;

// Exercise the real route replacement and Settings subscriptions. Repository
// responses and the native read-only channel are fixtures; no provider or
// account content is changed. JSON-isolate work needs real async turns while
// widget animation and the 30-second observation window use the test clock.
class ReplayCheckpointPreferences extends InMemorySharedPreferencesStore {
  ReplayCheckpointPreferences() : super.withData({});
  String? heldOwner;
  bool reject = false;
  int writes = 0;
  final release = Completer<void>();
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (heldOwner != null &&
        key == 'flutter.onboarding_v2_progress:$heldOwner') {
      writes++;
      await release.future;
      if (reject) return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final actions = <String>[];
  final nativeMethods = <String>[];
  var googleAvailable = true;
  var failStatus = false;
  String? heldOwner;
  final pendingReads = <String, Completer<void>>{};
  const replacementOwner = '93de60db-7756-4587-82f4-93a7b928b812';

  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    // CalendarPage may persist incidental snapshots during route replacement.
    // Use Hive's supported memory backend so those writes remain in widget
    // fake time, rather than leaving a native file queue after the test ends.
    await Hive.openBox<String>(
      'calendar_snapshot_store_v1',
      bytes: Uint8List(0),
    );
    await calendarSnapshotStore.initialize();
    SharedPreferences.setMockInitialValues({});
    AppRestorationService.debugUserIdResolver = () => null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
      'receive_sharing_intent/messages',
      'receive_sharing_intent/events-media',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (name.startsWith('receive_sharing_intent/') &&
            name.contains('/events') &&
            call.method == 'listen') {
          scheduleMicrotask(
            () => messenger.handlePlatformMessage(name, null, (_) {}),
          );
        }
        return null;
      });
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.kemetic.calendar/device_import_v1'),
      (call) async {
        nativeMethods.add(call.method);
        return switch (call.method) {
          'deviceId' => 'fixture-device',
          'permissionStatus' => 'notDetermined',
          _ => throw StateError('Unexpected native action ${call.method}'),
        };
      },
    );
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        // This fixture delivers recovery through the public URL parser; the
        // lifecycle assertion consumes the same passwordRecovery auth event.
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/user') {
          return http.Response(
            jsonEncode((jsonDecode(session()) as Map)['user']),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/external_calendar')) {
          final action =
              (jsonDecode(request.body) as Map<String, dynamic>)['action']
                  as String;
          actions.add(action);
          final failed = failStatus;
          final owner = Supabase.instance.client.auth.currentUser?.id;
          if (heldOwner != null && owner == heldOwner) {
            await pendingReads.putIfAbsent(action, Completer<void>.new).future;
          }
          return http.Response(
            jsonEncode(
              failed
                  ? {
                      'error': {'code': 'unavailable', 'retryable': true},
                    }
                  : {
                      'available': action == 'device_status'
                          ? true
                          : googleAvailable,
                      'connection': {
                        'id': null,
                        'status': 'disconnected',
                        'account_label': owner,
                        'revision': owner == replacementOwner ? 2 : 1,
                      },
                      'sources': [],
                    },
            ),
            failed ? 503 : 200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          request.url.path.endsWith('get_together_inbox') ||
                  request.url.path.endsWith('get_commons_together_home_cards')
              ? '{}'
              : '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.recoverSession(session());
  });

  setUp(() async {
    actions.clear();
    nativeMethods.clear();
    googleAvailable = true;
    failStatus = false;
    heldOwner = null;
    pendingReads.clear();
    final client = Supabase.instance.client;
    setExternalCalendarRepositoryForTesting(
      client,
      ExternalCalendarRepository(client, lane: 'staging'),
    );
    // A completed recovery screen does not emit another auth event. Start
    // each independent app fixture with a fresh session, so the auth stream
    // cannot replay the prior test's passwordRecovery event.
    await client.auth.signOut(scope: SignOutScope.local);
    await client.auth.recoverSession(session());
    final storage = OnboardingProgressStorage();
    await storage.saveRequired(
      client.auth.currentUser!.id,
      const OnboardingProgress(),
    );
    await storage.saveRequired(replacementOwner, const OnboardingProgress());
  });

  tearDown(() {
    for (final pending in pendingReads.values) {
      if (!pending.isCompleted) pending.complete();
    }
    disposeSharedExternalCalendarController();
    DeviceCalendarController.disposeShared();
    setExternalCalendarRepositoryForTesting(Supabase.instance.client, null);
  });

  tearDownAll(() async {
    AppRestorationService.debugUserIdResolver = null;
    await Supabase.instance.dispose();
    await Hive.close();
  });

  Future<void> drain(WidgetTester tester) async {
    // Include the account checkpoint read before Settings mounts its panels.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  void expectReadyPanels(WidgetTester tester) {
    final google = tester.widget<ExternalCalendarPanel>(
      find.byType(ExternalCalendarPanel),
    );
    final device = tester.widget<DeviceCalendarPanel>(
      find.byType(DeviceCalendarPanel),
    );
    expect(
      google.state,
      googleAvailable
          ? ExternalCalendarPanelState.disconnected
          : ExternalCalendarPanelState.unconfigured,
    );
    expect(device.state, DeviceCalendarPanelState.disconnected);
    expect(find.text('Checking your calendar connection…'), findsNothing);
    expect(tester.takeException(), isNull);
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Settings replay row fits at $scale text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final capture = GlobalKey();
      final router = createAppRouterForTesting(initialLocation: '/settings');
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp.router(
            theme: AppTheme.dark,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      );
      await drain(tester);
      await tester.ensureVisible(find.text('Replay onboarding'));
      await tester.pump();
      expect(find.text('Replay onboarding'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final output = Platform.environment['HAW_SETTINGS_CAPTURE_DIR'];
      if (output != null) {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$output/settings-replay-${scale}x.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });
  }

  testWidgets('direct Settings entry resolves Google and native status', (
    tester,
  ) async {
    googleAvailable = false;
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = createAppRouterForTesting(initialLocation: '/settings');
    final google = externalCalendarController(Supabase.instance.client);
    final device = DeviceCalendarController.instance;
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    );
    await drain(tester);
    expectReadyPanels(tester);
    expect(find.byType(AuthGate), findsNothing);
    expect(externalCalendarController(Supabase.instance.client), same(google));
    expect(DeviceCalendarController.instance, same(device));
    await tester.pump(const Duration(seconds: 30));
    await drain(tester);
    expectReadyPanels(tester);
    expect(actions, containsAll(['status', 'device_status']));
    expect(nativeMethods, contains('deviceId'));
    expect(nativeMethods, isNot(contains('requestPermission')));
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await tester.runAsync(() async {
      final client = Supabase.instance.client;
      await client.removeAllChannels();
      await client.realtime.disconnect();
      client.realtime.reconnectTimer.reset();
    });
  });

  testWidgets(
    'root Settings replacements preserve both controllers and real Retry actions',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = createAppRouterForTesting(initialLocation: '/');
      final google = externalCalendarController(Supabase.instance.client);
      final device = DeviceCalendarController.instance;
      var googleChanges = 0;
      var deviceChanges = 0;
      void onGoogleChanged() => googleChanges++;
      void onDeviceChanged() => deviceChanges++;
      google.addListener(onGoogleChanged);
      device.addListener(onDeviceChanged);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      );
      await drain(tester);
      expect(find.byType(AuthGate), findsOneWidget);
      await tester.runAsync(
        () => Future.wait([google.loadStatus(), device.refreshStatus()]),
      );
      await tester.pump();
      expect(google.status?.available, true);
      expect(device.errorCode, isNull);

      for (var round = 0; round < 3; round++) {
        router.go('/settings');
        await tester.pump();
        await drain(tester);
        expect(find.byType(AuthGate), findsNothing);
        expect(find.byType(ExternalCalendarSettings), findsOneWidget);
        expect(find.byType(DeviceCalendarSettings), findsOneWidget);
        expect(
          externalCalendarController(Supabase.instance.client),
          same(google),
          reason: 'Replacing the root route must not replace the account owner',
        );
        expect(DeviceCalendarController.instance, same(device));
        expectReadyPanels(tester);
        expect(Supabase.instance.client.auth.currentUser?.id, isNotNull);
        if (round < 2) {
          router.go('/');
          await tester.pump();
          await drain(tester);
          expect(find.byType(AuthGate), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }

      await tester.pump(const Duration(seconds: 30));
      await drain(tester);
      expectReadyPanels(tester);
      failStatus = true;
      await tester.runAsync(
        () => Future.wait([google.loadStatus(), device.refreshStatus()]),
      );
      await tester.pump();
      expect(google.error?.code, 'unavailable');
      expect(device.errorCode, 'unavailable');
      expect(
        tester
            .widget<ExternalCalendarPanel>(find.byType(ExternalCalendarPanel))
            .state,
        ExternalCalendarPanelState.offline,
      );
      expect(
        tester
            .widget<DeviceCalendarPanel>(find.byType(DeviceCalendarPanel))
            .state,
        DeviceCalendarPanelState.offline,
      );
      final googleBeforeRetry = googleChanges;
      final deviceBeforeRetry = deviceChanges;
      final statusBeforeRetry = actions
          .where((action) => action == 'status')
          .length;
      final nativeBeforeRetry = actions
          .where((action) => action == 'device_status')
          .length;
      failStatus = false;
      for (final panelType in [
        ExternalCalendarSettings,
        DeviceCalendarSettings,
      ]) {
        final retry = find.descendant(
          of: find.byType(panelType),
          matching: find.text('Retry'),
        );
        await tester.ensureVisible(retry);
        await tester.pump();
        await tester.tap(retry);
        await drain(tester);
      }
      expectReadyPanels(tester);
      expect(googleChanges, greaterThan(googleBeforeRetry));
      expect(deviceChanges, greaterThan(deviceBeforeRetry));
      expect(
        actions.where((action) => action == 'status').length,
        greaterThan(statusBeforeRetry),
      );
      expect(
        actions.where((action) => action == 'device_status').length,
        greaterThan(nativeBeforeRetry),
      );
      expect(
        actions.every((action) => {'status', 'device_status'}.contains(action)),
        true,
      );
      expect(nativeMethods, isNot(contains('requestPermission')));
      google.removeListener(onGoogleChanged);
      device.removeListener(onDeviceChanged);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await tester.runAsync(() async {
        final client = Supabase.instance.client;
        await client.removeAllChannels();
        await client.realtime.disconnect();
        client.realtime.reconnectTimer.reset();
      });
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> sendCalendarLink(WidgetTester tester, String result) async {
    const lane = 'staging';
    final delivered = Completer<void>();
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'com.llfbandit.app_links/events',
      const StandardMethodCodec().encodeSuccessEnvelope(
        'maat://calendar-import?lane=$lane&result=$result',
      ),
      (_) => delivered.complete(),
    );
    await delivered.future;
  }

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Existing overlay grace periods settle after the owning widget unmounts.
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(() async {
      final client = Supabase.instance.client;
      await client.removeAllChannels();
      await client.realtime.disconnect();
      client.realtime.reconnectTimer.reset();
    });
  }

  String replacementSession() {
    final value = jsonDecode(session()) as Map<String, dynamic>;
    (value['user'] as Map<String, dynamic>)['id'] = replacementOwner;
    final tokenParts = (value['access_token'] as String).split('.');
    final claims =
        jsonDecode(
              utf8.decode(base64Url.decode(base64Url.normalize(tokenParts[1]))),
            )
            as Map<String, dynamic>;
    claims['sub'] = replacementOwner;
    tokenParts[1] = base64Url
        .encode(utf8.encode(jsonEncode(claims)))
        .replaceAll('=', '');
    value['access_token'] = tokenParts.join('.');
    return jsonEncode(value);
  }

  for (final retained in [false, true]) {
    testWidgets(
      'Settings replay opens existing onboarding with retained host $retained',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final owner = Supabase.instance.client.auth.currentUser!.id;
        AppRestorationService.debugUserIdResolver = () => owner;
        addTearDown(
          () => AppRestorationService.debugUserIdResolver = () => null,
        );
        final storage = OnboardingProgressStorage();
        final prefs = await SharedPreferences.getInstance();
        final completionKey = 'onboarding_v1_completed:$owner';
        await prefs.setBool(completionKey, true);
        addTearDown(() => prefs.remove(completionKey));
        await storage.saveRequired(
          owner,
          const OnboardingProgress(
            currentStep: TrueOnboardingStep.complete,
            completedOnboarding: true,
            hawSlide: 'complete',
            firstMaatFlowId: '42',
            seenHelpers: {'calendar_toggle'},
          ),
        );
        final router = createAppRouterForTesting(
          initialLocation: retained ? '/' : '/settings',
        );
        await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
        );
        await drain(tester);
        if (retained) {
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 400));
            await drain(tester);
          }
          expect(find.byType(OnboardingOverlay), findsNothing);
          unawaited(router.push<void>('/settings'));
          await drain(tester);
        }
        await tester.ensureVisible(find.text('Replay onboarding'));
        await tester.tap(find.text('Replay onboarding'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 400));
          await drain(tester);
        }
        expect(router.routeInformationProvider.value.uri.path, '/');
        expect(find.byType(OnboardingOverlay), findsOneWidget);
        expect(find.text('REJECT THE GRIND.'), findsOneWidget);
        final replay = await storage.load(owner);
        expect(replay.replayActive, isTrue);
        expect(replay.hawSlide, 'exhale');
        expect(replay.completedOnboarding, isTrue);
        expect(replay.firstMaatFlowId, '42');
        expect(replay.seenHelpers, contains('calendar_toggle'));
        expect(prefs.getBool(completionKey), isTrue);
        await tester.tap(find.text('skip'));
        await drain(tester);
        expect(find.byType(OnboardingOverlay), findsNothing);
        expect((await storage.load(owner)).replayActive, isFalse);
        expect(tester.takeException(), isNull);
        await closeApp(tester);
        router.dispose();
      },
    );
  }

  for (final accountChange in [false, true]) {
    testWidgets(
      'Settings replay fences held checkpoint account change $accountChange',
      (tester) async {
        final previousStore = SharedPreferencesStorePlatform.instance;
        final checkpointStore = ReplayCheckpointPreferences();
        SharedPreferences.setMockInitialValues({});
        SharedPreferencesStorePlatform.instance = checkpointStore;
        addTearDown(() {
          if (!checkpointStore.release.isCompleted) {
            checkpointStore.release.complete();
          }
          SharedPreferencesStorePlatform.instance = previousStore;
          SharedPreferences.setMockInitialValues({});
        });
        final owner = Supabase.instance.client.auth.currentUser!.id;
        final storage = OnboardingProgressStorage();
        await storage.saveRequired(
          owner,
          const OnboardingProgress(completedOnboarding: true),
        );
        checkpointStore.heldOwner = owner;
        checkpointStore.reject = !accountChange;
        final router = createAppRouterForTesting(initialLocation: '/settings');
        await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
        );
        await drain(tester);
        await tester.ensureVisible(find.text('Replay onboarding'));
        await tester.tap(find.text('Replay onboarding'));
        await tester.pump();
        expect(find.text('Opening onboarding…'), findsOneWidget);
        await tester.tap(find.text('Opening onboarding…'));
        await tester.pump();
        expect(checkpointStore.writes, 1);
        expect(router.routeInformationProvider.value.uri.path, '/settings');
        if (accountChange) {
          await tester.runAsync(
            () => Supabase.instance.client.auth.recoverSession(
              replacementSession(),
            ),
          );
          await drain(tester);
        }
        checkpointStore.release.complete();
        await drain(tester);
        expect(router.routeInformationProvider.value.uri.path, '/settings');
        expect(find.byType(OnboardingOverlay), findsNothing);
        if (accountChange) {
          expect((await storage.load(replacementOwner)).replayActive, isFalse);
          expect((await storage.load(owner)).replayActive, isTrue);
        } else {
          expect(
            find.text('Could not restart onboarding. Please try again.'),
            findsOneWidget,
          );
          expect((await storage.load(owner)).replayActive, isFalse);
          expect((await storage.load(owner)).completedOnboarding, isTrue);
        }
        await closeApp(tester);
        router.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final replay in [false, true]) {
    for (final result in ['connected', 'denied', 'reconnect_required']) {
      testWidgets(
        'cold onboarding calendar callback $result replay $replay resumes the saved account',
        (tester) async {
          tester.view.physicalSize = const Size(393, 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final owner = Supabase.instance.client.auth.currentUser!.id;
          final storage = OnboardingProgressStorage();
          await storage.saveRequired(
            owner,
            OnboardingProgress(
              completedOnboarding: replay,
              replayActive: replay,
              hawSlide: 'calendarConnection',
              calendarConnectionPending: true,
            ),
          );
          final router = createAppRouterForTesting(
            initialLocation: '/settings?external_calendar=$result',
          );
          await tester.pumpWidget(
            MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
          );
          await drain(tester);
          expect(find.byType(HawCalendarConnectionPage), findsOneWidget);
          expectReadyPanels(tester);
          expect(nativeMethods, isNot(contains('requestPermission')));
          expect(
            actions.every(
              (action) => {'status', 'device_status'}.contains(action),
            ),
            isTrue,
          );
          await tester.scrollUntilVisible(
            find.text('Continue'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Continue'));
          await drain(tester);
          expect(router.routeInformationProvider.value.uri.path, '/');
          final restored = await storage.load(owner);
          expect(restored.hawSlide, 'segmentation');
          expect(restored.calendarConnectionPending, isFalse);
          expect(restored.completedOnboarding, replay);
          expect(restored.replayActive, replay);
          await closeApp(tester);
          router.dispose();
          await storage.saveRequired(owner, const OnboardingProgress());
        },
      );
    }
  }

  testWidgets(
    'an account switch discards the prior account calendar continuation',
    (tester) async {
      final owner = Supabase.instance.client.auth.currentUser!.id;
      final storage = OnboardingProgressStorage();
      await storage.saveRequired(
        owner,
        const OnboardingProgress(
          hawSlide: 'calendarConnection',
          calendarConnectionPending: true,
        ),
      );
      final router = createAppRouterForTesting(initialLocation: '/settings');
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      );
      await drain(tester);
      expect(find.byType(HawCalendarConnectionPage), findsOneWidget);
      await tester.runAsync(
        () => Supabase.instance.client.auth.setInitialSession(
          replacementSession(),
        ),
      );
      await drain(tester);
      expect(find.byType(HawCalendarConnectionPage), findsNothing);
      expect(
        (await storage.load(replacementOwner)).calendarConnectionPending,
        isFalse,
      );
      expect((await storage.load(owner)).calendarConnectionPending, isTrue);
      await closeApp(tester);
      router.dispose();
      await storage.saveRequired(owner, const OnboardingProgress());
    },
  );

  testWidgets(
    'MyApp starts calendar owners after paint and handles native return on Settings',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = createAppRouterForTesting(initialLocation: '/settings');
      final client = Supabase.instance.client;
      final google = externalCalendarController(client);
      final device = DeviceCalendarController.instance;
      // This callback is queued before MyApp may schedule its startup callback.
      // Current-session startup must leave the first rendered frame unblocked.
      bool? googleBusyAtFirstPaint, deviceBusyAtFirstPaint;
      tester.binding.addPostFrameCallback((_) {
        googleBusyAtFirstPaint = google.busy;
        deviceBusyAtFirstPaint = device.busy;
      });
      await tester.pumpWidget(
        MyApp(router: router, calendarLinkEnvironment: 'staging'),
      );
      expect(googleBusyAtFirstPaint, false);
      expect(deviceBusyAtFirstPaint, false);
      await drain(tester);
      expectReadyPanels(tester);
      expect(actions, containsAll(['status', 'device_status']));
      final actionCount = actions.length;
      final googleGeneration = google.generation;
      final deviceGeneration = device.generation;
      await tester.runAsync(() => client.auth.setInitialSession(session()));
      await drain(tester);
      expect(actions.length, actionCount);
      expect(google.generation, googleGeneration);
      expect(device.generation, deviceGeneration);
      expect(find.byType(AuthGate), findsNothing);
      await sendCalendarLink(tester, 'denied');
      await tester.pump();
      await drain(tester);
      expect(
        find.text(
          'Google Calendar access wasn’t granted. You can try connecting again.',
        ),
        findsOneWidget,
      );
      expect(externalCalendarController(client), same(google));
      expect(DeviceCalendarController.instance, same(device));
      expectReadyPanels(tester);
      expect(client.auth.currentUser?.id, isNotNull);
      await closeApp(tester);
      final afterDispose = actions.length;
      await tester.runAsync(
        () => Future.wait([google.loadStatus(), device.refreshStatus()]),
      );
      expect(
        actions.length,
        afterDispose,
        reason: 'Only actual app disposal retires both owners',
      );
      router.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'MyApp fences pending reads and native return across account replacement and signout',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = createAppRouterForTesting(initialLocation: '/settings');
      final client = Supabase.instance.client;
      final firstOwner = client.auth.currentUser!.id;
      final google = externalCalendarController(client);
      final device = DeviceCalendarController.instance;
      heldOwner = firstOwner;
      await tester.pumpWidget(
        MyApp(router: router, calendarLinkEnvironment: 'staging'),
      );
      await drain(tester);
      expect(pendingReads.keys, containsAll(['status', 'device_status']));
      expect(google.busy, true);
      expect(device.busy, true);
      await sendCalendarLink(tester, 'reconnect_required');
      await tester.runAsync(
        () => client.auth.recoverSession(replacementSession()),
      );
      // The auth observer clears old account presentation before a new frame.
      expect(google.status, isNull);
      expect(device.status.revision, isNull);
      await tester.pump();
      await drain(tester);
      expect(google.status?.accountLabel, replacementOwner);
      expect(google.status?.revision, 2);
      expect(device.status.revision, 2);
      expect(router.routeInformationProvider.value.uri.toString(), '/settings');
      expect(
        find.text(
          'Google Calendar could not finish connecting. Please try again.',
        ),
        findsNothing,
      );
      for (final pending in pendingReads.values) {
        pending.complete();
      }
      await drain(tester);
      expect(google.status?.accountLabel, replacementOwner);
      expect(google.status?.revision, 2);
      expect(device.status.revision, 2);
      expectReadyPanels(tester);

      heldOwner = replacementOwner;
      pendingReads.clear();
      final pendingGoogle = google.loadStatus();
      final pendingDevice = device.refreshStatus();
      await drain(tester);
      expect(pendingReads.keys, containsAll(['status', 'device_status']));
      await sendCalendarLink(tester, 'account_mismatch');
      await tester.runAsync(
        () => client.auth.signOut(scope: SignOutScope.local),
      );
      expect(google.status, isNull);
      expect(device.status.revision, isNull);
      await tester.pump();
      await drain(tester);
      expect(find.byType(ExternalCalendarSettings), findsNothing);
      expect(find.byType(DeviceCalendarSettings), findsNothing);
      expect(router.routeInformationProvider.value.uri.toString(), '/settings');
      for (final pending in pendingReads.values) {
        pending.complete();
      }
      await drain(tester);
      await Future.wait([pendingGoogle, pendingDevice]);
      expect(google.status, isNull);
      expect(google.busy, false);
      expect(device.status.revision, isNull);
      expect(device.busy, false);
      expect(client.auth.currentUser, isNull);
      await closeApp(tester);
      router.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  for (final completesRecovery in [true, false]) {
    testWidgets(
      'MyApp keeps recovery imports stopped and ${completesRecovery ? 'restarts after completion' : 'stays stopped after cancel'}',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final router = createAppRouterForTesting(initialLocation: '/settings');
        final client = Supabase.instance.client;
        final google = externalCalendarController(client);
        final device = DeviceCalendarController.instance;
        await tester.pumpWidget(
          MyApp(router: router, calendarLinkEnvironment: 'staging'),
        );
        await drain(tester);
        expectReadyPanels(tester);
        final fixture = jsonDecode(session()) as Map<String, dynamic>;
        final recoveryUri = Uri(
          scheme: 'maat',
          host: 'auth-callback',
          fragment: Uri(
            queryParameters: {
              'access_token': fixture['access_token'] as String,
              'refresh_token': fixture['refresh_token'] as String,
              'expires_in': '3600',
              'token_type': 'bearer',
              'type': 'recovery',
            },
          ).query,
        );
        await tester.runAsync(() => client.auth.getSessionFromUrl(recoveryUri));
        expect(google.status, isNull);
        expect(device.status.revision, isNull);
        final whileRecovering = actions.length;
        await tester.pump();
        await drain(tester);
        expect(find.byType(PasswordRecoveryScreen), findsOneWidget);
        expect(find.byType(ExternalCalendarSettings), findsNothing);
        await sendCalendarLink(tester, 'denied');
        await tester.pump(const Duration(seconds: 3));
        await drain(tester);
        expect(actions.length, whileRecovering);
        expect(
          router.routeInformationProvider.value.uri.toString(),
          '/settings',
        );
        expect(find.byType(PasswordRecoveryScreen), findsOneWidget);
        final recovery = tester.widget<PasswordRecoveryScreen>(
          find.byType(PasswordRecoveryScreen),
        );
        // These are the existing screen's acknowledged-success/cancel boundaries;
        // password input and server validation have their own screen coverage.
        await tester.runAsync(
          completesRecovery ? recovery.onPasswordUpdated : recovery.onCancel,
        );
        expect(actions.length, whileRecovering);
        await tester.pump();
        await drain(tester);
        expect(find.byType(PasswordRecoveryScreen), findsNothing);
        if (completesRecovery) {
          expect(actions.length, greaterThan(whileRecovering));
          expectReadyPanels(tester);
          expect(client.auth.currentUser, isNotNull);
        } else {
          expect(actions.length, whileRecovering);
          expect(client.auth.currentUser, isNull);
          expect(google.status, isNull);
          expect(device.status.revision, isNull);
          expect(find.byType(ExternalCalendarSettings), findsNothing);
        }
        await closeApp(tester);
        router.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
