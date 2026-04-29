const String profileBackdropAssetDirectory = 'assets/profile/day_cycle_alt';

class ProfileBackdropFrame {
  final String assetPath;
  final int minuteOfDay;

  const ProfileBackdropFrame({
    required this.assetPath,
    required this.minuteOfDay,
  });
}

// Curated anchors across the day. These alternates are visually consistent
// enough to support live blending without the doubled-landmark issue from the
// older hourly set.
const List<ProfileBackdropFrame> profileBackdropFrames = [
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_ud0tf5ud0tf5ud0t.png',
    minuteOfDay: 30,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_w23cuuw23cuuw23c.png',
    minuteOfDay: 3 * 60 + 30,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_tj7dxltj7dxltj7d.png',
    minuteOfDay: 5 * 60 + 15,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_fzalkbfzalkbfzal.png',
    minuteOfDay: 6 * 60,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_obejgdobejgdobej.png',
    minuteOfDay: 6 * 60 + 45,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_akck2oakck2oakck.png',
    minuteOfDay: 8 * 60,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_kqnl1zkqnl1zkqnl.png',
    minuteOfDay: 9 * 60 + 30,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_hxen9ghxen9ghxen.png',
    minuteOfDay: 11 * 60,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_xt94fyxt94fyxt94.png',
    minuteOfDay: 12 * 60 + 15,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_34xdte34xdte34xd.png',
    minuteOfDay: 13 * 60 + 30,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_qpd87fqpd87fqpd8.png',
    minuteOfDay: 14 * 60 + 45,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_twbjprtwbjprtwbj.png',
    minuteOfDay: 16 * 60,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_xk3nzmxk3nzmxk3n.png',
    minuteOfDay: 17 * 60 + 15,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_utruv3utruv3utru (1).png',
    minuteOfDay: 18 * 60 + 30,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_8m6x8m8m6x8m8m6x.png',
    minuteOfDay: 19 * 60 + 15,
  ),
  ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/Gemini_Generated_Image_vc4fm5vc4fm5vc4f.png',
    minuteOfDay: 20 * 60 + 15,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/primary_night_pyramid.png',
    minuteOfDay: 23 * 60,
  ),
];

// The profile backdrop should follow the phone's current local clock.
DateTime profileBackdropPhoneLocalNow([DateTime Function()? clock]) =>
    (clock ?? DateTime.now)().toLocal();

Duration profileBackdropDelayUntilNextBlendTick(DateTime now) {
  final nextTick = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute + 1,
  );
  final delay = nextTick.difference(now);
  return delay > Duration.zero ? delay : const Duration(minutes: 1);
}

class ProfileBackdropBlend {
  final ProfileBackdropFrame current;
  final ProfileBackdropFrame next;
  final double t;

  const ProfileBackdropBlend({
    required this.current,
    required this.next,
    required this.t,
  });

  factory ProfileBackdropBlend.forTime(DateTime now) {
    final minuteOfDay =
        (now.hour * 60) +
        now.minute +
        (now.second / 60) +
        (now.millisecond / 60000);

    for (var index = 0; index < profileBackdropFrames.length; index++) {
      final current = profileBackdropFrames[index];
      final next =
          profileBackdropFrames[(index + 1) % profileBackdropFrames.length];
      final nextMinute = index == profileBackdropFrames.length - 1
          ? next.minuteOfDay + 1440
          : next.minuteOfDay;
      final wrappedMinute =
          index == profileBackdropFrames.length - 1 &&
              minuteOfDay < current.minuteOfDay
          ? minuteOfDay + 1440
          : minuteOfDay;

      if (wrappedMinute >= current.minuteOfDay && wrappedMinute < nextMinute) {
        final span = nextMinute - current.minuteOfDay;
        final t = span <= 0
            ? 0.0
            : (wrappedMinute - current.minuteOfDay) / span;
        return ProfileBackdropBlend(
          current: current,
          next: next,
          t: t.clamp(0.0, 1.0).toDouble(),
        );
      }
    }

    return ProfileBackdropBlend(
      current: profileBackdropFrames.first,
      next: profileBackdropFrames[1],
      t: 0.0,
    );
  }
}
