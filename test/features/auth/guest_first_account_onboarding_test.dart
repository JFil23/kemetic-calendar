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
          await Supabase.instance.client.auth.recoverSession(jsonEncode(auth));
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
              '/private/tmp/haw-guest-commit-evidence/visuals/first-guide-${start == '/' ? 'calendar' : 'pages'}-${width.toInt()}.png',
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
}
