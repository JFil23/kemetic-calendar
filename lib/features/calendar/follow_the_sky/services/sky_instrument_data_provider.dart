import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/observing_place.dart';
import '../domain/sky_event.dart';
import '../domain/sky_instrument_data.dart';
import '../domain/sky_observing_night.dart';
import 'instrument_family_resolver.dart';
import 'sky_observation_window_policy.dart';

abstract interface class SkyInstrumentDataProvider {
  Future<SkyInstrumentData> resolve({
    required SkyObservingNight night,
    required ObservingPlace? place,
  });
}

/// Catalog-backed deterministic presentation data.
///
/// It intentionally does not claim observer-specific ephemeris accuracy. A
/// later astronomy engine can implement [SkyInstrumentDataProvider] without
/// changing the sheet or domain models.
class CatalogSkyInstrumentDataProvider implements SkyInstrumentDataProvider {
  const CatalogSkyInstrumentDataProvider({
    this.familyResolver = const InstrumentFamilyResolver(),
    this.windowPolicy = const SkyObservationWindowPolicy(),
  });

  static const String calculationVersion = 'catalog-window-v1';
  final InstrumentFamilyResolver familyResolver;
  final SkyObservationWindowPolicy windowPolicy;

  @override
  Future<SkyInstrumentData> resolve({
    required SkyObservingNight night,
    required ObservingPlace? place,
  }) async {
    tzdata.initializeTimeZones();
    final locationResolution = _locationFor(place?.ianaTimeZone);
    final location = locationResolution.location;
    final event = night.windowSource;
    final instant = tz.TZDateTime.from(event.primaryInstantUtc, location);
    final window = windowPolicy.resolve(
      event: event,
      ianaTimeZone: location.name,
      toLocal: (utc, _) => tz.TZDateTime.from(utc.toUtc(), location),
    );
    final provenance = SkyInstrumentProvenance(
      source: event.source,
      sourceVersion: event.sourceVersion,
      calculationVersion: calculationVersion,
    );
    final visibility = SkyInstrumentVisibility(
      // The catalog fallback never uses latitude/longitude for geometry.
      isLocal: false,
      isTimeFallback: locationResolution.isFallback,
      summary: locationResolution.isFallback
          ? 'Time zone unavailable · using UTC · sky position unavailable'
          : place == null
          ? 'Local time · sky position unavailable'
          : 'Local time for ${place.label} · sky position unavailable',
    );
    final family = familyResolver.resolve(night);

    return switch (family) {
      SkyInstrumentFamily.lunarPath => _lunar(
        instant,
        window.startLocal,
        window.endLocal,
        provenance,
        visibility,
      ),
      SkyInstrumentFamily.meteorWindow => _meteor(
        event,
        location,
        instant,
        window.startLocal,
        window.endLocal,
        provenance,
        visibility,
      ),
      SkyInstrumentFamily.opposition => _opposition(
        event,
        instant,
        window.startLocal,
        window.endLocal,
        provenance,
        visibility,
      ),
      SkyInstrumentFamily.elongation => _elongation(
        event,
        instant,
        window.startLocal,
        window.endLocal,
        provenance,
        visibility,
      ),
      SkyInstrumentFamily.conjunction => _conjunction(
        event,
        instant,
        window.startLocal,
        window.endLocal,
        provenance,
        visibility,
      ),
      SkyInstrumentFamily.solarThreshold => _solarThreshold(
        event,
        instant,
        window.startLocal,
        window.endLocal,
        provenance,
        visibility,
      ),
      SkyInstrumentFamily.solarEclipse => _solarEclipse(
        event,
        instant,
        window.startLocal,
        window.endLocal,
        provenance,
        visibility,
      ),
    };
  }

  ({tz.Location location, bool isFallback}) _locationFor(String? iana) {
    if (iana == null || iana.trim().isEmpty) {
      return (location: tz.local, isFallback: false);
    }
    try {
      return (location: tz.getLocation(iana.trim()), isFallback: false);
    } on Object {
      return (location: tz.UTC, isFallback: true);
    }
  }

  LunarPathData _lunar(
    DateTime instant,
    DateTime viewingStart,
    DateTime viewingEnd,
    SkyInstrumentProvenance provenance,
    SkyInstrumentVisibility visibility,
  ) {
    return LunarPathData(
      viewingWindowStart: viewingStart,
      viewingWindowEnd: viewingEnd,
      rise: null,
      transit: null,
      set: null,
      moonSamples: const <SkyPositionSample>[],
      eclipseMarkers: const <DateTime>[],
      phaseInstant: instant,
      provenance: provenance,
      visibility: visibility,
    );
  }

