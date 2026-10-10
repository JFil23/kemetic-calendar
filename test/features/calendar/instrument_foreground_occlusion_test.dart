import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/presentation/instrument_event_presentation_frame.dart';

void main() {
  testWidgets(
    'foreground paints over stationary artwork during partial scroll',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const capture = ValueKey('occlusion-capture');
      const scroll = ValueKey('foreground-scroll');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: capture,
              child: InstrumentEventPresentationFrame(
                decoration: const BoxDecoration(color: Colors.black),
                instrument: const SizedBox.shrink(),
                instrumentFooter: const SizedBox.shrink(),
                inputBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xffff0000)),
                body: const SizedBox(height: 900),
                bodyScrollKey: scroll,
                lowerSheetKey: const ValueKey('foreground'),
                graphicSpace: const MaatDayViewGraphicSpace.fixed(height: 354),
                foregroundStyle: const MaatDayViewForegroundStyle.color(
                  color: Color(0xff0000ff),
                  borderColor: Colors.blue,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.byKey(scroll), const Offset(0, -160));
      await tester.pumpAndSettle();
      final foreground = tester.getTopLeft(
        find.byKey(const ValueKey('foreground')),
      );
      expect(foreground.dy, lessThan(300));
      expect(foreground.dy, greaterThan(0));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(capture),
      );
      final pixel = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final offset = (300 * image.width + 195) * 4;
        final color = bytes.buffer.asUint8List(offset, 4).toList();
        image.dispose();
        return color;
      });
      // Geometry assertions alone missed the first sliver painting on top.
      expect(pixel, [0, 0, 255, 255]);
    },
  );
}
