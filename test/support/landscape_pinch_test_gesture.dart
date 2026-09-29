import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pinchLandscapeTime(
  WidgetTester tester, {
  required double factor,
  Offset? focalPoint,
}) async {
  final pane = tester.getRect(
    find.byKey(const ValueKey('landscape-time-pinch')),
  );
  final center = focalPoint ?? pane.center;
  final first = await tester.createGesture(kind: PointerDeviceKind.touch);
  final second = await tester.createGesture(kind: PointerDeviceKind.touch);
  await first.down(center - const Offset(100, 0));
  await second.down(center + const Offset(100, 0));
  await first.moveTo(center - const Offset(92, 0));
  await second.moveTo(center + const Offset(92, 0));
  await tester.pump(const Duration(milliseconds: 16));
  for (var i = 1; i <= 10; i++) {
    final radius = (92 * math.pow(factor, i / 10)).toDouble();
    await first.moveTo(center - Offset(radius, 0));
    await second.moveTo(center + Offset(radius, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await first.up();
  await second.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}
