import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/calendar/calendar_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    for (final family in manifest) {
      final loader = FontLoader(family['family']);
      for (final font in family['fonts']) {
        loader.addFont(rootBundle.load(font['asset']));
      }
      await loader.load();
    }
  });
  for (final width in [320.0, 326.0, 390.0, 768.0, 1280.0]) {
    for (final gregorian in [false, true]) {
      for (final progress in [0.0, .5, 1.0, 1.5, 2.0, 2.5, 3.0]) {
        testWidgets(
          'complete day numerals $width G=$gregorian expansion=$progress',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final boundary = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.dark,
                home: RepaintBoundary(
                  key: boundary,
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: buildCalendarMonthCardPreview(
                        kYear: 2,
                        kMonth: 7,
                        todayDay: 28,
                        showGregorian: gregorian,
                        notesForDay: (_) => const [],
                        expansionLevel:
                            MonthExpansionLevel.values[progress.floor()],
                        expansionProgress: progress % 1 == 0 ? null : progress,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final numerals = find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  w.style?.fontSize == 23 &&
                  int.tryParse(w.data ?? '') != null,
            );
            expect(numerals, findsNWidgets(30));
            for (final element in numerals.evaluate()) {
              final text = element.widget as Text;
              expect(text.textScaler, TextScaler.noScaling);
              final reference = TextPainter(
                text: TextSpan(text: text.data, style: text.style),
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.noScaling,
                maxLines: 1,
              )..layout();
              final paragraph = find.descendant(
                of: find.byWidget(text),
                matching: find.byType(RichText),
              );
              final actual = tester.getRect(paragraph);
              expect(
                actual.width + .01,
                greaterThanOrEqualTo(reference.width),
                reason: '${text.data} must retain its full glyph width',
              );
              final cell = find.ancestor(
                of: find.byWidget(text),
                matching: find.byWidgetPredicate(
                  (w) => w.runtimeType.toString() == '_DayChip',
                ),
              );
              final cellRect = tester.getRect(cell);
              expect(actual.left, greaterThanOrEqualTo(cellRect.left - .01));
              expect(actual.right, lessThanOrEqualTo(cellRect.right + .01));
              reference.dispose();
            }
            expect(tester.takeException(), isNull);
            if (!gregorian && progress == 0) {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final image = await render.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  '/tmp/haw-guest-brand-numeral-evidence/calendar-${width.toInt()}.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          },
        );
      }
    }
  }
}
