import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/calendar/calendar_banner_resolver.dart';
import 'package:mobile/features/calendar/calendar_geometry_snapshot.dart';
import 'package:mobile/features/calendar/calendar_section_index.dart';

typedef CalendarShadowFrameScheduler = void Function(void Function() callback);
typedef CalendarGeometrySnapshotReader = CalendarGeometrySnapshot? Function();
typedef CalendarScrollOffsetReader = double? Function();
typedef CalendarMonthReader = MonthRef? Function();
typedef CalendarLegacyCandidateReader =
    MonthRef? Function(CalendarShadowSampleReason reason);

/// The event that caused one passive shadow resolution.
enum CalendarShadowSampleReason { scroll, scrollEnd, geometryPublication }

/// Primary explanation assigned to a shadow/authority divergence.
///
/// The enum order is not classification precedence; precedence is frozen in
/// [_classifyDivergence] and the Phase 3 brief.
enum CalendarShadowDivergenceCategory {
  centerVsLeadingEdgePolicy,
  heriu,
  interstitialOwnership,
  legacyScrollEndBias,
  samplingCadence,
  unclassified,
}

/// One committed transition or divergence retained by the bounded trace.
final class CalendarShadowTraceEntry {
  const CalendarShadowTraceEntry({
    required this.generation,
    required this.scrollSampleSerial,
    required this.scrollOffset,
    required this.reason,
    required this.resolutionMode,
    required this.authoritativeMonth,
    required this.legacyCandidate,
    required this.shadowMonth,
    required this.isTransition,
    required this.divergenceCategory,
  });

  final int generation;
  final int scrollSampleSerial;
  final double scrollOffset;
  final CalendarShadowSampleReason reason;
  final CalendarBannerResolutionMode resolutionMode;
  final MonthRef? authoritativeMonth;
  final MonthRef? legacyCandidate;
  final MonthRef? shadowMonth;
  final bool isTransition;
  final CalendarShadowDivergenceCategory? divergenceCategory;

  bool get isDivergence => divergenceCategory != null;
}

/// Coordinator for the leading-edge banner policy and passive legacy diffing.
///
/// Inputs are sampled through readers only after a coalesced frame callback.
/// A fresh non-null result publishes through [activeBannerMonth], whose
/// listenable is the sole Phase 4 banner writer. Legacy authority is still
/// observed only for bounded diagnostics; this object does not mutate page,
/// restoration, hydration, pinch, rotation, or navigation state.
final class CalendarScrollCoordinator {
  CalendarScrollCoordinator({
    required MonthRef initialBannerMonth,
    required CalendarShadowFrameScheduler scheduleAfterFrame,
    required CalendarGeometrySnapshotReader readSnapshot,
    required CalendarScrollOffsetReader readScrollOffset,
    required CalendarMonthReader readAuthoritativeMonth,
    CalendarLegacyCandidateReader? readLegacyCandidate,
    CalendarBannerResolver? resolver,
    CalendarSectionIndex index = const CalendarSectionIndex(),
    int traceCapacity = defaultTraceCapacity,
  }) : _activeBannerMonth = ValueNotifier<MonthRef>(initialBannerMonth),
       _scheduleAfterFrame = scheduleAfterFrame,
       _readSnapshot = readSnapshot,
       _readScrollOffset = readScrollOffset,
       _readAuthoritativeMonth = readAuthoritativeMonth,
       _readLegacyCandidate = readLegacyCandidate,
       _resolver =
           resolver ??
           CalendarBannerResolver(
             deadband: defaultBannerDeadband,
             index: index,
           ),
       _index = index,
       _traceCapacity = traceCapacity {
    if (traceCapacity <= 0) {
      throw RangeError.value(
        traceCapacity,
        'traceCapacity',
        'must be positive',
      );
    }
    for (final category in CalendarShadowDivergenceCategory.values) {
      _divergenceCounts[category] = 0;
    }
  }

  static const double defaultBannerDeadband = 8;
  static const int defaultTraceCapacity = 128;
  static const double _offsetTolerance = 0.000001;

  final CalendarShadowFrameScheduler _scheduleAfterFrame;
  final CalendarGeometrySnapshotReader _readSnapshot;
  final CalendarScrollOffsetReader _readScrollOffset;
  final CalendarMonthReader _readAuthoritativeMonth;
  final CalendarLegacyCandidateReader? _readLegacyCandidate;
  final CalendarBannerResolver _resolver;
  final CalendarSectionIndex _index;
  final int _traceCapacity;
  final ValueNotifier<MonthRef> _activeBannerMonth;

