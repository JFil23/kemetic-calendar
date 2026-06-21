import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/widgets/recurrence_until_date_picker.dart';

void main() {
  testWidgets(
    'recurrence until picker opens with existing value and Cancel preserves state on small phone',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final initial = DateTime(DateTime.now().year + 1, 7, 10);

      await tester.pumpWidget(
        MaterialApp(home: _RecurrenceUntilHost(initialDate: initial)),
      );

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 0'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('recurrence-until-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('End repeat date'), findsOneWidget);
      expect(find.text('Gregorian Calendar'), findsOneWidget);
      expect(find.text('July'), findsWidgets);
      expect(find.text('10'), findsWidgets);
      expect(find.text('${initial.year}'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 0'), findsOneWidget);
    },
  );

  testWidgets(
    'recurrence until picker Done saves visible date and reopens it',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final initial = DateTime(DateTime.now().year + 2, 8, 11);

      await tester.pumpWidget(
        MaterialApp(home: _RecurrenceUntilHost(initialDate: initial)),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('recurrence-until-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 1'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('recurrence-until-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('End repeat date'), findsOneWidget);
      expect(find.text('August'), findsWidgets);
      expect(find.text('11'), findsWidgets);
      expect(find.text('${initial.year}'), findsWidgets);
    },
  );

  testWidgets(
    'recurrence until picker Kemetic mode preserves selected Gregorian date',
    (tester) async {
      final initial = DateTime(DateTime.now().year + 2, 6, 21);
      final kDate = KemeticMath.fromGregorian(initial);

      await tester.pumpWidget(
        MaterialApp(home: _RecurrenceUntilHost(initialDate: initial)),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('recurrence-until-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kemetic'));
      await tester.pumpAndSettle();

      expect(find.text('Kemetic Calendar'), findsOneWidget);
      expect(find.text(getMonthById(kDate.kMonth).displayFull), findsWidgets);
      expect(find.text('${kDate.kDay}'), findsWidgets);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 1'), findsOneWidget);
    },
  );

  testWidgets('recurrence until picker preserves first-date validation', (
    tester,
  ) async {
    final initial = DateTime(DateTime.now().year, 1, 5);
    final firstDate = DateTime(DateTime.now().year, 2, 7);

    await tester.pumpWidget(
      MaterialApp(
        home: _RecurrenceUntilHost(initialDate: initial, firstDate: firstDate),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('recurrence-until-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.text(_label(firstDate)), findsOneWidget);
    expect(find.text('Updates: 1'), findsOneWidget);
  });

  test('recurrence until adapter preserves windows and date conversion', () {
    final date = DateTime(2028, 2, 29);
    final k = KemeticMath.fromGregorian(date);
    final adapter = RecurrenceUntilDatePickerAdapter(
      today: DateTime(2026, 6, 21),
      kemeticYearStart: k.kYear,
    );

    final gregorianYears = adapter
        .buildColumns(date, StoneDatePickerCalendarMode.gregorian)
        .singleWhere((column) => column.id == 'year')
        .values;
    expect(gregorianYears, hasLength(40));
    expect(gregorianYears.first, '2026');
    expect(gregorianYears.last, '2065');

    final commonYearLeapDay = adapter.valueFromSelection(
      const StoneWheelSelection({'month': 1, 'day': 30, 'year': 1}),
      StoneDatePickerCalendarMode.gregorian,
    );
    expect(commonYearLeapDay, DateTime(2027, 2, 28));

    final kemeticSelection = adapter.selectionFromValue(
      date,
      StoneDatePickerCalendarMode.kemetic,
    );
    expect(
      adapter.valueFromSelection(
        kemeticSelection,
        StoneDatePickerCalendarMode.kemetic,
      ),
      DateUtils.dateOnly(date),
    );

    final kemeticYears = adapter
        .buildColumns(date, StoneDatePickerCalendarMode.kemetic)
        .singleWhere((column) => column.id == 'year')
        .values;
    expect(kemeticYears, hasLength(401));
  });
}

class _RecurrenceUntilHost extends StatefulWidget {
  const _RecurrenceUntilHost({required this.initialDate, this.firstDate});

  final DateTime initialDate;
  final DateTime? firstDate;

  @override
  State<_RecurrenceUntilHost> createState() => _RecurrenceUntilHostState();
}

class _RecurrenceUntilHostState extends State<_RecurrenceUntilHost> {
  late DateTime _selected = DateUtils.dateOnly(widget.initialDate);
  var _updates = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Updates: $_updates'),
            TextButton(
              key: const ValueKey<String>('recurrence-until-button'),
              onPressed: () async {
                final picked = await RecurrenceUntilDatePicker.show(
                  context,
                  initialDate: _selected,
                  firstDate: widget.firstDate,
                );
                if (picked == null || !mounted) return;
                setState(() {
                  _selected = DateUtils.dateOnly(picked);
                  _updates += 1;
                });
              },
              child: Text(_label(_selected)),
            ),
          ],
        ),
      ),
    );
  }
}

String _label(DateTime date) {
  final normalized = DateUtils.dateOnly(date);
  return 'Until: ${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
}

void _useSmallPhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
