import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/profile_backdrop_timeline.dart';

void main() {
  test('normalizes device clock samples to local time', () {
    final utcNow = DateTime.utc(2026, 4, 26, 18, 30, 45);

    expect(profileBackdropPhoneLocalNow(() => utcNow), utcNow.toLocal());
  });

  test(
    'blends within the current hour using live minute and second progress',
    () {
      final blend = ProfileBackdropBlend.forTime(
        DateTime(2026, 4, 26, 9, 15, 30),
      );

      expect(blend.current.assetPath, endsWith('/9am.jpg'));
      expect(blend.next.assetPath, endsWith('/10am.jpg'));
      expect(blend.t, closeTo(15.5 / 60, 0.0001));
    },
  );

  test('wraps from the last nightly frame back to midnight', () {
    final blend = ProfileBackdropBlend.forTime(DateTime(2026, 4, 26, 23, 30));

    expect(blend.current.assetPath, endsWith('/11pm.jpg'));
    expect(blend.next.assetPath, endsWith('/12am.jpg'));
    expect(blend.t, closeTo(0.5, 0.0001));
  });

  test('waits until the next hourly frame boundary', () {
    final delay = profileBackdropDelayUntilNextFrameChange(
      DateTime(2026, 4, 26, 9, 15, 30, 250),
    );

    expect(delay, const Duration(minutes: 44, seconds: 29, milliseconds: 750));
  });
}
