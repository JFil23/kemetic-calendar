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

  test('daily discipline makes The Djed prominent', () {
    final result = service.recommend(
      goal: FirstRhythmGoal.buildDailyDiscipline,
      timePreference: RhythmTimePreference.dawn,
      duration: RhythmDuration.twoMinutes,
    );

    expect(result.first.templateKey, StarterMaatFlowKeys.theDjed);
    expect(result.first.prominent, isTrue);
  });

  test('care for the body recommends Offering Table and Follow the Sky', () {
    final result = service.recommend(
      goal: FirstRhythmGoal.careForTheBody,
      timePreference: RhythmTimePreference.midday,
      duration: RhythmDuration.twentyMinutes,
    );

    expect(result.map((flow) => flow.templateKey), <String>[
      StarterMaatFlowKeys.offeringTable,
      StarterMaatFlowKeys.followTheSky,
    ]);
  });

  test('study and remember recommends Reading House and The Djed', () {
    final result = service.recommend(
      goal: FirstRhythmGoal.studyAndRemember,
      timePreference: RhythmTimePreference.evening,
      duration: RhythmDuration.tenMinutes,
    );

    expect(
      result.map((flow) => flow.templateKey),
      containsAllInOrder([
        StarterMaatFlowKeys.readingHouse,
        StarterMaatFlowKeys.theDjed,
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
            result.every((flow) => isMaatFlowNewJoinAllowed(flow.templateKey)),
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
