import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';
import '../support/maat_flow_visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMaatFlowVisualTestFonts);
  final draftPath = Platform.environment['HAW_RENWET_DRAFT'];
  final draft = draftPath == null
      ? null
      : jsonDecode(File(draftPath).readAsStringSync()) as List;
  for (final size in [
    const Size(390, 844),
    const Size(320, 740),
    const Size(844, 390),
  ]) {
    testWidgets(
      'Renwet cards fit and scroll at ${size.width} x ${size.height}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (var day = 1; day <= 30; day++) {
          final decan = (day - 1) ~/ 10 + 1;
          final key = 'renwet_${day}_$decan';
          final info = draft == null
              ? KemeticDayData.getInfoForDay(key)!
              : _draftCard(draft, day);
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark,
              home: RepaintBoundary(
                key: boundaryKey,
                child: Scaffold(
                  body: Center(
                    child: KemeticDayDropdown(
                      key: ValueKey(key),
                      dayInfo: info,
                      onClose: () {},
                      dayKey: key,
                      kYear: 2,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$key at $size');
          expect(find.text(info.cosmicContext), findsOneWidget);
          final scrollable = find.byType(Scrollable).first;
          if ([1, 11, 22, 28, 30].contains(day)) {
            await _capture(
              tester,
              boundaryKey,
              '${day}_${size.width.toInt()}_top',
            );
            await tester.ensureVisible(find.text(info.cosmicContext));
            await tester.pumpAndSettle();
            await _capture(
              tester,
              boundaryKey,
              '${day}_${size.width.toInt()}_rhythm',
            );
          }
          final state = tester.state<ScrollableState>(scrollable);
          state.position.jumpTo(state.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(
            find.textContaining(info.meduNeter.mantra, findRichText: true),
            findsOneWidget,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$key scrolled at $size',
          );
          if ([1, 11, 22, 28, 30].contains(day)) {
            await _capture(
              tester,
              boundaryKey,
              '${day}_${size.width.toInt()}_bottom',
            );
          }
        }
      },
    );
  }
}

KemeticDayInfo _draftCard(List draft, int day) {
  final c = draft[day - 1] as Map;
  final first = (day - 1) ~/ 10 * 10;
  return KemeticDayInfo(
    kemeticDate: c['kemeticDate'],
    season: c['season'],
    month: c['month'],
    decanName: c['decanName'],
    starCluster: c['starCluster'],
    maatPrinciple: c['maatPrinciple'],
    cosmicContext: (c['cosmicContext'] as String).replaceAll(r'\n', '\n'),
    decanFlow: draft.sublist(first, first + 10).map((entry) {
      final f = entry['flow'];
      return DecanDayInfo(
        day: f['day'],
        theme: f['theme'],
        action: f['action'],
        reflection: f['reflection'],
      );
    }).toList(),
    meduNeter: MeduNeterKey(
      glyph: c['meduNeter']['glyph'],
      colorFrequency: c['meduNeter']['colorFrequency'],
      mantra: c['meduNeter']['mantra'],
    ),
  );
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final path = Platform.environment['HAW_RENWET_CAPTURE_DIR'];
  if (path == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$path/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
