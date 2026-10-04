import 'dart:async';

import 'package:flutter/material.dart';

import 'starter_maat_flow_recommendation.dart';

enum HawOnboardingSlide {
  exhale,
  calendarConnection,
  segmentation,
  orientation,
  recommendedFlow,
  dayView,
  closing,
}

enum HawClosingPhase {
  copyVisible,
  copyFadingOut,
  sealFadingIn,
  sealHolding,
  windowFadingOut,
  complete,
}

@immutable
class HawCompassCopy {
  const HawCompassCopy({
    required this.decanKey,
    required this.dateLabel,
    required this.decanName,
    required this.decanOrdinalLabel,
    required this.monthName,
    required this.rhythmPhrase,
    required this.orientationQuestion,
    required this.dayAlignedReturnKey,
    this.dayAlignedReturnLine,
  });

  final String decanKey;
  final String dateLabel;
  final String decanName;
  final String decanOrdinalLabel;
  final String monthName;
  final String rhythmPhrase;
  final String orientationQuestion;
  final String dayAlignedReturnKey;
  final String? dayAlignedReturnLine;
}

typedef HawRecommendedFlowBuilder =
    Widget Function(
      BuildContext context,
      Future<void> Function(int flowId) onJoined,
    );

typedef HawDayViewBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback onEventOpened,
      VoidCallback onClosingComplete,
    );

class OnboardingOverlay extends StatefulWidget {
  const OnboardingOverlay({
    super.key,
    required this.compassCopy,
    required this.recommendedFlowBuilder,
    required this.dayViewBuilder,
    required this.dayViewEventTargetKey,
    required this.onEntryStateSelected,
    required this.onSkip,
    required this.onComplete,
    this.onSlideChanged,
    this.initialSlide = HawOnboardingSlide.exhale,
    this.initialEntryState,
    this.onConnectCalendar,
    this.recommendationReason,
    this.calendarConnectionBuilder,
    this.onBeforeSlideChanged,
  });

  final Future<void> Function(HawOnboardingSlide slide)? onBeforeSlideChanged;
  final HawOnboardingSlide initialSlide;
  final String? initialEntryState;
  final Future<void> Function()? onConnectCalendar;
  final String? recommendationReason;
  final WidgetBuilder? calendarConnectionBuilder;
  final HawCompassCopy compassCopy;
  final HawRecommendedFlowBuilder recommendedFlowBuilder;
  final HawDayViewBuilder dayViewBuilder;
  final GlobalKey dayViewEventTargetKey;
  final Future<void> Function(String entryState) onEntryStateSelected;
  final VoidCallback onSkip;
  final VoidCallback onComplete;
  final ValueChanged<HawOnboardingSlide>? onSlideChanged;

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  HawOnboardingSlide _slide = HawOnboardingSlide.exhale;
  final List<Timer> _timers = <Timer>[];

  bool _s1Line1 = false;
  bool _s1Line2 = false;
  bool _s1Wordmark = false;
  bool _showSkip = false;
  bool _showNext = false;
  String _nextLabel = '';

  bool _s2Question = false;
  int _s2VisibleOptions = 0;
  String? _selectedEntryState;
  bool _selectionInFlight = false;

  bool _s3Date = false;
  bool _s3Copy = false;

  bool _s4Visible = false;
  bool _joinInFlight = false;

  String? _actionError;
  bool _connectingCalendar = false;
  bool _transitioning = false;
  VoidCallback? _retryAction;

  bool get _reduceMotion {
    final media = MediaQuery.maybeOf(context);
    return media?.disableAnimations == true ||
        media?.accessibleNavigation == true;
  }

  @override
  void initState() {
    super.initState();
    _slide = widget.initialSlide;
    _selectedEntryState = widget.initialEntryState;
    WidgetsBinding.instance.addPostFrameCallback((_) => _enterSlide(_slide));
  }

  @override
  void dispose() {
    _clearTimers();
    super.dispose();
  }

