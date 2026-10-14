import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
      url: 'https://example.supabase.co',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
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
          profileHandle: 'Explore ḥꜣw',
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
            expect(find.text('Explore ḥꜣw'), findsOneWidget);
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
}
