const String profileBackdropAssetDirectory =
    'assets/profile/day_cycle_registered_v3_jpg';

class ProfileBackdropFrame {
  final String assetPath;
  final int minuteOfDay;

  const ProfileBackdropFrame({
    required this.assetPath,
    required this.minuteOfDay,
  });
}

const List<ProfileBackdropFrame> profileBackdropFrames = [
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/12am.jpg',
    minuteOfDay: 0,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/1am.jpg',
    minuteOfDay: 60,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/2am.jpg',
    minuteOfDay: 120,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/3am.jpg',
    minuteOfDay: 180,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/4am.jpg',
    minuteOfDay: 240,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/5am.jpg',
    minuteOfDay: 300,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/6am.jpg',
    minuteOfDay: 360,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/7am.jpg',
    minuteOfDay: 420,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/8am.jpg',
    minuteOfDay: 480,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/9am.jpg',
    minuteOfDay: 540,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/10am.jpg',
    minuteOfDay: 600,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/11am.jpg',
    minuteOfDay: 660,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/12pm.jpg',
    minuteOfDay: 720,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/1pm.jpg',
    minuteOfDay: 780,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/2pm.jpg',
    minuteOfDay: 840,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/3pm.jpg',
    minuteOfDay: 900,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/4pm.jpg',
    minuteOfDay: 960,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/5pm.jpg',
    minuteOfDay: 1020,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/6pm.jpg',
    minuteOfDay: 1080,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/7pm.jpg',
    minuteOfDay: 1140,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/8pm.jpg',
    minuteOfDay: 1200,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/9pm.jpg',
    minuteOfDay: 1260,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/10pm.jpg',
    minuteOfDay: 1320,
  ),
  ProfileBackdropFrame(
    assetPath: '$profileBackdropAssetDirectory/11pm.jpg',
    minuteOfDay: 1380,
  ),
];

// The profile backdrop should follow the phone's current local clock.
DateTime profileBackdropPhoneLocalNow([DateTime Function()? clock]) =>
    (clock ?? DateTime.now)().toLocal();

Duration profileBackdropDelayUntilNextFrameChange(DateTime now) {
  final nextFrame = DateTime(now.year, now.month, now.day, now.hour + 1);
  final delay = nextFrame.difference(now);
  return delay > Duration.zero ? delay : const Duration(hours: 1);
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
