import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rhythm/widgets/planner/nutrition_time_editor_row.dart';

void main() {
  testWidgets('nutrition time row is tappable across label, value, and gap', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: NutritionTimeEditorRow(
              value: '9:00 AM',
              onTap: () {
                taps += 1;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(nutritionTimeEditorLabelKey));
    await tester.pump();
    expect(taps, 1);

    await tester.tap(find.byKey(nutritionTimeEditorValueKey));
    await tester.pump();
    expect(taps, 2);

    final rowRect = tester.getRect(find.byKey(nutritionTimeEditorRowKey));
    await tester.tapAt(rowRect.center);
    await tester.pump();
    expect(taps, 3);
  });

  testWidgets('tapping the rendered time value opens the time picker', (
    tester,
  ) async {
    var selectedTime = const TimeOfDay(hour: 9, minute: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return NutritionTimeEditorRow(
                value: selectedTime.format(context),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                    useRootNavigator: true,
                  );
                  if (picked == null) return;
                  setState(() {
                    selectedTime = picked;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(nutritionTimeEditorValueKey));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
  });
}
