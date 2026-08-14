import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/day_view.dart';

void main() {
  testWidgets('focused month uses three tall decan bands and 30 day columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SingleChildScrollView(
            child: buildFocusedCalendarMonthGridForTesting(
              kYear: 6267,
              kMonth: 7,
              todayDay: 7,
              selectedDay: 14,
              notesForDay: (day) => const <NoteData>[],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('focused-month-grid')), findsOne);
    expect(find.text('FIRST DECAN'), findsNothing);
    expect(find.text('SECOND DECAN'), findsNothing);
    expect(find.text('THIRD DECAN'), findsNothing);

    final grid = tester.getRect(
      find.byKey(const ValueKey<String>('focused-month-grid')),
    );
    expect(grid.left, 0);
    expect(grid.right, 390);
    for (var decan = 0; decan < 3; decan++) {
      final band = tester.getRect(
        find.byKey(ValueKey<String>('focused-decan-$decan')),
      );
      expect(band.height, 112);
    }
    for (var day = 1; day <= 30; day++) {
      expect(
        find.byKey(ValueKey<String>('focused-day:6267-7-$day|K')),
        findsOneWidget,
      );
    }

    final first = tester.getRect(
      find.byKey(const ValueKey<String>('focused-day:6267-7-1|K')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey<String>('focused-day:6267-7-2|K')),
    );
    final eleventh = tester.getRect(
      find.byKey(const ValueKey<String>('focused-day:6267-7-11|K')),
    );
    expect(first.height, greaterThan(70));
    expect(first.right, closeTo(second.left, 0.01));
    expect(first.width, closeTo(second.width, 0.01));
    expect(first.bottom, lessThan(eleventh.top));

    final firstCellDecoration = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(const ValueKey<String>('focused-day:6267-7-1|K')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final firstCellBorder =
        (firstCellDecoration.decoration as BoxDecoration).border as Border;
    expect(firstCellBorder.top.style, BorderStyle.solid);
    expect(firstCellBorder.right.style, BorderStyle.solid);
    expect(firstCellBorder.bottom.style, BorderStyle.solid);
  });

  testWidgets('focused day columns preserve selection and tap behavior', (
    tester,
  ) async {
    int? tappedDay;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildFocusedCalendarMonthGridForTesting(
            kYear: 6267,
            kMonth: 7,
            selectedDay: 14,
            notesForDay: (day) => const <NoteData>[],
            onDayTap: (day) => tappedDay = day,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('focused-day:6267-7-22|K')),
    );
    expect(tappedDay, 22);

    final selected = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(const ValueKey<String>('focused-day:6267-7-14|K')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = selected.decoration as BoxDecoration;
    expect(decoration.color, isNot(Colors.transparent));
    expect(decoration.border, isNotNull);
  });
}
