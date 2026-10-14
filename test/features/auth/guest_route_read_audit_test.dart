import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/account_invitation_dialog.dart';
import 'package:mobile/features/auth/guest_experience_host.dart';
import 'package:mobile/features/auth/visitor_preferences.dart';
import 'guest_experience_test.dart' show flush;
import 'package:mobile/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final channel in [
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages',
      'receive_sharing_intent/events-media',
      'receive_sharing_intent/events-text',
      'receive_sharing_intent/messages',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family']);
      for (final a in font['fonts']) {
        loader.addFont(rootBundle.load(a['asset']));
      }
      await loader.load();
    }
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final location in [
    '/flows',
    '/flows?mode=myFlows',
    '/flows?mode=maatFlows',
    '/flows?create=flow',
    '/inbox',
    '/calendars',
    '/profile/me',
    '/profile/me/edit',
    '/profile/flow-post-picker',
    '/profile/insight-post-picker',
    '/profile-search',
    '/rhythm/today',
    '/rhythm/todo',
    '/rhythm/editor/timed',
    '/rhythm/editor/untimed',
    '/inbox/conversation/person',
    '/inbox/dm/thread',
  ]) {
    for (final width in [
      390.0,
      if ({
        '/flows?create=flow',
        '/profile/me/edit',
        '/inbox/conversation/person',
        '/rhythm/editor/timed',
      }.contains(location)) ...[
        768.0,
        1440.0,
      ],
    ]) {
      testWidgets(
        'canonical guest owner $location at $width does not read private data or invite on open',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            VisitorPreferences.introSeenKey: true,
            VisitorPreferences.invitationSeenKey: true,
          });
          requests.clear();
          tester.view.physicalSize = Size(width, width == 768 ? 1024 : 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final uri = Uri.parse(location);
          // Reuse the real route entries to audit their signed-out read owners.
          // The production guest redirect is the boundary under review, not a test
          // substitute for repository permissions or authenticated content.
          final canonical = app.createAppRouterForTesting(
            initialLocation: location,
          );
          final router = GoRouter(
            navigatorKey: canonical.routerDelegate.navigatorKey,
            initialLocation: location,
            routes: canonical.configuration.routes,
          );
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
                  onGoogleSignIn: (_) async {},
                  child: child!,
                ),
              ),
            ),
          );
          await flush(tester);
          expect(find.byType(AccountInvitationDialog), findsNothing);
          expect(
            requests.where((r) => !r.url.path.endsWith('/app_events')),
            isEmpty,
            reason: 'No private reads or guest writes may start on mount',
          );
          expect(tester.takeException(), isNull);
          if (location == '/calendars') {
            await tester.tap(find.byTooltip('New calendar'));
            await flush(tester);
            expect(find.byType(AccountInvitationDialog), findsNothing);
            final field = find.byType(TextField).first;
            await tester.enterText(field, 'Guest calendar draft');
            expect(requests, isEmpty);
            await tester.tap(find.text('Save').hitTestable());
            await flush(tester);
            expect(find.byType(AccountInvitationDialog), findsOneWidget);
            expect(requests, isEmpty);
            await tester.tap(find.byTooltip('Keep exploring'));
            await flush(tester);
            expect(find.byType(AccountInvitationDialog), findsNothing);
            expect(
              tester.widget<TextField>(field).controller!.text,
              'Guest calendar draft',
            );
            expect(requests, isEmpty);
          }
          if (uri.path.startsWith('/inbox/') ||
              uri.queryParameters['create'] == 'flow') {
            final field = find.byType(TextField).first;
            await tester.enterText(field, 'Guest draft kept here');
            await tester.pump();
            expect(
              tester.widget<TextField>(field).controller!.text,
              'Guest draft kept here',
            );
            expect(find.byType(AccountInvitationDialog), findsNothing);
            expect(requests, isEmpty);
          }
          if ({
            '/flows?create=flow',
            '/profile/me/edit',
            '/inbox/conversation/person',
            '/rhythm/editor/timed',
          }.contains(location)) {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await render.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final label = location.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-');
              final file = File(
                '/private/tmp/haw-guest-commit-evidence/visuals/$label-${width.toInt()}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          await Supabase.instance.client.removeAllChannels();
          router.dispose();
          canonical.dispose();
        },
      );
    }
  }
}
