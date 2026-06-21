import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker_theme.dart';
import 'package:mobile/shared/date_picker/stone_register_date_wheel.dart';

void main() {
  testWidgets('renders selected row and Stone Register wheel mechanics', (
    tester,
  ) async {
    final controller = FixedExtentScrollController(initialItem: 1);
    addTearDown(controller.dispose);

    int? selectedIndex;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StoneRegisterDateWheel(
              columns: const [
                StoneWheelColumn(
                  id: 'month',
                  values: ['One', 'Two', 'Three'],
                  selectedIndex: 1,
                  looping: false,
                  flex: 1,
                ),
              ],
              controllers: {'month': controller},
              accent: StoneRegisterDatePickerTheme.gold,
              onSelectedItemChanged: (_, index) => selectedIndex = index,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Two'), findsOneWidget);

    final picker = tester.widget<CupertinoPicker>(
      find.byKey(const ValueKey('stone-register-wheel-month')),
    );
    expect(picker.itemExtent, StoneRegisterDatePickerTheme.rowHeight);
    expect(picker.selectionOverlay, isA<SizedBox>());

    await tester.drag(
      find.byKey(const ValueKey('stone-register-wheel-month')),
      const Offset(0, -StoneRegisterDatePickerTheme.rowHeight),
    );
    await tester.pumpAndSettle();

    expect(selectedIndex, isNotNull);
  });
}
