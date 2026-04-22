import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rhythm/todo_day_window.dart';

void main() {
  test('buildTodoDayWindow centers 2 days before and after today', () {
    final days = buildTodoDayWindow(anchorDay: DateTime(2026, 4, 21));

    expect(days, [
      DateTime(2026, 4, 19),
      DateTime(2026, 4, 20),
      DateTime(2026, 4, 21),
      DateTime(2026, 4, 22),
      DateTime(2026, 4, 23),
    ]);
  });

  test('buildTodoDayWindow normalizes dates across DST boundaries', () {
    final days = buildTodoDayWindow(anchorDay: DateTime(2026, 3, 8, 17, 45));

    expect(days, [
      DateTime(2026, 3, 6),
      DateTime(2026, 3, 7),
      DateTime(2026, 3, 8),
      DateTime(2026, 3, 9),
      DateTime(2026, 3, 10),
    ]);
    expect(days.every((day) => day.hour == 0 && day.minute == 0), isTrue);
  });

  test(
    'resolveTodoDayWindowIndex falls back to today when focus is out of range',
    () {
      final today = DateTime(2026, 4, 21);
      final days = buildTodoDayWindow(anchorDay: today);

      expect(
        resolveTodoDayWindowIndex(
          days,
          today: today,
          focusDay: DateTime(2026, 4, 26),
        ),
        2,
      );
    },
  );

  test('resolveTodoDayWindowIndex keeps an in-range future day selected', () {
    final today = DateTime(2026, 4, 21);
    final days = buildTodoDayWindow(anchorDay: today);

    expect(
      resolveTodoDayWindowIndex(
        days,
        today: today,
        focusDay: DateTime(2026, 4, 23),
      ),
      4,
    );
  });
}
