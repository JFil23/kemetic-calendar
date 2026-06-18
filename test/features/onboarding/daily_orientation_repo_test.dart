import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/daily_orientation_repo.dart';

void main() {
  const userId = 'user-a';
  const otherUserId = 'user-b';

  DailyOrientationEntry entry({
    required String userId,
    required DateTime date,
    String? chosenReturn,
    String? source,
  }) {
    return DailyOrientationEntry(
      userId: userId,
      localDate: date,
      chosenReturn: chosenReturn,
      source: source,
      status: 'started',
    );
  }

  group('DailyOrientationCarryResolver', () {
    test('carries Day 1 intention across a missed Day 2 into Day 3', () {
      final resolved = DailyOrientationCarryResolver.resolveEffectiveCarry(
        userId: userId,
        localDate: DateTime(2026, 6, 3),
        latestPriorCarry: entry(
          userId: userId,
          date: DateTime(2026, 6),
          chosenReturn: 'Hold the line',
          source: 'daily_orientation_start',
        ),
      );

      expect(resolved?.localDate, DateTime(2026, 6, 3));
      expect(resolved?.chosenReturn, 'Hold the line');
      expect(resolved?.source, 'daily_orientation_start');
    });

    test('new Day 3 carry overrides the prior carry going forward', () {
      final resolved = DailyOrientationCarryResolver.resolveEffectiveCarry(
        userId: userId,
        localDate: DateTime(2026, 6, 4),
        latestPriorCarry: entry(
          userId: userId,
          date: DateTime(2026, 6, 3),
          chosenReturn: 'Carry the new word',
          source: 'newly_set',
        ),
      );

      expect(resolved?.chosenReturn, 'Carry the new word');
      expect(resolved?.source, 'newly_set');
    });

    test('exact-date value wins over latest prior carry', () {
      final resolved = DailyOrientationCarryResolver.resolveEffectiveCarry(
        userId: userId,
        localDate: DateTime(2026, 6, 3),
        exactEntry: entry(
          userId: userId,
          date: DateTime(2026, 6, 3),
          chosenReturn: 'Today only',
          source: 'newly_set',
        ),
        latestPriorCarry: entry(
          userId: userId,
          date: DateTime(2026, 6),
          chosenReturn: 'Older carry',
          source: 'daily_orientation_start',
        ),
      );

      expect(resolved?.chosenReturn, 'Today only');
      expect(resolved?.source, 'newly_set');
    });

    test('empty or null chosen_return does not become active carry', () {
      final resolved = DailyOrientationCarryResolver.resolveEffectiveCarry(
        userId: userId,
        localDate: DateTime(2026, 6, 3),
        exactEntry: entry(
          userId: userId,
          date: DateTime(2026, 6, 3),
          chosenReturn: '',
        ),
        latestPriorCarry: entry(
          userId: userId,
          date: DateTime(2026, 6),
          chosenReturn: '   ',
        ),
      );

      expect(resolved?.chosenReturn?.trim(), anyOf(isNull, isEmpty));
    });

    test('another user carry is never loaded', () {
      final resolved = DailyOrientationCarryResolver.resolveEffectiveCarry(
        userId: userId,
        localDate: DateTime(2026, 6, 3),
        latestPriorCarry: entry(
          userId: otherUserId,
          date: DateTime(2026, 6),
          chosenReturn: 'Other user carry',
        ),
      );

      expect(resolved, isNull);
    });

    test('future carry is ignored for earlier target dates', () {
      final resolved = DailyOrientationCarryResolver.resolveEffectiveCarry(
        userId: userId,
        localDate: DateTime(2026, 6, 3),
        latestPriorCarry: entry(
          userId: userId,
          date: DateTime(2026, 6, 4),
          chosenReturn: 'Tomorrow carry',
        ),
      );

      expect(resolved, isNull);
    });
  });
}
