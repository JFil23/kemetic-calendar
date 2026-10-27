import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/ask_haw/ask_haw_flow_contract_editor.dart';
import 'package:mobile/features/ask_haw/ask_haw_flow_contract.dart';
import '../../support/maat_flow_visual_test_fonts.dart';
import '../../support/ask_haw_flow_contract_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMaatFlowVisualTestFonts);
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('authored assistance form fits $size / $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final state in [
          'collapsed',
          'expanded',
          'step',
          'alternative',
          'unsupported',
          'selector',
        ]) {
          final capture = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark,
              home: RepaintBoundary(
                key: capture,
                child: Scaffold(
                  backgroundColor: const Color(0xFF050403),
                  appBar: AppBar(title: const Text('Flow Studio')),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: state == 'selector'
                        ? AskHawStepSelector(
                            contract: AskHawFlowContract.tryFromJson(
                              askHawFlowContractFixture,
                            )!,
                            stepId: 'prepare',
                            onChanged: (_) {},
                          )
                        : AskHawFlowContractEditor(
                            key: ValueKey(state),
                            value: state == 'unsupported'
                                ? const {
                                    'version': 42,
                                    'future': {'keep': true},
                                  }
                                : askHawFlowContractFixture,
                            initiallyExpanded: state != 'collapsed',
                            onChanged: (_) {},
                          ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          if (state == 'step') {
            await tester.ensureVisible(
              find.byKey(const ValueKey('ask-haw-step-0-id')),
            );
          }
          if (state == 'alternative') {
            await tester.ensureVisible(
              find.byKey(const ValueKey('ask-haw-alternative--1000000-label')),
            );
          }
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull, reason: '$state $size $scale');
          if (Platform.environment['HAW_ASK_CREATOR_CAPTURE_DIR']
              case final String path when path.isNotEmpty) {
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '$path/$state-${size.width.toInt()}-$scale.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      });
    }
  }
}
