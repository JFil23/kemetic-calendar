import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/profile_backdrop_timeline.dart';

void main() {
  test('normalizes device clock samples to local time', () {
    final utcNow = DateTime.utc(2026, 4, 26, 18, 30, 45);

    expect(profileBackdropPhoneLocalNow(() => utcNow), utcNow.toLocal());
  });

  test('blends across the curated dawn interval', () {
    final blend = ProfileBackdropBlend.forTime(
      DateTime(2026, 4, 26, 5, 37, 30),
    );

    expect(blend.current.assetPath, endsWith('/5am.jpg'));
    expect(blend.next.assetPath, endsWith('/6am.jpg'));
    expect(blend.t, closeTo(37.5 / 60, 0.0001));
  });

  test('wraps from the late-night anchor back into the overnight sequence', () {
    final blend = ProfileBackdropBlend.forTime(DateTime(2026, 4, 26, 23, 30));

    expect(blend.current.assetPath, endsWith('/11pm.jpg'));
    expect(blend.next.assetPath, endsWith('/12am.jpg'));
    expect(blend.t, closeTo(0.5, 0.0001));
  });

  test('waits until the next minute blend tick', () {
    final delay = profileBackdropDelayUntilNextBlendTick(
      DateTime(2026, 4, 26, 9, 15, 30, 250),
    );

    expect(delay, const Duration(seconds: 29, milliseconds: 750));
  });
}
