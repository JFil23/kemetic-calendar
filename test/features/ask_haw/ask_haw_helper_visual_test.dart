import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/onboarding/guided_onboarding_overlay.dart';
import 'package:mobile/features/onboarding/onboarding_progress.dart';
import 'package:mobile/features/pages/pages_layout.dart';
import 'package:mobile/features/pages/pages_models.dart';
import '../../support/maat_flow_visual_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMaatFlowVisualTestFonts);
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Ask helper points to existing Pages + at $size / $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final plus = GlobalKey();
        final capture = GlobalKey();
        var dismissals = 0;
        const helper = OnboardingHelperRegistry.askHawQuickAdd;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: RepaintBoundary(
              key: capture,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PagesLayout(
                    cards: const [],
                    onOpen: (_) {},
                    onProfile: () {},
                    onNewNote: () {},
                    newNoteKey: plus,
                    onSearchResult: (_) {},
                    searchRecords: () => [],
                    profileIdentity: const PagesProfileIdentity.visitor(),
                  ),
                  GuidedOnboardingOverlay(
                    target: CoachmarkTarget(
                      key: plus,
                      title: helper.title,
                      body: helper.body,
                      placement: CoachmarkPlacement.below,
                      variant: CoachmarkVariant.helperBubble,
                      showDismissButton: true,
                      dismissLabel: 'Got it',
                      onDismiss: () => dismissals++,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        expect(find.text(helper.title), findsOneWidget);
        if (Platform.environment['HAW_ASK_CONTROLS_CAPTURE_DIR']
            case final String path when path.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('$path/helper-${size.width.toInt()}-$scale.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.text('Got it'));
        await tester.tap(find.text('Got it'));
        expect(dismissals, 1);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
