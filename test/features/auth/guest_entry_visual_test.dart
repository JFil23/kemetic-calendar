import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/core/navigation_persistence_policy.dart';
import 'package:mobile/services/app_navigation_restoration_controller.dart';
import 'package:mobile/services/app_restoration_service.dart';
import 'package:mobile/services/app_window_service.dart';
import 'package:mobile/services/restoration_coordinator.dart';
import 'package:mobile/features/auth/visitor_preferences.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/pages/pages_page.dart';
import 'package:mobile/features/pages/pages_board.dart';
import 'package:mobile/features/pages/pages_models.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/account_invitation_dialog.dart';
import 'package:mobile/features/onboarding/onboarding_overlay.dart';
import 'package:mobile/features/pages/guest_pages_content.dart';
import 'package:mobile/features/pages/pages_layout.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/auth/guest_experience_host.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

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
  testWidgets(
    'guest Pages Calendar opens despite a previous account deferred launch',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        VisitorPreferences.introSeenKey: true,
        VisitorPreferences.invitationSeenKey: true,
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      final restoration = AppRestorationService.instance;
      AppWindowService.debugWindowIdResolver = () async => 'guest-entry-window';
      AppWindowService.instance.resetForTesting();
      AppRestorationService.debugUserIdResolver = () => 'previous-account';
      AppRestorationService.debugRemoteSnapshotWriter = (_, _, _, _) async {};
      addTearDown(() {
        app.resetBootRestorationForTesting();
        RestorationCoordinator.instance.beginLaunchRestore(
          reason: RestorationRestoreReason.coldLaunch,
          targetLocation: '/',
        );
        AppRestorationService.debugUserIdResolver = null;
        AppRestorationService.debugRemoteSnapshotWriter = null;
        AppWindowService.debugWindowIdResolver = null;
        AppWindowService.instance.resetForTesting();
        AppNavigationRestorationController.instance.resetForTesting();
      });
      late SharedPreferences prefs;
      late String? originalSnapshot;
      late String? launch;
      const oldAccountKey =
          'app_restoration_v1:previous-account:guest-entry-window';
      // Use the real asynchronous persistence boundary rather than keeping
      // service writes queued inside the widget test's simulated clock.
      await tester.runAsync(() async {
        await AppNavigationRestorationController.instance.recordVisibleSurface(
          route: '/inbox',
          source: NavigationSource.userPrimaryTab,
        );
        await restoration.flushPendingWrites();
        prefs = await SharedPreferences.getInstance();
        originalSnapshot = prefs.getString(oldAccountKey);
        expect(originalSnapshot, isNotNull);
        AppRestorationService.debugUserIdResolver = () => null;
        final snapshot = await restoration.readBestSnapshot(
          includeRemote: false,
        );
        expect(snapshot.status, AppRestorationReadStatus.tentative);
        expect(snapshot.snapshot!.userId, 'previous-account');
        expect(snapshot.snapshot!.routeLocation, '/inbox');
        launch = await app.readBootRestoredLocationForTesting();
        expect(launch, '/pages');
        expect(app.deferredBootRestoredLocationForTesting, '/inbox');
      });
      RestorationCoordinator.instance.beginLaunchRestore(
        reason: RestorationRestoreReason.coldLaunch,
        targetLocation: app.deferredBootRestoredLocationForTesting ?? launch,
      );
      requests.clear();
      final router = app.createAppRouterForTesting(initialLocation: launch!);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: app.MyApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PagesPage), findsOneWidget);
      final calendarTile = find.byWidgetPredicate(
        (w) =>
            w is PagesTile && w.card.destination == PagesDestination.calendar,
      );
      await tester.ensureVisible(calendarTile);
      await tester.tap(calendarTile);
      await tester.pump();
      // The first Calendar frame must render even before auth emits again.
      expect(find.byType(CalendarPage), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Pages').hitTestable(), findsOneWidget);
      expect(find.byType(AccountInvitationDialog), findsNothing);
      expect(app.deferredBootRestoredLocationForTesting, '/inbox');
      expect(prefs.getString(oldAccountKey), originalSnapshot);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          '/tmp/haw-guest-entry/guest-calendar-restored-launch.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await Supabase.instance.client.removeAllChannels();
      router.dispose();
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(320, 568),
    const Size(1024, 768),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('guest entry ${size.width}x${size.height} $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final content = GuestPagesContent(DateTime(2026, 10, 13));
        addTearDown(content.dispose);
        final boundary = GlobalKey();
        Widget app(Widget child) => MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: RepaintBoundary(key: boundary, child: child),
        );
        final pages = PagesLayout(
          cards: content.cards,
          onOpen: (_) {},
          onProfile: () {},
          onNewNote: () {},
          onSearchResult: (_) {},
          searchRecords: content.searchRecords,
          profileIdentity: const PagesProfileIdentity.visitor(),
        );
        for (final entry in <String, Widget>{
          'intro': const Scaffold(
            backgroundColor: HawIntroSlide.backgroundColor,
            body: HawIntroSlide(
              line1Visible: true,
              line2Visible: true,
              wordmarkVisible: true,
              reduceMotion: true,
            ),
          ),
          'pages': pages,
          'invitation': Stack(
            children: [
              pages,
              AccountInvitationDialog(
                onGoogleSignIn: () async {},
                onDismiss: () {},
              ),
            ],
          ),
        }.entries) {
          await tester.pumpWidget(app(entry.value));
          await tester.pumpAndSettle();
          final layoutError = tester.takeException();
          if (entry.key == 'intro') {
            expect(find.text('REJECT THE GRIND.'), findsOneWidget);
            expect(find.text('EMBRACE YOUR RHYTHM.'), findsOneWidget);
            final viewport = tester.getRect(
              find.byType(SingleChildScrollView).first,
            );
            for (final copy in [
              'REJECT THE GRIND.',
              'EMBRACE YOUR RHYTHM.',
              'this is ḥꜣw',
            ]) {
              final rect = tester.getRect(find.text(copy));
              expect(rect.top, greaterThanOrEqualTo(viewport.top));
              expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
            }
          } else if (entry.key == 'pages') {
            expect(
              find.descendant(
                of: find.byType(AppBar),
                matching: find.text('ḥꜣw'),
              ),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: find.byType(AppBar),
                matching: find.byIcon(Icons.person_outline),
              ),
              findsNothing,
            );
            expect(find.text('Loading…'), findsNothing);
          } else {
            expect(find.text('Keep exploring').hitTestable(), findsOneWidget);
            expect(find.text('Create account'), findsOneWidget);
          }
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          render.markNeedsPaint();
          await tester.pump();
          await tester.runAsync(() async {
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '/tmp/haw-guest-entry/${entry.key}-${size.width.toInt()}x${size.height.toInt()}-$scale.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          expect(layoutError, isNull, reason: entry.key);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  // Capture the production builder boundary, without a test Scaffold supplying
  // the sizing or DefaultTextStyle that the visitor host itself must own.
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(320, 568),
    const Size(1024, 768),
    const Size(1280, 720),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('root guest intro ${size.width}x${size.height} $scale', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        final router = GoRouter(
          initialLocation: '/pages',
          routes: [
            GoRoute(
              path: '/pages',
              builder: (_, _) => const Scaffold(
                body: Center(child: Text('Public Pages underneath')),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.dark,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: RepaintBoundary(
                key: boundary,
                child: GuestExperienceHost(
                  router: router,
                  onGoogleSignIn: (_) async {},
                  child: child!,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.byKey(const ValueKey('visitor-intro'))),
          Rect.fromLTWH(0, 0, size.width, size.height),
        );
        final viewport = tester.getRect(
          find.byType(SingleChildScrollView).first,
        );
        for (final copy in [
          'REJECT THE GRIND.',
          'EMBRACE YOUR RHYTHM.',
          'this is ḥꜣw',
        ]) {
          final text = find.text(copy);
          expect(text, findsOneWidget);
          final rect = tester.getRect(text);
          expect(rect.top, greaterThanOrEqualTo(viewport.top));
          expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
          final rich = tester.widget<RichText>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          expect(
            rich.text.style?.decoration?.contains(TextDecoration.underline) ??
                false,
            isFalse,
          );
        }
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '/tmp/haw-guest-entry/root-intro-${size.width.toInt()}x${size.height.toInt()}-$scale.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        router.dispose();
      });
    }
  }

  testWidgets(
    'reduced-motion entry paints a real dissolve before enabling Pages',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      final content = GuestPagesContent(DateTime(2026, 10, 13));
      final router = GoRouter(
        initialLocation: '/pages',
        routes: [
          GoRoute(
            path: '/pages',
            builder: (_, _) => PagesLayout(
              cards: content.cards,
              onOpen: (_) {},
              onProfile: () {},
              onNewNote: () {},
              onSearchResult: (_) {},
              searchRecords: content.searchRecords,
              profileIdentity: const PagesProfileIdentity.visitor(),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: true, accessibleNavigation: true),
            child: RepaintBoundary(
              key: boundary,
              child: GuestExperienceHost(
                router: router,
                onGoogleSignIn: (_) async {},
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<List<int>> capture(String name) async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        return (await tester.runAsync(() async {
          final image = await render.toImage();
          final rgba = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('/tmp/haw-guest-entry/dissolve-$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(png!.buffer.asUint8List());
          final bytes = rgba!.buffer.asUint8List().toList();
          image.dispose();
          return bytes;
        }))!;
      }

      final before = await capture('intro');
      await tester.pump(const Duration(milliseconds: 2800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final fade = tester.widget<FadeTransition>(
        find.byKey(const ValueKey('visitor-intro-dissolve')),
      );
      expect(fade.opacity.value, closeTo(.5, .02));
      expect(find.byType(HawIntroSlide), findsOneWidget);
      expect(find.byTooltip('New note').hitTestable(), findsNothing);
      final middle = await capture('middle');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(HawIntroSlide), findsNothing);
      expect(find.byTooltip('New note').hitTestable(), findsOneWidget);
      final after = await capture('pages');
      // Check the painted blend itself, including the visible intro and Pages
      // pixels. A duration/controller assertion alone cannot catch a hard cut.
      var changedChannels = 0;
      var blendError = 0.0;
      for (var i = 0; i < before.length; i++) {
        if (i % 4 == 3 || (before[i] - after[i]).abs() < 40) continue;
        changedChannels++;
        blendError += (middle[i] - (before[i] + after[i]) / 2).abs();
      }
      expect(changedChannels, greaterThan(1000));
      expect(blendError / changedChannels, lessThan(4));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      router.dispose();
      content.dispose();
    },
  );
}
