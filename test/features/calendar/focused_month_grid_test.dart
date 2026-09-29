import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart';
import 'package:mobile/features/calendar/day_view.dart';
import 'package:mobile/widgets/calendar_floating_shortcuts.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';

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

  testWidgets(
    'focused Heriu Renpet uses the same full-width lattice and special day keys',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var kYear = 6267;
      while (KemeticMath.isLeapKemeticYear(kYear)) {
        kYear++;
      }

      int? tappedDay;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SingleChildScrollView(
              child: buildFocusedEpagomenalGridForTesting(
                kYear: kYear,
                todayDay: 2,
                selectedDay: 4,
                dayRowHeight: 336,
                notesForDay: (day) => const <NoteData>[],
                onDayTap: (day) => tappedDay = day,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Heriu Renpet'), findsOneWidget);
      expect(find.text('FIRST DECAN'), findsNothing);
      expect(find.text('SECOND DECAN'), findsNothing);
      expect(find.text('THIRD DECAN'), findsNothing);

      final grid = tester.getRect(
        find.byKey(const ValueKey<String>('focused-epagomenal-grid')),
      );
      expect(grid.left, 0);
      expect(grid.right, 390);

      for (var day = 1; day <= 5; day++) {
        expect(
          find.byKey(ValueKey<String>('focused-day:$kYear-13-$day|K')),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is KemeticDayButton &&
                widget.dayKey == 'epagomenal_${day}_$kYear',
          ),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(ValueKey<String>('focused-day:$kYear-13-6|K')),
        findsNothing,
      );

      final first = tester.getRect(
        find.byKey(ValueKey<String>('focused-day:$kYear-13-1|K')),
      );
      final second = tester.getRect(
        find.byKey(ValueKey<String>('focused-day:$kYear-13-2|K')),
      );
      expect(first.height, 336);
      expect(first.right, closeTo(second.left, 0.01));
      expect(first.width, closeTo(second.width, 0.01));

      await tester.tap(
        find.byKey(ValueKey<String>('focused-day:$kYear-13-5|K')),
      );
      expect(tappedDay, 5);

      final selected = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(ValueKey<String>('focused-day:$kYear-13-4|K')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = selected.decoration as BoxDecoration;
      expect(decoration.color, isNot(Colors.transparent));
      expect(decoration.border, isNotNull);
    },
  );

  testWidgets('focused Heriu Renpet adds the sixth leap-year cell', (
    tester,
  ) async {
    var kYear = 6267;
    while (!KemeticMath.isLeapKemeticYear(kYear)) {
      kYear++;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildFocusedEpagomenalGridForTesting(
            kYear: kYear,
            notesForDay: (day) => const <NoteData>[],
          ),
        ),
      ),
    );

    for (var day = 1; day <= 6; day++) {
      expect(
        find.byKey(ValueKey<String>('focused-day:$kYear-13-$day|K')),
        findsOneWidget,
      );
    }
  });

  testWidgets(
    'focused Today stays focused and selects today before shortcuts remain usable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var todayTaps = 0;
      var calendarsTaps = 0;
      var inboxTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: buildFocusedMonthDetailForTesting(
            kYear: 6267,
            kMonth: 7,
            todayYear: 6267,
            todayMonth: 8,
            todayDay: 5,
            onTodayPressed: () => todayTaps++,
            onCalendarsPressed: () => calendarsTaps++,
            onInboxPressed: () => inboxTaps++,
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Today'), findsOneWidget);
      expect(find.bySemanticsLabel('Calendars'), findsOneWidget);
      expect(find.bySemanticsLabel('Inbox'), findsOneWidget);

      final shortcutsRect = tester.getRect(
        find.byKey(calendarFloatingShortcutsSurfaceKey),
      );
      final todayRect = tester.getRect(
        find.byKey(calendarFloatingTodaySurfaceKey),
      );
      expect(shortcutsRect.right, 390 - kCalendarFloatingShortcutsTrailing);
      expect(shortcutsRect.bottom, 844 - kCalendarFloatingShortcutsBottom);
      expect(todayRect.left, kCalendarFloatingShortcutsLeading);
      expect(todayRect.bottom, shortcutsRect.bottom);

      expect(
        find.byKey(const ValueKey<String>('focused-day:6267-7-1|K')),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Today'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('focused-day:6267-8-5|K')),
        findsOneWidget,
      );
      final todayCell = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('focused-day:6267-8-5|K')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (todayCell.decoration as BoxDecoration).color,
        isNot(Colors.transparent),
      );
      expect(find.byType(Navigator), findsOneWidget);

      await tester.tap(find.byKey(calendarFloatingCalendarsButtonKey));
      await tester.tap(find.byKey(calendarFloatingInboxButtonKey));
      expect(todayTaps, 1);
      expect(calendarsTaps, 1);
      expect(inboxTaps, 1);
    },
  );

  testWidgets('calendar drill-in route uses a soft Apple-style transition', (
    tester,
  ) async {
    const sourceKey = ValueKey<String>('calendar-transition-source');
    const destinationKey = ValueKey<String>('calendar-transition-destination');
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const ColoredBox(
          key: sourceKey,
          color: Colors.black,
          child: SizedBox.expand(),
        ),
      ),
    );

    final route = buildCalendarDrillInRouteForTesting(
      const ColoredBox(
        key: destinationKey,
        color: Color(0xFF120F08),
        child: SizedBox.expand(),
      ),
    );
    expect(route.transitionDuration, const Duration(milliseconds: 320));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 300));

    navigatorKey.currentState!.push(route);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    expect(find.byKey(sourceKey, skipOffstage: false), findsOneWidget);
    expect(find.byKey(destinationKey, skipOffstage: false), findsOneWidget);
    final fade = tester.widget<FadeTransition>(
      find.ancestor(
        of: find.byKey(destinationKey),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));

    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(sourceKey, skipOffstage: false), findsOneWidget);
    expect(find.byKey(destinationKey, skipOffstage: false), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
