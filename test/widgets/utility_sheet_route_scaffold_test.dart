import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/utility_sheet_route_scaffold.dart';

void main() {
  Widget buildHarness({
    required VoidCallback onClose,
    Widget child = const Center(child: Text('Utility sheet body')),
  }) {
    return MaterialApp(
      home: UtilitySheetRouteScaffold(
        semanticLabel: 'Test Sheet',
        onClose: onClose,
        child: child,
      ),
    );
  }

  testWidgets('dragging down from the header past threshold dismisses', (
    tester,
  ) async {
    var closeCount = 0;
    await tester.pumpWidget(buildHarness(onClose: () => closeCount++));

    await tester.drag(
      find.byKey(utilitySheetRouteDragHandleKey),
      const Offset(0, 140),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(closeCount, 1);
  });

  testWidgets('short downward drag snaps back without dismissing', (
    tester,
  ) async {
    var closeCount = 0;
    await tester.pumpWidget(buildHarness(onClose: () => closeCount++));

    await tester.drag(
      find.byKey(utilitySheetRouteDragHandleKey),
      const Offset(0, 60),
    );
    await tester.pump(const Duration(milliseconds: 220));

    expect(closeCount, 0);
    expect(find.text('Utility sheet body'), findsOneWidget);
  });

  testWidgets('upward drag from the header does not dismiss', (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(buildHarness(onClose: () => closeCount++));

    await tester.drag(
      find.byKey(utilitySheetRouteDragHandleKey),
      const Offset(0, -160),
    );
    await tester.pump(const Duration(milliseconds: 220));

    expect(closeCount, 0);
  });

  testWidgets('tapping outside still dismisses', (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(buildHarness(onClose: () => closeCount++));

    await tester.tapAt(const Offset(24, 24));
    await tester.pump(const Duration(milliseconds: 20));

    expect(closeCount, 1);
  });

  testWidgets('close button still dismisses', (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(buildHarness(onClose: () => closeCount++));

    await tester.tap(find.byKey(utilitySheetRouteCloseButtonKey));
    await tester.pump(const Duration(milliseconds: 20));

    expect(closeCount, 1);
  });

  testWidgets('body scrolling does not dismiss the route sheet', (
    tester,
  ) async {
    var closeCount = 0;
    await tester.pumpWidget(
      buildHarness(
        onClose: () => closeCount++,
        child: ListView.builder(
          key: const Key('utility-sheet-body-list'),
          itemCount: 40,
          itemBuilder: (context, index) =>
              SizedBox(height: 56, child: Text('Row $index')),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('utility-sheet-body-list')),
      const Offset(0, 180),
    );
    await tester.pump(const Duration(milliseconds: 220));

    expect(closeCount, 0);
  });
}
