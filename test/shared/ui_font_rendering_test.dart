import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_fonts.dart';

import '../support/maat_flow_visual_test_fonts.dart';

void main() {
  setUpAll(loadMaatFlowVisualTestFonts);

  test('UI consumers keep the shared web-compatible font selection', () {
    final bypasses = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('core/theme/app_fonts.dart'))
        .where(
          (file) => RegExp(
            r'''['"]Inter(?:Web)?['"]''',
          ).hasMatch(file.readAsStringSync()),
        )
        .map((file) => file.path)
        .toList();
    expect(
      bypasses,
      isEmpty,
      reason:
          'Use AppFonts.ui so new surfaces retain the web compatibility fix.',
    );
  });

  test('the deployed UI font contains real glyph outlines', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final family = manifest.singleWhere(
      (dynamic item) => item['family'] == AppFonts.webUi,
    );
    final faces = family['fonts'] as List<dynamic>;
    expect(faces, hasLength(1));
    final bytes = await rootBundle.load(faces.single['asset'] as String);
    final tableCount = bytes.getUint16(4);
    final tables = <String, int>{};
    for (var i = 0; i < tableCount; i++) {
      final start = 12 + i * 16;
      final tag = String.fromCharCodes(
        List.generate(4, (j) => bytes.getUint8(start + j)),
      );
      tables[tag] = bytes.getUint32(start + 12);
    }
    expect(
      tables,
      isNot(contains('fvar')),
      reason: 'The web UI face must be static.',
    );
    expect(tables, isNot(contains('gvar')));
    expect(tables['glyf'], greaterThan(10000));
    expect(tables['cmap'], greaterThan(100));
  });

  for (final weight in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
  ]) {
    testWidgets('UI labels paint visible ink at weight ${weight.value}', (
      tester,
    ) async {
      final key = GlobalKey();
      addTearDown(tester.view.reset);
      for (final size in [
        const Size(390, 844),
        const Size(844, 390),
        const Size(390, 844),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final label in [
          'FLOW',
          '90 DAYS',
          'CALENDAR',
          'Notes',
          'Search all of ḥꜣw',
          '@render-check',
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                    color: Colors.black,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppFonts.webUi,
                        fontSize: 8,
                        height: 1,
                        letterSpacing: 1.6,
                        fontWeight: weight,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final ink = await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 3);
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            var ink = 0;
            for (var i = 0; i < pixels.lengthInBytes; i += 4) {
              if (pixels.getUint8(i) > 32) ink++;
            }
            image.dispose();
            return ink;
          });
          expect(
            ink,
            greaterThan(label.length * 5),
            reason:
                '$label must paint, not merely exist in the widget/semantics tree at size $size.',
          );
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
}
