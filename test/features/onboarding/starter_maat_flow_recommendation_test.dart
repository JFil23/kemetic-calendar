import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_flow_catalog.dart';
import 'package:mobile/features/onboarding/starter_maat_flow_recommendation.dart';

void main() {
  const service = StarterFlowRecommendationService();

  test('follow the sky recommends the sole new sky product', () {
    final result = service.recommend(
      goal: FirstRhythmGoal.followTheSky,
      timePreference: RhythmTimePreference.flexible,
      duration: RhythmDuration.tenMinutes,
    );

    expect(result.map((flow) => flow.templateKey), <String>[
      StarterMaatFlowKeys.followTheSky,
    ]);
  });

  test('dawn daily discipline makes Dawn House Rite prominent', () {
    final result = service.recommend(
      goal: FirstRhythmGoal.buildDailyDiscipline,
      timePreference: RhythmTimePreference.dawn,
      duration: RhythmDuration.twoMinutes,
    );

    expect(result.first.templateKey, StarterMaatFlowKeys.dawnHouseRite);
    expect(result.first.prominent, isTrue);
  });

  test('care for the body recommends Offering Table and Tending', () {
    final result = service.recommend(
      goal: FirstRhythmGoal.careForTheBody,
      timePreference: RhythmTimePreference.midday,
      duration: RhythmDuration.twentyMinutes,
    );

    expect(result.map((flow) => flow.templateKey), <String>[
      StarterMaatFlowKeys.offeringTable,
      StarterMaatFlowKeys.theTending,
    ]);
  });

  test('study and remember recommends Reading House and Kept Word', () {
    final result = service.recommend(
      goal: FirstRhythmGoal.studyAndRemember,
      timePreference: RhythmTimePreference.evening,
      duration: RhythmDuration.tenMinutes,
    );

    expect(
      result.map((flow) => flow.templateKey),
      containsAllInOrder([
        StarterMaatFlowKeys.readingHouse,
        StarterMaatFlowKeys.keptWord,
      ]),
    );
  });

  test('every input combination recommends only core products', () {
    for (final goal in FirstRhythmGoal.values) {
      for (final timePreference in RhythmTimePreference.values) {
        for (final duration in RhythmDuration.values) {
          final result = service.recommend(
            goal: goal,
            timePreference: timePreference,
            duration: duration,
          );
          expect(result, hasLength(lessThanOrEqualTo(3)));
          expect(
            result.every((flow) => isCoreMaatFlowKey(flow.templateKey)),
            isTrue,
            reason: '$goal / $timePreference / $duration',
          );
          expect(
            result.map((flow) => flow.templateKey),
            isNot(contains('the-decan-watch')),
          );
        }
      }
    }
  });
}
