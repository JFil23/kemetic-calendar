import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/calendar/the_course_context.dart';

void main() {
  test('season instruction helper branches by Kemetic season', () {
    expect(
      courseSeasonInstruction(KemeticSeason.akhet),
      contains('Receive; do not force'),
    );
    expect(
      courseSeasonInstruction(KemeticSeason.peret),
      contains('Emerge; plant'),
    );
    expect(
      courseSeasonInstruction(KemeticSeason.shemu),
      contains('Complete; gather'),
    );
    expect(
      courseSeasonInstruction(KemeticSeason.transition),
      contains('Threshold days'),
    );
  });

  test(
    'calendar context exposes date, decan, principle, and season labels',
    () {
      final akhet = courseContextForKemeticDate(kYear: 2, kMonth: 1, kDay: 1);
      final peret = courseContextForKemeticDate(kYear: 2, kMonth: 5, kDay: 1);
      final shemu = courseContextForKemeticDate(kYear: 2, kMonth: 9, kDay: 1);
      final transition = courseContextForKemeticDate(
        kYear: 2,
        kMonth: 13,
        kDay: 1,
      );

      expect(akhet.seasonKey, 'akhet');
      expect(peret.seasonKey, 'peret');
      expect(shemu.seasonKey, 'shemu');
      expect(transition.seasonKey, 'transition');
      expect(akhet.kemeticDateLabel, isNotEmpty);
      expect(akhet.decanName, isNotEmpty);
      expect(akhet.maatPrinciple, isNotEmpty);
    },
  );
}
