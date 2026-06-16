import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rhythm/planner/planner_scale_math.dart';

void main() {
  group('plannerScaleTiltDegrees', () {
    test('starts dramatically tilted at 0 percent', () {
      expect(plannerScaleTiltDegrees(0), closeTo(11, 0.001));
    });

    test('stays strongly tilted at 40 percent', () {
      expect(plannerScaleTiltDegrees(40), greaterThan(10));
    });

    test('stays visibly tilted through the middle range', () {
      expect(plannerScaleTiltDegrees(70), greaterThan(7));
    });

    test('approaches level near completion', () {
      expect(plannerScaleTiltDegrees(90), lessThan(4));
      expect(plannerScaleTiltDegrees(90), greaterThanOrEqualTo(0));
    });

    test('is exactly level at 100 percent', () {
      expect(plannerScaleTiltDegrees(100), closeTo(0, 0.001));
    });

    test('never overshoots past level', () {
      for (var pct = 0; pct <= 150; pct++) {
        expect(plannerScaleTiltDegrees(pct), greaterThanOrEqualTo(0));
      }
    });

    test('is monotonic toward level', () {
      var previous = plannerScaleTiltDegrees(0);

      for (var pct = 1; pct <= 100; pct++) {
        final current = plannerScaleTiltDegrees(pct);
        expect(current, lessThanOrEqualTo(previous));
        previous = current;
      }
    });
  });
}
