import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum FollowSkyTrackMode {
  fullMoonNight,
  lunarEclipse,
  meteorActivity,
  oppositionNight,
  elongationCycle,
  conjunctionApproach,
  equinoxDayNight,
  solsticeSunArc,
  solarEclipse,
}

enum FollowSkyTrackDataQuality {
  observerCalculated,
  locallyDerived,
  catalogEnvelope,
  globalTimingEnvelope,
}

@immutable
class FollowSkyTrackSample {
  const FollowSkyTrackSample({required this.at, required this.value});

  final DateTime at;
  final double value;
}

@immutable
class FollowSkyVisualState {
  const FollowSkyVisualState({
    required this.selectedAt,
    required this.trackFraction,
    required this.eventStrength,
    required this.altitudeNormalized,
    required this.separationNormalized,
    required this.daylight,
  });

  final DateTime selectedAt;
  final double trackFraction;
  final double eventStrength;

  /// -1 is below the horizon, 0 is on it, and 1 is the track's apex.
  final double altitudeNormalized;

  /// 0 is closest/together; 1 is the track's widest visible gap.
  final double separationNormalized;

  /// 0 is full night and 1 is full daylight.
  final double daylight;
}

/// The sole presentation-time authority for a Follow Sky observation.
///
/// Catalog instants remain astronomy facts. This definition instead describes
/// the visible phenomenon a person can understand by scrubbing the instrument.
@immutable
class FollowSkyTrackDefinition {
  FollowSkyTrackDefinition({
    required this.mode,
    required this.trackStart,
    required this.trackEnd,
    required this.astronomyAnchor,
    required this.experiencePeak,
    required this.visualMetric,
    required this.dataQuality,
    this.sunrise,
    this.sunset,
    this.metricSamples = const <FollowSkyTrackSample>[],
  }) {
    if (!trackEnd.isAfter(trackStart)) {
      throw ArgumentError.value(trackEnd, 'trackEnd', 'must follow trackStart');
    }
    if (experiencePeak.isBefore(trackStart) ||
        experiencePeak.isAfter(trackEnd)) {
      throw ArgumentError.value(
        experiencePeak,
        'experiencePeak',
        'must be inside the track',
      );
    }
  }

  final FollowSkyTrackMode mode;
  final DateTime trackStart;
  final DateTime trackEnd;
  final DateTime astronomyAnchor;
  final DateTime experiencePeak;
  final String visualMetric;
  final FollowSkyTrackDataQuality dataQuality;
  final DateTime? sunrise;
  final DateTime? sunset;
  final List<FollowSkyTrackSample> metricSamples;

  Duration get duration => trackEnd.difference(trackStart);
  bool get spansMultipleCivilDays => duration > const Duration(hours: 30);

  double get peakFraction => fractionFor(experiencePeak);

