import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/daily_cosmic_context_badge.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMaatFlowVisualTestFonts);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final size in [
      const Size(390, 844),
      const Size(320, 640),
      const Size(844, 390),
    ]) {
      for (final scale in [1.0, 2.0]) {
        for (final enabled in [true, false]) {
          testWidgets(
            'Rhythm card fits $platform $size at $scale, on: $enabled',
            (tester) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = size;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(tester.view.reset);
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              final boundary = GlobalKey();
              await tester.pumpWidget(
                MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.dark.copyWith(platform: platform),
                  home: RepaintBoundary(
                    key: boundary,
                    child: Scaffold(
                      body: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
                          child: Center(
                            child: DailyCosmicContextCard(
                              badge: dailyCosmicContextBadgeForDate(
                                DateTime(2026, 10, 9),
                              )!,
                              automaticDisplay: enabled,
                              onDismiss: () {},
                              onAutomaticDisplayChanged: (_) {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final toggle = tester.getRect(
                find.byKey(dailyCosmicContextAutomaticToggleKey),
              );
              final close = tester.getRect(
                find.byKey(dailyCosmicContextDismissButtonKey),
              );
              expect(toggle.right, lessThanOrEqualTo(close.left));
              expect(close.right, lessThan(size.width));
              final output = Platform.environment['HAW_RHYTHM_CAPTURE'];
              if (output != null) {
                final rendered =
                    boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                await tester.runAsync(() async {
                  final image = await rendered.toImage(pixelRatio: 2);
                  final bytes = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await Directory(output).create(recursive: true);
                  await File(
                    '$output/card-${platform.name}-${size.width.toInt()}-$scale-${enabled ? 'on' : 'off'}.png',
                  ).writeAsBytes(bytes!.buffer.asUint8List());
                  image.dispose();
                });
              }
            },
          );
        }
      }
    }
  }
}
