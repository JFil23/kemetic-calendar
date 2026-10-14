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
  test(
    'new accounts wait until the next decan and never see pre-account reviews',
    () {
      for (final month in [1, 2, 12]) {
        for (final joinDay in [1, 9, 10, 11, 19, 20, 21, 29, 30]) {
          final join = at(4, month, joinDay, 12);
          final startDay = ((joinDay - 1) ~/ 10) * 10 + 1;
          final start = KemeticMath.toGregorian(4, month, startDay);
          final end = at(4, month, startDay + 9, 23);
          expect(
            isAccountEligibleForDecanReflection(
              accountCreatedAt: join,
              now: end,
              windowStart: start,
            ),
            isFalse,
          );
          final following = month == 12 && startDay == 21
              ? at(5, 1, 1, 0)
              : DateTime(end.year, end.month, end.day + 1);
          expect(
            isAccountEligibleForDecanReflection(
              accountCreatedAt: join,
              now: following,
              windowStart: start,
            ),
            isTrue,
          );
          expect(
            isAccountEligibleForDecanReflection(
              accountCreatedAt: join,
              now: following,
              windowStart: DateTime(start.year, start.month, start.day - 10),
            ),
            isFalse,
          );
        }
      }
      final supplementary = at(4, 13, 3, 12);
      final finalStart = KemeticMath.toGregorian(4, 12, 21);
      expect(
        isAccountEligibleForDecanReflection(
          accountCreatedAt: supplementary,
          now: at(4, 13, 5, 23),
          windowStart: finalStart,
        ),
        isFalse,
      );
      expect(
        isAccountEligibleForDecanReflection(
          accountCreatedAt: supplementary,
          now: at(5, 1, 1, 0),
          windowStart: finalStart,
        ),
        isTrue,
      );
      expect(
        isAccountEligibleForDecanReflection(
          accountCreatedAt: null,
          now: at(5, 1, 1, 0),
          windowStart: finalStart,
        ),
        isFalse,
      );
    },
  );
}
