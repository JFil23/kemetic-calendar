import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/flow_appearance.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';

import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List image;
  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    image = (await rootBundle.load(
      'assets/follow_the_sky/discovery_hero.jpg',
    )).buffer.asUint8List();
  });

  for (final size in [
    const Size(1180, 820),
    const Size(820, 1180),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets(
      'canonical posted detail preserves the My Flows visual at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const capture = ValueKey('canonical-posted-flow-capture');
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'GentiumPlus'),
            home: RepaintBoundary(
              key: capture,
              child: UtilitySheetRouteScaffold(
                semanticLabel: 'Flow details',
                maxWidth: 640,
                onClose: () {},
                child: buildMyFlowDetailPreviewForTesting(
                  flowName: 'autumn ideas for the month of October!!',
                  eventCount: 10,
                  appearance: const FlowAppearance(
                    imageObjectPath: 'fixture/autumn.png',
                  ),
                  appearanceImageBytes: image,
                  nowOverride: DateTime(2026, 10, 5),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(image),
            tester.element(find.byKey(capture)),
          ),
        );
        await tester.pumpAndSettle();
        final bounds = tester.getRect(
          find.byKey(const ValueKey('user-flow-detail-appearance')),
        );
        expect(bounds.width, size.width > 640 ? 640 : size.width);
        expect(bounds.center.dx, size.width / 2);
        expect(
          find.byKey(const ValueKey('user-flow-detail-options')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('user-flow-manage')), findsOneWidget);
        expect(find.text('Remove from profile'), findsNothing);
        expect(find.textContaining('SAVED ·'), findsNothing);
        if (size == const Size(844, 390)) {
          final caption = tester.getRect(
            find.byKey(const ValueKey('user-flow-detail-caption')),
          );
          final title = tester.getRect(
            find.byKey(const ValueKey('user-flow-detail-title')),
          );
          final back = tester.getRect(
            find.byKey(const ValueKey('user-flow-detail-back')),
          );
          final options = tester.getRect(
            find.byKey(const ValueKey('user-flow-detail-options')),
          );
          expect(caption.top, greaterThanOrEqualTo(back.bottom + 8));
          expect(caption.top, greaterThanOrEqualTo(options.bottom + 8));
          expect(title.top, greaterThanOrEqualTo(caption.bottom + 6.9));
          expect(
            title.bottom,
            lessThan(
              tester
                  .getRect(find.byKey(const ValueKey('user-flow-manage')))
                  .top,
            ),
          );
        }
        expect(tester.takeException(), isNull);
        final folder = Platform.environment['HAW_CANONICAL_POST_CAPTURE_DIR'];
        if (folder != null) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(capture),
            );
            final rendered = await boundary.toImage();
            final data = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(folder).create(recursive: true);
            await File(
              '$folder/canonical-${size.width.toInt()}x${size.height.toInt()}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        await tester.tap(
          find.byKey(const ValueKey('user-flow-detail-options')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Edit Flow'), findsOneWidget);
        expect(find.text('Share Flow'), findsOneWidget);
        expect(find.text('Done / Add to journal'), findsOneWidget);
      },
    );
  }
}