  void _clearTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  void _after(Duration duration, VoidCallback action) {
    if (_reduceMotion) {
      action();
      return;
    }
    final timer = Timer(duration, () {
      if (!mounted) return;
      action();
    });
    _timers.add(timer);
  }

  void _enterSlide(HawOnboardingSlide slide) {
    _clearTimers();
    widget.onSlideChanged?.call(slide);

    setState(() {
      _actionError = null;
      _showNext = false;
      _nextLabel = '';
      _showSkip =
          slide == HawOnboardingSlide.calendarConnection ||
          slide == HawOnboardingSlide.segmentation ||
          slide == HawOnboardingSlide.orientation ||
          slide == HawOnboardingSlide.recommendedFlow;

      if (slide == HawOnboardingSlide.exhale) {
        _s1Line1 = false;
        _s1Line2 = false;
        _s1Wordmark = false;
        _showSkip = false;
      } else if (slide == HawOnboardingSlide.segmentation) {
        _s2Question = false;
        _s2VisibleOptions = 0;
        _selectedEntryState = null;
        _selectionInFlight = false;
      } else if (slide == HawOnboardingSlide.orientation) {
        _s3Date = false;
        _s3Copy = false;
      } else if (slide == HawOnboardingSlide.recommendedFlow) {
        _s4Visible = false;
      }
    });

    switch (slide) {
      case HawOnboardingSlide.exhale:
        _after(const Duration(milliseconds: 700), () {
          setState(() => _s1Line1 = true);
        });
        _after(const Duration(milliseconds: 2200), () {
          setState(() => _s1Line2 = true);
        });
        _after(const Duration(milliseconds: 4200), () {
          setState(() => _s1Wordmark = true);
        });
        _after(const Duration(milliseconds: 5800), () {
          setState(() {
            _nextLabel = 'tap to begin';
            _showNext = true;
            _showSkip = true;
          });
        });
      case HawOnboardingSlide.calendarConnection:
        break;
      case HawOnboardingSlide.segmentation:
        _after(const Duration(milliseconds: 240), () {
          setState(() => _s2Question = true);
        });
        for (var i = 0; i < _entryOptions.length; i += 1) {
          _after(Duration(milliseconds: 500 + (i * 60)), () {
            setState(() => _s2VisibleOptions = i + 1);
          });
        }
      case HawOnboardingSlide.orientation:
        _after(const Duration(milliseconds: 400), () {
          setState(() => _s3Date = true);
        });
        _after(const Duration(milliseconds: 1000), () {
          setState(() => _s3Copy = true);
        });
        _after(const Duration(milliseconds: 3200), () {
          setState(() {
            _nextLabel = 'next';
            _showNext = true;
          });
        });
      case HawOnboardingSlide.recommendedFlow:
        _after(const Duration(milliseconds: 220), () {
          setState(() => _s4Visible = true);
        });
      case HawOnboardingSlide.dayView:
        break;
      case HawOnboardingSlide.closing:
        break;
    }
  }

