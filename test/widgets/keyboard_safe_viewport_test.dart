import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/keyboard_aware.dart';

void main() {
  testWidgets('viewport stays above the keyboard in portrait and landscape', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _ViewportHarness());
    await tester.pump();

    expect(
      tester.getRect(find.byKey(_frameKey)).bottom,
      lessThanOrEqualTo(844 - 320),
    );
    expect(find.byType(AnimatedPadding), findsNothing);

    tester.view.physicalSize = const Size(844, 390);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pump();

    final landscapeFrame = tester.getRect(find.byKey(_frameKey));
    expect(landscapeFrame.top, greaterThanOrEqualTo(0));
    expect(landscapeFrame.bottom, lessThanOrEqualTo(390 - 180));
    expect(tester.takeException(), isNull);
  });

  testWidgets('viewport clamps preferred sheet height to visible space', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 500);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _ViewportHarness(
        maxHeightFactor: 0.9,
        closedHeightFactor: 0.6,
        openHeightFactor: 0.9,
      ),
    );
    await tester.pump();

    final frame = tester.getRect(find.byKey(_frameKey));
    expect(frame.height, lessThanOrEqualTo(188));
    expect(frame.bottom, lessThanOrEqualTo(200));
    expect(tester.takeException(), isNull);
  });
}

const _frameKey = ValueKey<String>('keyboard-safe-test-frame');

class _ViewportHarness extends StatelessWidget {
  const _ViewportHarness({
    this.maxHeightFactor = 0.9,
    this.closedHeightFactor,
    this.openHeightFactor,
  });

  final double maxHeightFactor;
  final double? closedHeightFactor;
  final double? openHeightFactor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: KeyboardSafeViewport(
            maxHeightFactor: maxHeightFactor,
            closedHeightFactor: closedHeightFactor,
            openHeightFactor: openHeightFactor,
            child: const SizedBox(key: _frameKey, width: 390, height: 800),
          ),
        ),
      ),
    );
  }
}
