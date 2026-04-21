import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/pinch_gesture_surface.dart';

void main() {
  Future<void> pumpSurface(
    WidgetTester tester, {
    GestureScaleStartCallback? onScaleStart,
    GestureScaleUpdateCallback? onScaleUpdate,
    GestureScaleEndCallback? onScaleEnd,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: PinchGestureSurface(
                enableTouchPinch: true,
                onScaleStart: onScaleStart,
                onScaleUpdate: onScaleUpdate,
                onScaleEnd: onScaleEnd,
                child: Material(
                  color: Colors.blueGrey,
                  child: InkWell(onTap: onTap, child: const SizedBox.expand()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('single-finger taps still reach child interactions', (
    tester,
  ) async {
    var tapCount = 0;
    await pumpSurface(tester, onTap: () => tapCount++);

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(tapCount, 1);
  });

  testWidgets('two-finger pans do not trigger pinch callbacks', (tester) async {
    var pinchStarts = 0;
    await pumpSurface(tester, onScaleStart: (_) => pinchStarts++);
    final center = tester.getCenter(find.byType(PinchGestureSurface));

    final gestureA = await tester.createGesture(kind: PointerDeviceKind.touch);
    final gestureB = await tester.createGesture(kind: PointerDeviceKind.touch);

    await gestureA.down(center + const Offset(-30, 0));
    await gestureB.down(center + const Offset(30, 0));
    await tester.pump();

    await gestureA.moveTo(center + const Offset(-26, 0));
    await gestureB.moveTo(center + const Offset(34, 0));
    await tester.pump();

    await gestureA.moveTo(center + const Offset(-22, 0));
    await gestureB.moveTo(center + const Offset(38, 0));
    await tester.pump();

    await gestureA.up();
    await gestureB.up();
    await tester.pumpAndSettle();

    expect(pinchStarts, 0);
  });

  testWidgets('two-finger pinch emits scale lifecycle callbacks', (
    tester,
  ) async {
    var pinchStarts = 0;
    var pinchEnds = 0;
    final scales = <double>[];

    await pumpSurface(
      tester,
      onScaleStart: (_) => pinchStarts++,
      onScaleUpdate: (details) => scales.add(details.scale),
      onScaleEnd: (_) => pinchEnds++,
    );
    final center = tester.getCenter(find.byType(PinchGestureSurface));

    final gestureA = await tester.createGesture(kind: PointerDeviceKind.touch);
    final gestureB = await tester.createGesture(kind: PointerDeviceKind.touch);

    await gestureA.down(center + const Offset(-30, 0));
    await gestureB.down(center + const Offset(30, 0));
    await tester.pump();

    await gestureA.moveTo(center + const Offset(-60, 0));
    await gestureB.moveTo(center + const Offset(60, 0));
    await tester.pump();

    await gestureA.moveTo(center + const Offset(-80, 0));
    await gestureB.moveTo(center + const Offset(80, 0));
    await tester.pump();

    await gestureA.up();
    await tester.pump();
    await gestureB.up();
    await tester.pumpAndSettle();

    expect(pinchStarts, 1);
    expect(pinchEnds, 1);
    expect(scales, isNotEmpty);
    expect(scales.any((scale) => scale > 1.0), isTrue);
  });
}
