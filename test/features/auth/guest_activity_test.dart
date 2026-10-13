import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/guest_activity.dart';

void main() {
  late Duration time;
  late GuestActivity activity;
  setUp(() {
    time = Duration.zero;
    activity = GuestActivity(now: () => time)..setEnabled(true);
  });
  test('idle and one interaction followed by waiting never invite', () {
    time += const Duration(minutes: 1);
    expect(activity.sample(), isFalse);
    expect(activity.activeTime, Duration.zero);
    activity.interact();
    time += const Duration(minutes: 1);
    expect(activity.sample(), isFalse);
    expect(activity.activeTime, const Duration(seconds: 1));
  });
  test('five cumulative active seconds invite once', () {
    for (var i = 0; i < 10; i++) {
      activity.interact();
      time += const Duration(milliseconds: 500);
      expect(activity.sample(), i == 9);
    }
    activity.consume();
    activity.interact();
    time += const Duration(seconds: 5);
    expect(activity.sample(), isFalse);
  });
  test('background, intro and dialog pauses cannot earn activity', () {
    activity.interact();
    time += const Duration(milliseconds: 500);
    activity.setEnabled(false);
    time += const Duration(minutes: 2);
    activity.interact();
    activity.setEnabled(true);
    expect(activity.activeTime, const Duration(milliseconds: 500));
    time += const Duration(seconds: 5);
    expect(activity.sample(), isFalse);
    expect(activity.activeTime, const Duration(milliseconds: 500));
  });
  test('short separated bursts accumulate without charging the idle gap', () {
    for (var i = 0; i < 5; i++) {
      activity.interact();
      time += const Duration(seconds: 10);
      expect(activity.sample(), i == 4);
    }
    expect(activity.activeTime, GuestActivity.threshold);
  });
}
