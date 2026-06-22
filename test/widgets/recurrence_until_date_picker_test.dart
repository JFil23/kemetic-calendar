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

  testWidgets(
    'reminder repeat end-date picker opens with current end date and Cancel preserves settings on small phone',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final initial = DateTime(DateTime.now().year - 1, 5, 15);
      final start = DateTime(initial.year, 5, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: _ReminderRepeatEndDateHost(
            startDate: start,
            initialEndDate: initial,
          ),
        ),
      );

      expect(find.text(_reminderLabel(initial)), findsOneWidget);
      expect(find.text('Updates: 0'), findsOneWidget);
      expect(find.text('Repeat: weekly'), findsOneWidget);
      expect(find.text('CTA: Save Reminder'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('reminder-repeat-end-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('End repeat date'), findsOneWidget);
      expect(find.text('Gregorian Calendar'), findsOneWidget);
      expect(find.text('May'), findsWidgets);
      expect(find.text('15'), findsWidgets);
      expect(find.text('${initial.year}'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text(_reminderLabel(initial)), findsOneWidget);
      expect(find.text('Updates: 0'), findsOneWidget);
      expect(find.text('Repeat: weekly'), findsOneWidget);
      expect(find.text('CTA: Save Reminder'), findsOneWidget);
    },
  );

  testWidgets(
    'reminder repeat end-date picker Done saves visible date and reopens it',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final start = DateTime(DateTime.now().year + 1, 6, 10);
      final initial = DateTime(start.year, 7, 12);

      await tester.pumpWidget(
        MaterialApp(
          home: _ReminderRepeatEndDateHost(
            startDate: start,
            initialEndDate: initial,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('reminder-repeat-end-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(_reminderLabel(initial)), findsOneWidget);
      expect(find.text('Updates: 1'), findsOneWidget);
      expect(find.text('Repeat: weekly'), findsOneWidget);
      expect(find.text('CTA: Save Reminder'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('reminder-repeat-end-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('End repeat date'), findsOneWidget);
      expect(find.text('July'), findsWidgets);
      expect(find.text('12'), findsWidgets);
      expect(find.text('${initial.year}'), findsWidgets);
    },
  );

  testWidgets(
    'reminder repeat end-date picker keeps caller-owned start clamp',
    (tester) async {
      final start = DateTime(DateTime.now().year + 1, 8, 20);
      final initial = DateTime(start.year, 8, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: _ReminderRepeatEndDateHost(
            startDate: start,
            initialEndDate: initial,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('reminder-repeat-end-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(_reminderLabel(start)), findsOneWidget);
      expect(find.text('Updates: 1'), findsOneWidget);
      expect(find.text('Repeat: weekly'), findsOneWidget);
      expect(find.text('CTA: Save Reminder'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('reminder-repeat-end-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('End repeat date'), findsOneWidget);
      expect(find.text('August'), findsWidgets);
      expect(find.text('20'), findsWidgets);
      expect(find.text('${start.year}'), findsWidgets);
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

class _ReminderRepeatEndDateHost extends StatefulWidget {
  const _ReminderRepeatEndDateHost({
    required this.startDate,
    required this.initialEndDate,
  });

  final DateTime startDate;
  final DateTime? initialEndDate;

  @override
  State<_ReminderRepeatEndDateHost> createState() =>
      _ReminderRepeatEndDateHostState();
}

class _ReminderRepeatEndDateHostState
    extends State<_ReminderRepeatEndDateHost> {
  late final DateTime _start = DateUtils.dateOnly(widget.startDate);
  late DateTime? _end = widget.initialEndDate == null
      ? null
      : DateUtils.dateOnly(widget.initialEndDate!);
  var _updates = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Updates: $_updates'),
            const Text('Repeat: weekly'),
            const Text('CTA: Save Reminder'),
            TextButton(
              key: const ValueKey<String>('reminder-repeat-end-button'),
              onPressed: () async {
                final picked = await RecurrenceUntilDatePicker.show(
                  context,
                  initialDate: _end ?? _start,
                  allowPast: true,
                );
                if (picked == null || !mounted) return;
                setState(() {
                  final normalized = DateUtils.dateOnly(picked);
                  _end = normalized.isBefore(_start) ? _start : normalized;
                  _updates += 1;
                });
              },
              child: Text(_reminderLabel(_end)),
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

String _reminderLabel(DateTime? date) {
  if (date == null) return 'End date: Never';
  final normalized = DateUtils.dateOnly(date);
  return 'End date: ${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
}

void _useSmallPhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
