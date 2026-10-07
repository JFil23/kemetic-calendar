import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/decan_reflection_window.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart' show KemeticMath;

void main() {
  DateTime at(int year, int month, int day, int hour) {
    final d = KemeticMath.toGregorian(year, month, day);
    return DateTime(d.year, d.month, d.day, hour);
  }

  test('manual invitation selects preceding decan until 20:00 on day ten', () {
    final before = latestCompletedDecanReflectionWindow(
      at(4, 2, 10, 19),
      availableOnly: true,
    )!;
    final after = latestCompletedDecanReflectionWindow(
      at(4, 2, 10, 20),
      availableOnly: true,
    )!;
    expect(before.end, KemeticMath.toGregorian(4, 1, 30));
    expect(after.start, KemeticMath.toGregorian(4, 2, 1));
    expect(after.end, KemeticMath.toGregorian(4, 2, 10));
    // Automatic Calendar still applies its existing 20:00 visibility gate.
    expect(
      latestCompletedDecanReflectionWindow(at(4, 2, 10, 19))!.end,
      after.end,
    );
  });
  test(
    'any-time window spans supplementary days, year rollover and all civil dates',
    () {
      for (final year in [3, 4]) {
        final first = at(year, 1, 1, 0);
        final nextYear = at(year + 1, 1, 1, 0);
        for (
          var day = first;
          day.isBefore(nextYear);
          day = DateTime(day.year, day.month, day.day + 1)
        ) {
          for (final hour in [0, 19, 20, 23]) {
            final now = DateTime(day.year, day.month, day.day, hour);
            final w = latestCompletedDecanReflectionWindow(
              now,
              availableOnly: true,
            )!;
            final gate = decanReflectionAvailableAt(w.start);
            expect(gate, DateTime(w.end.year, w.end.month, w.end.day, 20));
            expect(gate.isAfter(now), isFalse, reason: '$now');
            expect(KemeticMath.fromGregorian(w.start).kDay, isIn([1, 11, 21]));
            expect(
              KemeticMath.fromGregorian(w.end).kMonth,
              lessThanOrEqualTo(12),
            );
            expect(
              w.end,
              DateTime.utc(w.start.year, w.start.month, w.start.day + 9),
            );
          }
        }
        expect(
          latestCompletedDecanReflectionWindow(first, availableOnly: true)!.end,
          KemeticMath.toGregorian(year - 1, 12, 30),
        );
      }
    },
  );
}
