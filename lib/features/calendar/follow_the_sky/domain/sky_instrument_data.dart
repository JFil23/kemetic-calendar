import 'sky_event_kind.dart';

enum SkyInstrumentFamily {
  lunarPath,
  meteorWindow,
  opposition,
  elongation,
  conjunction,
  solarThreshold,
  solarEclipse,
}

class SkyInstrumentProvenance {
  const SkyInstrumentProvenance({
    required this.source,
    required this.sourceVersion,
    required this.calculationVersion,
  });

  final String source;
  final String sourceVersion;
  final String calculationVersion;
}

class SkyInstrumentVisibility {
  const SkyInstrumentVisibility({
    required this.isLocal,
    required this.isTimeFallback,
    required this.summary,
  });

  /// True only when observer coordinates were used to calculate sky geometry.
  final bool isLocal;
  final bool isTimeFallback;
  final String summary;
}

class SkyPositionSample {
  const SkyPositionSample({
    required this.at,
    required this.azimuthDegrees,
    required this.altitudeDegrees,
  });

  final DateTime at;
  final double azimuthDegrees;
  final double altitudeDegrees;
}

sealed class SkyInstrumentData {
  const SkyInstrumentData({
    required this.family,
    required this.viewingWindowStart,
    required this.viewingWindowEnd,
    required this.provenance,
    required this.visibility,
  });

  final SkyInstrumentFamily family;
  final DateTime viewingWindowStart;
  final DateTime viewingWindowEnd;
  final SkyInstrumentProvenance provenance;
  final SkyInstrumentVisibility visibility;
}

/// Absolute civil-time domain for the observation scrubber.
///
/// Offsets are relative to [start], so a window may cross midnight without
/// collapsing into a 0–1439 minute-of-day coordinate.
class SkyViewingTimeline {
  SkyViewingTimeline({required this.start, required this.end}) {
    if (!end.isAfter(start)) {
      throw ArgumentError.value(end, 'end', 'must be after start');
    }
  }

  final DateTime start;
  final DateTime end;

  int get durationMinutes => end.difference(start).inMinutes;

  DateTime timeAtOffset(int offsetMinutes) =>
      start.add(Duration(minutes: offsetMinutes.clamp(0, durationMinutes)));

  int offsetFor(DateTime value) =>
      value.difference(start).inMinutes.clamp(0, durationMinutes);
}

final class LunarPathData extends SkyInstrumentData {
  const LunarPathData({
    required super.viewingWindowStart,
    required super.viewingWindowEnd,
    required this.rise,
    required this.transit,
    required this.set,
    required this.moonSamples,
    required this.eclipseMarkers,
    required this.phaseInstant,
    required super.provenance,
    required super.visibility,
  }) : super(family: SkyInstrumentFamily.lunarPath);

  final DateTime? rise;
  final DateTime? transit;
  final DateTime? set;
  final List<SkyPositionSample> moonSamples;
  final List<DateTime> eclipseMarkers;
  final DateTime phaseInstant;
}

final class MeteorWindowData extends SkyInstrumentData {
  const MeteorWindowData({
    required this.radiantName,
    required this.peakWindowStart,
    required this.peakWindowEnd,
    required this.estimatedZenithalHourlyRate,
    required super.provenance,
    required super.visibility,
  }) : super(
         family: SkyInstrumentFamily.meteorWindow,
         viewingWindowStart: peakWindowStart,
         viewingWindowEnd: peakWindowEnd,
       );

  final String radiantName;
  final DateTime peakWindowStart;
  final DateTime peakWindowEnd;
  final int? estimatedZenithalHourlyRate;
}

final class OppositionData extends SkyInstrumentData {
  const OppositionData({
    required this.bodyName,
    required this.closestApproach,
    required this.altitudeSamples,
    required super.viewingWindowStart,
    required super.viewingWindowEnd,
    required super.provenance,
    required super.visibility,
  }) : super(family: SkyInstrumentFamily.opposition);

  final String bodyName;
  final DateTime closestApproach;
  final List<SkyPositionSample> altitudeSamples;
}

final class ElongationData extends SkyInstrumentData {
  const ElongationData({
    required this.bodyName,
    required this.direction,
    required this.maximumElongationDegrees,
    required this.maximumAt,
    required super.viewingWindowStart,
    required super.viewingWindowEnd,
    required super.provenance,
    required super.visibility,
  }) : super(family: SkyInstrumentFamily.elongation);

  final String bodyName;
  final String direction;
  final double? maximumElongationDegrees;
  final DateTime maximumAt;
}

class SeparationSample {
  const SeparationSample({required this.at, required this.degrees});
  final DateTime at;
  final double degrees;
}

final class ConjunctionData extends SkyInstrumentData {
  const ConjunctionData({
    required this.bodyA,
    required this.bodyB,
    required this.closestApproach,
    required this.minimumSeparationDegrees,
    required this.separationSamples,
    required super.viewingWindowStart,
    required super.viewingWindowEnd,
    required super.provenance,
    required super.visibility,
  }) : super(family: SkyInstrumentFamily.conjunction);

  final String bodyA;
  final String bodyB;
  final DateTime closestApproach;
  final double? minimumSeparationDegrees;
  final List<SeparationSample> separationSamples;
}

final class SolarThresholdData extends SkyInstrumentData {
  const SolarThresholdData({
    required this.thresholdKind,
    required this.thresholdInstant,
    required this.solarSamples,
    required super.viewingWindowStart,
    required super.viewingWindowEnd,
    required super.provenance,
    required super.visibility,
  }) : super(family: SkyInstrumentFamily.solarThreshold);

  final SkyEventKind thresholdKind;
  final DateTime thresholdInstant;
  final List<SkyPositionSample> solarSamples;
}

final class SolarEclipseData extends SkyInstrumentData {
  const SolarEclipseData({
    required this.greatestEclipse,
    required this.contactInstants,
    required this.globalVisibilitySummary,
    required super.viewingWindowStart,
    required super.viewingWindowEnd,
    required super.provenance,
    required super.visibility,
  }) : super(family: SkyInstrumentFamily.solarEclipse);

  final DateTime greatestEclipse;
  final List<DateTime> contactInstants;
  final String globalVisibilitySummary;
}
