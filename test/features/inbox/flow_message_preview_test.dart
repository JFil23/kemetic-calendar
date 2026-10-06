import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/inbox/presentation/flow_message_preview.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  setUpAll(loadMaatFlowVisualTestFonts);

  for (final width in [320.0, 390.0, 844.0]) {
    testWidgets('image and empty color previews at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final data = await rootBundle.load(
        'assets/the_reading_house/reference_hero.jpg',
      );
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      const capture = ValueKey('flow-message-preview-capture');
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: RepaintBoundary(
              key: capture,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: FlowMessagePreview(
                        title: 'The Reading House',
                        appearance: const FlowAppearance(
                          imageObjectPath: 'reference.jpg',
                        ),
                        color: 0xFF6F93A8,
                        localImageBytes: bytes,
                        allowImageFetch: false,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: FlowMessagePreview(
                        title: 'Follow the sky',
                        appearance: FlowAppearance.empty,
                        color: 0xFFD1AF32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    MediaQuery(
                      data: MediaQueryData(textScaler: TextScaler.linear(2)),
                      child: const Align(
                        alignment: Alignment.centerRight,
                        child: FlowMessagePreview(
                          title: 'A longer flow title that stays readable',
                          appearance: FlowAppearance(
                            signKind: FlowSignKind.palmCount,
                          ),
                          color: 0xFF6F93A8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(bytes),
          tester.element(find.byType(Scaffold)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The Reading House'), findsOneWidget);
      expect(find.text('Follow the sky'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('user-flow-appearance-image-layer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('user-flow-appearance-fallback-layer')),
        findsNWidgets(2),
      );
      expect(
        find.byKey(const ValueKey('user-flow-appearance-sign-layer')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      final folder = Platform.environment['HAW_FLOW_PREVIEW_CAPTURE_DIR'];
      if (folder != null) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          final rendered = await boundary.toImage();
          final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
          await Directory(folder).create(recursive: true);
          await File(
            '$folder/flow-preview-${width.toInt()}.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          rendered.dispose();
        });
      }
    });
  }
}
