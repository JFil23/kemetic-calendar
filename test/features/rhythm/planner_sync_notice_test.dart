import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../support/maat_flow_visual_test_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rhythm/widgets/planner/planner_sync_notice.dart';

void main() {
  setUpAll(() async {
    await loadMaatFlowVisualTestFonts();
    await (FontLoader(
          'Ahem',
        )..addFont(rootBundle.load('ios/Runner/Fonts/GentiumPlus-Regular.ttf')))
        .load();
  });
  for (final width in [297.0, 390.0, 844.0]) {
    testWidgets('Planner sync states fit viewport $width', (tester) async {
      tester.view.physicalSize = Size(width, 664);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final message in [
        'Changes pending account sync. They will retry automatically.',
        'Another device changed this item. Both versions are preserved in your account.',
        'Could not refresh. Showing the last account copy.',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: Brightness.dark,
              fontFamily: 'GentiumPlus',
            ),
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Padding(
                padding: const EdgeInsets.all(18),
                child: PlannerSyncNotice(message: message, onReview: () {}),
              ),
            ),
          ),
        );
        expect(find.text(message), findsOneWidget);
        expect(find.text('Review changes'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_PLANNER_SYNC') &&
            width == 297 &&
            message.startsWith('Another')) {
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              Uri.file('/private/tmp/haw-planner-sync-state.png'),
            ),
          );
        }
      }
    });
  }
}
