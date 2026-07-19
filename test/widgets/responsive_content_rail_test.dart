import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/responsive_content_rail.dart';

void main() {
  testWidgets('keeps phone portrait child at full available width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const childKey = Key('rail-child');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveContentRail(
            maxWidth: 760,
            child: ColoredBox(
              key: childKey,
              color: Colors.white,
              child: SizedBox(width: double.infinity, height: 20),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(childKey)).width, 390);
  });

  testWidgets('centers and caps child width on desktop', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const childKey = Key('rail-child');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveContentRail(
            maxWidth: 760,
            child: ColoredBox(
              key: childKey,
              color: Colors.white,
              child: SizedBox(width: double.infinity, height: 20),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(childKey)).width, 760);
    expect(tester.getTopLeft(find.byKey(childKey)).dx, 340);
  });
}
