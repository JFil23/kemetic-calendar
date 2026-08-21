part of 'calendar_page.dart';

/// Debug tests enable this automatically. Profile/release benchmarks must opt
/// in explicitly; ordinary profile/release builds compile the branches out.
const bool _calendarBoundaryBenchmarkEnabled =
    kDebugMode ||
    bool.fromEnvironment('CALENDAR_BOUNDARY_BENCHMARK', defaultValue: false);

/// Seeded content variants used by the calendar boundary performance harness.
enum CalendarBoundaryHarnessContent { empty, eventHeavy }

enum CalendarBoundaryInstrumentation { timingOnly, fullProbe }

enum CalendarTodayHydrationTrigger { none, early, late }

final class CalendarBoundaryProbeCounts {
  int builds = 0;
  int layouts = 0;
  int paints = 0;

  void reset() {
    builds = 0;
    layouts = 0;
    paints = 0;
  }

  Map<String, int> toJson() => <String, int>{
    'builds': builds,
    'layouts': layouts,
    'paints': paints,
  };
}

/// One frame-coalesced observation of scroll and body-anchor continuity.
final class CalendarBoundaryFrameSample {
  const CalendarBoundaryFrameSample({
    required this.frameTimestampMicros,
    required this.scrollPixels,
    required this.bodyAnchorViewportY,
    required this.bannerMonth,
    required this.collectorScheduledPublications,
    required this.collectorCommittedPublications,
    required this.bannerPublications,
    required this.restorationSchedules,
    required this.restorationWrites,
    required this.hydrationSchedules,
    required this.pageCounts,
    required this.bodyCounts,
    required this.bannerCounts,
  });

  final int frameTimestampMicros;
  final double scrollPixels;
  final double? bodyAnchorViewportY;
  final MonthRef bannerMonth;
  final int collectorScheduledPublications;
  final int collectorCommittedPublications;
  final int bannerPublications;
  final int restorationSchedules;
  final int restorationWrites;
  final int hydrationSchedules;
  final Map<String, int> pageCounts;
  final Map<String, int> bodyCounts;
  final Map<String, int> bannerCounts;

  Map<String, Object?> toJson() => <String, Object?>{
    'frame_timestamp_us': frameTimestampMicros,
    'scroll_pixels': scrollPixels,
    'body_anchor_viewport_y': bodyAnchorViewportY,
    'banner_year': bannerMonth.year,
    'banner_month': bannerMonth.month,
    'collector_scheduled_publications': collectorScheduledPublications,
    'collector_committed_publications': collectorCommittedPublications,
    'banner_publications': bannerPublications,
    'restoration_schedules': restorationSchedules,
    'restoration_writes': restorationWrites,
    'hydration_schedules': hydrationSchedules,
    'page': pageCounts,
    'body': bodyCounts,
    'banner': bannerCounts,
  };
}

/// Test-only diagnostics attached to the real [CalendarPage].
///
/// The app never supplies this controller. When present, CalendarPage skips
/// startup/network work, seeds deterministic content, and otherwise uses its
/// production portrait scroll tree and scroll-derived consumers unchanged.
final class CalendarBoundaryHarnessController {
  static const Duration todayAnimationDuration = Duration(milliseconds: 320);
  static const Duration _todaySchedulerTimingTolerance = Duration(
    milliseconds: 1,
  );

  CalendarBoundaryHarnessController({
    required this.expansionLevel,
    required this.content,
    required this.instrumentation,
  });

  final MonthExpansionLevel expansionLevel;
  final CalendarBoundaryHarnessContent content;
  final CalendarBoundaryInstrumentation instrumentation;
  final CalendarBoundaryProbeCounts pageCounts = CalendarBoundaryProbeCounts();
  final CalendarBoundaryProbeCounts bodyCounts = CalendarBoundaryProbeCounts();
  final CalendarBoundaryProbeCounts bannerCounts =
      CalendarBoundaryProbeCounts();
  final List<CalendarBoundaryFrameSample> _samples =
      <CalendarBoundaryFrameSample>[];
  final List<Map<String, int>> _frameTimings = <Map<String, int>>[];
  final List<Map<String, Object?>> _diagnosticEvents = <Map<String, Object?>>[];

  CalendarPageState? _state;
  bool _sampleScheduled = false;
  bool _captureFrameTimings = false;
  bool _diagnosticScrollingListenerAttached = false;
  Stopwatch? _diagnosticStopwatch;
  int _bannerPublicationCount = 0;
  int _restorationScheduleCount = 0;
  int _restorationWriteCount = 0;
  int _hydrationScheduleCount = 0;
  int _scheduledPublicationBaseline = 0;
  int _committedPublicationBaseline = 0;
  int _bannerPublicationBaseline = 0;
  int _restorationScheduleBaseline = 0;
  int _restorationWriteBaseline = 0;
  int _hydrationScheduleBaseline = 0;
  CalendarTodayHydrationTrigger _todayHydrationTrigger =
      CalendarTodayHydrationTrigger.none;
  double? _todayTravelStart;
  double? _todayTravelTarget;
  double? _todayLastScrollPixels;
  double? _todayHydrationTriggerProgress;
  Duration? _todayRequestedHydrationElapsed;
  Duration? _todayActualHydrationElapsed;
  Duration? _todayHydrationWallElapsed;
  Duration? _todayAnimationResolutionWallElapsed;
  Stopwatch? _todayAnimationWallClock;
  int? _todayTickerEpochMonotonicUs;
  int? _todayTimerDeadlineMonotonicUs;
  int? _todayTimerCallbackEntryMonotonicUs;
  int? _todayHydrationCommitEntryMonotonicUs;
  Timer? _todayHydrationTimer;
  Completer<void>? _todayHydrationCommitCompleter;
  int? _todayEpochFrameCallbackId;
  bool _todayAnimationTransactionStarted = false;
  bool _todayAnimationEpochPrimed = false;
  bool? _todayOriginalAnimationActiveAtCommit;
  bool _todayOriginalAnimationActive = false;
  int _todayHydrationCommitCount = 0;
  bool _todayTravelArmed = false;
  bool _todayCaptureArrival = false;
  bool _todayAnimationStarted = false;
  bool _todayArrivalScheduled = false;
  Object? _todayArrivalError;
  String? _todayArrivalStack;
  final List<Map<String, Object?>> _todayArrivalSamples =
      <Map<String, Object?>>[];

