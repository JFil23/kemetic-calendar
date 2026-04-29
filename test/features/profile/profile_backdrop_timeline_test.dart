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

    expect(
      blend.current.assetPath,
      endsWith('/Gemini_Generated_Image_tj7dxltj7dxltj7d.png'),
    );
    expect(
      blend.next.assetPath,
      endsWith('/Gemini_Generated_Image_fzalkbfzalkbfzal.png'),
    );
    expect(blend.t, closeTo(0.5, 0.0001));
  });

  test('wraps from the late-night anchor back into the overnight sequence', () {
    final blend = ProfileBackdropBlend.forTime(DateTime(2026, 4, 26, 23, 30));

    expect(blend.current.assetPath, endsWith('/primary_night_pyramid.png'));
    expect(
      blend.next.assetPath,
      endsWith('/Gemini_Generated_Image_ud0tf5ud0tf5ud0t.png'),
    );
    expect(blend.t, closeTo(30 / 90, 0.0001));
  });

  test('waits until the next minute blend tick', () {
    final delay = profileBackdropDelayUntilNextBlendTick(
      DateTime(2026, 4, 26, 9, 15, 30, 250),
    );

    expect(delay, const Duration(seconds: 29, milliseconds: 750));
  });
}
