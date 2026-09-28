import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  setUpAll(() async {
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
  Widget preview(MonthExpansionLevel level) => buildCalendarMonthCardPreview(
    kYear: 2,
    kMonth: 7,
    todayDay: 11,
    notesForDay: (_) => [],
    expansionLevel: level,
  );

  testWidgets('calendar preview visual reference', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [const Size(393, 852), const Size(852, 393)]) {
      tester.view.physicalSize = size;
      for (final level in MonthExpansionLevel.values) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: RepaintBoundary(
                key: key,
                child: SingleChildScrollView(child: preview(level)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final directory = Platform.environment['HAW_CALENDAR_CAPTURE_DIR'];
        if (directory != null) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(directory).create(recursive: true);
            await File(
              '$directory/${level.name}-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    }
  });

  testWidgets('calendar previews do not share main calendar anchor identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: Column(
            children: [
              preview(MonthExpansionLevel.compact),
              preview(MonthExpansionLevel.details),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
