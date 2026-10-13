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
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  setUpAll(() async {
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
}
