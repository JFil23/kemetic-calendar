import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

const String profileBackdropAssetDirectory = 'assets/profile/day_cycle_alt_2';

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

class ProfileDayCycleBackdrop extends StatefulWidget {
  const ProfileDayCycleBackdrop({
    super.key,
    this.opacity = 0.9,
    this.alignment = const Alignment(-0.08, -1.0),
  });

  final double opacity;
  final Alignment alignment;

  @override
  State<ProfileDayCycleBackdrop> createState() =>
      _ProfileDayCycleBackdropState();
}

class _ProfileDayCycleBackdropState extends State<ProfileDayCycleBackdrop>
    with WidgetsBindingObserver {
  static const int _backdropSourceWidth = 2730;

  final Set<String> _precachedAssets = <String>{};
  Timer? _tickTimer;
  DateTime _visibleNow = profileBackdropPhoneLocalNow();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextTick();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _primeAssets(ProfileBackdropBlend.forTime(_visibleNow));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    _refreshVisibleTime();
  }

  void _primeAssets(ProfileBackdropBlend blend) {
    final assetsToPrime = <String>[
      for (final assetPath in {blend.current.assetPath, blend.next.assetPath})
        if (_precachedAssets.add(assetPath)) assetPath,
    ];
    if (assetsToPrime.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final assetPath in assetsToPrime) {
        unawaited(precacheImage(_backdropImageProvider(assetPath), context));
      }
    });
  }

  ImageProvider<Object> _backdropImageProvider(String assetPath) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    final logicalWidth = mediaQuery?.size.width ?? 1024.0;
    final targetWidth = math.min(
      _backdropSourceWidth,
      math.max(1, (logicalWidth * devicePixelRatio).round()),
    );
    return ResizeImage.resizeIfNeeded(targetWidth, null, AssetImage(assetPath));
  }

  void _refreshVisibleTime() {
    final now = profileBackdropPhoneLocalNow();
    _primeAssets(ProfileBackdropBlend.forTime(now));
    setState(() {
      _visibleNow = now;
    });
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    _tickTimer?.cancel();
    final now = profileBackdropPhoneLocalNow();
    _tickTimer = Timer(profileBackdropDelayUntilNextBlendTick(now), () {
      if (!mounted) return;
      _refreshVisibleTime();
    });
  }

  Widget _buildBackdropImage(String assetPath) {
    return Image(
      image: _backdropImageProvider(assetPath),
      fit: BoxFit.cover,
      alignment: widget.alignment,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) =>
          const _ProfileBackdropFallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blend = ProfileBackdropBlend.forTime(_visibleNow);
    final nextOpacity = blend.t;
    _primeAssets(blend);

    return RepaintBoundary(
      child: SizedBox.expand(
        child: Opacity(
          opacity: widget.opacity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackdropImage(blend.current.assetPath),
              if (nextOpacity > 0.001)
                Opacity(
                  opacity: nextOpacity,
                  child: _buildBackdropImage(blend.next.assetPath),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileBackdropFallback extends StatelessWidget {
  const _ProfileBackdropFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF05070E), Color(0xFF090807), Color(0xFF000000)],
          stops: [0.0, 0.58, 1.0],
        ),
      ),
    );
  }
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
