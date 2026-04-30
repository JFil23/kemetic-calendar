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

const List<String> _profileBackdropHourLabels = <String>[
  '12am',
  '1am',
  '2am',
  '3am',
  '4am',
  '5am',
  '6am',
  '7am',
  '8am',
  '9am',
  '10am',
  '11am',
  '12pm',
  '1pm',
  '2pm',
  '3pm',
  '4pm',
  '5pm',
  '6pm',
  '7pm',
  '8pm',
  '9pm',
  '10pm',
  '11pm',
];

final List<ProfileBackdropFrame>
profileBackdropFrames = List<ProfileBackdropFrame>.generate(24, (index) {
  return ProfileBackdropFrame(
    assetPath:
        '$profileBackdropAssetDirectory/${_profileBackdropHourLabels[index]}.jpg',
    minuteOfDay: index * 60,
  );
}, growable: false);

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
