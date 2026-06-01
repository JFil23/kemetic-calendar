import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/starter_maat_flow_recommendation.dart';

void main() {
  const service = StarterFlowRecommendationService();

  test('follow the sky recommends sky and decan flows', () {
    final result = service.recommend(
      goal: FirstRhythmGoal.followTheSky,
      timePreference: RhythmTimePreference.flexible,
      duration: RhythmDuration.tenMinutes,
    );

    expect(
      result.map((flow) => flow.templateKey),
      containsAllInOrder([
        StarterMaatFlowKeys.followTheSky,
        StarterMaatFlowKeys.walkTheDecan,
      ]),
    );
  });

  test('dawn daily discipline makes Rite House Dawn prominent', () {
    final result = service.recommend(
      goal: FirstRhythmGoal.buildDailyDiscipline,
      timePreference: RhythmTimePreference.dawn,
      duration: RhythmDuration.twoMinutes,
    );

    expect(result.first.templateKey, StarterMaatFlowKeys.riteHouseDawn);
    expect(result.first.prominent, isTrue);
  });

  test('care for the body recommends Body in Balance', () {
    final result = service.recommend(
      goal: FirstRhythmGoal.careForTheBody,
      timePreference: RhythmTimePreference.midday,
      duration: RhythmDuration.twentyMinutes,
    );

    expect(result.first.templateKey, StarterMaatFlowKeys.bodyInBalance);
  });

  test('study and remember recommends Keep the Word and Walk the Decan', () {
    final result = service.recommend(
      goal: FirstRhythmGoal.studyAndRemember,
      timePreference: RhythmTimePreference.evening,
      duration: RhythmDuration.tenMinutes,
    );

    expect(
      result.map((flow) => flow.templateKey),
      containsAllInOrder([
        StarterMaatFlowKeys.keepTheWord,
        StarterMaatFlowKeys.walkTheDecan,
      ]),
    );
  });
}
