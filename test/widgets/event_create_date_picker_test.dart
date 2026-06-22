import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_page.dart' show KemeticMath;
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/widgets/event_create_date_picker.dart';

void main() {
  testWidgets(
    'event create date picker opens with selected date and Cancel preserves draft on small phone',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final initial = DateTime(DateTime.now().year + 1, 9, 18);

      await tester.pumpWidget(
        MaterialApp(home: _EventCreateDateHost(initialDate: initial)),
      );

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 0'), findsOneWidget);
      _expectDraftFields();

      await tester.tap(find.byKey(const ValueKey<String>('event-date-button')));
      await tester.pumpAndSettle();

      expect(find.text('Event date'), findsOneWidget);
      expect(find.text('Gregorian Calendar'), findsWidgets);
      expect(find.text('September'), findsWidgets);
      expect(find.text('18'), findsWidgets);
      expect(find.text('${initial.year}'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 0'), findsOneWidget);
      _expectDraftFields();
    },
  );

  testWidgets(
    'event create date picker Done saves visible date and reopens it',
    (tester) async {
      _useSmallPhoneSurface(tester);
      final initial = DateTime(DateTime.now().year + 2, 10, 21);

      await tester.pumpWidget(
        MaterialApp(home: _EventCreateDateHost(initialDate: initial)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('event-date-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Updates: 1'), findsOneWidget);
      _expectDraftFields();

      await tester.tap(find.byKey(const ValueKey<String>('event-date-button')));
      await tester.pumpAndSettle();

      expect(find.text('Event date'), findsOneWidget);
      expect(find.text('October'), findsWidgets);
      expect(find.text('21'), findsWidgets);
      expect(find.text('${initial.year}'), findsWidgets);
    },
  );

  testWidgets(
    'event create date picker Kemetic mode preserves selected Gregorian date',
    (tester) async {
      final initial = DateTime(DateTime.now().year + 2, 6, 21);
      final kDate = KemeticMath.fromGregorian(initial);

      await tester.pumpWidget(
        MaterialApp(home: _EventCreateDateHost(initialDate: initial)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('event-date-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kemetic'));
      await tester.pumpAndSettle();

      expect(find.text('Kemetic Calendar'), findsWidgets);
      expect(find.text(getMonthById(kDate.kMonth).displayFull), findsWidgets);
      expect(find.text('${kDate.kDay}'), findsWidgets);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text(_label(initial)), findsOneWidget);
      expect(find.text('Mode: kemetic'), findsOneWidget);
      expect(find.text('Updates: 1'), findsOneWidget);
      _expectDraftFields();
    },
  );

  test('event create adapter preserves windows and day clamping', () {
    final date = DateTime(2028, 2, 29);
    final k = KemeticMath.fromGregorian(date);
    final adapter = EventCreateDatePickerAdapter(
      gregorianYearStart: 1828,
      kemeticYearStart: k.kYear - 200,
    );

    final gregorianYears = adapter
        .buildColumns(
          EventCreateDatePickerValue(
            date: date,
            mode: EventCreateDatePickerMode.gregorian,
          ),
          StoneDatePickerCalendarMode.gregorian,
        )
        .singleWhere((column) => column.id == 'year')
        .values;
    expect(gregorianYears, hasLength(401));
    expect(gregorianYears.first, '1828');
    expect(gregorianYears.last, '2228');

    final commonYearLeapDay = adapter.valueFromSelection(
      const StoneWheelSelection({'month': 1, 'day': 30, 'year': 199}),
      StoneDatePickerCalendarMode.gregorian,
    );
    expect(commonYearLeapDay.date, DateTime(2027, 2, 28));
    expect(commonYearLeapDay.mode, EventCreateDatePickerMode.gregorian);

    final kemeticSelection = adapter.selectionFromValue(
      EventCreateDatePickerValue(
        date: date,
        mode: EventCreateDatePickerMode.kemetic,
      ),
      StoneDatePickerCalendarMode.kemetic,
    );
    final kemeticRoundTrip = adapter.valueFromSelection(
      kemeticSelection,
      StoneDatePickerCalendarMode.kemetic,
    );
    expect(kemeticRoundTrip.date, DateUtils.dateOnly(date));
    expect(kemeticRoundTrip.mode, EventCreateDatePickerMode.kemetic);
  });
}

class _EventCreateDateHost extends StatefulWidget {
  const _EventCreateDateHost({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_EventCreateDateHost> createState() => _EventCreateDateHostState();
}

class _EventCreateDateHostState extends State<_EventCreateDateHost> {
  late DateTime _date = DateUtils.dateOnly(widget.initialDate);
  var _mode = EventCreateDatePickerMode.gregorian;
  var _updates = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Updates: $_updates'),
            Text('Mode: ${_mode.name}'),
            const Text('Title: Temple prep'),
            const Text('Location: Courtyard'),
            const Text('Detail: Bring linen'),
            const Text('Time: 12:00 PM-1:00 PM'),
            const Text('All-day: false'),
            const Text('Calendar: Temple'),
            const Text('Alert: none'),
            const Text('Category: Ritual'),
            const Text('Color: gold'),
            TextButton(
              key: const ValueKey<String>('event-date-button'),
              onPressed: () async {
                final picked = await EventCreateDatePicker.show(
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
              },
              child: Text(_label(_date)),
            ),
          ],
        ),
      ),
    );
  }
}

void _expectDraftFields() {
  expect(find.text('Title: Temple prep'), findsOneWidget);
  expect(find.text('Location: Courtyard'), findsOneWidget);
  expect(find.text('Detail: Bring linen'), findsOneWidget);
  expect(find.text('Time: 12:00 PM-1:00 PM'), findsOneWidget);
  expect(find.text('All-day: false'), findsOneWidget);
  expect(find.text('Calendar: Temple'), findsOneWidget);
  expect(find.text('Alert: none'), findsOneWidget);
  expect(find.text('Category: Ritual'), findsOneWidget);
  expect(find.text('Color: gold'), findsOneWidget);
}

String _label(DateTime date) {
  final normalized = DateUtils.dateOnly(date);
  return 'Event date: ${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
}

void _useSmallPhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
