import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/daily_orientation_repo.dart';

void main() {
  test('skipped or missed days keep the latest unresolved carry available', () {
    const userId = 'user-1';
    final day1 = DateTime(2026, 6, 1);
    final day2 = DateTime(2026, 6, 2);
    final day3 = DateTime(2026, 6, 3);

    final carry = DailyOrientationEntry(
      userId: userId,
      localDate: day1,
      chosenReturn: 'Patience with my mother',
      status: 'started',
    );
    final skippedDay = DailyOrientationEntry(
      userId: userId,
      localDate: day2,
      status: 'skipped',
    );

    final afterOneSkipped = DailyOrientationCarryResolver.resolveEffectiveCarry(
      userId: userId,
      localDate: day2,
      exactEntry: skippedDay,
      latestPriorCarry: carry,
    );
    final afterConsecutiveMissed =
        DailyOrientationCarryResolver.resolveEffectiveCarry(
          userId: userId,
          localDate: day3,
          latestPriorCarry: carry,
        );

    expect(afterOneSkipped?.chosenReturn, 'Patience with my mother');
    expect(afterConsecutiveMissed?.chosenReturn, 'Patience with my mother');
  });

  test('new carry after release supersedes a previously skipped intention', () {
    const userId = 'user-1';
    final day2 = DateTime(2026, 6, 2);
    final day3 = DateTime(2026, 6, 3);

    final newCarry = DailyOrientationEntry(
      userId: userId,
      localDate: day2,
      chosenReturn: 'Speak plainly',
      source: 'newly_set',
      status: 'started',
    );

    final resolved = DailyOrientationCarryResolver.resolveEffectiveCarry(
      userId: userId,
      localDate: day3,
      latestPriorCarry: newCarry,
    );

    expect(resolved?.chosenReturn, 'Speak plainly');
  });
}
