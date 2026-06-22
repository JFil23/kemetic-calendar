import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/date_picker/kemetic_picker_labels.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';
import 'package:mobile/shared/date_picker/stone_register_date_wheel.dart';

void main() {
  testWidgets('renders a native scroll column with strongest centered row', (
    tester,
  ) async {
    const column = StoneWheelColumn(
      id: 'month',
      values: ['One', 'Two', 'Three'],
      selectedIndex: 1,
      flex: 1,
    );
    final controller = ScrollController(
      initialScrollOffset: StoneRegisterWheelMetrics.initialOffsetFor(column),
    );
    addTearDown(controller.dispose);

    int? selectedIndex;
    await _pumpWheel(
      tester,
      column: column,
      controller: controller,
      onSelected: (index) => selectedIndex = index,
    );

    expect(find.text('Two'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stone-register-wheel-month')),
      findsOneWidget,
    );

    expect(_opacityFor(tester, 'Two'), closeTo(1.0, 0.01));
    expect(_scaleFor(tester, 'Two'), closeTo(1.06, 0.01));
    expect(_opacityFor(tester, 'One'), lessThan(_opacityFor(tester, 'Two')));
    expect(_scaleFor(tester, 'One'), lessThan(_scaleFor(tester, 'Two')));

    await tester.drag(
      find.byKey(const ValueKey('stone-register-wheel-month')),
      const Offset(0, -StoneRegisterDatePickerTheme.rowHeight),
    );
    await tester.pumpAndSettle();

    expect(selectedIndex, 2);
  });

  testWidgets('repaints row depth from fractional scroll offset', (
    tester,
  ) async {
    const column = StoneWheelColumn(
      id: 'month',
      values: ['One', 'Two', 'Three'],
      selectedIndex: 1,
      flex: 1,
    );
    final controller = ScrollController(
      initialScrollOffset: StoneRegisterWheelMetrics.initialOffsetFor(column),
    );
    addTearDown(controller.dispose);

    await _pumpWheel(tester, column: column, controller: controller);

    controller.jumpTo(StoneRegisterDatePickerTheme.rowHeight * 1.5);
    await tester.pump();
    await tester.pump();

    expect(_opacityFor(tester, 'Two'), closeTo(0.81, 0.04));
    expect(_scaleFor(tester, 'Two'), closeTo(0.99, 0.04));
    expect(_opacityFor(tester, 'Three'), closeTo(0.81, 0.04));
    expect(_scaleFor(tester, 'Three'), closeTo(0.99, 0.04));
  });

  testWidgets('deferred snap centers the nearest row after scroll settles', (
    tester,
  ) async {
    const column = StoneWheelColumn(
      id: 'month',
      values: ['One', 'Two', 'Three'],
      selectedIndex: 1,
      flex: 1,
    );
    final controller = ScrollController(
      initialScrollOffset: StoneRegisterWheelMetrics.initialOffsetFor(column),
    );
    addTearDown(controller.dispose);

    await _pumpWheel(tester, column: column, controller: controller);

    controller.jumpTo(StoneRegisterDatePickerTheme.rowHeight * 1.6);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(
      controller.offset,
      closeTo(StoneRegisterDatePickerTheme.rowHeight * 2, 0.5),
    );
  });

  testWidgets('Kemetic month labels fit the small-phone wheel', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const column = StoneWheelColumn(
      id: 'month',
      values: kKemeticPickerMonthLabels,
      selectedIndex: 0,
      flex: 1,
      looping: true,
      textStyle: TextStyle(
        fontFamily: StoneRegisterDatePickerTheme.serifFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.05,
      ),
    );
    final controller = ScrollController(
      initialScrollOffset: StoneRegisterWheelMetrics.initialOffsetFor(column),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: StoneRegisterDateWheel(
                columns: const [column],
                controllers: {'month': controller},
                accent: StoneRegisterDatePickerTheme.gold,
                onSelectedItemChanged: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );

    for (var index = 0; index < kKemeticPickerMonthLabels.length; index += 1) {
      controller.jumpTo(
        StoneRegisterWheelMetrics.offsetForSelectedIndex(
          column,
          index,
          currentOffset: controller.offset,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(kKemeticPickerMonthLabels[index]), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpWheel(
  WidgetTester tester, {
  required StoneWheelColumn column,
  required ScrollController controller,
  ValueChanged<int>? onSelected,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: StoneRegisterDateWheel(
            columns: [column],
            controllers: {'month': controller},
            accent: StoneRegisterDatePickerTheme.gold,
            onSelectedItemChanged: (_, index) => onSelected?.call(index),
          ),
        ),
      ),
    ),
  );
}

double _opacityFor(WidgetTester tester, String label) {
  final opacityFinder = find.ancestor(
    of: find.text(label),
    matching: find.byType(Opacity),
  );
  return tester.widget<Opacity>(opacityFinder.first).opacity;
}

double _scaleFor(WidgetTester tester, String label) {
  final transformFinder = find.ancestor(
    of: find.text(label),
    matching: find.byType(Transform),
  );
  final transform = tester.widget<Transform>(transformFinder.first);
  return transform.transform.storage[0];
}