  final ListQueue<CalendarShadowTraceEntry> _trace = ListQueue();
  final Map<CalendarShadowDivergenceCategory, int> _divergenceCounts = {};

  final Set<CalendarShadowSampleReason> _pendingReasons = {};
  bool _sampleScheduled = false;
  bool _disposed = false;
  int _latestScrollSampleSerial = 0;
  int _resolutionAttemptCount = 0;
  int _committedSampleCount = 0;
  int _staleGenerationRejectionCount = 0;
  int _staleScrollSerialRejectionCount = 0;
  double? _lastCommittedOffset;
  MonthRef? _shadowIncumbent;
  MonthRef? _lastCommittedShadow;
  CalendarBannerResolutionMode _lastDirectionalMode =
      CalendarBannerResolutionMode.initial;

  List<CalendarShadowTraceEntry> get trace =>
      List<CalendarShadowTraceEntry>.unmodifiable(_trace);

  /// The isolated authoritative state read by the scrolling month banner.
  ///
  /// Exposing only [ValueListenable] prevents the page from writing around the
  /// coordinator or using a banner transition as broader calendar state.
  ValueListenable<MonthRef> get activeBannerMonth => _activeBannerMonth;

  Map<CalendarShadowDivergenceCategory, int> get divergenceCounts =>
      Map<CalendarShadowDivergenceCategory, int>.unmodifiable(
        _divergenceCounts,
      );

  MonthRef? get shadowMonth => _lastCommittedShadow;

  int get latestScrollSampleSerial => _latestScrollSampleSerial;

  int get debugResolutionAttemptCount => _resolutionAttemptCount;

  int get debugCommittedSampleCount => _committedSampleCount;

  int get debugStaleGenerationRejectionCount => _staleGenerationRejectionCount;

  int get debugStaleScrollSerialRejectionCount =>
      _staleScrollSerialRejectionCount;

  void noteScroll() {
    if (_disposed) return;
    _latestScrollSampleSerial++;
    _queue(CalendarShadowSampleReason.scroll);
  }

  void noteScrollEnd() {
    if (_disposed) return;
    _latestScrollSampleSerial++;
    _queue(CalendarShadowSampleReason.scrollEnd);
  }

  void noteGeometryPublication() {
    if (_disposed) return;
    _queue(CalendarShadowSampleReason.geometryPublication);
  }

  void _queue(CalendarShadowSampleReason reason) {
    _pendingReasons.add(reason);
    if (_sampleScheduled) return;
    _sampleScheduled = true;
    _scheduleAfterFrame(_resolvePendingSample);
  }

  CalendarShadowSampleReason? _takePendingReason() {
    // Preserve a live sample when scroll end arrives before the frame flush.
    // Geometry-only work runs last because both scroll samples already read
    // the newest complete snapshot.
    for (final reason in const [
      CalendarShadowSampleReason.scroll,
      CalendarShadowSampleReason.scrollEnd,
      CalendarShadowSampleReason.geometryPublication,
    ]) {
      if (_pendingReasons.remove(reason)) return reason;
    }
    return null;
  }

