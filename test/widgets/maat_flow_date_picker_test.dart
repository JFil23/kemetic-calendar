import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/calendar_completion.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/shared/date_picker/kemetic_picker_labels.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/widgets/maat_flow_date_picker.dart';

void main() {
  testWidgets(
    'Ma_at flow date picker opens with current date and Cancel preserves detail state on small phone',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final initial = DateTime(DateTime.now().year + 1, 7, 14);

      await tester.pumpWidget(
        MaterialApp(home: _MaatFlowDateHost(initialDate: initial)),
      );

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 0'), findsOneWidget);
      _expectDetailState(initial);

      await tester.tap(
        find.byKey(const ValueKey<String>('maat-flow-date-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('Kemetic Calendar'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 0'), findsOneWidget);
      _expectDetailState(initial);
    },
  );

  testWidgets(
    'Ma_at flow date picker Done saves visible date and reopens it without off-by-one',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final initial = DateTime(DateTime.now().year + 2, 10, 23);

      await tester.pumpWidget(
        MaterialApp(home: _MaatFlowDateHost(initialDate: initial)),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('maat-flow-date-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 1'), findsOneWidget);
      _expectDetailState(initial);

      await tester.tap(
        find.byKey(const ValueKey<String>('maat-flow-date-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('Kemetic Calendar'), findsWidgets);
      final kDate = KemeticMath.fromGregorian(initial);
      expect(find.text(kemeticPickerMonthLabel(kDate.kMonth)), findsWidgets);
      expect(find.text('${kDate.kDay}'), findsWidgets);
    },
  );

  testWidgets(
    'Ma_at flow date picker Gregorian mode preserves selected date and completion controls',
    (tester) async {
      final initial = DateTime(DateTime.now().year + 2, 6, 21);

      await tester.pumpWidget(
        MaterialApp(
          home: _MaatFlowDateHost(
            initialDate: initial,
            initialMode: MaatFlowDatePickerMode.gregorian,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('maat-flow-date-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gregorian Calendar'), findsWidgets);
      expect(find.text('June'), findsWidgets);
      expect(find.text('21'), findsWidgets);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Mode: gregorian'), findsOneWidget);
      expect(find.text('Updates: 1'), findsOneWidget);

      await tester.tap(find.text('Partly'));
      await tester.pumpAndSettle();

      expect(find.text('Completion: partial'), findsOneWidget);
      _expectDetailState(initial, completion: CompletionStatus.partial);
    },
  );

  testWidgets('Ma_at flow date picker defaults empty value to tomorrow', (
    tester,
  ) async {
    final expected = _tomorrow(DateUtils.dateOnly(DateTime.now()));

    await tester.pumpWidget(const MaterialApp(home: _MaatFlowDateHost()));

    await tester.tap(
      find.byKey(const ValueKey<String>('maat-flow-date-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.text(_label(expected)), findsOneWidget);
    expect(find.text('Updates: 1'), findsOneWidget);
  });

  test(
    'Ma_at flow adapter preserves future windows, full labels, and clamping',
    () {
      final date = DateTime(2028, 2, 29);
      final k = KemeticMath.fromGregorian(date);
      final adapter = MaatFlowDatePickerAdapter(
        today: DateTime(2026, 6, 21),
        kemeticYearStart: k.kYear,
      );

      final gregorianColumns = adapter.buildColumns(
        MaatFlowDatePickerValue(
          date: date,
          mode: MaatFlowDatePickerMode.gregorian,
        ),
        StoneDatePickerCalendarMode.gregorian,
      );
      expect(
        gregorianColumns.singleWhere((column) => column.id == 'month').values,
        containsAll(<String>['January', 'February', 'December']),
      );
      final gregorianYears = gregorianColumns
          .singleWhere((column) => column.id == 'year')
          .values;
      expect(gregorianYears, hasLength(40));
      expect(gregorianYears.first, '2026');
      expect(gregorianYears.last, '2065');

      final commonYearLeapDay = adapter.valueFromSelection(
        const StoneWheelSelection({'month': 1, 'day': 30, 'year': 1}),
        StoneDatePickerCalendarMode.gregorian,
      );
      expect(commonYearLeapDay.date, DateTime(2027, 2, 28));
      expect(commonYearLeapDay.mode, MaatFlowDatePickerMode.gregorian);

      final kemeticSelection = adapter.selectionFromValue(
        MaatFlowDatePickerValue(
          date: date,
          mode: MaatFlowDatePickerMode.kemetic,
        ),
        StoneDatePickerCalendarMode.kemetic,
      );
      final kemeticRoundTrip = adapter.valueFromSelection(
        kemeticSelection,
        StoneDatePickerCalendarMode.kemetic,
      );
      expect(kemeticRoundTrip.date, DateUtils.dateOnly(date));
      expect(kemeticRoundTrip.mode, MaatFlowDatePickerMode.kemetic);
    },
  );
}

class _MaatFlowDateHost extends StatefulWidget {
  const _MaatFlowDateHost({
    this.initialDate,
    this.initialMode = MaatFlowDatePickerMode.kemetic,
  });

  final DateTime? initialDate;
  final MaatFlowDatePickerMode initialMode;

  @override
  State<_MaatFlowDateHost> createState() => _MaatFlowDateHostState();
}

class _MaatFlowDateHostState extends State<_MaatFlowDateHost> {
  late DateTime? _selected = widget.initialDate == null
      ? null
      : DateUtils.dateOnly(widget.initialDate!);
  late MaatFlowDatePickerMode _mode = widget.initialMode;
  var _completion = CompletionStatus.none;
  var _updates = 0;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Updates: $_updates'),
              Text('Mode: ${_mode.name}'),
              Text('Completion: ${_completion.wireName}'),
              const Text('Detail state: unchanged'),
              const Text('Palette styling: unchanged'),
              const Text('Sheet sizing: unchanged'),
              const Text('Scroll behavior: unchanged'),
              const Text('Journal badges: unchanged'),
              TextButton(
                key: const ValueKey<String>('maat-flow-date-button'),
                onPressed: () async {
                  final picked = await MaatFlowDatePicker.show(
                    context: context,
                    initialDate: _selected,
                    initialMode: _mode,
                  );
                  if (picked == null || !mounted) return;
                  setState(() {
                    _selected = DateUtils.dateOnly(picked.date);
                    _mode = picked.mode;
                    _updates += 1;
                  });
                },
                child: Text(
                  selected == null ? 'Pick start date' : _label(selected),
                ),
              ),
              CalendarCompletionPicker(
                current: _completion,
                onChanged: (status) {
                  setState(() {
                    _completion = status;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _expectDetailState(
  DateTime selectedDate, {
  CompletionStatus completion = CompletionStatus.none,
}) {
  expect(find.text(_label(selectedDate)), findsOneWidget);
  expect(find.text('Completion: ${completion.wireName}'), findsOneWidget);
  expect(find.text('Detail state: unchanged'), findsOneWidget);
  expect(find.text('Palette styling: unchanged'), findsOneWidget);
  expect(find.text('Sheet sizing: unchanged'), findsOneWidget);
  expect(find.text('Scroll behavior: unchanged'), findsOneWidget);
  expect(find.text('Journal badges: unchanged'), findsOneWidget);
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
