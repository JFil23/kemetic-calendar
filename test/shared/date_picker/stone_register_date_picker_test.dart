import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/shared/date_picker/stone_register_date_picker.dart';
import 'package:mobile/widgets/gregorian_date_picker.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart';

void main() {
  testWidgets(
    'shared picker opens with initial value and Cancel returns null',
    (tester) async {
      DateTime? result = DateTime(1900);
      var completed = false;

      await _pumpPickerHost(
        tester,
        onOpen: (context) async {
          result = await StoneRegisterDatePicker.show<DateTime>(
            context,
            initialValue: DateTime(2026),
            adapter: const _SimpleDateAdapter(),
            initialMode: StoneDatePickerCalendarMode.kemetic,
            title: 'Pick a date',
          );
          completed = true;
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Pick a date'), findsOneWidget);
      expect(find.text('Kemetic 1'), findsWidgets);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, isNull);
    },
  );

  testWidgets('shared picker Done returns the visible selected value', (
    tester,
  ) async {
    DateTime? result;

    await _pumpPickerHost(
      tester,
      onOpen: (context) async {
        result = await StoneRegisterDatePicker.show<DateTime>(
          context,
          initialValue: DateTime(2026, 2, 2),
          adapter: const _SimpleDateAdapter(),
          initialMode: StoneDatePickerCalendarMode.gregorian,
          title: 'Pick a date',
        );
      },
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result, DateTime(2026, 2, 2));
  });

  testWidgets('mode switch changes accent label without corrupting date', (
    tester,
  ) async {
    DateTime? result;

    await _pumpPickerHost(
      tester,
      onOpen: (context) async {
        result = await StoneRegisterDatePicker.show<DateTime>(
          context,
          initialValue: DateTime(2026, 1, 1),
          adapter: const _SimpleDateAdapter(),
          initialMode: StoneDatePickerCalendarMode.kemetic,
          title: 'Pick a date',
        );
      },
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Kemetic Calendar'), findsOneWidget);

    await tester.tap(find.text('Gregorian'));
    await tester.pumpAndSettle();
    expect(find.text('Gregorian Calendar'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 1, 1));
  });

  test('Gregorian adapter preserves month lengths and leap years', () {
    const adapter = GregorianDatePickerAdapter(yearStart: 2020);

    final leapColumns = adapter.buildColumns(
      DateTime(2024, 2, 29),
      StoneDatePickerCalendarMode.gregorian,
    );
    expect(
      leapColumns.singleWhere((column) => column.id == 'day').values,
      hasLength(29),
    );

    final commonYear = adapter.valueFromSelection(
      const StoneWheelSelection({'month': 1, 'day': 30, 'year': 3}),
      StoneDatePickerCalendarMode.gregorian,
    );
    expect(commonYear, DateTime(2023, 2, 28));
  });

  testWidgets('migrated Gregorian picker returns initial date on Done', (
    tester,
  ) async {
    DateTime? result;

    await _pumpPickerHost(
      tester,
      onOpen: (context) async {
        result = await showGregorianDatePicker(
          context: context,
          initialDate: DateTime(2024, 2, 29),
        );
      },
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('29'), findsWidgets);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result, DateTime(2024, 2, 29));
  });

  testWidgets(
    'migrated Kemetic picker uses app month metadata and conversion',
    (tester) async {
      DateTime? result;
      final monthLabel = getMonthById(1).displayFull;

      await _pumpPickerHost(
        tester,
        onOpen: (context) async {
          result = await showKemeticDatePicker(
            context: context,
            initialDate: DateTime(2025, 3, 20),
          );
        },
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(monthLabel), findsWidgets);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(result, DateTime(2025, 3, 20));
    },
  );
}

Future<void> _pumpPickerHost(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) onOpen,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => onOpen(context),
              child: const Text('Open'),
            );
          },
        ),
      ),
    ),
  );
}

class _SimpleDateAdapter extends StoneDatePickerAdapter<DateTime> {
  const _SimpleDateAdapter();

  @override
  List<StoneWheelColumn> buildColumns(
    DateTime value,
    StoneDatePickerCalendarMode mode,
  ) {
    final monthPrefix = mode == StoneDatePickerCalendarMode.kemetic
        ? 'Kemetic'
        : 'Gregorian';
    return [
      StoneWheelColumn(
        id: 'month',
        values: ['$monthPrefix 1', '$monthPrefix 2'],
        selectedIndex: value.month - 1,
        looping: true,
        flex: 2,
      ),
      StoneWheelColumn(
        id: 'day',
        values: const ['1', '2'],
        selectedIndex: value.day - 1,
        looping: true,
      ),
      StoneWheelColumn(
        id: 'year',
        values: const ['2026', '2027'],
        selectedIndex: value.year - 2026,
      ),
    ];
  }

  @override
  DateTime clampOrNormalize(DateTime value, StoneDatePickerCalendarMode mode) {
    return DateTime(
      value.year.clamp(2026, 2027).toInt(),
      value.month,
      value.day,
    );
  }

  @override
  String formatValue(DateTime value, StoneDatePickerCalendarMode mode) {
    return '${value.year}-${value.month}-${value.day}';
  }

  @override
  StoneWheelSelection selectionFromValue(
    DateTime value,
    StoneDatePickerCalendarMode mode,
  ) {
    return StoneWheelSelection({
      'month': value.month - 1,
      'day': value.day - 1,
      'year': value.year - 2026,
    });
  }

  @override
  DateTime valueFromSelection(
    StoneWheelSelection selection,
    StoneDatePickerCalendarMode mode,
  ) {
    return DateTime(
      2026 + selection.indexOf('year'),
      1 + selection.indexOf('month'),
      1 + selection.indexOf('day'),
    );
  }
}
