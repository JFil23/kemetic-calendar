import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/services/app_navigation_restoration_controller.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/services/restoration_coordinator.dart';
import 'package:mobile/features/auth/visitor_preferences.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/daily_cosmic_context_badge.dart';
import 'package:mobile/features/pages/pages_board.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:mobile/features/auth/account_invitation_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

import 'guest_experience_test.dart' show flush;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final channel in [
      'receive_sharing_intent/events-media',
      'receive_sharing_intent/events-text',
      'receive_sharing_intent/messages',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    for (final name in ['messages', 'events']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('com.llfbandit.app_links/$name'),
            (_) async => null,
          );
    }
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await loadMaatFlowVisualTestFonts();
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family']);
      for (final asset in font['fonts']) {
        loader.addFont(rootBundle.load(asset['asset']));
      }
      await loader.load();
    }
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final size in [
    const Size(326, 664),
    const Size(768, 1024),
    const Size(1280, 800),
  ]) {
    for (final dismissInvitation in [false, true]) {
      testWidgets('fresh guest Calendar renders without an account snapshot '
          '${size.width.toInt()} after invitation=$dismissInvitation', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          VisitorPreferences.introSeenKey: true,
          VisitorPreferences.invitationSeenKey: dismissInvitation,
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        AppWindowService.debugWindowIdResolver = () async =>
            'fresh-guest-${size.width}-$dismissInvitation';
        AppWindowService.instance.resetForTesting();
        AppRestorationService.debugUserIdResolver = () => null;
        addTearDown(() {
          app.resetBootRestorationForTesting();
          AppRestorationService.debugUserIdResolver = null;
          AppWindowService.debugWindowIdResolver = null;
          AppWindowService.instance.resetForTesting();
          AppNavigationRestorationController.instance.resetForTesting();
        });
        late String launch;
        await tester.runAsync(() async {
          final snapshot = await AppRestorationService.instance
              .readBestSnapshot(includeRemote: false);
          expect(snapshot.status, AppRestorationReadStatus.awaitingAuth);
          expect(snapshot.snapshot, isNull);
          launch = (await app.readBootRestoredLocationForTesting())!;
        });
        expect(launch, '/pages');
        RestorationCoordinator.instance.beginLaunchRestore(
          reason: RestorationRestoreReason.coldLaunch,
          targetLocation: launch,
        );
        final router = app.createAppRouterForTesting(initialLocation: launch);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: app.MyApp(router: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(dailyCosmicContextOverlayKey), findsOneWidget);
        await tester.tap(find.byKey(dailyCosmicContextDismissButtonKey));
        await tester.pumpAndSettle();
        expect(find.byKey(dailyCosmicContextOverlayKey), findsNothing);
        // Supabase's initial signed-out event is already delivered before
        // Calendar mounts. No later auth event may be needed for first paint.
        if (dismissInvitation) {
          await tester.tap(find.byTooltip('New note'));
          await flush(tester);
          await tester.enterText(
            find.byKey(const ValueKey('quick-add-input')),
            'Guest calendar draft',
          );
          await tester.tap(
            find.byKey(const ValueKey('quick-add-submit-button')),
          );
          await tester.pumpAndSettle();
          await flush(tester);
          expect(find.byType(AccountInvitationDialog), findsOneWidget);
          await tester.tap(find.byTooltip('Keep exploring'));
          await tester.pumpAndSettle();
          await flush(tester);
          expect(find.byType(AccountInvitationDialog), findsNothing);
          await tester.tap(find.byKey(const ValueKey('quick-add-close')));
          await tester.pumpAndSettle();
        }
        requests.clear();
        final calendarTile = find.byWidgetPredicate(
          (w) =>
              w is PagesTile && w.card.destination == PagesDestination.calendar,
        );
        await tester.ensureVisible(calendarTile);
        await tester.tap(calendarTile);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/');
        expect(find.byType(CalendarPage), findsOneWidget);
        expect(find.byTooltip('Pages').hitTestable(), findsOneWidget);
        expect(find.text('30').hitTestable(), findsWidgets);
        expect(find.byType(AccountInvitationDialog), findsNothing);
        expect(requests, isEmpty);
        expect(tester.takeException(), isNull);
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '/tmp/haw-guest-fresh-calendar/'
            'calendar-${size.width.toInt()}-$dismissInvitation.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await Supabase.instance.client.removeAllChannels();
        router.dispose();
      });
    }
  }
}