  DateTime timeAtFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0).toDouble();
    return trackStart.add(
      Duration(milliseconds: (duration.inMilliseconds * clamped).round()),
    );
  }

  double fractionFor(DateTime value) {
    final clamped = clamp(value);
    final span = duration.inMilliseconds;
    if (span <= 0) return 0;
    return clamped.difference(trackStart).inMilliseconds / span;
  }

  DateTime clamp(DateTime value) {
    if (value.isBefore(trackStart)) return trackStart;
    if (value.isAfter(trackEnd)) return trackEnd;
    return value;
  }

  FollowSkyVisualState stateAt(DateTime value) {
    final selected = clamp(value);
    final fraction = fractionFor(selected);
    final peakShape = _peakEnvelope(fraction);
    final sample = _sampleAt(selected);

    return switch (mode) {
      FollowSkyTrackMode.fullMoonNight => FollowSkyVisualState(
        selectedAt: selected,
        trackFraction: fraction,
        eventStrength: 1,
        altitudeNormalized: sample ?? math.sin(math.pi * fraction),
        separationNormalized: 0,
        daylight: 0,
      ),
      FollowSkyTrackMode.lunarEclipse => FollowSkyVisualState(
        selectedAt: selected,
        trackFraction: fraction,
        eventStrength: sample ?? peakShape,
        altitudeNormalized: math.sin(math.pi * fraction),
        separationNormalized: 0,
        daylight: 0,
      ),
      FollowSkyTrackMode.meteorActivity => FollowSkyVisualState(
        selectedAt: selected,
        trackFraction: fraction,
        eventStrength: sample ?? peakShape,
        altitudeNormalized: 0,
        separationNormalized: 0,
        daylight: 0,
      ),
      FollowSkyTrackMode.oppositionNight => FollowSkyVisualState(
        selectedAt: selected,
        trackFraction: fraction,
        eventStrength: 1,
        altitudeNormalized: sample ?? math.sin(math.pi * fraction),
        separationNormalized: 1,
        daylight: 0,
      ),
      FollowSkyTrackMode.elongationCycle => FollowSkyVisualState(
        selectedAt: selected,
        trackFraction: fraction,
        eventStrength: peakShape,
        altitudeNormalized: 0,
        separationNormalized: sample ?? 0.12 + peakShape * 0.88,
        daylight: 0,
      ),
      FollowSkyTrackMode.conjunctionApproach => FollowSkyVisualState(
        selectedAt: selected,
        trackFraction: fraction,
        eventStrength: peakShape,
        altitudeNormalized: 0,
        separationNormalized: sample ?? 1 - peakShape * 0.9,
        daylight: 0,
      ),
      FollowSkyTrackMode.equinoxDayNight => _solarDayState(selected, fraction),
      FollowSkyTrackMode.solsticeSunArc => FollowSkyVisualState(
        selectedAt: selected,
        trackFraction: fraction,
        eventStrength: 1,
        altitudeNormalized: sample ?? math.sin(math.pi * fraction),
        separationNormalized: 0,
        daylight: 1,
      ),
      FollowSkyTrackMode.solarEclipse => FollowSkyVisualState(
        selectedAt: selected,
        trackFraction: fraction,
        eventStrength: sample ?? peakShape,
        altitudeNormalized: 0,
        separationNormalized: 1 - (sample ?? peakShape),
        daylight: 1,
      ),
    };
  }

  FollowSkyVisualState _solarDayState(DateTime selected, double fraction) {
    final rise = sunrise;
    final set = sunset;
    if (rise == null || set == null || !set.isAfter(rise)) {
      final daylight = math.sin(math.pi * fraction).clamp(0.0, 1.0);
      return FollowSkyVisualState(
        selectedAt: selected,
        trackFraction: fraction,
        eventStrength: daylight,
        altitudeNormalized: daylight,
        separationNormalized: 0,
        daylight: daylight,
      );
    }

    const twilight = Duration(minutes: 42);
    final dawnStart = rise.subtract(twilight);
    final dawnEnd = rise.add(twilight);
    final duskStart = set.subtract(twilight);
    final duskEnd = set.add(twilight);
    final daylight = selected.isBefore(dawnStart)
        ? 0.0
        : selected.isBefore(rise)
        ? 0.55 * _durationFraction(selected, dawnStart, rise)
        : selected.isBefore(dawnEnd)
        ? 0.55 + 0.45 * _durationFraction(selected, rise, dawnEnd)
        : selected.isBefore(duskStart)
        ? 1.0
        : selected.isBefore(set)
        ? 1 - 0.45 * _durationFraction(selected, duskStart, set)
        : selected.isBefore(duskEnd)
        ? 0.55 * (1 - _durationFraction(selected, set, duskEnd))
        : 0.0;
    final altitude = selected.isBefore(rise)
        ? -(1 - _durationFraction(selected, trackStart, rise))
        : selected.isAfter(set)
        ? -_durationFraction(selected, set, trackEnd).clamp(0.0, 1.0)
        : math
              .sin(math.pi * _durationFraction(selected, rise, set))
              .clamp(0.0, 1.0);
    return FollowSkyVisualState(
      selectedAt: selected,
      trackFraction: fraction,
      eventStrength: daylight,
      altitudeNormalized: altitude,
      separationNormalized: 0,
      daylight: daylight.clamp(0.0, 1.0),
    );
  }

  double _peakEnvelope(double fraction) {
    final peak = peakFraction;
    final span = fraction <= peak
        ? math.max(peak, 0.0001)
        : math.max(1 - peak, 0.0001);
    return (1 - (fraction - peak).abs() / span).clamp(0.0, 1.0);
  }

  double? _sampleAt(DateTime selected) {
    if (metricSamples.isEmpty) return null;
    final samples = metricSamples.toList(growable: false)
      ..sort((left, right) => left.at.compareTo(right.at));
    if (!selected.isAfter(samples.first.at)) return samples.first.value;
    if (!selected.isBefore(samples.last.at)) return samples.last.value;
    for (var index = 0; index < samples.length - 1; index++) {
      final left = samples[index];
      final right = samples[index + 1];
      if (selected.isAfter(right.at)) continue;
      final fraction = _durationFraction(selected, left.at, right.at);
      return left.value + (right.value - left.value) * fraction;
    }
    return samples.last.value;
  }
}

double _durationFraction(DateTime value, DateTime start, DateTime end) {
  final span = end.difference(start).inMilliseconds;
  if (span <= 0) return 0;
  return (value.difference(start).inMilliseconds / span).clamp(0.0, 1.0);
}
