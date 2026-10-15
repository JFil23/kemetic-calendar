import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/snapshot/calendar_snapshot_runtime.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/guest_experience_host.dart';
import 'package:mobile/features/auth/account_access.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/account_invitation_dialog.dart';
import 'package:mobile/features/auth/visitor_preferences.dart';
import 'package:mobile/features/onboarding/onboarding_overlay.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/pages_resource_test.dart' show session, uid;
import 'guest_experience_test.dart' show flush;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  Completer<void>? completionGate;
  var completionReads = 0;
  late Directory storage;
  setUpAll(() async {
    storage = Directory.systemTemp.createTempSync('first-account-guide-');
    Hive.init(storage.path);
    SharedPreferences.setMockInitialValues({});
    for (final channel in [
      'receive_sharing_intent/events-media',
      'receive_sharing_intent/events-text',
      'receive_sharing_intent/messages',
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/profiles') &&
            r.url.queryParameters['select'] == 'onboarding_completed_at') {
          completionReads++;
          final gate = completionGate;
          if (gate != null) await gate.future;
        }
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
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family']);
      for (final a in font['fonts']) {
        loader.addFont(rootBundle.load(a['asset']));
      }
      await loader.load();
    }
    await calendarSnapshotStore.initialize();
  });
  tearDownAll(() async {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await Supabase.instance.dispose();
    // Process-wide Hive owners live until this isolated Flutter worker exits.
    // Keep their temporary files as evidence instead of closing shared stores
    // while disposal writes from the app are still draining.
  });
  setUp(() async {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    SharedPreferences.setMockInitialValues({
      VisitorPreferences.introSeenKey: true,
    });
    requests.clear();
    completionGate = null;
    completionReads = 0;
  });
  for (final start in ['/pages', '/']) {
    for (final width in [390.0, 768.0, 1440.0]) {
      testWidgets(
        'first account starts at intention picker above retained draft from $start at $width',
        (tester) async {
          tester.view.physicalSize = Size(width, width == 768 ? 1024 : 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var now = Duration.zero;
          final router = app.createAppRouterForTesting(initialLocation: start);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.dark,
                routerConfig: router,
                builder: (_, child) => GuestExperienceHost(
                  router: router,
                  activityNow: () => now,
                  onGoogleSignIn: (_) async {},
                  child: child!,
                ),
              ),
            ),
          );
          await flush(tester);
          await tester.tap(find.byTooltip('New note'));
          await flush(tester);
          final input = find.byKey(const ValueKey('quick-add-input'));
          expect(input, findsOneWidget);
          await tester.enterText(input, 'My untouched guest draft');
          expect(find.byType(AccountInvitationDialog), findsNothing);
          for (var i = 0; i < 8; i++) {
            await tester.tap(input);
            now += const Duration(milliseconds: 700);
            await tester.pump(const Duration(milliseconds: 700));
          }
          await flush(tester);
          expect(find.byType(AccountInvitationDialog), findsOneWidget);
          final auth = jsonDecode(session()) as Map<String, dynamic>;
          (auth['user'] as Map)['created_at'] = DateTime.now()
              .toUtc()
              .toIso8601String();
          final gate = completionGate = Completer<void>();
          await Supabase.instance.client.auth.recoverSession(jsonEncode(auth));
          await flush(tester);
          expect(completionReads, greaterThan(0));
          // A slow verified completion read must leave the sign-in housing
          // covering the retained draft. This was the live recording's gap.
          await tester.pump(const Duration(seconds: 3));
          expect(find.byType(AccountInvitationDialog), findsOneWidget);
          expect(find.byType(OnboardingOverlay), findsNothing);
          expect(input.hitTestable(), findsNothing);
          completionGate = null;
          gate.complete();
          // Observe every transition frame, rather than only asserting the
          // eventual picker after the Calendar has finished its startup.
          var pickerPresented = false;
          for (var frame = 0; frame < 60; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            final invited = find
                .byType(AccountInvitationDialog)
                .evaluate()
                .isNotEmpty;
            final guide = find.byType(OnboardingOverlay).evaluate().isNotEmpty;
            expect(
              invited || guide,
              isTrue,
              reason: 'uncovered handoff frame $frame',
            );
            if (guide) pickerPresented = true;
          }
          expect(
            pickerPresented,
            isTrue,
            reason: 'The picker must not wait for Calendar hydration.',
          );
          for (var i = 0; i < 4; i++) {
            await flush(tester);
          }
          expect(find.byType(AccountInvitationDialog), findsNothing);
          expect(find.byType(OnboardingOverlay), findsOneWidget);
          expect(
            find.text('What brought you here today?').hitTestable(),
            findsOneWidget,
          );
          expect(find.byType(HawIntroSlide), findsNothing);
          expect(find.byType(CalendarPage), findsOneWidget);
          expect(
            (await OnboardingProgressStorage().load(uid)).hawSlide,
            'segmentation',
          );
          expect(
            requests.where(
              (r) =>
                  r.url.path.contains('create_user_event') ||
                  r.url.path.contains('decan_reflections'),
            ),
            isEmpty,
          );
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '${Directory.systemTemp.path}/haw-guest-commit-evidence/visuals/first-guide-${start == '/' ? 'calendar' : 'pages'}-${width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.tap(find.text('skip').hitTestable());
          await flush(tester);
          expect(find.byType(OnboardingOverlay), findsNothing);
          expect(
            tester.widget<TextField>(input).controller!.text,
            'My untouched guest draft',
          );
          expect(
            requests.where((r) => r.url.path.contains('create_user_event')),
            isEmpty,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          await Supabase.instance.client.removeAllChannels();
          router.dispose();
        },
      );
    }
  }
  for (final completedAccount in [false, true]) {
    testWidgets(
      completedAccount
          ? 'completed account returns to browsing without a first-account guide'
          : 'departure during a held completion read cancels the guide',
      (tester) async {
        if (completedAccount) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('onboarding_v1_completed:$uid', true);
        }
        final router = GoRouter(
          initialLocation: '/pages',
          routes: [
            GoRoute(
              path: '/pages',
              builder: (context, _) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => AccountAccess.require(context),
                    child: const Text('Retained browsing'),
                  ),
                ),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            builder: (_, child) => GuestExperienceHost(
              router: router,
              onGoogleSignIn: (_) async {},
              child: child!,
            ),
          ),
        );
        await flush(tester);
        await tester.tap(find.text('Retained browsing'));
        await flush(tester);
        expect(find.byType(AccountInvitationDialog), findsOneWidget);
        final gate = completedAccount ? null : Completer<void>();
        completionGate = gate;
        await Supabase.instance.client.auth.recoverSession(session());
        await flush(tester);
        if (completedAccount) {
          expect(completionReads, 0);
        } else {
          expect(completionReads, greaterThan(0));
          expect(find.byType(AccountInvitationDialog), findsOneWidget);
          // Supabase logout uses its real async storage/HTTP boundary. Do not
          // await that work while the widget clock is paused.
          await tester.runAsync(() async {
            await Supabase.instance.client.auth
                .signOut(scope: SignOutScope.local)
                .timeout(const Duration(seconds: 10));
          });
          await flush(tester);
          completionGate = null;
          gate!.complete();
        }
        await flush(tester);
        await flush(tester);
        expect(find.byType(AccountInvitationDialog), findsNothing);
        expect(find.byType(OnboardingOverlay), findsNothing);
        expect(find.byType(CalendarPage), findsNothing);
        expect(find.text('Retained browsing').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        router.dispose();
      },
    );
  }
}
