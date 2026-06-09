import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/calendar/day_view_chrome.dart';
import 'package:mobile/features/calendar/kemetic_month_metadata.dart';
import 'package:mobile/features/profile/profile_backdrop_timeline.dart';
import 'package:mobile/features/rhythm/theme/rhythm_theme.dart';
import 'package:mobile/features/rhythm/widgets/rhythm_section_card.dart';
import 'package:mobile/shared/glossy_text.dart';
import 'package:mobile/widgets/kemetic_heart_icon.dart';
import 'package:mobile/widgets/kemetic_day_info.dart';
import 'package:mobile/widgets/kemetic_date_picker.dart' show KemeticMath;

class OnboardingSlide {
  const OnboardingSlide({
    this.eyebrow,
    required this.title,
    required this.description,
    required this.primaryActionLabel,
    required this.visual,
    this.backdropOpacity = 1.0,
    this.backdropBlurSigma = 16,
    this.textBackplateOpacity = 0,
    this.textBackplateBlurSigma = 0,
  });

  final String? eyebrow;
  final String title;
  final String description;
  final String primaryActionLabel;
  final Widget visual;
  final double backdropOpacity;
  final double backdropBlurSigma;
  final double textBackplateOpacity;
  final double textBackplateBlurSigma;
}

const List<_FloatingGlyph> _ambientGlyphs = [
  _FloatingGlyph(
    label: '𓇳',
    alignment: Alignment(-0.88, -0.72),
    drift: Offset(18, 20),
    phase: 0.00,
    fontSize: 28,
  ),
  _FloatingGlyph(
    label: '𓋹',
    alignment: Alignment(-0.74, -0.18),
    drift: Offset(16, 10),
    phase: 0.10,
    fontSize: 23,
  ),
  _FloatingGlyph(
    label: '𓆣',
    alignment: Alignment(-0.94, 0.08),
    drift: Offset(22, -16),
    phase: 0.22,
    fontSize: 24,
  ),
  _FloatingGlyph(
    label: '𓂀',
    alignment: Alignment(0.86, -0.28),
    drift: Offset(-14, 16),
    phase: 0.35,
    fontSize: 23,
  ),
  _FloatingGlyph(
    label: '𓇯',
    alignment: Alignment(0.14, -0.88),
    drift: Offset(12, 14),
    phase: 0.48,
    fontSize: 20,
  ),
  _FloatingGlyph(
    label: '𓊹',
    alignment: Alignment(0.92, 0.20),
    drift: Offset(-16, -14),
    phase: 0.62,
    fontSize: 18,
  ),
  _FloatingGlyph(
    label: '𓏏',
    alignment: Alignment(0.82, 0.76),
    drift: Offset(10, -22),
    phase: 0.76,
    fontSize: 18,
  ),
  _FloatingGlyph(
    label: '𓅓',
    alignment: Alignment(-0.28, 0.86),
    drift: Offset(16, -12),
    phase: 0.88,
    fontSize: 20,
  ),
  _FloatingGlyph(
    label: '𓏲',
    alignment: Alignment(-0.16, -0.72),
    drift: Offset(18, -12),
    phase: 0.06,
    fontSize: 17,
  ),
  _FloatingGlyph(
    label: '𓊽',
    alignment: Alignment(0.54, -0.70),
    drift: Offset(-16, 14),
    phase: 0.14,
    fontSize: 20,
  ),
  _FloatingGlyph(
    label: '𓆓',
    alignment: Alignment(-0.92, 0.44),
    drift: Offset(14, -22),
    phase: 0.28,
    fontSize: 18,
  ),
  _FloatingGlyph(
    label: '𓍿',
    alignment: Alignment(0.96, -0.04),
    drift: Offset(-12, 18),
    phase: 0.42,
    fontSize: 16,
  ),
  _FloatingGlyph(
    label: '𓇼',
    alignment: Alignment(0.36, 0.82),
    drift: Offset(10, -18),
    phase: 0.56,
    fontSize: 16,
  ),
  _FloatingGlyph(
    label: '𓐍',
    alignment: Alignment(-0.52, 0.68),
    drift: Offset(20, -14),
    phase: 0.68,
    fontSize: 17,
  ),
  _FloatingGlyph(
    label: '𓈖',
    alignment: Alignment(0.72, 0.54),
    drift: Offset(-18, -10),
    phase: 0.82,
    fontSize: 18,
  ),
];

class OnboardingOverlay extends StatefulWidget {
  OnboardingOverlay({
    super.key,
    required this.slides,
    required this.onSkip,
    required this.onComplete,
  }) : assert(slides.isNotEmpty, 'At least one onboarding slide is required.');

  final List<OnboardingSlide> slides;
  final VoidCallback onSkip;
  final VoidCallback onComplete;

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  late final PageController _pageController = PageController();
  int _currentIndex = 0;

  bool get _isLastSlide => _currentIndex == widget.slides.length - 1;

