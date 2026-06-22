import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/shared/date_picker/kemetic_picker_labels.dart';
import 'package:mobile/widgets/day_sheet_date_picker.dart';

void main() {
  testWidgets(
    'day sheet date picker opens with selected day and Cancel preserves sheet state on small phone',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final initial = DateTime(DateTime.now().year + 1, 7, 14);

      await tester.pumpWidget(
        MaterialApp(home: _DaySheetDateHost(initialDate: initial)),
      );

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 0'), findsOneWidget);
      _expectSurroundingSheetState(initial);

      await tester.tap(
        find.byKey(const ValueKey<String>('day-sheet-date-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Day sheet date'), findsOneWidget);
      expect(find.text('Gregorian Calendar'), findsWidgets);
      expect(find.text('July'), findsWidgets);
      expect(find.text('14'), findsWidgets);
      expect(find.text('${initial.year}'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 0'), findsOneWidget);
      _expectSurroundingSheetState(initial);
    },
  );

  testWidgets(
    'day sheet date picker Done saves visible date and reopens it without off-by-one',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final initial = DateTime(DateTime.now().year + 2, 11, 23);

      await tester.pumpWidget(
        MaterialApp(home: _DaySheetDateHost(initialDate: initial)),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('day-sheet-date-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 1'), findsOneWidget);
      _expectSurroundingSheetState(initial);

      await tester.tap(
        find.byKey(const ValueKey<String>('day-sheet-date-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Day sheet date'), findsOneWidget);
      expect(find.text('November'), findsWidgets);
      expect(find.text('23'), findsWidgets);
      expect(find.text('${initial.year}'), findsWidgets);
    },
  );

  testWidgets(
    'day sheet date picker Kemetic mode preserves selected Gregorian date',
    (tester) async {
      final initial = DateTime(DateTime.now().year + 2, 6, 21);
      final kDate = KemeticMath.fromGregorian(initial);

      await tester.pumpWidget(
        MaterialApp(
          home: _DaySheetDateHost(
            initialDate: initial,
            initialMode: DaySheetDatePickerMode.kemetic,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('day-sheet-date-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kemetic Calendar'), findsWidgets);
      expect(find.text(kemeticPickerMonthLabel(kDate.kMonth)), findsWidgets);
      expect(find.text('${kDate.kDay}'), findsWidgets);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Mode: kemetic'), findsOneWidget);
      expect(find.text('Updates: 1'), findsOneWidget);
      _expectSurroundingSheetState(initial);
    },
  );

  testWidgets('allowDateChange=false prevents date mutation', (tester) async {
    final initial = DateTime(DateTime.now().year + 3, 3, 8);

    await tester.pumpWidget(
      MaterialApp(
        home: _DaySheetDateHost(initialDate: initial, allowDateChange: false),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('day-sheet-date-title')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day sheet date'), findsNothing);
    expect(find.text(_label(initial)), findsOneWidget);
    expect(find.text('Updates: 0'), findsOneWidget);
    _expectSurroundingSheetState(initial);
  });
}

class _DaySheetDateHost extends StatefulWidget {
  const _DaySheetDateHost({
    required this.initialDate,
    this.initialMode = DaySheetDatePickerMode.gregorian,
    this.allowDateChange = true,
  });

  final DateTime initialDate;
  final DaySheetDatePickerMode initialMode;
  final bool allowDateChange;

  @override
  State<_DaySheetDateHost> createState() => _DaySheetDateHostState();
}

class _DaySheetDateHostState extends State<_DaySheetDateHost> {
  late DateTime _date = DateUtils.dateOnly(widget.initialDate);
  late DaySheetDatePickerMode _mode = widget.initialMode;
  late final DateTime _sourceEditingDate = _date;
  var _updates = 0;

  @override
  Widget build(BuildContext context) {
    final kDate = KemeticMath.fromGregorian(_date);
    final source = DateUtils.dateOnly(_sourceEditingDate);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Updates: $_updates'),
            Text('Mode: ${_mode.name}'),
            Text('Kemetic day: ${kDate.kYear}-${kDate.kMonth}-${kDate.kDay}'),
            Text('Restoration kDay: ${kDate.kDay}'),
            Text('Session kDay: ${kDate.kDay}'),
            Text('Editing source: ${_label(source)}'),
            const Text('Reminder state: unchanged'),
            const Text('Title: Existing note'),
            const Text('Location: West room'),
            const Text('Detail: Bring offering list'),
            const Text('Time: 12:00 PM-1:00 PM'),
            const Text('All-day: false'),
            const Text('Calendar: Personal'),
            const Text('Alert: none'),
            const Text('Category: Ritual'),
            const Text('Color: gold'),
            GestureDetector(
              key: const ValueKey<String>('day-sheet-date-title'),
              onTap: widget.allowDateChange ? null : () {},
              child: TextButton(
                key: const ValueKey<String>('day-sheet-date-button'),
                onPressed: widget.allowDateChange
                    ? () async {
                        final picked = await DaySheetDatePicker.show(
                          context: context,
                          initialDate: _date,
                          initialMode: _mode,
                        );
                        if (picked == null || !mounted) return;
                        setState(() {
                          _date = DateUtils.dateOnly(picked.date);
                          _mode = picked.mode;
                          _updates += 1;
                        });
                      }
                    : null,
                child: Text(_label(_date)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _expectSurroundingSheetState(DateTime selectedDate) {
  final kDate = KemeticMath.fromGregorian(selectedDate);
  expect(
    find.text('Kemetic day: ${kDate.kYear}-${kDate.kMonth}-${kDate.kDay}'),
    findsOneWidget,
  );
  expect(find.text('Restoration kDay: ${kDate.kDay}'), findsOneWidget);
  expect(find.text('Session kDay: ${kDate.kDay}'), findsOneWidget);
  expect(find.text('Editing source: ${_label(selectedDate)}'), findsOneWidget);
  expect(find.text('Reminder state: unchanged'), findsOneWidget);
  expect(find.text('Title: Existing note'), findsOneWidget);
  expect(find.text('Location: West room'), findsOneWidget);
  expect(find.text('Detail: Bring offering list'), findsOneWidget);
  expect(find.text('Time: 12:00 PM-1:00 PM'), findsOneWidget);
  expect(find.text('All-day: false'), findsOneWidget);
  expect(find.text('Calendar: Personal'), findsOneWidget);
  expect(find.text('Alert: none'), findsOneWidget);
  expect(find.text('Category: Ritual'), findsOneWidget);
  expect(find.text('Color: gold'), findsOneWidget);
}

String _label(DateTime date) {
  final normalized = DateUtils.dateOnly(date);
  return 'Day sheet date: ${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
}

void _useSmallPhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