  MeteorWindowData _meteor(
    SkyEvent event,
    tz.Location location,
    DateTime instant,
    DateTime viewingStart,
    DateTime viewingEnd,
    SkyInstrumentProvenance provenance,
    SkyInstrumentVisibility visibility,
  ) {
    final peak = event.peakWindowUtc;
    final start = peak == null
        ? viewingStart
        : tz.TZDateTime.from(peak.startUtc, location);
    final end = peak == null
        ? viewingEnd
        : tz.TZDateTime.from(peak.endUtc, location);
    return MeteorWindowData(
      radiantName: event.name,
      peakWindowStart: start,
      peakWindowEnd: end,
      estimatedZenithalHourlyRate: null,
      provenance: provenance,
      visibility: visibility,
    );
  }

  OppositionData _opposition(
    SkyEvent event,
    DateTime instant,
    DateTime viewingStart,
    DateTime viewingEnd,
    SkyInstrumentProvenance provenance,
    SkyInstrumentVisibility visibility,
  ) {
    return OppositionData(
      bodyName: event.name.replaceAll(' Opposition', ''),
      closestApproach: instant,
      altitudeSamples: const <SkyPositionSample>[],
      viewingWindowStart: viewingStart,
      viewingWindowEnd: viewingEnd,
      provenance: provenance,
      visibility: visibility,
    );
  }

  ElongationData _elongation(
    SkyEvent event,
    DateTime instant,
    DateTime viewingStart,
    DateTime viewingEnd,
    SkyInstrumentProvenance provenance,
    SkyInstrumentVisibility visibility,
  ) {
    final western = event.name.toLowerCase().contains('western');
    return ElongationData(
      bodyName: event.name.split(' ').first,
      direction: western ? 'western' : 'eastern',
      maximumElongationDegrees: null,
      maximumAt: instant,
      viewingWindowStart: viewingStart,
      viewingWindowEnd: viewingEnd,
      provenance: provenance,
      visibility: visibility,
    );
  }

  ConjunctionData _conjunction(
    SkyEvent event,
    DateTime instant,
    DateTime viewingStart,
    DateTime viewingEnd,
    SkyInstrumentProvenance provenance,
    SkyInstrumentVisibility visibility,
  ) {
    final names = event.name.replaceAll(' Conjunction', '').split('/');
    final minimumSeparation = _separationFromNotes(event.notes);
    return ConjunctionData(
      bodyA: names.first.trim(),
      bodyB: names.length > 1 ? names[1].trim() : 'companion',
      closestApproach: instant,
      minimumSeparationDegrees: minimumSeparation,
      separationSamples: <SeparationSample>[
        if (minimumSeparation != null)
          SeparationSample(at: instant, degrees: minimumSeparation),
      ],
      viewingWindowStart: viewingStart,
      viewingWindowEnd: viewingEnd,
      provenance: provenance,
      visibility: visibility,
    );
  }

  SolarThresholdData _solarThreshold(
    SkyEvent event,
    DateTime instant,
    DateTime viewingStart,
    DateTime viewingEnd,
    SkyInstrumentProvenance provenance,
    SkyInstrumentVisibility visibility,
  ) {
    return SolarThresholdData(
      thresholdKind: event.kind,
      thresholdInstant: instant,
      solarSamples: const <SkyPositionSample>[],
      viewingWindowStart: viewingStart,
      viewingWindowEnd: viewingEnd,
      provenance: provenance,
      visibility: visibility,
    );
  }

  SolarEclipseData _solarEclipse(
    SkyEvent event,
    DateTime instant,
    DateTime viewingStart,
    DateTime viewingEnd,
    SkyInstrumentProvenance provenance,
    SkyInstrumentVisibility visibility,
  ) {
    return SolarEclipseData(
      greatestEclipse: instant,
      contactInstants: const <DateTime>[],
      globalVisibilitySummary: event.notes?.trim().isNotEmpty == true
          ? event.notes!.trim()
          : 'Global greatest-eclipse timing; local visibility may differ.',
      viewingWindowStart: viewingStart,
      viewingWindowEnd: viewingEnd,
      provenance: provenance,
      visibility: visibility,
    );
  }

  double? _separationFromNotes(String? notes) {
    final match = RegExp(r'~([0-9]+(?:\.[0-9]+)?)°').firstMatch(notes ?? '');
    return match == null ? null : double.tryParse(match.group(1)!);
  }
}