  void _handlePrimaryAction() {
    if (_isLastSlide) {
      widget.onComplete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeSlide = widget.slides[_currentIndex];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(
                        alpha: 0.48 * activeSlide.backdropOpacity,
                      ),
                      Colors.black.withValues(
                        alpha: 0.62 * activeSlide.backdropOpacity,
                      ),
                      Colors.black.withValues(
                        alpha: 0.82 * activeSlide.backdropOpacity,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: activeSlide.backdropBlurSigma,
                  sigmaY: activeSlide.backdropBlurSigma,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.14),
                      radius: 1.0,
                      colors: [
                        KemeticGold.light.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widget.slides.length,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return _OnboardingSlideView(
                          slide: widget.slides[index],
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 8,
                    child: TextButton(
                      onPressed: widget.onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: KemeticGold.light.withValues(
                          alpha: 0.72,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ProgressDots(
                          count: widget.slides.length,
                          currentIndex: _currentIndex,
                        ),
                        const SizedBox(height: 18),
                        _PrimaryActionButton(
                          label: activeSlide.primaryActionLabel,
                          onPressed: _handlePrimaryAction,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isLastSlide
                              ? 'Swipe or tap to begin'
                              : 'Swipe to continue',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: slide.visual),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.40),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                  stops: const [0.0, 0.42, 0.68, 1.0],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 24, 12, 148),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _SlideTextBackplate(
                opacity: slide.textBackplateOpacity,
                blurSigma: slide.textBackplateBlurSigma,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (slide.eyebrow != null && slide.eyebrow!.isNotEmpty) ...[
                      Text(
                        slide.eyebrow!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: KemeticGold.light.withValues(alpha: 0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    GlossyText(
                      text: slide.title,
                      gradient: goldGloss,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'GentiumPlus',
                        height: 1.12,
                      ),
                    ),
                    if (slide.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        slide.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.42,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingWelcomeVisual extends StatefulWidget {
  const OnboardingWelcomeVisual({super.key});

  @override
  State<OnboardingWelcomeVisual> createState() =>
      _OnboardingWelcomeVisualState();
}

class _OnboardingWelcomeVisualState extends State<OnboardingWelcomeVisual>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();
  late final AnimationController _introController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  @override
  void dispose() {
    _ambientController.dispose();
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ambientController, _introController]),
      builder: (context, _) {
        const double heroLift = -58;
        final ambientT = _ambientController.value;
        final introT = Curves.easeOutCubic.transform(_introController.value);
        final introSettle = Curves.easeOutExpo.transform(
          _introController.value,
        );
        final pulse =
            (0.90 + (introT * 0.10)) +
            (math.sin(ambientT * math.pi * 2) * 0.03);
        final ringTurn = (ambientT * 0.016) - 0.008;
        final introGlow = (1 - introT) * 0.22;
        final logoOpacity = Curves.easeOut.transform(
          (_introController.value * 1.2).clamp(0.0, 1.0),
        );
        final bloomScale = ui.lerpDouble(1.72, 1.0, introSettle) ?? 1.0;
        final haloScale = ui.lerpDouble(1.30, 1.0, introSettle) ?? 1.0;
        final revealDrop = ui.lerpDouble(-120, 0, introSettle) ?? 0.0;
        final introBeamOpacity = (1 - introT) * 0.24;
        final introRingOpacity = (1 - introT) * 0.18;
        Widget liftedCenter(Widget child) {
          return Center(
            child: Transform.translate(
              offset: const Offset(0, heroLift),
              child: child,
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(0, revealDrop),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          KemeticGold.light.withValues(alpha: introBeamOpacity),
                          KemeticGold.base.withValues(
                            alpha: introBeamOpacity * 0.48,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.28, 0.72],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.12),
                  radius: 0.92,
                  colors: [
                    KemeticGold.base.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            liftedCenter(
              Transform.scale(
                scale: bloomScale,
                child: Container(
                  width: 470,
                  height: 470,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        KemeticGold.light.withValues(alpha: 0.16 + introGlow),
                        KemeticGold.base.withValues(
                          alpha: 0.08 + introGlow * 0.7,
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.34, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 0.02),
                      radius: 0.72,
                      colors: [
                        KemeticGold.light.withValues(alpha: introGlow),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -90,
              top: -90,
              width: 220,
              height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      KemeticGold.light.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -70,
              bottom: 130,
              width: 180,
              height: 180,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      KemeticGold.base.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            for (final glyph in _ambientGlyphs)
              _AnimatedGlyph(glyph: glyph, t: ambientT, introT: introT),
            liftedCenter(
              Transform.scale(
                scale: haloScale,
                child: Container(
                  width: 386,
                  height: 386,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: KemeticGold.light.withValues(
                        alpha: introRingOpacity,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            liftedCenter(
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 258,
                  height: 258,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        KemeticGold.light.withValues(alpha: 0.20),
                        KemeticGold.base.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.46, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            liftedCenter(
              Transform.rotate(
                angle: ringTurn,
                child: Container(
                  width: 334 * (0.86 + introT * 0.14),
                  height: 334 * (0.86 + introT * 0.14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: KemeticGold.base.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
            ),
            liftedCenter(
              Container(
                width: 286 * (0.82 + introT * 0.18),
                height: 286 * (0.82 + introT * 0.18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: KemeticGold.light.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
            liftedCenter(
              Opacity(
                opacity: logoOpacity,
                child: Transform.scale(
                  scale: 0.90 + (introT * 0.10),
                  child: const GlossyText(
                    text: 'ḥꜣw',
                    gradient: goldGloss,
                    style: TextStyle(
                      fontSize: 88,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'GentiumPlus',
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 1 - introT,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.34),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class OnboardingDayInsightVisual extends StatefulWidget {
  const OnboardingDayInsightVisual({
    super.key,
    required this.dayKey,
    required this.kYear,
    required this.kMonth,
    required this.kDay,
  });

  final String dayKey;
  final int kYear;
  final int kMonth;
  final int kDay;

  @override
  State<OnboardingDayInsightVisual> createState() =>
      _OnboardingDayInsightVisualState();
}

class _OnboardingDayInsightVisualState extends State<OnboardingDayInsightVisual>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();
  late final AnimationController _interactionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6200),
  )..repeat();
  final GlobalKey _visualKey = GlobalKey();
  final GlobalKey _dateButtonKey = GlobalKey();
  Rect? _dateButtonRect;
  late final ScrollController _miniCalendarScrollController = ScrollController(
    initialScrollOffset: _initialMiniCalendarOffset,
  );

  double get _initialMiniCalendarOffset {
    final dayCount = widget.kMonth == 13
        ? (KemeticMath.isLeapKemeticYear(widget.kYear) ? 6 : 5)
        : 30;
    final maxStart = (dayCount - 10).clamp(0, dayCount);
    return ((widget.kDay - 5).clamp(0, maxStart)).toDouble() * 34;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDateButtonRect());
  }

  @override
  void didUpdateWidget(covariant OnboardingDayInsightVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDateButtonRect());
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _interactionController.dispose();
    _miniCalendarScrollController.dispose();
    super.dispose();
  }

  void _syncDateButtonRect() {
    final visualBox =
        _visualKey.currentContext?.findRenderObject() as RenderBox?;
    final buttonBox =
        _dateButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (visualBox == null || buttonBox == null || !buttonBox.hasSize) return;

    final topLeft = visualBox.globalToLocal(
      buttonBox.localToGlobal(Offset.zero),
    );
    final nextRect = topLeft & buttonBox.size;
    if (!mounted || nextRect == _dateButtonRect) return;
    setState(() => _dateButtonRect = nextRect);
  }

  double _pulse({
    required double t,
    required double start,
    required double peak,
    required double end,
  }) {
    if (t <= start || t >= end) return 0;
    if (t <= peak) {
      return Curves.easeOut.transform((t - start) / (peak - start));
    }
    return 1 - Curves.easeIn.transform((t - peak) / (end - peak));
  }

  double _hold({
    required double t,
    required double inStart,
    required double inEnd,
    required double outStart,
    required double outEnd,
  }) {
    if (t <= inStart || t >= outEnd) return 0;
    if (t < inEnd) {
      return Curves.easeOut.transform((t - inStart) / (inEnd - inStart));
    }
    if (t <= outStart) return 1;
    return 1 - Curves.easeIn.transform((t - outStart) / (outEnd - outStart));
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDateButtonRect());

    final dayInfo = KemeticDayData.getInfoForDay(widget.dayKey);
    final monthName = getMonthById(widget.kMonth).displayFull;

    return AnimatedBuilder(
      animation: Listenable.merge([_ambientController, _interactionController]),
      builder: (context, _) {
        final ambientT = _ambientController.value;
        final loopT = _interactionController.value;
        final highlightPulse = _pulse(
          t: loopT,
          start: 0.08,
          peak: 0.20,
          end: 0.34,
        );
        final clickFlash = _pulse(t: loopT, start: 0.18, peak: 0.26, end: 0.38);
        final cardReveal = _hold(
          t: loopT,
          inStart: 0.24,
          inEnd: 0.40,
          outStart: 0.82,
          outEnd: 0.96,
        );
        final cardScale = ui.lerpDouble(0.94, 0.985, cardReveal) ?? 0.985;
        final cardOffsetY = ui.lerpDouble(18, 0, cardReveal) ?? 0;
        final scrimOpacity = 0.28 * cardReveal;
        final ambientFloat = math.sin((ambientT * math.pi * 2) + 0.2) * 6;

        return Stack(
          key: _visualKey,
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.14),
                  radius: 1.08,
                  colors: [
                    KemeticGold.base.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.58, 1.0],
                ),
              ),
            ),
            Positioned(
              left: -84,
              top: 86,
              width: 220,
              height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      KemeticGold.light.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -52,
              top: 170,
              width: 170,
              height: 170,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      KemeticGold.base.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            for (final glyph in _ambientGlyphs)
              _AnimatedGlyph(glyph: glyph, t: ambientT, introT: 1.0),
            IgnorePointer(
              child: Transform.translate(
                offset: Offset(0, ambientFloat),
                child: Column(
                  children: [
                    KemeticDayViewHeader(
                      currentKy: widget.kYear,
                      currentKm: widget.kMonth,
                      currentKd: widget.kDay,
                      showGregorian: false,
                      getMonthName: (_) => monthName,
                      miniCalendarScrollController:
                          _miniCalendarScrollController,
                      dateButtonBuilder: (_, currentGregorian) {
                        return Container(
                          key: _dateButtonKey,
                          child: KemeticDayButton(
                            dayKey: widget.dayKey,
                            kYear: widget.kYear,
                            openOnTap: true,
                            child: Text(
                              '${monthName.split(' ').first} ${widget.kDay}, ${currentGregorian.year}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              softWrap: false,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                    const Expanded(child: _OnboardingDayViewTimeline()),
                  ],
                ),
              ),
            ),
            if (_dateButtonRect != null)
              ..._buildDateInteractionHighlight(
                _dateButtonRect!,
                highlightPulse: highlightPulse,
                clickFlash: clickFlash,
              ),
            if (cardReveal > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: scrimOpacity),
                    ),
                  ),
                ),
              ),
            if (_dateButtonRect != null)
              Positioned(
                left: 0,
                right: 0,
                top: _dateButtonRect!.bottom + 8 + cardOffsetY,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: cardReveal,
                    child: Transform.scale(
                      scale: cardScale,
                      alignment: Alignment.topCenter,
                      child: Center(
                        child: _OnboardingDayInsightCard(dayInfo: dayInfo),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildDateInteractionHighlight(
    Rect rect, {
    required double highlightPulse,
    required double clickFlash,
  }) {
    final outerRect = rect.inflate(10);
    final haloRect = rect.inflate(16);

    return [
      Positioned.fromRect(
        rect: haloRect,
        child: IgnorePointer(
          child: Transform.scale(
            scale: 1 + (clickFlash * 0.08),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: RadialGradient(
                  radius: 1.12,
                  colors: [
                    KemeticGold.light.withValues(
                      alpha: 0.12 + (highlightPulse * 0.10),
                    ),
                    KemeticGold.base.withValues(
                      alpha: 0.06 + (highlightPulse * 0.08),
                    ),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: KemeticGold.base.withValues(
                      alpha: 0.12 + (highlightPulse * 0.10),
                    ),
                    blurRadius: 18 + (highlightPulse * 10),
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned.fromRect(
        rect: outerRect,
        child: IgnorePointer(
          child: Transform.scale(
            scale: 1 - (clickFlash * 0.04),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: KemeticGold.light.withValues(
                    alpha: 0.18 + (highlightPulse * 0.24),
                  ),
                  width: 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    KemeticGold.light.withValues(
                      alpha: 0.06 + (highlightPulse * 0.06),
                    ),
                    KemeticGold.base.withValues(
                      alpha: 0.08 + (highlightPulse * 0.08),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _OnboardingDayInsightCard extends StatelessWidget {
  const _OnboardingDayInsightCard({required this.dayInfo});

  final KemeticDayInfo? dayInfo;

  @override
  Widget build(BuildContext context) {
    if (dayInfo == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          height: 360,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: KemeticGold.light.withValues(alpha: 0.16),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.88),
                Colors.black.withValues(alpha: 0.78),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlossyText(
                text: 'Daily Insight',
                gradient: goldGloss,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'GentiumPlus',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your day card will appear here with the same insight and reflection you see inside the app.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: IgnorePointer(
        child: SizedBox(
          width: 348,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: goldGloss,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(1),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: KemeticGold.text(
                            '☀️ Kemetic Date Alignment',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(Icons.close, color: KemeticGold.base, size: 30),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    decoration: const BoxDecoration(gradient: goldGloss),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Season:', dayInfo!.season),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Ma\'at Principle:',
                          dayInfo!.maatPrinciple,
                        ),
                        const SizedBox(height: 18),
                        KemeticGold.text(
                          '△ The Day’s Rhythm',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _contextExcerpt(dayInfo!.cosmicContext),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFCCCCCC),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFFCCCCCC),
          height: 1.45,
        ),
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: KemeticGold.base,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  String _contextExcerpt(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');
    final firstParagraph = normalized.split(RegExp(r'\n\s*\n')).first.trim();
    return firstParagraph.isEmpty ? normalized : firstParagraph;
  }
}

class _OnboardingDayViewTimeline extends StatelessWidget {
  const _OnboardingDayViewTimeline();

  static const _hours = [
    '12 PM',
    '1 PM',
    '2 PM',
    '3 PM',
    '4 PM',
    '5 PM',
    '6 PM',
    '7 PM',
    '8 PM',
    '9 PM',
    '10 PM',
    '11 PM',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentTimeLineTop = constraints.maxHeight * 0.78;
        final chipTop = currentTimeLineTop - 58;
        final chipWidth = math.max(112.0, (constraints.maxWidth - 126) / 2);
        final firstLeft = 102.0;
        final secondLeft = constraints.maxWidth - chipWidth - 18;

        return Stack(
          children: [
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _hours.length,
              itemBuilder: (context, index) {
                return SizedBox(
                  height: 100,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Text(
                          _hours[index],
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: Divider(height: 1, color: Color(0xFF161616)),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              top: currentTimeLineTop,
              child: Container(height: 1, color: const Color(0xFF7A1414)),
            ),
            Positioned(
              left: firstLeft,
              top: chipTop,
              child: _OnboardingPreviewEventChip(
                width: chipWidth,
                title: 'Evening Reflection',
                subtitle: 'Medu Neter Learning Journey',
                accent: const Color(0xFF04D47B),
                background: const Color(0xFF053C22),
              ),
            ),
            Positioned(
              left: secondLeft,
              top: chipTop,
              child: _OnboardingPreviewEventChip(
                width: chipWidth,
                title: 'Evening Reflection',
                subtitle: 'Kung Fu Practice Schedule',
                accent: const Color(0xFF8C6BFF),
                background: const Color(0xFF28194A),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OnboardingPreviewEventChip extends StatelessWidget {
  const _OnboardingPreviewEventChip({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.background,
  });

  final double width;
  final String title;
  final String subtitle;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 74,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 5)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingActionPathVisual extends StatefulWidget {
  const OnboardingActionPathVisual({super.key});

  @override
  State<OnboardingActionPathVisual> createState() =>
      _OnboardingActionPathVisualState();
}

class _OnboardingActionPathVisualState extends State<OnboardingActionPathVisual>
    with TickerProviderStateMixin {
  static const String _promptSource =
      'Turn my strength, study, and nutrition goals into a 10-day flow';

  late final AnimationController _ambientController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();
  late final AnimationController _storyController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ambientController.dispose();
    _storyController.dispose();
    super.dispose();
  }

  double _segment(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return Curves.easeOutCubic.transform((t - start) / (end - start));
  }

  String _typedPrompt(double progress, bool showCursor) {
    final count = (_promptSource.length * progress).round().clamp(
      0,
      _promptSource.length,
    );
    final typed = _promptSource.substring(0, count);
    if (count == 0) return showCursor ? '|' : '';
    return '$typed${showCursor ? '|' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_ambientController, _storyController]),
        builder: (context, _) {
          final ambientT = _ambientController.value;
          final storyT = _storyController.value;
          final easedPhase = Curves.easeInOutCubic.transform(storyT);
          final generatorOpacity = 1 - easedPhase;
          final plannerOpacity = easedPhase;
          final promptReveal = Curves.easeOutCubic.transform(
            (storyT / 0.34).clamp(0.0, 1.0),
          );
          final plannerStage = Curves.easeOutCubic.transform(storyT);
          final notesReveal = _segment(plannerStage, 0.14, 0.52);
          final showCursor =
              generatorOpacity > 0.74 && (((storyT * 10).floor() % 2) == 0);
          final typedPrompt = _typedPrompt(promptReveal, showCursor);
          final generatorPulse =
              0.5 + 0.5 * math.sin((ambientT * math.pi * 2) + 0.72);
          final generatorGlow =
              generatorOpacity * (0.32 + (generatorPulse * 0.68));

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final stageWidth = math.min(width * 0.86, 344.0);
              final stageHeight = math.min(height * 0.60, 448.0);
              final stageTop = math.max(62.0, height * 0.08);
              final stageLeft = (width - stageWidth) / 2;
              final stageFloat =
                  math.sin((ambientT * math.pi * 2) + 0.28) * 4.0;

              return Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.18),
                        radius: 1.02,
                        colors: [
                          KemeticGold.base.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.54, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -60,
                    top: 94,
                    width: 200,
                    height: 200,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            KemeticGold.light.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -88,
                    top: 292,
                    width: 230,
                    height: 230,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            KemeticGold.base.withValues(alpha: 0.07),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (final glyph in _ambientGlyphs)
                    _AnimatedGlyph(glyph: glyph, t: ambientT, introT: 1.0),
                  Positioned(
                    left: stageLeft,
                    top: stageTop + stageFloat,
                    width: stageWidth,
                    height: stageHeight,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: const Alignment(0, -0.08),
                                  radius: 0.96,
                                  colors: [
                                    KemeticGold.light.withValues(
                                      alpha: 0.08 + (generatorOpacity * 0.04),
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: Opacity(
                            opacity: generatorOpacity,
                            child: Transform.translate(
                              offset: Offset(
                                (1 - generatorOpacity) * 18,
                                (1 - generatorOpacity) * 14,
                              ),
                              child: Transform.scale(
                                scale: 0.96 + (generatorOpacity * 0.04),
                                child: _OnboardingFlowGeneratorCard(
                                  width: stageWidth,
                                  height: stageHeight,
                                  typedPrompt: typedPrompt,
                                  buttonGlow: generatorGlow,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: Opacity(
                            opacity: plannerOpacity,
                            child: Transform.translate(
                              offset: Offset(
                                (1 - plannerOpacity) * -18,
                                (1 - plannerOpacity) * 16,
                              ),
                              child: Transform.scale(
                                scale: 0.96 + (plannerOpacity * 0.04),
                                child: _OnboardingPlannerPreviewCard(
                                  width: stageWidth,
                                  height: stageHeight,
                                  notesReveal: notesReveal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class OnboardingSocialFeedVisual extends StatefulWidget {
  const OnboardingSocialFeedVisual({super.key});

  @override
  State<OnboardingSocialFeedVisual> createState() =>
      _OnboardingSocialFeedVisualState();
}

class _OnboardingSocialFeedVisualState extends State<OnboardingSocialFeedVisual>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  late final AnimationController _feedController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 9000),
  )..repeat();

  @override
  void dispose() {
    _ambientController.dispose();
    _feedController.dispose();
    super.dispose();
  }

  double _reveal(double value, double start, double end) {
    if (value <= start) return 0;
    if (value >= end) return 1;
    return Curves.easeOutCubic.transform((value - start) / (end - start));
  }

  double _closeableReveal(
    double value, {
    required double openStart,
    required double openEnd,
    required double closeStart,
    required double closeEnd,
  }) {
    return _reveal(value, openStart, openEnd) *
        (1 - _reveal(value, closeStart, closeEnd));
  }

  double _pulse(double value, double start, double end) {
    if (value <= start || value >= end) return 0;
    final t = (value - start) / (end - start);
    return math.sin(t * math.pi).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_ambientController, _feedController]),
        builder: (context, _) {
          final ambientT = _ambientController.value;
          final feedT = _feedController.value;
          final float = math.sin((ambientT * math.pi * 2) + 0.18) * 4.0;
          final shimmer = 0.5 + 0.5 * math.sin(ambientT * math.pi * 2);
          final detailProgress = _closeableReveal(
            feedT,
            openStart: 0.38,
            openEnd: 0.50,
            closeStart: 0.88,
            closeEnd: 0.98,
          );
          final detailScroll = _reveal(feedT, 0.56, 0.82);
          final tapProgress = _pulse(feedT, 0.30, 0.43);

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              return Stack(
                fit: StackFit.expand,
                children: [
                  const Positioned.fill(
                    child: ProfileDayCycleBackdrop(opacity: 0.82),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF004D76).withValues(alpha: 0.58),
                            Colors.black.withValues(alpha: 0.12),
                            Colors.black.withValues(alpha: 0.62),
                            Colors.black.withValues(alpha: 0.96),
                          ],
                          stops: const [0.0, 0.26, 0.68, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, float),
                    child: _OnboardingSocialFeedCard(
                      width: width,
                      height: height,
                      firstReveal: _reveal(feedT, 0.00, 0.28),
                      secondReveal: _reveal(feedT, 0.18, 0.52),
                      thirdReveal: _reveal(feedT, 0.36, 0.74),
                      tapProgress: tapProgress,
                      detailProgress: detailProgress,
                      detailScroll: detailScroll,
                      pulse: shimmer,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _OnboardingSocialFeedCard extends StatelessWidget {
  const _OnboardingSocialFeedCard({
    required this.width,
    required this.height,
    required this.firstReveal,
    required this.secondReveal,
    required this.thirdReveal,
    required this.tapProgress,
    required this.detailProgress,
    required this.detailScroll,
    required this.pulse,
  });

  final double width;
  final double height;
  final double firstReveal;
  final double secondReveal;
  final double thirdReveal;
  final double tapProgress;
  final double detailProgress;
  final double detailScroll;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final showRealFeedPreview = width >= 0;
    if (showRealFeedPreview) {
      return _OnboardingRealFeedScreen(
        width: width,
        height: height,
        firstReveal: firstReveal,
        secondReveal: secondReveal,
        thirdReveal: thirdReveal,
        tapProgress: tapProgress,
        detailProgress: detailProgress,
        detailScroll: detailScroll,
        pulse: pulse,
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF030303),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: KemeticGold.base.withValues(alpha: 0.10 + pulse * 0.06),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      KemeticGold.base.withValues(alpha: 0.12),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [goldLight, gold, goldDeep],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: KemeticGold.base.withValues(alpha: 0.25),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'ḥ',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'GentiumPlus',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const GlossyText(
                              text: 'Shared Confirmation',
                              gradient: goldGloss,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'GentiumPlus',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Flows, insights, and witness from the field',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.58),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _OnboardingFeedPost(
                    reveal: firstReveal,
                    avatarText: 'A',
                    label: 'Amina shared a practice',
                    title: '10-day strength rhythm',
                    body:
                        'Building slowly. One offering to the body before the day scatters.',
                    footer: '12 confirmations',
                  ),
                  const SizedBox(height: 10),
                  _OnboardingFeedPost(
                    reveal: secondReveal,
                    avatarText: 'K',
                    label: 'Khepri posted an insight',
                    title: 'Today asked me to simplify.',
                    body:
                        'The pattern was not more effort. It was removing what fed chaos.',
                    footer: '8 replies',
                    compact: true,
                  ),
                  const SizedBox(height: 10),
                  _OnboardingFeedPost(
                    reveal: thirdReveal,
                    avatarText: 'N',
                    label: 'Nia witnessed your flow',
                    title: 'This helped me name my own rhythm.',
                    body:
                        'Shared growth turns private insight into confirmation.',
                    footer: 'Walk together',
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingRealFeedScreen extends StatelessWidget {
  const _OnboardingRealFeedScreen({
    required this.width,
    required this.height,
    required this.firstReveal,
    required this.secondReveal,
    required this.thirdReveal,
    required this.tapProgress,
    required this.detailProgress,
    required this.detailScroll,
    required this.pulse,
  });

  final double width;
  final double height;
  final double firstReveal;
  final double secondReveal;
  final double thirdReveal;
  final double tapProgress;
  final double detailProgress;
  final double detailScroll;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final horizontal = width < 380 ? 22.0 : 30.0;
    final topBarHeight = math.max(52.0, math.min(64.0, height * 0.085));
    final headerTop = topBarHeight + 8;
    final panelTop = math.max(headerTop + 96, height * 0.22);
    final columnGap = width < 380 ? 10.0 : 14.0;
    final cardGlow = 0.10 + (pulse * 0.04);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topBarHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF004D76).withValues(alpha: 0.96),
                    const Color(0xFF004D76).withValues(alpha: 0.58),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.72, 1.0],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 8),
                child: Row(
                  children: [
                    KemeticGold.icon(Icons.close, size: 28),
                    const SizedBox(width: 28),
                    const GlossyText(
                      text: 'ḥꜣw',
                      gradient: goldGloss,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'GentiumPlus',
                      ),
                    ),
                    const Spacer(),
                    KemeticGold.icon(Icons.add, size: 28),
                    const SizedBox(width: 22),
                    KemeticGold.icon(Icons.calendar_today, size: 26),
                    const SizedBox(width: 22),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        KemeticGold.icon(Icons.apps, size: 28),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4A58),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 22),
                    KemeticGold.icon(Icons.person, size: 28),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: headerTop,
            left: horizontal,
            right: horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GlossyText(
                  text: 'Shared Confirmation',
                  gradient: goldGloss,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'GentiumPlus',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Flows and insights from the people you follow, plus the wider field of meaning.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 14,
                    height: 1.26,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: KemeticGold.light.withValues(alpha: 0.82),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pull down at the top to return to profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: panelTop,
            left: horizontal + 2,
            right: horizontal + 2,
            bottom: -height * 0.24,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: KemeticGold.base.withValues(alpha: 0.34),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: KemeticGold.base.withValues(alpha: cardGlow),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _OnboardingFeedPost(
                              reveal: firstReveal,
                              avatarText: 'ḥ',
                              label: 'Your Flow',
                              title:
                                  '30-Day Flow: Conditioning the Subconscious for Wealth, A...',
                              body: 'BigJFil',
                              footer: 'Posted Thoth ...',
                              tapProgress: tapProgress,
                            ),
                            const SizedBox(height: 16),
                            _OnboardingFeedPost(
                              reveal: thirdReveal,
                              avatarText: 'ḥ',
                              label: 'Following',
                              title: 'Cooking and Art Mastery',
                              body: 'October/potato\n@potato',
                              footer: 'Posted Thoth ...',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: columnGap),
                      Expanded(
                        child: Column(
                          children: [
                            _OnboardingFeedPost(
                              reveal: secondReveal,
                              avatarText: 'ḥ',
                              label: 'Your Flow',
                              title: '10-Day Yoga Plan',
                              body: 'BigJFil',
                              footer: 'Posted Paopi (...',
                              compact: true,
                            ),
                            const SizedBox(height: 16),
                            _OnboardingFeedPost(
                              reveal: thirdReveal,
                              avatarText: 'ḥ',
                              label: 'Your Flow',
                              title:
                                  'ḥꜣw Series: Ten Layers of Time\'s Presence',
                              body: 'BigJFil',
                              footer: 'Posted Mesut-...',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (detailProgress > 0)
            Positioned(
              top: math.max(topBarHeight + 48, height * 0.13),
              left: horizontal + 12,
              right: horizontal + 12,
              bottom: 146,
              child: _OnboardingPostDetailPreview(
                progress: detailProgress,
                scroll: detailScroll,
              ),
            ),
        ],
      ),
    );
  }
}

class _OnboardingFeedPost extends StatelessWidget {
  const _OnboardingFeedPost({
    required this.reveal,
    required this.avatarText,
    required this.label,
    required this.title,
    required this.body,
    required this.footer,
    this.compact = false,
    this.tapProgress = 0,
  });

  final double reveal;
  final String avatarText;
  final String label;
  final String title;
  final String body;
  final String footer;
  final bool compact;
  final double tapProgress;

  @override
  Widget build(BuildContext context) {
    final accent = label == 'Following'
        ? const Color(0xFF16D7D4)
        : label == 'Community'
        ? KemeticGold.base
        : const Color(0xFF7C4DFF);
    final authorLines = body.split('\n');
    final authorName = authorLines.first;
    final authorHandle = authorLines.length > 1 ? authorLines[1] : null;
    final reactions = label == 'Following'
        ? 3
        : compact
        ? 1
        : 2;
    final replies = label == 'Following' ? 5 : 0;

    return Opacity(
      opacity: reveal,
      child: Transform.translate(
        offset: Offset(0, (1 - reveal) * 22),
        child: Transform.scale(
          scale: 1 + (tapProgress * 0.018),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(14, 14, 14, compact ? 14 : 18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.46),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: KemeticGold.base.withValues(
                      alpha: 0.28 + (tapProgress * 0.42),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                    if (tapProgress > 0)
                      BoxShadow(
                        color: KemeticGold.base.withValues(
                          alpha: 0.18 * tapProgress,
                        ),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.34),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: accent.withValues(alpha: 0.98),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.74),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: KemeticGold.base.withValues(alpha: 0.34),
                            ),
                          ),
                          child: Center(
                            child: KemeticGold.text(
                              avatarText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'GentiumPlus',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'GentiumPlus',
                                ),
                              ),
                              if (authorHandle != null) ...[
                                const SizedBox(height: 1),
                                Text(
                                  authorHandle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.52),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 16 : 18),
                    KemeticGold.text(
                      title,
                      maxLines: compact ? 3 : 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 20 : 21,
                        fontWeight: FontWeight.w800,
                        height: 1.06,
                        fontFamily: 'GentiumPlus',
                      ),
                    ),
                    SizedBox(height: compact ? 16 : 18),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.46),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            footer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.north_east_rounded,
                          size: 18,
                          color: KemeticGold.light.withValues(alpha: 0.92),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 18 : 22),
                    Row(
                      children: [
                        KemeticHeartIcon(
                          size: 22,
                          color: label == 'Following'
                              ? const Color(0xFFFF465A)
                              : KemeticGold.base,
                          filled: label == 'Following',
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$reactions',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: KemeticGold.base,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$replies',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (tapProgress > 0)
                Positioned(
                  right: 16 - (tapProgress * 2),
                  top: 18 - (tapProgress * 2),
                  child: Opacity(
                    opacity: tapProgress,
                    child: Container(
                      width: 42 + (tapProgress * 12),
                      height: 42 + (tapProgress * 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: KemeticGold.light.withValues(alpha: 0.13),
                        border: Border.all(
                          color: KemeticGold.light.withValues(alpha: 0.62),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: KemeticGold.light,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPostDetailPreview extends StatelessWidget {
  const _OnboardingPostDetailPreview({
    required this.progress,
    required this.scroll,
  });

  final double progress;
  final double scroll;

  @override
  Widget build(BuildContext context) {
    final open = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final scrollT = Curves.easeInOutCubic.transform(scroll.clamp(0.0, 1.0));
    final scrollY = -128.0 * scrollT;

    return Opacity(
      opacity: open,
      child: Transform.translate(
        offset: Offset(0, (1 - open) * 28),
        child: Transform.scale(
          alignment: Alignment.topCenter,
          scale: 0.94 + (0.06 * open),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: KemeticGold.base.withValues(alpha: 0.44),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.48),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: KemeticGold.base.withValues(alpha: 0.14),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            KemeticGold.base.withValues(alpha: 0.14),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.28),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            KemeticGold.icon(Icons.close, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: GlossyText(
                                text: 'Flow detail',
                                gradient: goldGloss,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'GentiumPlus',
                                ),
                              ),
                            ),
                            KemeticGold.icon(
                              Icons.bookmark_add_outlined,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: ClipRect(
                            child: Transform.translate(
                              offset: Offset(0, scrollY),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _DetailPill(
                                    label: 'Your Flow',
                                    accent: const Color(0xFF7C4DFF),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.76,
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: KemeticGold.base.withValues(
                                              alpha: 0.34,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: KemeticGold.text(
                                            'ḥ',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'GentiumPlus',
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'BigJFil',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'GentiumPlus',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  KemeticGold.text(
                                    '30-Day Flow: Conditioning the Subconscious for Wealth, Abundance, and Order',
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      height: 1.06,
                                      fontFamily: 'GentiumPlus',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_outlined,
                                        size: 15,
                                        color: Colors.white.withValues(
                                          alpha: 0.48,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        'Posted Thoth 29',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.58,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      const KemeticHeartIcon(
                                        size: 20,
                                        color: Color(0xFFFF465A),
                                        filled: true,
                                      ),
                                      const SizedBox(width: 5),
                                      const Text(
                                        '2',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        color: KemeticGold.base,
                                        size: 21,
                                      ),
                                      const SizedBox(width: 5),
                                      const Text(
                                        '0',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  _DetailSection(
                                    title: 'Practice rhythm',
                                    body:
                                        'A daily sequence for study, breath, food, body, and money attention. Each check-in turns intention into visible rhythm.',
                                  ),
                                  const SizedBox(height: 14),
                                  _DetailSection(
                                    title: 'Today asks',
                                    body:
                                        'Notice where scattered desire can become order. Choose the smallest action that confirms the person you are becoming.',
                                  ),
                                  const SizedBox(height: 14),
                                  _DetailComment(
                                    name: 'October/potato',
                                    text:
                                        'This helped me name the pattern I was already trying to build.',
                                  ),
                                  const SizedBox(height: 12),
                                  _DetailComment(
                                    name: 'Nia',
                                    text:
                                        'Saved this flow for my next decan. The structure makes the work feel reachable.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: KemeticGold.base.withValues(alpha: 0.58),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: accent.withValues(alpha: 0.98),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KemeticGold.text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 12,
              height: 1.32,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailComment extends StatelessWidget {
  const _DetailComment({required this.name, required this.text});

  final String name;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: KemeticGold.base.withValues(alpha: 0.16),
            border: Border.all(color: KemeticGold.base.withValues(alpha: 0.28)),
          ),
          child: Center(
            child: KemeticGold.text(
              name.isEmpty ? '?' : name.substring(0, 1),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.64),
                  fontSize: 11.5,
                  height: 1.28,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnboardingFlowGeneratorCard extends StatelessWidget {
  const _OnboardingFlowGeneratorCard({
    required this.width,
    required this.height,
    required this.typedPrompt,
    required this.buttonGlow,
  });

  static const _palette = [
    Color(0xFF4DD0E1),
    Color(0xFF7C4DFF),
    Color(0xFFEF5350),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFF42A5F5),
  ];

  final double width;
  final double height;
  final String typedPrompt;
  final double buttonGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF000000),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: KemeticGold.base.withValues(
                    alpha: 0.10 + (buttonGlow * 0.10),
                  ),
                  blurRadius: 26,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const GlossyText(
                  text: 'Generate with AI',
                  gradient: silverGloss,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Describe what you want and AI will create it',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 16),
                const GlossyText(
                  text: 'What do you want to create?',
                  gradient: silverGloss,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 94,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      typedPrompt.isEmpty
                          ? 'Paste a long plan or notes and ask AI to turn it into a flow...'
                          : typedPrompt,
                      maxLines: 4,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: typedPrompt.isEmpty ? 0.34 : 0.88,
                        ),
                        fontSize: 13.5,
                        height: 1.34,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const GlossyText(
                  text: 'Color',
                  gradient: silverGloss,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < _palette.length; i++) ...[
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              HSLColor.fromColor(
                                _palette[i],
                              ).withLightness(0.76).toColor(),
                              _palette[i],
                              HSLColor.fromColor(
                                _palette[i],
                              ).withLightness(0.34).toColor(),
                            ],
                          ),
                          border: Border.all(
                            color: i == 4
                                ? Colors.white.withValues(alpha: 0.70)
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                      ),
                      if (i != _palette.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const GlossyText(
                  text: 'Date range (optional)',
                  gradient: silverGloss,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Expanded(
                      child: _OnboardingGeneratorDateButton(label: 'Apr 17'),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _OnboardingGeneratorDateButton(label: 'Apr 26'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [goldLight, gold, goldDeep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: KemeticGold.base.withValues(
                          alpha: 0.20 + (buttonGlow * 0.16),
                        ),
                        blurRadius: 18 + (buttonGlow * 10),
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Generate Flow',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingGeneratorDateButton extends StatelessWidget {
  const _OnboardingGeneratorDateButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: silver, width: 1.1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OnboardingPlannerPreviewCard extends StatelessWidget {
  const _OnboardingPlannerPreviewCard({
    required this.width,
    required this.height,
    required this.notesReveal,
  });

  final double width;
  final double height;
  final double notesReveal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RhythmSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KemeticGold.text(
                        'Planner',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'GentiumPlus',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Move through today with clarity and grace.',
                        style: RhythmTheme.subheading,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: RhythmTheme.frostSurface(),
                            child: KemeticGold.icon(
                              Icons.wb_sunny_rounded,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Thoth 29 · Akhet',
                                  style: RhythmTheme.subheading.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const LinearProgressIndicator(
                                  value: 0.0,
                                  minHeight: 8,
                                  backgroundColor: Colors.white12,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    RhythmTheme.aurora,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '0% aligned so far',
                                  style: RhythmTheme.subheading.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: KemeticGold.text(
                    '"What still needs tending before this month can\nclose cleanly?"',
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'GentiumPlus',
                      height: 1.24,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                RhythmSectionCard(
                  title: 'Notes',
                  subtitle:
                      'Affirmations to keep front-of-mind. Double-tap to spotlight.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          Container(
                            constraints: const BoxConstraints(minHeight: 88),
                            padding: const EdgeInsets.fromLTRB(14, 14, 70, 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              'Write a note, affirmation, or reminder',
                              style: RhythmTheme.subheading.copyWith(
                                color: Colors.white38,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: goldGloss,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.black,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _OnboardingPlannerReveal(
                        reveal: notesReveal,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 200,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: RhythmTheme.aurora.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: KemeticGold.text(
                                      'ḥꜣw',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'GentiumPlus',
                                        height: 1.15,
                                      ),
                                      maxLines: 2,
                                      softWrap: true,
                                    ),
                                  ),
                                  const Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Icon(
                                      Icons.more_vert,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = 0; i < 5; i++)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    height: 8,
                                    width: i == 0 ? 18 : 8,
                                    decoration: BoxDecoration(
                                      color: i == 0
                                          ? RhythmTheme.aurora
                                          : Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.list_alt,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ClipRect(
                  child: SizedBox(
                    height: 74,
                    child: RhythmSectionCard(
                      title: 'Nutrition',
                      subtitle: 'Track what is feeding your momentum.',
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPlannerReveal extends StatelessWidget {
  const _OnboardingPlannerReveal({required this.reveal, required this.child});

  final double reveal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: reveal.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - reveal.clamp(0.0, 1.0)) * 16),
        child: child,
      ),
    );
  }
}

class OnboardingLiveCalendarHighlightVisual extends StatefulWidget {
  const OnboardingLiveCalendarHighlightVisual({
    super.key,
    required this.dayKeys,
  });

  final Map<int, GlobalKey> dayKeys;

  @override
  State<OnboardingLiveCalendarHighlightVisual> createState() =>
      _OnboardingLiveCalendarHighlightVisualState();
}

class _OnboardingLiveCalendarHighlightVisualState
    extends State<OnboardingLiveCalendarHighlightVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat(reverse: true);
  final GlobalKey _visualKey = GlobalKey();
  Map<int, Rect> _dayRects = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDayRects());
  }

  @override
  void didUpdateWidget(
    covariant OnboardingLiveCalendarHighlightVisual oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDayRects());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncDayRects() {
    final visualBox =
        _visualKey.currentContext?.findRenderObject() as RenderBox?;
    if (visualBox == null) return;

    final nextRects = <int, Rect>{};
    for (final entry in widget.dayKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final topLeft = visualBox.globalToLocal(box.localToGlobal(Offset.zero));
      nextRects[entry.key] = topLeft & box.size;
    }

    if (!mounted || mapEquals(nextRects, _dayRects)) return;
    setState(() => _dayRects = nextRects);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDayRects());

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final shimmer = Curves.easeInOut.transform(_controller.value);
        return Stack(
          key: _visualKey,
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.22),
                    radius: 1.05,
                    colors: [
                      KemeticGold.base.withValues(alpha: 0.04 + shimmer * 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            if (_dayRects.isNotEmpty) ..._buildHighlightLayers(shimmer),
          ],
        );
      },
    );
  }

  List<Widget> _buildHighlightLayers(double shimmer) {
    const highlightGroups = [
      [8, 9, 10],
      [18, 19, 20],
      [28, 29, 30],
    ];

    final groupRects = <({Rect rect, double phase})>[];
    for (var i = 0; i < highlightGroups.length; i++) {
      final rects = highlightGroups[i]
          .map((day) => _dayRects[day])
          .whereType<Rect>()
          .toList();
      if (rects.length != 3) continue;
      final union = rects
          .skip(1)
          .fold(rects.first, (a, b) => a.expandToInclude(b));
      groupRects.add((rect: union.inflate(6), phase: i * 0.18));
    }

    final cellRects = <({Rect rect, double phase})>[];
    for (final entry in widget.dayKeys.entries) {
      final rect = _dayRects[entry.key];
      if (rect == null) continue;
      cellRects.add((rect: rect.deflate(1), phase: (entry.key % 10) * 0.08));
    }

    return [
      for (final group in groupRects)
        Positioned.fromRect(
          rect: group.rect.inflate(2),
          child: IgnorePointer(
            child: Builder(
              builder: (context) {
                final pulse =
                    0.5 +
                    0.5 *
                        math.sin(
                          ((_controller.value + group.phase) % 1.0) *
                              math.pi *
                              2,
                        );
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: RadialGradient(
                      center: const Alignment(0, 0),
                      radius: 1.12,
                      colors: [
                        KemeticGold.light.withValues(
                          alpha: 0.09 + (pulse * 0.05),
                        ),
                        KemeticGold.base.withValues(
                          alpha: 0.04 + (pulse * 0.04),
                        ),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: KemeticGold.base.withValues(
                          alpha: 0.08 + (pulse * 0.06),
                        ),
                        blurRadius: 18 + (pulse * 8),
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      for (final cell in cellRects)
        Positioned.fromRect(
          rect: cell.rect.inflate(4),
          child: IgnorePointer(
            child: Builder(
              builder: (context) {
                final pulse =
                    0.5 +
                    0.5 *
                        math.sin(
                          ((_controller.value + cell.phase) % 1.0) *
                              math.pi *
                              2,
                        );
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: RadialGradient(
                      radius: 1.08,
                      colors: [
                        KemeticGold.light.withValues(
                          alpha: 0.10 + (pulse * 0.06),
                        ),
                        KemeticGold.base.withValues(
                          alpha: 0.04 + (pulse * 0.05),
                        ),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: KemeticGold.base.withValues(
                          alpha: 0.10 + (pulse * 0.06),
                        ),
                        blurRadius: 14 + (pulse * 8),
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      for (final cell in cellRects)
        Positioned.fromRect(
          rect: cell.rect,
          child: IgnorePointer(
            child: Builder(
              builder: (context) {
                final pulse =
                    0.5 +
                    0.5 *
                        math.sin(
                          ((_controller.value + cell.phase) % 1.0) *
                              math.pi *
                              2,
                        );
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        KemeticGold.light.withValues(
                          alpha: 0.06 + (pulse * 0.05),
                        ),
                        KemeticGold.base.withValues(
                          alpha: 0.10 + (pulse * 0.07),
                        ),
                        KemeticGold.base.withValues(
                          alpha: 0.04 + (pulse * 0.03),
                        ),
                      ],
                    ),
                    border: Border.all(
                      color: KemeticGold.light.withValues(
                        alpha: 0.14 + (pulse * 0.10),
                      ),
                      width: 0.9,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
    ];
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [goldLight, gold, goldDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: KemeticGold.base.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideTextBackplate extends StatelessWidget {
  const _SlideTextBackplate({
    required this.opacity,
    required this.blurSigma,
    required this.child,
  });

  final double opacity;
  final double blurSigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return child;

    final radius = BorderRadius.circular(30);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: KemeticGold.light.withValues(alpha: opacity * 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: opacity * 0.22),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.18),
                        radius: 1.18,
                        colors: [
                          Colors.black.withValues(alpha: opacity),
                          Colors.black.withValues(alpha: opacity * 0.92),
                          Colors.black.withValues(alpha: opacity * 0.42),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.54, 0.84, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: active ? goldGloss : null,
            color: active ? null : Colors.white24,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: KemeticGold.base.withValues(alpha: 0.32),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _AnimatedGlyph extends StatelessWidget {
  const _AnimatedGlyph({
    required this.glyph,
    required this.t,
    required this.introT,
  });

  final _FloatingGlyph glyph;
  final double t;
  final double introT;

  @override
  Widget build(BuildContext context) {
    final oscillation = math.sin((t + glyph.phase) * math.pi * 2);
    final revealStart = glyph.phase * 0.45;
    final reveal = Curves.easeOut.transform(
      ((introT - revealStart) / 0.55).clamp(0.0, 1.0),
    );
    final dx = glyph.drift.dx * oscillation;
    final dy = glyph.drift.dy * math.cos((t + glyph.phase) * math.pi * 2);
    final opacity = (0.08 + ((oscillation + 1) * 0.05)) * reveal;

    return Align(
      alignment: glyph.alignment,
      child: Transform.translate(
        offset: Offset(dx, dy + ((1 - reveal) * 26)),
        child: Transform.scale(
          scale: 0.92 + (reveal * 0.08),
          child: Text(
            glyph.label,
            style: TextStyle(
              color: KemeticGold.light.withValues(alpha: opacity),
              fontSize: glyph.fontSize,
              height: 1.0,
              fontFamilyFallback: const [
                'NotoSansEgyptianHieroglyphs',
                'Segoe UI Historic',
                'NotoSans',
                'Arial',
                'sans-serif',
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingGlyph {
  const _FloatingGlyph({
    required this.label,
    required this.alignment,
    required this.drift,
    required this.phase,
    required this.fontSize,
  });

  final String label;
  final Alignment alignment;
  final Offset drift;
  final double phase;
  final double fontSize;
}