  void _resolvePendingSample() {
    _sampleScheduled = false;
    if (_disposed) return;
    final reason = _takePendingReason();
    if (reason == null) return;

    final snapshot = _readSnapshot();
    final scrollOffset = _readScrollOffset();
    if (snapshot == null || scrollOffset == null || !scrollOffset.isFinite) {
      _scheduleRemainingSample();
      return;
    }

    final sampledGeneration = snapshot.generation;
    final sampledSerial = _latestScrollSampleSerial;
    final mode = _modeFor(reason, scrollOffset);
    _resolutionAttemptCount++;
    final shadow = _resolver.resolve(
      snapshot: snapshot,
      activationCoordinate: scrollOffset,
      mode: mode,
      incumbent: _shadowIncumbent,
    );
    final authoritative = _readAuthoritativeMonth();
    final legacyCandidate = _readLegacyCandidate?.call(reason);

    final currentSnapshot = _readSnapshot();
    if (currentSnapshot == null ||
        currentSnapshot.generation != sampledGeneration) {
      _staleGenerationRejectionCount++;
      _scheduleRemainingSample();
      return;
    }
    if (_latestScrollSampleSerial != sampledSerial) {
      _staleScrollSerialRejectionCount++;
      _scheduleRemainingSample();
      return;
    }

    final isTransition = _lastCommittedShadow != shadow;
    final isDivergence = authoritative != shadow;
    final divergenceCategory = isDivergence
        ? _classifyDivergence(
            snapshot: snapshot,
            scrollOffset: scrollOffset,
            reason: reason,
            authoritative: authoritative,
            legacyCandidate: legacyCandidate,
            shadow: shadow,
          )
        : null;

    _committedSampleCount++;
    _lastCommittedOffset = scrollOffset;
    _lastCommittedShadow = shadow;
    if (shadow != null) {
      _shadowIncumbent = shadow;
      if (_activeBannerMonth.value != shadow) {
        _activeBannerMonth.value = shadow;
      }
    }
    if (mode == CalendarBannerResolutionMode.scrollingTowardFuture ||
        mode == CalendarBannerResolutionMode.scrollingTowardPast) {
      _lastDirectionalMode = mode;
    }

    if (divergenceCategory != null) {
      _divergenceCounts[divergenceCategory] =
          _divergenceCounts[divergenceCategory]! + 1;
    }
    if (isTransition || isDivergence) {
      _trace.addLast(
        CalendarShadowTraceEntry(
          generation: sampledGeneration,
          scrollSampleSerial: sampledSerial,
          scrollOffset: scrollOffset,
          reason: reason,
          resolutionMode: mode,
          authoritativeMonth: authoritative,
          legacyCandidate: legacyCandidate,
          shadowMonth: shadow,
          isTransition: isTransition,
          divergenceCategory: divergenceCategory,
        ),
      );
      while (_trace.length > _traceCapacity) {
        _trace.removeFirst();
      }
    }
    _scheduleRemainingSample();
  }

  void _scheduleRemainingSample() {
    if (_disposed || _pendingReasons.isEmpty || _sampleScheduled) return;
    _sampleScheduled = true;
    _scheduleAfterFrame(_resolvePendingSample);
  }

  CalendarBannerResolutionMode _modeFor(
    CalendarShadowSampleReason reason,
    double scrollOffset,
  ) {
    final previousOffset = _lastCommittedOffset;
    if (previousOffset == null) return CalendarBannerResolutionMode.initial;
    final delta = scrollOffset - previousOffset;
    if (reason == CalendarShadowSampleReason.geometryPublication &&
        delta.abs() <= _offsetTolerance) {
      return CalendarBannerResolutionMode.geometryOnlyAtUnchangedOffset;
    }
    if (delta > _offsetTolerance) {
      return CalendarBannerResolutionMode.scrollingTowardFuture;
    }
    if (delta < -_offsetTolerance) {
      return CalendarBannerResolutionMode.scrollingTowardPast;
    }
    return _lastDirectionalMode;
  }

  CalendarShadowDivergenceCategory _classifyDivergence({
    required CalendarGeometrySnapshot snapshot,
    required double scrollOffset,
    required CalendarShadowSampleReason reason,
    required MonthRef? authoritative,
    required MonthRef? legacyCandidate,
    required MonthRef? shadow,
  }) {
    final activationOwner = snapshot.ownerAt(scrollOffset);
    final activationGeometry = activationOwner == null
        ? null
        : snapshot.geometryFor(activationOwner);
    if (activationGeometry?.activationIsInLeadingInterstitial(scrollOffset) ??
        false) {
      return CalendarShadowDivergenceCategory.interstitialOwnership;
    }
    if (authoritative?.month == CalendarSectionIndex.monthsPerYear ||
        shadow?.month == CalendarSectionIndex.monthsPerYear) {
      return CalendarShadowDivergenceCategory.heriu;
    }
    if (reason == CalendarShadowSampleReason.scrollEnd &&
        legacyCandidate != null &&
        legacyCandidate != shadow) {
      return CalendarShadowDivergenceCategory.legacyScrollEndBias;
    }
    if (legacyCandidate != null && legacyCandidate != authoritative) {
      return CalendarShadowDivergenceCategory.samplingCadence;
    }
    if (authoritative != null &&
        shadow != null &&
        _index.distance(authoritative, shadow).abs() == 1) {
      return CalendarShadowDivergenceCategory.centerVsLeadingEdgePolicy;
    }
    return CalendarShadowDivergenceCategory.unclassified;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pendingReasons.clear();
    _trace.clear();
    _activeBannerMonth.dispose();
  }
}