  Future<void> _goTo(HawOnboardingSlide slide) async {
    if (_slide == slide || _transitioning) return;
    setState(() {
      _transitioning = true;
      _actionError = null;
    });
    try {
      await widget.onBeforeSlideChanged?.call(slide);
      if (!mounted) return;
      setState(() => _slide = slide);
      _enterSlide(slide);
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionError = 'Could not save your place. Please try again.';
          _retryAction = () => unawaited(_goTo(slide));
        });
      }
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
  }

  void _handleNext() {
    switch (_slide) {
      case HawOnboardingSlide.exhale:
        _goTo(HawOnboardingSlide.calendarConnection);
      case HawOnboardingSlide.orientation:
        _goTo(HawOnboardingSlide.recommendedFlow);
      case HawOnboardingSlide.calendarConnection:
      case HawOnboardingSlide.segmentation:
      case HawOnboardingSlide.recommendedFlow:
      case HawOnboardingSlide.dayView:
      case HawOnboardingSlide.closing:
        break;
    }
  }

  Future<void> _connectCalendar() async {
    if (_connectingCalendar) return;
    setState(() {
      _connectingCalendar = true;
      _actionError = null;
    });
    try {
      await widget.onConnectCalendar?.call();
      if (mounted) await _goTo(HawOnboardingSlide.segmentation);
    } catch (_) {
      if (mounted) {
        setState(
          () => _actionError =
              'Could not open calendar connection. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _connectingCalendar = false);
    }
  }

  Future<void> _handleEntrySelected(_EntryOption option) async {
    if (_selectionInFlight || _selectedEntryState != null) return;
    setState(() {
      _selectionInFlight = true;
      _selectedEntryState = option.value;
    });
    try {
      await widget.onEntryStateSelected(option.value);
      if (!mounted) return;
      _after(const Duration(milliseconds: 500), () {
        unawaited(_goTo(HawOnboardingSlide.orientation));
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedEntryState = null;
          _selectionInFlight = false;
          _actionError = 'Could not save your choice. Please try again.';
          _retryAction = () => unawaited(_handleEntrySelected(option));
        });
      }
    }
  }

  Future<void> _handleJoinedFromRecommendedFlow(int flowId) async {
    if (_joinInFlight) return;
    setState(() => _joinInFlight = true);
    try {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      await _goTo(HawOnboardingSlide.dayView);
    } finally {
      if (mounted) setState(() => _joinInFlight = false);
    }
  }

  void _handleEventOpened() {
    _goTo(HawOnboardingSlide.closing);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _HawColors.ground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: _reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            child: KeyedSubtree(
              key: ValueKey<Object>(_slideSwitcherKey),
              child: _buildSlide(context),
            ),
          ),
          if (_actionError != null &&
              _slide != HawOnboardingSlide.calendarConnection)
            Positioned(
              left: 24,
              right: 24,
              bottom: 16,
              child: SafeArea(
                child: Material(
                  color: _HawColors.cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _actionError!,
                            style: const TextStyle(
                              color: _HawColors.goldMuted,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _retryAction,
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: _HawColors.goldPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  right: 24,
                  child: _TypographicCue(
                    label: 'skip',
                    visible: _showSkip,
                    onTap: widget.onSkip,
                  ),
                ),
                Positioned(
                  bottom: 48,
                  left: 44,
                  child: _TypographicCue(
                    label: _nextLabel,
                    visible:
                        _showNext && _nextLabel.isNotEmpty && !_transitioning,
                    onTap: _handleNext,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(BuildContext context) {
    switch (_slide) {
      case HawOnboardingSlide.exhale:
        return _ExhaleSlide(
          line1Visible: _s1Line1,
          line2Visible: _s1Line2,
          wordmarkVisible: _s1Wordmark,
          reduceMotion: _reduceMotion,
        );
      case HawOnboardingSlide.calendarConnection:
        return widget.calendarConnectionBuilder?.call(context) ??
            HawCalendarOffer(
              onConnect: _connectingCalendar ? null : _connectCalendar,
              onContinue: () => _goTo(HawOnboardingSlide.segmentation),
              busy: _connectingCalendar,
              error: _actionError,
            );
      case HawOnboardingSlide.segmentation:
        return _SegmentationSlide(
          questionVisible: _s2Question,
          visibleOptions: _s2VisibleOptions,
          selectedValue: _selectedEntryState,
          selectionInFlight: _selectionInFlight,
          reduceMotion: _reduceMotion,
          onSelected: _handleEntrySelected,
        );
      case HawOnboardingSlide.orientation:
        return _OrientationSlide(
          copy: widget.compassCopy,
          dateVisible: _s3Date,
          copyVisible: _s3Copy,
          reduceMotion: _reduceMotion,
        );
      case HawOnboardingSlide.recommendedFlow:
        return _RecommendedFlowSlide(
          reason: widget.recommendationReason,
          visible: _s4Visible,
          reduceMotion: _reduceMotion,
          child: widget.recommendedFlowBuilder(
            context,
            _handleJoinedFromRecommendedFlow,
          ),
        );
      case HawOnboardingSlide.dayView:
      case HawOnboardingSlide.closing:
        return widget.dayViewBuilder(
          context,
          _handleEventOpened,
          widget.onComplete,
        );
    }
  }

  Object get _slideSwitcherKey {
    return switch (_slide) {
      HawOnboardingSlide.closing => HawOnboardingSlide.dayView,
      _ => _slide,
    };
  }
}

class HawOnboardingDetailFrame extends StatelessWidget {
  const HawOnboardingDetailFrame({
    super.key,
    required this.closing,
    required this.detail,
  });
  final Widget closing, detail;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: SingleChildScrollView(child: closing)),
      detail,
    ],
  );
}

class HawOnboardingClosingBanner extends StatefulWidget {
  const HawOnboardingClosingBanner({
    super.key,
    required this.onComplete,
    this.onPhaseChanged,
    this.onCommit,
    this.copy =
        'At the end of the day,\nmark your truth.\n\nThe next morning\nwill carry you forward.',
  });

  final VoidCallback onComplete;
  final ValueChanged<HawClosingPhase>? onPhaseChanged;
  final String copy;
  final Future<void> Function()? onCommit;

  @override
  State<HawOnboardingClosingBanner> createState() =>
      _HawOnboardingClosingBannerState();
}

class _HawOnboardingClosingBannerState
    extends State<HawOnboardingClosingBanner> {
  final List<Timer> _timers = <Timer>[];
  HawClosingPhase _phase = HawClosingPhase.copyVisible;
  bool _entered = false;
  bool _committing = false;
  String? _completionError;

  bool get _reduceMotion {
    final media = MediaQuery.maybeOf(context);
    return media?.disableAnimations == true ||
        media?.accessibleNavigation == true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _entered = true);
      widget.onPhaseChanged?.call(_phase);
    });
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _setPhase(HawClosingPhase phase) {
    if (!mounted) return;
    setState(() => _phase = phase);
    widget.onPhaseChanged?.call(phase);
  }

  void _after(Duration duration, VoidCallback action) {
    final timer = Timer(duration, () {
      if (mounted) action();
    });
    _timers.add(timer);
  }

  Future<void> _beginClose() async {
    if (_phase != HawClosingPhase.copyVisible || _committing) return;
    if (widget.onCommit != null) {
      setState(() {
        _committing = true;
        _completionError = null;
      });
      try {
        await widget.onCommit!();
      } catch (_) {
        if (mounted) {
          setState(
            () => _completionError = 'Could not finish saving. Tap × to retry.',
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _committing = false);
      }
      if (!mounted) return;
    }
    _setPhase(HawClosingPhase.copyFadingOut);
    _after(const Duration(milliseconds: 500), () {
      _setPhase(HawClosingPhase.sealFadingIn);
    });
    _after(const Duration(milliseconds: 1100), () {
      _setPhase(HawClosingPhase.sealHolding);
    });
    _after(const Duration(milliseconds: 2200), () {
      _setPhase(HawClosingPhase.windowFadingOut);
    });
    _after(const Duration(milliseconds: 2900), () {
      _setPhase(HawClosingPhase.complete);
      widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final windowVisible =
        _phase != HawClosingPhase.windowFadingOut &&
        _phase != HawClosingPhase.complete;
    final copyVisible = _phase == HawClosingPhase.copyVisible;
    final copyFading = _phase == HawClosingPhase.copyFadingOut;
    final showCopy = copyVisible || copyFading;
    final showSeal =
        _phase == HawClosingPhase.sealFadingIn ||
        _phase == HawClosingPhase.sealHolding ||
        _phase == HawClosingPhase.windowFadingOut;

    return AnimatedSlide(
      duration: _reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      offset: _entered ? Offset.zero : const Offset(0, 0.18),
      child: AnimatedOpacity(
        duration: _reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOut,
        opacity: windowVisible && _entered ? 1 : 0,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 160),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
          decoration: BoxDecoration(
            color: _HawColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _HawColors.border, width: 0.5),
          ),
          child: Stack(
            children: [
              // Retain a finite card while both copy and seal are dissolved.
              const SizedBox(width: double.infinity, height: 120),
              Positioned(
                top: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: _reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  opacity: _phase == HawClosingPhase.copyVisible ? 1 : 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _beginClose,
                    child: Semantics(
                      button: true,
                      label: 'Close closing message',
                      onTap: _beginClose,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Text(
                            '×',
                            style: TextStyle(
                              color: _HawColors.goldGhost,
                              fontFamily: _HawType.displayFamily,
                              fontFamilyFallback: _HawType.displayFallback,
                              fontSize: 20,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (showCopy)
                AnimatedOpacity(
                  duration: _reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  opacity: copyVisible ? 1 : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 34),
                    child: Text(
                      _completionError == null
                          ? widget.copy
                          : '${widget.copy}\n\n$_completionError',
                      style: const TextStyle(
                        color: _HawColors.goldMuted,
                        fontFamily: _HawType.bodyFamily,
                        fontFamilyFallback: _HawType.bodyFallback,
                        fontSize: 17,
                        fontWeight: FontWeight.w300,
                        height: 1.7,
                      ),
                    ),
                  ),
                ),
              if (showSeal)
                AnimatedOpacity(
                  duration: _reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  opacity:
                      _phase == HawClosingPhase.sealFadingIn ||
                          _phase == HawClosingPhase.sealHolding
                      ? 1
                      : 0,
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'this is ḥꜣw',
                      style: TextStyle(
                        color: _HawColors.goldPrimary,
                        fontFamily: _HawType.bodyFamily,
                        fontFamilyFallback: _HawType.bodyFallback,
                        fontStyle: FontStyle.italic,
                        fontSize: 17,
                        fontWeight: FontWeight.w300,
                        height: 1.2,
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

/// The connection invitation uses the opening's type and spacing. Controllers
/// and provider permissions are supplied by the host, never by this surface.
class HawCalendarOffer extends StatelessWidget {
  const HawCalendarOffer({
    super.key,
    required this.onConnect,
    required this.onContinue,
    this.busy = false,
    this.error,
  });
  final VoidCallback? onConnect;
  final VoidCallback onContinue;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) => _HawCenteredFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Bring your time with you.',
          style: TextStyle(
            color: _HawColors.goldPrimary,
            fontFamily: _HawType.displayFamily,
            fontFamilyFallback: _HawType.displayFallback,
            fontSize: 30,
            height: 1.22,
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'Your existing calendar can live inside ḥꜣw.',
          style: TextStyle(
            color: _HawColors.goldMuted,
            fontFamily: _HawType.bodyFamily,
            fontFamilyFallback: _HawType.bodyFallback,
            fontSize: 21,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 42),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              flex: 3,
              child: _TypographicCue(
                label: busy ? 'connecting…' : 'Connect calendar',
                visible: true,
                onTap: onConnect,
                fontSize: 16,
                minHeight: 44,
              ),
            ),
            const SizedBox(width: 20),
            Flexible(
              flex: 2,
              child: _TypographicCue(
                label: 'not now',
                visible: true,
                onTap: onContinue,
                fontSize: 16,
                minHeight: 44,
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              error!,
              style: const TextStyle(
                color: _HawColors.goldMuted,
                fontFamily: _HawType.bodyFamily,
                fontFamilyFallback: _HawType.bodyFallback,
                fontSize: 17,
              ),
            ),
          ),
      ],
    ),
  );
}

/// Restores a known enrollment before its shared detail page becomes editable.
/// The host supplies its account-keyed identity and existing repository read.
class HawSavedFlowDetail<T extends Object> extends StatefulWidget {
  const HawSavedFlowDetail({
    required super.key,
    required this.load,
    required this.builder,
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T flow) builder;

  @override
  State<HawSavedFlowDetail<T>> createState() => _HawSavedFlowDetailState<T>();
}

class _HawSavedFlowDetailState<T extends Object>
    extends State<HawSavedFlowDetail<T>> {
  late Future<T> _flow = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _flow,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: CircularProgressIndicator(color: _HawColors.goldPrimary),
        );
      }
      if (snapshot.hasData) {
        return widget.builder(context, snapshot.requireData);
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your saved flow could not load. Please retry.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _HawColors.goldMuted,
                  fontFamily: _HawType.bodyFamily,
                  fontSize: 21,
                ),
              ),
              const SizedBox(height: 16),
              _TypographicCue(
                label: 'retry',
                visible: true,
                onTap: () => setState(() {
                  _flow = widget.load();
                }),
                fontSize: 16,
                minHeight: 44,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _HawCenteredFrame extends StatelessWidget {
  const _HawCenteredFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxHeight < 600 ||
          MediaQuery.textScalerOf(context).scale(16) > 24;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          44,
          compact ? 80 : 0,
          44,
          compact ? 100 : 0,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: compact ? 0 : constraints.maxHeight,
          ),
          child: IntrinsicHeight(child: child),
        ),
      );
    },
  );
}

class _ExhaleSlide extends StatelessWidget {
  const _ExhaleSlide({
    required this.line1Visible,
    required this.line2Visible,
    required this.wordmarkVisible,
    required this.reduceMotion,
  });

  final bool line1Visible;
  final bool line2Visible;
  final bool wordmarkVisible;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return _HawCenteredFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedOpacity(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 80),
            curve: Curves.linear,
            opacity: line1Visible ? 1 : 0,
            child: const _DisplayLine(
              'Reject the grind.',
              color: _HawColors.goldPrimary,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedOpacity(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 1100),
            curve: Curves.easeOut,
            opacity: line2Visible ? 1 : 0,
            child: const _DisplayLine(
              'Embrace your rhythm.',
              color: _HawColors.goldWarm,
            ),
          ),
          const SizedBox(height: 60),
          AnimatedOpacity(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 1400),
            curve: Curves.easeOut,
            opacity: wordmarkVisible ? 1 : 0,
            child: const Text(
              'this is ḥꜣw',
              style: TextStyle(
                color: _HawColors.goldGhost,
                fontFamily: _HawType.bodyFamily,
                fontFamilyFallback: _HawType.bodyFallback,
                fontStyle: FontStyle.italic,
                fontSize: 17,
                fontWeight: FontWeight.w300,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisplayLine extends StatelessWidget {
  const _DisplayLine(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontFamily: _HawType.displayFamily,
        fontFamilyFallback: _HawType.displayFallback,
        fontSize: 30,
        fontWeight: FontWeight.w400,
        height: 1.22,
        letterSpacing: 1.8,
      ),
    );
  }
}

class _SegmentationSlide extends StatelessWidget {
  const _SegmentationSlide({
    required this.questionVisible,
    required this.visibleOptions,
    required this.selectedValue,
    required this.selectionInFlight,
    required this.reduceMotion,
    required this.onSelected,
  });

  final bool questionVisible;
  final int visibleOptions;
  final String? selectedValue;
  final bool selectionInFlight;
  final bool reduceMotion;
  final ValueChanged<_EntryOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 96, 44, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedOpacity(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 800),
              opacity: questionVisible ? 1 : 0,
              curve: Curves.easeOut,
              child: const Text(
                'What brought you here today?',
                style: TextStyle(
                  color: _HawColors.goldPrimary,
                  fontFamily: _HawType.displayFamily,
                  fontFamilyFallback: _HawType.displayFallback,
                  fontSize: 19,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 42),
            Expanded(
              child: ListView.separated(
                physics: const ClampingScrollPhysics(),
                itemCount: _entryOptions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  final option = _entryOptions[index];
                  final selected = selectedValue == option.value;
                  final dimmed = selectedValue != null && !selected;
                  return AnimatedOpacity(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    opacity: visibleOptions > index ? (dimmed ? 0.28 : 1) : 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: selectionInFlight
                          ? null
                          : () => onSelected(option),
                      child: Semantics(
                        button: true,
                        selected: selected,
                        child: AnimatedContainer(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 76),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: selected
                                ? _HawColors.goldPrimary.withValues(alpha: 0.06)
                                : _HawColors.cardBg,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: selected
                                  ? _HawColors.goldPrimary.withValues(
                                      alpha: 0.55,
                                    )
                                  : _HawColors.border,
                              width: selected ? 0.8 : 0.5,
                            ),
                          ),
                          child: Text(
                            option.label,
                            style: TextStyle(
                              color: selected
                                  ? _HawColors.goldPrimary
                                  : _HawColors.goldMuted,
                              fontFamily: _HawType.bodyFamily,
                              fontFamilyFallback: _HawType.bodyFallback,
                              fontSize: 19,
                              fontWeight: selected
                                  ? FontWeight.w500
                                  : FontWeight.w300,
                              height: 1.25,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrientationSlide extends StatelessWidget {
  const _OrientationSlide({
    required this.copy,
    required this.dateVisible,
    required this.copyVisible,
    required this.reduceMotion,
  });

  final HawCompassCopy copy;
  final bool dateVisible;
  final bool copyVisible;
  final bool reduceMotion;

  String get _returnLine {
    final explicit = copy.dayAlignedReturnLine?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return _returnLineForKey(copy.dayAlignedReturnKey);
  }

  @override
  Widget build(BuildContext context) {
    return _HawCenteredFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedOpacity(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 800),
            opacity: dateVisible ? 1 : 0,
            curve: Curves.easeOut,
            child: Text(
              _todayLabel,
              style: const TextStyle(
                color: _HawColors.goldDim,
                fontFamily: _HawType.displayFamily,
                fontFamilyFallback: _HawType.displayFallback,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.2,
                letterSpacing: 0.45,
              ),
            ),
          ),
          const SizedBox(height: 36),
          AnimatedOpacity(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 1000),
            opacity: copyVisible ? 1 : 0,
            curve: Curves.easeOut,
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: _HawColors.goldMuted,
                  fontFamily: _HawType.bodyFamily,
                  fontFamilyFallback: _HawType.bodyFallback,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  height: 1.75,
                  letterSpacing: 0.16,
                ),
                children: [
                  TextSpan(
                    text: copy.decanKey == 'epagomenal'
                        ? 'You are in the five days outside the twelve months.\n\n'
                        : 'You are in the ${copy.decanOrdinalLabel} decan of ${copy.monthName}.\n\n',
                    style: const TextStyle(color: _HawColors.goldStrong),
                  ),
                  const TextSpan(text: 'A ḥꜣw reflection for these days:\n'),
                  TextSpan(
                    text: copy.orientationQuestion.trim().isNotEmpty
                        ? copy.orientationQuestion
                        : _returnLine,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _todayLabel {
    final date = copy.dateLabel.trim();
    if (date.startsWith('Today is ')) return date;
    return 'Today is $date';
  }
}

class _RecommendedFlowSlide extends StatelessWidget {
  const _RecommendedFlowSlide({
    required this.visible,
    required this.reduceMotion,
    required this.child,
    this.reason,
  });

  final String? reason;
  final bool visible;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 56, 22, 34),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final enlarged = MediaQuery.textScalerOf(context).scale(18) > 18;
            final minimumHeight = enlarged ? 780.0 : 620.0;
            return SingleChildScrollView(
              child: SizedBox(
                height: constraints.maxHeight < minimumHeight
                    ? minimumHeight
                    : constraints.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedOpacity(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      opacity: visible ? 1 : 0,
                      child: const Text(
                        'Recommended First Flow',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _HawColors.goldPrimary,
                          fontFamily: _HawType.displayFamily,
                          fontFamilyFallback: _HawType.displayFallback,
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (reason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          reason!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _HawColors.goldMuted,
                            fontFamily: _HawType.bodyFamily,
                            fontSize: 17,
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: AnimatedOpacity(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        opacity: visible ? 1 : 0,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final windowHeight = constraints.maxHeight > 650
                                ? 650.0
                                : constraints.maxHeight;
                            return Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                child: SizedBox(
                                  height: windowHeight,
                                  width: double.infinity,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: _HawColors.cardBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _HawColors.border,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: child,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TypographicCue extends StatelessWidget {
  const _TypographicCue({
    required this.label,
    required this.visible,
    required this.onTap,
    this.fontSize = 13,
    this.minHeight = 0,
  });

  final String label;
  final bool visible;
  final VoidCallback? onTap;
  final double fontSize;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Semantics(
          button: true,
          enabled: onTap != null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              constraints: BoxConstraints(minHeight: minHeight),
              padding: const EdgeInsets.all(10),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _HawColors.ghostDeep,
                  fontFamily: _HawType.bodyFamily,
                  fontFamilyFallback: _HawType.bodyFallback,
                  fontStyle: FontStyle.italic,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w300,
                  height: 1.2,
                  letterSpacing: 0.78,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryOption {
  const _EntryOption({required this.value, required this.label});

  final String value;
  final String label;
}

final List<_EntryOption> _entryOptions = [
  for (final intent in HawEntryIntent.values)
    _EntryOption(value: intent.name, label: intent.label),
];

String _returnLineForKey(String key) {
  return switch (key.trim()) {
    'begin_cleanly' => 'What can begin cleanly.',
    'keep_measure' => 'What can stay measured.',
    'make_record_useful' => 'What the record can hold.',
    'rise_with_attention' => 'Where attention can rise.',
    'hold_center' => 'What needs a steadier center.',
    'restore_beauty' => 'What beauty can restore.',
    'notice_deposit' => 'What has been deposited.',
    'sort_arrival' => 'What arrival brought.',
    'settle_after_flood' => 'What has been deposited.',
    'shape_first' => 'What needs first shape.',
    'reinforce_weight' => 'What should be reinforced.',
    'complete_support' => 'What support is necessary.',
    'see_forward_edge' => 'What is ahead.',
    'stay_middle' => 'What can continue.',
    'bring_forward_form' => 'What form is asking.',
    'shape_patiently' => 'What needs patient shaping.',
    'tend_formation' => 'What is worth tending.',
    'place_formation' => 'Where the formed work belongs.',
    'reserve_power' => 'What power can be reserved.',
    'dignify_repetition' => 'Where repetition can become practice.',
    'make_noble_practical' => 'What intention needs a step.',
    'listen_for_signal' => 'What signal is present.',
    'orient_movement' => 'What movement needs direction.',
    'release_with_care' => 'What is ready for release.',
    'attend_hidden_support' => 'What hidden support needs attention.',
    'carry_deliberately' => 'What can be carried deliberately.',
    'set_down_load' => 'What can be set down.',
    'stand_upright' => 'What can stand upright.',
    'quiet_courage' => 'What asks for quiet courage.',
    'follow_through' => 'What deserves follow-through.',
    'clear_standard' => 'What standard can guide.',
    'care_clean_action' => 'Where care can clean the action.',
    'repeatable_care' => 'What care can become repeatable.',
    'name_offering' => 'What offering is still owed.',
    'honest_accounting' => 'What needs honest accounting.',
    'close_cleanly' => 'What can close cleanly.',
    'guard_threshold' => 'What should not cross.',
    _ => '',
  };
}

class _HawColors {
  const _HawColors._();

  static const Color ground = Color(0xFF060604);
  static const Color goldPrimary = Color(0xFFC9A84C);
  static const Color goldWarm = Color(0xFFE2CF85);
  static const Color goldMuted = Color(0xFF8A7A58);
  static const Color goldStrong = Color(0xFFB8A06A);
  static const Color goldDim = Color(0xFF5A4E30);
  static const Color goldGhost = Color(0xFF8A7A58);
  static const Color ghostDeep = Color(0xFF8A7A58);
  static const Color border = Color(0xFF2A2416);
  static const Color cardBg = Color(0xFF0D0B07);
}

class _HawType {
  const _HawType._();

  static const String displayFamily = 'GentiumPlus';
  static const List<String> displayFallback = [
    'CormorantGaramond',
    'NotoSerif',
    'Georgia',
    'serif',
  ];
  static const String bodyFamily = 'CormorantGaramond';
  static const List<String> bodyFallback = [
    'GentiumPlus',
    'NotoSerif',
    'Georgia',
    'serif',
  ];
}
