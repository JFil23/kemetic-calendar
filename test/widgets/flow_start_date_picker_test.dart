import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/widgets/flow_start_date_picker.dart';

void main() {
  testWidgets(
    'Flow start picker opens with existing value and Cancel preserves state on small phone',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final initial = DateTime(DateTime.now().year + 1, 7, 10);

      await tester.pumpWidget(
        MaterialApp(home: _FlowStartHost(initialDate: initial)),
      );

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 0'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('flow-start-button')));
      await tester.pumpAndSettle();

      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('Gregorian Calendar'), findsOneWidget);
      expect(find.text('Jul'), findsWidgets);
      expect(find.text('10'), findsWidgets);
      expect(find.text('${initial.year}'), findsWidgets);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 0'), findsOneWidget);
    },
  );

  testWidgets(
    'Flow start picker Done saves visible date and reopen shows saved value',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final initial = DateTime(DateTime.now().year + 2, 8, 11);

      await tester.pumpWidget(
        MaterialApp(home: _FlowStartHost(initialDate: initial)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('flow-start-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('flow-start-button')));
      await tester.pumpAndSettle();

      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('Aug'), findsWidgets);
      expect(find.text('11'), findsWidgets);
      expect(find.text('${initial.year}'), findsWidgets);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 2'), findsOneWidget);
    },
  );

  testWidgets('Flow start picker defaults empty value to tomorrow', (
    tester,
  ) async {
    final expected = _tomorrow(DateUtils.dateOnly(DateTime.now()));

    await tester.pumpWidget(const MaterialApp(home: _FlowStartHost()));

    await tester.tap(find.byKey(const ValueKey<String>('flow-start-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.text(_label(expected)), findsOneWidget);
    expect(find.text('Updates: 1'), findsOneWidget);
  });

  test('Flow start adapter preserves future window and Kemetic conversion', () {
    final date = DateTime(2026, 6, 21);
    final k = KemeticMath.fromGregorian(date);
    final adapter = FlowStartDatePickerAdapter(
      today: DateTime(2026, 6, 21),
      kemeticYearStart: k.kYear,
    );

    final gregorianYearValues = adapter
        .buildColumns(date, StoneDatePickerCalendarMode.gregorian)
        .singleWhere((column) => column.id == 'year')
        .values;
    expect(gregorianYearValues, hasLength(40));
    expect(gregorianYearValues.first, '2026');
    expect(gregorianYearValues.last, '2065');

    final clampedLeapDay = adapter.valueFromSelection(
      const StoneWheelSelection({'month': 1, 'day': 30, 'year': 1}),
      StoneDatePickerCalendarMode.gregorian,
    );
    expect(clampedLeapDay, DateTime(2027, 2, 28));

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

    final kemeticYearValues = adapter
        .buildColumns(date, StoneDatePickerCalendarMode.kemetic)
        .singleWhere((column) => column.id == 'year')
        .values;
    expect(kemeticYearValues, hasLength(401));
  });
}

class _FlowStartHost extends StatefulWidget {
  const _FlowStartHost({this.initialDate});

  final DateTime? initialDate;

  @override
  State<_FlowStartHost> createState() => _FlowStartHostState();
}

class _FlowStartHostState extends State<_FlowStartHost> {
  late DateTime? _selected = widget.initialDate == null
      ? null
      : DateUtils.dateOnly(widget.initialDate!);
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
              key: const ValueKey<String>('flow-start-button'),
              onPressed: () async {
                final picked = await FlowStartDatePicker.show(
                  context,
                  initialDate: _selected,
                );
                if (picked == null || !mounted) return;
                setState(() {
                  _selected = DateUtils.dateOnly(picked);
                  _updates += 1;
                });
              },
              child: Text(
                _selected == null ? 'Select start date' : _label(_selected!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _label(DateTime date) {
  final normalized = DateUtils.dateOnly(date);
  return 'Start: ${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
}

DateTime _tomorrow(DateTime today) {
  var year = today.year;
  var month = today.month;
  var day = today.day + 1;
  final maxDay = DateUtils.getDaysInMonth(year, month);
  if (day > maxDay) {
    day = 1;
    month = month == 12 ? 1 : month + 1;
    if (month == 1) year++;
  }
  return DateTime(year, month, day);
}

void _useSmallPhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