  bool get probesEnabled =>
      instrumentation == CalendarBoundaryInstrumentation.fullProbe;

  bool get isAttached => _state != null;

  int get year => _requireState()._today.kYear;

  MonthRef get outgoingMonth => MonthRef(year: year, month: 2);

  MonthRef get incomingMonth => MonthRef(year: year, month: 3);

  ScrollController get scrollController => _requireState()._scrollCtrl;

  CalendarGeometrySnapshot? get snapshot =>
      _state?._calendarGeometryCollector.snapshot;

  MonthRef? get activeBannerMonth =>
      _state?._calendarScrollCoordinator.activeBannerMonth.value;

  MonthRef? get activeCenteredMonth =>
      _state?._calendarScrollCoordinator.activeCenteredMonth.value;

  int get layoutCorrectionCount =>
      _state?._calendarLayoutCorrection.debugCompletedCount ?? 0;

  int get layoutMissingAnchorCount =>
      _state?._calendarLayoutCorrection.debugMissingAnchorCount ?? 0;

  double get lastLayoutCorrection =>
      _state?._calendarLayoutCorrection.debugLastCorrection ?? 0;

  double monthViewportTop(MonthRef month) {
    final context = keyForMonth(month.year, month.month).currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      throw StateError('Month $month is not mounted.');
    }
    return renderObject.localToGlobal(Offset.zero).dy;
  }

  double monthHeight(MonthRef month) {
    final context = keyForMonth(month.year, month.month).currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      throw StateError('Month $month is not mounted.');
    }
    return renderObject.size.height;
  }

  RenderCalendarPinchDayAnchor _pinchDayAnchor(int year, int month, int day) {
    final context = keyForMonth(year, month).currentContext;
    final monthRenderObject = context?.findRenderObject();
    RenderCalendarPinchDayAnchor? match;

    void visit(RenderObject child) {
      if (match != null) return;
      if (child is RenderCalendarPinchDayAnchor &&
          child.year == year &&
          child.month == month &&
          child.day == day) {
        match = child;
        return;
      }
      child.visitChildren(visit);
    }

    monthRenderObject?.visitChildren(visit);
    final result = match;
    if (result == null || !result.attached) {
      throw StateError('Day $year/$month/$day is not mounted.');
    }
    return result;
  }

  Rect dayViewportRect(int year, int month, int day) {
    final anchor = _pinchDayAnchor(year, month, day);
    final origin = anchor.localToGlobal(Offset.zero);
    return origin & anchor.size;
  }

  void drivePinchExpansionProgress(
    double progress, {
    MonthRef? anchorMonth,
    int? anchorDay,
  }) {
    final state = _requireState();
    final anchor =
        anchorMonth ??
        state._calendarScrollCoordinator.activeCenteredMonth.value;
    state._pinchAnchorMonth = (anchor.year, anchor.month);
    state._pinchAnchorDay = anchorDay == null
        ? null
        : _pinchDayAnchor(anchor.year, anchor.month, anchorDay);
    state._applyPinchExpansionProgress(progress);
  }

  void commitPinchExpansionEndpoint(MonthExpansionLevel targetLevel) {
    _requireState()._commitPinchExpansionEndpoint(
      targetLevel,
      persistAndTrack: false,
    );
  }

  void finishPinchExpansionHarness() {
    final state = _requireState();
    state._transientMonthExpansionProgress.value = null;
    state._pinchAnchorMonth = null;
    state._pinchAnchorDay = null;
  }

  List<CalendarBoundaryFrameSample> get samples =>
      List<CalendarBoundaryFrameSample>.unmodifiable(_samples);

  double get todayTargetOffset {
    final state = _requireState();
    final target = state._centeredScrollOffsetForContext(
      state._todayDayKey.currentContext,
    );
    if (target == null) throw StateError('Today target is not mounted.');
    return target;
  }

  double get farPastTodayStartOffset {
    final state = _requireState();
    final firstMonth = snapshot?.geometryFor(MonthRef(year: year, month: 1));
    if (firstMonth == null) {
      throw StateError('The first month of the current year is not mounted.');
    }
    return (firstMonth.extent.leading + 1)
        .clamp(
          state._scrollCtrl.position.minScrollExtent,
          state._scrollCtrl.position.maxScrollExtent,
        )
        .toDouble();
  }

  double get nearTodayStartOffset {
    final position = _requireState()._scrollCtrl.position;
    return (todayTargetOffset - (position.viewportDimension * 0.75))
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  double get todayDisplayIntervalMicros {
    final state = _requireState();
    final refreshRate = View.of(state.context).display.refreshRate;
    return refreshRate > 0 ? 1000000.0 / refreshRate : 16666.667;
  }

  Duration? get todayRequestedHydrationElapsed {
    return switch (_todayHydrationTrigger) {
      CalendarTodayHydrationTrigger.none => null,
      CalendarTodayHydrationTrigger.early => Duration(
        microseconds:
            (todayAnimationDuration.inMicroseconds *
                    _inverseTodayCurveProgress(0.25))
                .round(),
      ),
      CalendarTodayHydrationTrigger.late => Duration(
        microseconds:
            (todayAnimationDuration.inMicroseconds - todayDisplayIntervalMicros)
                .round()
                .clamp(0, todayAnimationDuration.inMicroseconds),
      ),
    };
  }

  double _inverseTodayCurveProgress(double targetProgress) {
    var lower = 0.0;
    var upper = 1.0;
    for (var iteration = 0; iteration < 48; iteration++) {
      final candidate = (lower + upper) / 2;
      if (Curves.easeOutCubic.transform(candidate) < targetProgress) {
        lower = candidate;
      } else {
        upper = candidate;
      }
    }
    return (lower + upper) / 2;
  }

  bool get todayAnimationStarted => _todayAnimationTransactionStarted;

  bool get todayAnimationEpochPrimed => _todayAnimationEpochPrimed;

  int? get _todayTimerCallbackLatenessUs {
    final entry = _todayTimerCallbackEntryMonotonicUs;
    final deadline = _todayTimerDeadlineMonotonicUs;
    return entry == null || deadline == null ? null : entry - deadline;
  }

  Future<void>? get todayHydrationCommitFuture =>
      _todayHydrationCommitCompleter?.future;

  void prepareTodayTargetUnhydrated() {
    _requireState()._prepareCalendarBoundaryTodayTargetUnhydrated();
  }

  void armTodayTravel({
    required double startOffset,
    required CalendarTodayHydrationTrigger hydrationTrigger,
    bool captureArrival = true,
  }) {
    final state = _requireState();
    _disarmTodayTravel();
    _todayHydrationTrigger = hydrationTrigger;
    _todayTravelStart = startOffset;
    _todayTravelTarget = todayTargetOffset;
    _todayLastScrollPixels = startOffset;
    _todayHydrationTriggerProgress = null;
    _todayRequestedHydrationElapsed = null;
    _todayActualHydrationElapsed = null;
    _todayHydrationWallElapsed = null;
    _todayAnimationResolutionWallElapsed = null;
    _todayAnimationWallClock = null;
    _todayTickerEpochMonotonicUs = null;
    _todayTimerDeadlineMonotonicUs = null;
    _todayTimerCallbackEntryMonotonicUs = null;
    _todayHydrationCommitEntryMonotonicUs = null;
    _todayHydrationTimer = null;
    _todayHydrationCommitCompleter =
        hydrationTrigger == CalendarTodayHydrationTrigger.none
        ? null
        : Completer<void>();
    _todayEpochFrameCallbackId = null;
    _todayAnimationTransactionStarted = false;
    _todayAnimationEpochPrimed = false;
    _todayOriginalAnimationActiveAtCommit = null;
    _todayOriginalAnimationActive = false;
    _todayHydrationCommitCount = 0;
    _todayArrivalSamples.clear();
    _todayTravelArmed = true;
    _todayCaptureArrival = captureArrival;
    _todayAnimationStarted = false;
    _todayArrivalScheduled = false;
    _todayArrivalError = null;
    _todayArrivalStack = null;
    if (captureArrival) {
      state._scrollCtrl.addListener(_handleTodayScroll);
    }
    if (captureArrival) {
      state._scrollCtrl.position.isScrollingNotifier.addListener(
        _handleTodayScrollingState,
      );
    }
  }

  void invokeToday() {
    _requireState()._scrollToToday();
    // A real button event arrives through the engine's frame loop. Widget and
    // drive tests call this method between frames, so explicitly request the
    // frame that owns CalendarPage's post-frame target resolution.
    WidgetsBinding.instance.scheduleFrame();
  }

  void _commitTodayHydrationAtControlledTime() {
    if (!_todayTravelArmed) {
      throw StateError('Today travel is not armed.');
    }
    if (_todayHydrationTrigger == CalendarTodayHydrationTrigger.none) {
      throw StateError('The hydrated Today workload has no commit.');
    }
    if (_todayHydrationCommitCount != 0) {
      throw StateError('Today hydration may commit only once.');
    }
    _todayHydrationCommitEntryMonotonicUs = FlutterTimeline.now;
    markDiagnosticEvent(
      'today.hydration.commit_entry',
      details: <String, Object?>{
        'timer_deadline_monotonic_us': _todayTimerDeadlineMonotonicUs,
        'timer_callback_entry_monotonic_us':
            _todayTimerCallbackEntryMonotonicUs,
      },
    );
    final state = _requireState();
    final start = _todayTravelStart;
    final target = _todayTravelTarget;
    final requested = todayRequestedHydrationElapsed;
    if (start == null ||
        target == null ||
        !_todayAnimationTransactionStarted ||
        !_todayAnimationEpochPrimed ||
        requested == null) {
      throw StateError('Today animation transaction did not start.');
    }
    final pixels = state._scrollCtrl.position.pixels;
    _todayLastScrollPixels = pixels;
    _todayRequestedHydrationElapsed = requested;
    final actualElapsed = _todayAnimationWallClock?.elapsed;
    _todayActualHydrationElapsed = actualElapsed;
    _todayHydrationWallElapsed = actualElapsed;
    _todayOriginalAnimationActiveAtCommit = _todayOriginalAnimationActive;
    _todayHydrationTriggerProgress = ((pixels - start) / (target - start))
        .clamp(0.0, 1.0);
    state._applyCalendarBoundaryTodayHydrationCommit();
    final completer = _todayHydrationCommitCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  bool get todayArrivalReady => _todayArrivalSamples.length == 3;

  Map<String, Object?> get debugTodayTravelState => <String, Object?>{
    'armed': _todayTravelArmed,
    'capture_arrival': _todayCaptureArrival,
    'animation_started': _todayAnimationStarted,
    'arrival_scheduled': _todayArrivalScheduled,
    'arrival_count': _todayArrivalSamples.length,
    'arrival_error': _todayArrivalError?.toString(),
    'arrival_stack': _todayArrivalStack,
    'hydration_commit_count': _todayHydrationCommitCount,
    'hydration_progress': _todayHydrationTriggerProgress,
    'requested_trigger_elapsed_us':
        _todayRequestedHydrationElapsed?.inMicroseconds,
    'actual_trigger_elapsed_us': _todayActualHydrationElapsed?.inMicroseconds,
    'trigger_wall_elapsed_us': _todayHydrationWallElapsed?.inMicroseconds,
    'original_animation_active': _todayOriginalAnimationActive,
    'animation_epoch_primed': _todayAnimationEpochPrimed,
    'original_animation_active_at_commit':
        _todayOriginalAnimationActiveAtCommit,
    'original_animation_resolution_wall_elapsed_us':
        _todayAnimationResolutionWallElapsed?.inMicroseconds,
    'ticker_epoch_monotonic_us': _todayTickerEpochMonotonicUs,
    'timer_deadline_monotonic_us': _todayTimerDeadlineMonotonicUs,
    'timer_callback_entry_monotonic_us': _todayTimerCallbackEntryMonotonicUs,
    'hydration_commit_entry_monotonic_us':
        _todayHydrationCommitEntryMonotonicUs,
    'timer_callback_lateness_us': _todayTimerCallbackLatenessUs,
    'start': _todayTravelStart,
    'target': _todayTravelTarget,
    'last_scroll': _todayLastScrollPixels,
    'scroll_pixels': _state?._scrollCtrl.hasClients ?? false
        ? _state!._scrollCtrl.position.pixels
        : null,
    'is_scrolling': _state?._scrollCtrl.hasClients ?? false
        ? _state!._scrollCtrl.position.isScrollingNotifier.value
        : null,
  };

  void resetMeasurements() {
    final state = _requireState();
    pageCounts.reset();
    bodyCounts.reset();
    bannerCounts.reset();
    _samples.clear();
    _frameTimings.clear();
    _diagnosticEvents.clear();
    _diagnosticStopwatch = null;
    _scheduledPublicationBaseline =
        state._calendarGeometryCollector.debugScheduledPublicationCount;
    _committedPublicationBaseline =
        state._calendarGeometryCollector.debugPublicationCount;
    _bannerPublicationBaseline = _bannerPublicationCount;
    _restorationScheduleBaseline = _restorationScheduleCount;
    _restorationWriteBaseline = _restorationWriteCount;
    _hydrationScheduleBaseline = _hydrationScheduleCount;
  }

  Map<String, Object?> measurementReport({
    required String scenario,
    required double transitionOffset,
    required int idleFrameCount,
  }) {
    final state = _requireState();
    final bannerPublications =
        _bannerPublicationCount - _bannerPublicationBaseline;
    return <String, Object?>{
      'scenario': scenario,
      'transition_offset': transitionOffset,
      'idle_frame_count': idleFrameCount,
      'banner_transition_count': bannerPublications,
      'banner_publication_count': bannerPublications,
      'collector_scheduled_publication_count':
          state._calendarGeometryCollector.debugScheduledPublicationCount -
          _scheduledPublicationBaseline,
      'collector_committed_publication_count':
          state._calendarGeometryCollector.debugPublicationCount -
          _committedPublicationBaseline,
      'restoration_schedule_count':
          _restorationScheduleCount - _restorationScheduleBaseline,
      'restoration_write_count':
          _restorationWriteCount - _restorationWriteBaseline,
      'hydration_schedule_count':
          _hydrationScheduleCount - _hydrationScheduleBaseline,
      'page': pageCounts.toJson(),
      'body': bodyCounts.toJson(),
      'banner': bannerCounts.toJson(),
      'frame_timings': List<Map<String, int>>.unmodifiable(_frameTimings),
      'diagnostic_events': List<Map<String, Object?>>.unmodifiable(
        _diagnosticEvents,
      ),
      'samples': <Map<String, Object?>>[
        for (final sample in _samples) sample.toJson(),
      ],
    };
  }

  Map<String, Object?> todayMeasurementReport({
    required String scenario,
    required int idleFrameCount,
  }) {
    if (!probesEnabled) {
      throw StateError('Today diagnostics belong to the full-probe pass.');
    }
    if (!todayArrivalReady) {
      throw StateError('Today A/B/C arrival samples are incomplete.');
    }
    final state = _requireState();
    final a = _todayArrivalSamples[0];
    final b = _todayArrivalSamples[1];
    final c = _todayArrivalSamples[2];
    final aY = a['target_viewport_y'] as double?;
    final bY = b['target_viewport_y'] as double?;
    final cY = c['target_viewport_y'] as double?;
    final tolerance = 1.0 / View.of(state.context).devicePixelRatio;
    final deltaAB = aY == null || bY == null ? null : bY - aY;
    final deltaBC = bY == null || cY == null ? null : cY - bY;
    return <String, Object?>{
      ...measurementReport(
        scenario: scenario,
        transitionOffset: _todayTravelTarget ?? todayTargetOffset,
        idleFrameCount: idleFrameCount,
      ),
      ...todayTreatmentReport(),
      'arrival_a_to_b_delta_px': deltaAB,
      'arrival_b_to_c_delta_px': deltaBC,
      'arrival_continuity_passed':
          deltaAB != null &&
          deltaBC != null &&
          deltaAB.abs() <= tolerance &&
          deltaBC.abs() <= tolerance,
      'arrival_samples': List<Map<String, Object?>>.unmodifiable(
        _todayArrivalSamples,
      ),
    };
  }

  Map<String, Object?> todayTreatmentReport() {
    final state = _requireState();
    final finalTarget = todayTargetOffset;
    final finalPixels = state._scrollCtrl.position.pixels;
    final arrivalTolerance = 1.0 / View.of(state.context).devicePixelRatio;
    final requested = _todayRequestedHydrationElapsed;
    final actual = _todayActualHydrationElapsed;
    final wall = _todayHydrationWallElapsed;
    final animationDurationMicros = todayAnimationDuration.inMicroseconds;
    final displayInterval = Duration(
      microseconds: todayDisplayIntervalMicros.round(),
    );
    final expectedProgress = requested == null
        ? null
        : Curves.easeOutCubic.transform(
            (requested.inMicroseconds / animationDurationMicros).clamp(
              0.0,
              1.0,
            ),
          );
    final progressWindowCenter = actual ?? requested;
    final spatialProgressMinimum = progressWindowCenter == null
        ? null
        : Curves.easeOutCubic.transform(
            ((progressWindowCenter - displayInterval).inMicroseconds /
                    animationDurationMicros)
                .clamp(0.0, 1.0),
          );
    final spatialProgressMaximum = progressWindowCenter == null
        ? null
        : Curves.easeOutCubic.transform(
            ((progressWindowCenter + displayInterval).inMicroseconds /
                    animationDurationMicros)
                .clamp(0.0, 1.0),
          );
    final triggerTimingValid = requested == null
        ? true
        : actual != null &&
              actual >= requested - _todaySchedulerTimingTolerance &&
              actual <= requested + displayInterval;
    final wallDelayValid = requested == null
        ? true
        : wall != null && wall <= requested + displayInterval;
    final spatialProgressValid = expectedProgress == null
        ? true
        : _todayHydrationTriggerProgress != null &&
              spatialProgressMinimum != null &&
              spatialProgressMaximum != null &&
              _todayHydrationTriggerProgress! >= spatialProgressMinimum &&
              _todayHydrationTriggerProgress! <= spatialProgressMaximum;
    final commitValid = requested == null
        ? _todayHydrationCommitCount == 0
        : _todayHydrationCommitCount == 1 &&
              _todayOriginalAnimationActiveAtCommit == true;
    return <String, Object?>{
      'today_hydration_trigger': _todayHydrationTrigger.name,
      'today_requested_trigger_elapsed_us': requested?.inMicroseconds,
      'today_actual_trigger_elapsed_us': actual?.inMicroseconds,
      'today_trigger_wall_elapsed_us': wall?.inMicroseconds,
      'today_trigger_early_tolerance_us':
          _todaySchedulerTimingTolerance.inMicroseconds,
      'today_wall_delay_tolerance_us': todayDisplayIntervalMicros.round(),
      'today_expected_trigger_progress': expectedProgress,
      'today_actual_trigger_progress': _todayHydrationTriggerProgress,
      'today_spatial_progress_minimum': spatialProgressMinimum,
      'today_spatial_progress_maximum': spatialProgressMaximum,
      'today_hydration_commit_count': _todayHydrationCommitCount,
      'today_original_animation_active_at_commit':
          _todayOriginalAnimationActiveAtCommit,
      'today_original_animation_resolution_wall_elapsed_us':
          _todayAnimationResolutionWallElapsed?.inMicroseconds,
      'today_ticker_epoch_monotonic_us': _todayTickerEpochMonotonicUs,
      'today_timer_deadline_monotonic_us': _todayTimerDeadlineMonotonicUs,
      'today_timer_callback_entry_monotonic_us':
          _todayTimerCallbackEntryMonotonicUs,
      'today_hydration_commit_entry_monotonic_us':
          _todayHydrationCommitEntryMonotonicUs,
      'today_timer_callback_lateness_us': _todayTimerCallbackLatenessUs,
      'today_treatment_trigger_timing_valid': triggerTimingValid,
      'today_treatment_wall_delay_valid': wallDelayValid,
      'today_treatment_spatial_progress_valid': spatialProgressValid,
      'today_treatment_commit_valid': commitValid,
      'today_treatment_valid':
          triggerTimingValid &&
          wallDelayValid &&
          spatialProgressValid &&
          commitValid,
      'today_start_offset': _todayTravelStart,
      'today_initial_target_offset': _todayTravelTarget,
      'today_final_target_offset': finalTarget,
      'today_final_scroll_pixels': finalPixels,
      'today_reached_target':
          (finalPixels - finalTarget).abs() <= arrivalTolerance,
      'arrival_tolerance_logical_px': arrivalTolerance,
    };
  }

  Map<String, Object?> todayDelayDiagnosticReport() {
    if (!probesEnabled) {
      throw StateError('Today delay diagnosis belongs to the full-probe pass.');
    }
    return <String, Object?>{
      ...todayTreatmentReport(),
      'page': pageCounts.toJson(),
      'body': bodyCounts.toJson(),
      'banner': bannerCounts.toJson(),
      'frame_timings': List<Map<String, int>>.unmodifiable(_frameTimings),
      'diagnostic_events': List<Map<String, Object?>>.unmodifiable(
        _diagnosticEvents,
      ),
    };
  }

  void _attach(CalendarPageState state) {
    if (_state != null && _state != state) {
      throw StateError('Calendar boundary harness controller is already used.');
    }
    _state = state;
    if (!probesEnabled) return;
    state._calendarGeometryCollector.addListener(_handleGeometryPublication);
    state._calendarScrollCoordinator.activeBannerMonth.addListener(
      _handleBannerPublication,
    );
    state._scrollCtrl.addListener(_scheduleSample);
    WidgetsBinding.instance.addTimingsCallback(_handleFrameTimings);
  }

  void _detach(CalendarPageState state) {
    if (_state != state) return;
    _captureFrameTimings = false;
    _disarmTodayTravel();
    if (probesEnabled) {
      WidgetsBinding.instance.removeTimingsCallback(_handleFrameTimings);
      _removeDiagnosticScrollingListener();
      state._scrollCtrl.removeListener(_scheduleSample);
      state._calendarScrollCoordinator.activeBannerMonth.removeListener(
        _handleBannerPublication,
      );
      state._calendarGeometryCollector.removeListener(
        _handleGeometryPublication,
      );
    }
    _state = null;
  }

  void _handleGeometryPublication() {
    markDiagnosticEvent('geometry.publication');
    _scheduleSample();
  }

  void _handleDiagnosticScrollingState() {
    final state = _state;
    if (state == null || !state._scrollCtrl.hasClients) return;
    markDiagnosticEvent(
      state._scrollCtrl.position.isScrollingNotifier.value
          ? 'scroll_activity.start'
          : 'scroll_activity.end',
    );
  }

  void beginFrameTimingCapture() {
    _requireState();
    if (!probesEnabled) {
      throw StateError('Frame correlation belongs to the full-probe pass.');
    }
    _frameTimings.clear();
    _diagnosticEvents.clear();
    _diagnosticStopwatch = Stopwatch()..start();
    _requireState()._scrollCtrl.position.isScrollingNotifier.addListener(
      _handleDiagnosticScrollingState,
    );
    _diagnosticScrollingListenerAttached = true;
    _captureFrameTimings = true;
    markDiagnosticEvent('capture.start');
  }

  void endFrameTimingCapture() {
    markDiagnosticEvent('capture.end');
    _diagnosticStopwatch?.stop();
    _captureFrameTimings = false;
    _removeDiagnosticScrollingListener();
  }

  void _removeDiagnosticScrollingListener() {
    if (!_diagnosticScrollingListenerAttached) return;
    final state = _state;
    if (state != null && state._scrollCtrl.hasClients) {
      state._scrollCtrl.position.isScrollingNotifier.removeListener(
        _handleDiagnosticScrollingState,
      );
    }
    _diagnosticScrollingListenerAttached = false;
  }

  void markDiagnosticEvent(
    String name, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    if (!probesEnabled || !_captureFrameTimings) return;
    final state = _requireState();
    final stopwatch = _diagnosticStopwatch;
    if (stopwatch == null) return;
    final activeBanner =
        state._calendarScrollCoordinator.activeBannerMonth.value;
    final frameTimestampMicros =
        WidgetsBinding.instance.schedulerPhase.name == 'idle'
        ? null
        : WidgetsBinding.instance.currentFrameTimeStamp.inMicroseconds;
    _diagnosticEvents.add(<String, Object?>{
      'name': name,
      'monotonic_us': FlutterTimeline.now,
      'elapsed_us': stopwatch.elapsedMicroseconds,
      'frame_timestamp_us': frameTimestampMicros,
      'scroll_pixels': state._scrollCtrl.hasClients
          ? state._scrollCtrl.position.pixels
          : null,
      'is_scrolling': state._scrollCtrl.hasClients
          ? state._scrollCtrl.position.isScrollingNotifier.value
          : false,
      'banner_year': activeBanner.year,
      'banner_month': activeBanner.month,
      'collector_scheduled_publications':
          state._calendarGeometryCollector.debugScheduledPublicationCount,
      'collector_committed_publications':
          state._calendarGeometryCollector.debugPublicationCount,
      'restoration_schedules': _restorationScheduleCount,
      'restoration_writes': _restorationWriteCount,
      'hydration_schedules': _hydrationScheduleCount,
      ...details,
    });
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    if (!_captureFrameTimings) return;
    for (final timing in timings) {
      _frameTimings.add(<String, int>{
        'vsync_start_us': timing.timestampInMicroseconds(FramePhase.vsyncStart),
        'build_start_us': timing.timestampInMicroseconds(FramePhase.buildStart),
        'build_finish_us': timing.timestampInMicroseconds(
          FramePhase.buildFinish,
        ),
        'raster_start_us': timing.timestampInMicroseconds(
          FramePhase.rasterStart,
        ),
        'raster_finish_us': timing.timestampInMicroseconds(
          FramePhase.rasterFinish,
        ),
        'build_duration_us': timing.buildDuration.inMicroseconds,
        'raster_duration_us': timing.rasterDuration.inMicroseconds,
      });
    }
  }

  void _noteTodayAnimationStarted(
    Future<void> animation, {
    required double targetPixels,
  }) {
    if (!_todayTravelArmed) return;
    _todayTravelTarget = targetPixels;
    _todayAnimationTransactionStarted = true;
    _todayOriginalAnimationActive = true;
    markDiagnosticEvent('today.animation.transaction_started');
    if (_todayHydrationTrigger != CalendarTodayHydrationTrigger.none) {
      _todayEpochFrameCallbackId = WidgetsBinding.instance
          .scheduleFrameCallback((_) {
            _todayEpochFrameCallbackId = null;
            if (!_todayTravelArmed || _todayAnimationEpochPrimed) return;
            _todayAnimationEpochPrimed = true;
            final tickerEpoch = FlutterTimeline.now;
            _todayTickerEpochMonotonicUs = tickerEpoch;
            _todayAnimationWallClock = Stopwatch()..start();
            final requested = todayRequestedHydrationElapsed;
            _todayRequestedHydrationElapsed = requested;
            if (requested == null) return;
            _todayTimerDeadlineMonotonicUs =
                tickerEpoch + requested.inMicroseconds;
            markDiagnosticEvent(
              'today.ticker_epoch_frame_callback',
              details: <String, Object?>{
                'requested_elapsed_us': requested.inMicroseconds,
                'timer_deadline_monotonic_us': _todayTimerDeadlineMonotonicUs,
              },
            );
            _todayHydrationTimer = Timer(requested, () {
              final callbackEntry = FlutterTimeline.now;
              _todayTimerCallbackEntryMonotonicUs = callbackEntry;
              markDiagnosticEvent(
                'today.timer.callback_entry',
                details: <String, Object?>{
                  'timer_deadline_monotonic_us': _todayTimerDeadlineMonotonicUs,
                  'callback_lateness_us': _todayTimerCallbackLatenessUs,
                },
              );
              _todayHydrationTimer = null;
              if (!_todayTravelArmed) return;
              _commitTodayHydrationAtControlledTime();
            });
          });
      WidgetsBinding.instance.scheduleFrame();
    }
    unawaited(
      animation.whenComplete(() {
        _todayOriginalAnimationActive = false;
        _todayAnimationResolutionWallElapsed =
            _todayAnimationWallClock?.elapsed;
        _todayAnimationWallClock?.stop();
      }),
    );
  }

  void _handleTodayScroll() {
    if (!_todayTravelArmed) return;
    final state = _requireState();
    final start = _todayTravelStart;
    final target = _todayTravelTarget;
    if (start == null || target == null || start == target) return;
    final pixels = state._scrollCtrl.position.pixels;
    _todayLastScrollPixels = pixels;
    if (_todayCaptureArrival &&
        (pixels - start).abs() > precisionErrorTolerance) {
      _todayAnimationStarted = true;
    }
    if (probesEnabled) _scheduleSample();
  }

  void _noteTodayHydrationCommit() {
    _todayHydrationCommitCount++;
    if (probesEnabled) _scheduleSample();
  }

  void _handleTodayScrollingState() {
    try {
      if (!_todayTravelArmed) return;
      final position = _requireState()._scrollCtrl.position;
      if (position.isScrollingNotifier.value) {
        _todayAnimationStarted = true;
        return;
      }
      if (!_todayAnimationStarted || _todayArrivalScheduled) return;
      _todayArrivalScheduled = true;
      _captureTodayArrivalSample('A');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_todayTravelArmed || _state == null) return;
        _captureTodayArrivalSample('B');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_todayTravelArmed || _state == null) return;
          _captureTodayArrivalSample('C');
          _disarmTodayTravel();
        }, debugLabel: 'CalendarBoundaryHarness.todayArrivalC');
        WidgetsBinding.instance.scheduleFrame();
      }, debugLabel: 'CalendarBoundaryHarness.todayArrivalB');
      WidgetsBinding.instance.scheduleFrame();
    } catch (error, stackTrace) {
      _todayArrivalError = error;
      _todayArrivalStack = stackTrace.toString();
      rethrow;
    }
  }

  void _captureTodayArrivalSample(String label) {
    final state = _requireState();
    final targetObject = state._todayDayKey.currentContext?.findRenderObject();
    final viewportObject = state
        ._scrollCtrl
        .position
        .context
        .notificationContext
        ?.findRenderObject();
    double? viewportY;
    if (targetObject is RenderBox &&
        targetObject.attached &&
        viewportObject is RenderBox &&
        viewportObject.attached) {
      viewportY =
          targetObject.localToGlobal(Offset.zero).dy -
          viewportObject.localToGlobal(Offset.zero).dy;
    }
    _todayArrivalSamples.add(<String, Object?>{
      'label': label,
      'frame_timestamp_us': developer.Timeline.now,
      'scroll_pixels': state._scrollCtrl.position.pixels,
      'target_viewport_y': viewportY,
      'target_offset': todayTargetOffset,
      'last_scroll_pixels': _todayLastScrollPixels,
    });
  }

  void _disarmTodayTravel() {
    _todayHydrationTimer?.cancel();
    _todayHydrationTimer = null;
    final epochCallbackId = _todayEpochFrameCallbackId;
    if (epochCallbackId != null) {
      WidgetsBinding.instance.cancelFrameCallbackWithId(epochCallbackId);
      _todayEpochFrameCallbackId = null;
    }
    final state = _state;
    if (state != null && state._scrollCtrl.hasClients) {
      state._scrollCtrl.removeListener(_handleTodayScroll);
      if (_todayCaptureArrival) {
        state._scrollCtrl.position.isScrollingNotifier.removeListener(
          _handleTodayScrollingState,
        );
      }
    }
    _todayTravelArmed = false;
    _todayCaptureArrival = false;
  }

  void _handleBannerPublication() {
    _bannerPublicationCount++;
    markDiagnosticEvent('banner.publication');
    _scheduleSample();
  }

  void _noteRestorationSchedule() {
    if (!probesEnabled) return;
    _restorationScheduleCount++;
    markDiagnosticEvent('restoration.schedule');
    _scheduleSample();
  }

  void _noteRestorationWrite() {
    if (!probesEnabled) return;
    _restorationWriteCount++;
    markDiagnosticEvent('restoration.write');
    _scheduleSample();
  }

  void _noteHydrationSchedule() {
    if (!probesEnabled) return;
    _hydrationScheduleCount++;
    markDiagnosticEvent('hydration.schedule');
    _scheduleSample();
  }

  void _scheduleSample() {
    if (_sampleScheduled) return;
    _sampleScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sampleScheduled = false;
      final state = _state;
      if (state == null || !state.mounted || !state._scrollCtrl.hasClients) {
        return;
      }

      final anchorBox = keyForMonth(year, 2).currentContext?.findRenderObject();
      final viewportObject = state
          ._scrollCtrl
          .position
          .context
          .notificationContext
          ?.findRenderObject();
      double? anchorViewportY;
      if (anchorBox is RenderBox &&
          anchorBox.attached &&
          viewportObject is RenderBox &&
          viewportObject.attached) {
        anchorViewportY =
            anchorBox.localToGlobal(Offset.zero).dy -
            viewportObject.localToGlobal(Offset.zero).dy;
      }

      if (_samples.length >= 4096) _samples.removeAt(0);
      _samples.add(
        CalendarBoundaryFrameSample(
          frameTimestampMicros:
              WidgetsBinding.instance.currentFrameTimeStamp.inMicroseconds,
          scrollPixels: state._scrollCtrl.position.pixels,
          bodyAnchorViewportY: anchorViewportY,
          bannerMonth: state._calendarScrollCoordinator.activeBannerMonth.value,
          collectorScheduledPublications:
              state._calendarGeometryCollector.debugScheduledPublicationCount,
          collectorCommittedPublications:
              state._calendarGeometryCollector.debugPublicationCount,
          bannerPublications: _bannerPublicationCount,
          restorationSchedules: _restorationScheduleCount,
          restorationWrites: _restorationWriteCount,
          hydrationSchedules: _hydrationScheduleCount,
          pageCounts: pageCounts.toJson(),
          bodyCounts: bodyCounts.toJson(),
          bannerCounts: bannerCounts.toJson(),
        ),
      );
    }, debugLabel: 'CalendarBoundaryHarness.sample');
  }

  CalendarPageState _requireState() {
    final state = _state;
    if (state == null) {
      throw StateError('Calendar boundary harness is not mounted.');
    }
    return state;
  }

  void dispose() {
    if (_state != null) {
      throw StateError('Unmount the calendar boundary harness before dispose.');
    }
  }
}

class _CalendarBoundaryBuildProbe extends StatelessWidget {
  const _CalendarBoundaryBuildProbe({
    required this.counts,
    required this.child,
  });

  final CalendarBoundaryProbeCounts counts;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    counts.builds++;
    return child;
  }
}

class _CalendarBoundaryRenderProbe extends SingleChildRenderObjectWidget {
  const _CalendarBoundaryRenderProbe({
    required this.counts,
    required super.child,
  });

  final CalendarBoundaryProbeCounts counts;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCalendarBoundaryProbe(counts);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCalendarBoundaryProbe renderObject,
  ) {
    renderObject.counts = counts;
  }
}

class _RenderCalendarBoundaryProbe extends RenderProxyBox {
  _RenderCalendarBoundaryProbe(this._counts);

  CalendarBoundaryProbeCounts _counts;

  set counts(CalendarBoundaryProbeCounts value) => _counts = value;

  @override
  void performLayout() {
    _counts.layouts++;
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _counts.paints++;
    super.paint(context, offset);
  }
}
