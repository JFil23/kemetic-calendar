import 'dart:math' as math;

/// Astronomy used only by the graphic. Existing copy, scheduling and tracking
/// authorities do not consume this model.
enum SkyBody { mercury, venus, mars, jupiter, saturn }

enum MeteorPeakShape { narrow, moderate, broad, plateau }

enum MeteorCharacter { low, ordinary, notable }

enum SolarEclipseType { total, annular, partial }

enum LunarEclipseType { partial, penumbral, total }

class MeteorPhysics {
  const MeteorPhysics({
    required this.constellation,
    required this.rightAscensionDegrees,
    required this.declinationDegrees,
    required this.velocityKmPerSecond,
    required this.zenithalHourlyRate,
    required this.peakShape,
    required this.halfMaximumHours,
    required this.fireballs,
    required this.trains,
  });
  final String constellation;
  final double rightAscensionDegrees, declinationDegrees, velocityKmPerSecond;
  final double zenithalHourlyRate, halfMaximumHours;
  final MeteorPeakShape peakShape;
  final MeteorCharacter fireballs, trains;
  factory MeteorPhysics.fromJson(Map<String, dynamic> j) => MeteorPhysics(
    constellation: j['constellation'] as String,
    rightAscensionDegrees: (j['rightAscensionDegrees'] as num).toDouble(),
    declinationDegrees: (j['declinationDegrees'] as num).toDouble(),
    velocityKmPerSecond: (j['velocityKmPerSecond'] as num).toDouble(),
    zenithalHourlyRate: (j['zenithalHourlyRate'] as num).toDouble(),
    peakShape: MeteorPeakShape.values.byName(j['peakShape'] as String),
    halfMaximumHours: (j['halfMaximumHours'] as num).toDouble(),
    fireballs: MeteorCharacter.values.byName(j['fireballs'] as String),
    trains: MeteorCharacter.values.byName(j['trains'] as String),
  );

  /// Typical shower envelope, not a year-specific rate prediction. Broad date
  /// uncertainty is represented by a flat maximum across the catalog window.
  double activity(double hoursFromPeak, {double uncertaintyHours = 0}) {
    final distance = math.max(0.0, hoursFromPeak.abs() - uncertaintyHours / 2);
    final exponent = peakShape == MeteorPeakShape.plateau ? 4 : 2;
    return math.exp(
      -math.ln2 * math.pow(distance / halfMaximumHours, exponent),
    );
  }

  double get streakLength => 10 + velocityKmPerSecond * 0.65;
}

class PlanetAppearance {
  const PlanetAppearance({
    required this.body,
    required this.angularDiameterArcseconds,
    required this.apparentMagnitude,
  });
  final SkyBody body;
  final double angularDiameterArcseconds, apparentMagnitude;
  // A bounded square-root scale communicates angular size without claiming
  // literal angular screen scale. 14" -> 13.5 px; 45" -> 19.4 px.
  double get visualRadius =>
      (6 + 2 * math.sqrt(angularDiameterArcseconds)).clamp(7, 20);
  double get glowOpacity =>
      (0.08 + (1 - apparentMagnitude) * 0.035).clamp(0.06, 0.28);
  factory PlanetAppearance.fromJson(Map<String, dynamic> j) => PlanetAppearance(
    body: SkyBody.values.byName(j['body'] as String),
    angularDiameterArcseconds: (j['angularDiameterArcseconds'] as num)
        .toDouble(),
    apparentMagnitude: (j['apparentMagnitude'] as num).toDouble(),
  );
}

class SolarEclipsePhysics {
  const SolarEclipsePhysics({
    required this.type,
    required this.magnitude,
    required this.lunarSolarRadiusRatio,
  });
  final SolarEclipseType type;
  final double magnitude, lunarSolarRadiusRatio;
  double get minimumCenterDistance => type == SolarEclipseType.partial
      ? math.max(0, 1 + lunarSolarRadiusRatio - 2 * magnitude)
      : 0;
  bool get hasTotality =>
      type == SolarEclipseType.total && lunarSolarRadiusRatio >= 1;
  factory SolarEclipsePhysics.fromJson(Map<String, dynamic> j) =>
      SolarEclipsePhysics(
        type: SolarEclipseType.values.byName(j['type'] as String),
        magnitude: (j['magnitude'] as num).toDouble(),
        lunarSolarRadiusRatio: (j['lunarSolarRadiusRatio'] as num).toDouble(),
      );
}

class LunarEclipsePhysics {
  const LunarEclipsePhysics({
    required this.type,
    required this.umbralMagnitude,
    required this.penumbralMagnitude,
  });
  final LunarEclipseType type;
  final double umbralMagnitude, penumbralMagnitude;
  factory LunarEclipsePhysics.fromJson(Map<String, dynamic> j) =>
      LunarEclipsePhysics(
        type: LunarEclipseType.values.byName(j['type'] as String),
        umbralMagnitude: (j['umbralMagnitude'] as num).toDouble(),
        penumbralMagnitude: (j['penumbralMagnitude'] as num).toDouble(),
      );
}

/// Sourced graphic facts. Bulk geocentric ephemerides are generated separately
/// so calendar discovery does not load them. No observer is baked into them.
class SkyGraphicAstronomy {
  const SkyGraphicAstronomy({
    required this.source,
    required this.sourceVersion,
    required this.calculationVersion,
    this.provisional = false,
    this.meteor,
    this.planets = const [],
    this.solarEclipse,
    this.lunarEclipse,
    this.elongationDegrees,
    this.elongationDirection,
    this.minimumSeparationDegrees,
    this.separations = const [],
    this.epochUtc,
  });
  final String source, sourceVersion, calculationVersion;
  final bool provisional;
  final MeteorPhysics? meteor;
  final List<PlanetAppearance> planets;
  final SolarEclipsePhysics? solarEclipse;
  final LunarEclipsePhysics? lunarEclipse;
  final double? elongationDegrees, minimumSeparationDegrees;
  final String? elongationDirection;

  /// Hour offset from catalog instant and actual separation in degrees.
  final List<List<double>> separations;
  final DateTime? epochUtc;

  Map<String, dynamic> toJson() => {
    'source': source,
    'sourceVersion': sourceVersion,
    'calculationVersion': calculationVersion,
    'provisional': provisional,
    if (meteor case final m?)
      'meteor': {
        'constellation': m.constellation,
        'rightAscensionDegrees': m.rightAscensionDegrees,
        'declinationDegrees': m.declinationDegrees,
        'velocityKmPerSecond': m.velocityKmPerSecond,
        'zenithalHourlyRate': m.zenithalHourlyRate,
        'peakShape': m.peakShape.name,
        'halfMaximumHours': m.halfMaximumHours,
        'fireballs': m.fireballs.name,
        'trains': m.trains.name,
      },
    if (planets.isNotEmpty)
      'planets': planets
          .map(
            (p) => {
              'body': p.body.name,
              'angularDiameterArcseconds': p.angularDiameterArcseconds,
              'apparentMagnitude': p.apparentMagnitude,
            },
          )
          .toList(growable: false),
    if (solarEclipse case final s?)
      'solarEclipse': {
        'type': s.type.name,
        'magnitude': s.magnitude,
        'lunarSolarRadiusRatio': s.lunarSolarRadiusRatio,
      },
    if (lunarEclipse case final l?)
      'lunarEclipse': {
        'type': l.type.name,
        'umbralMagnitude': l.umbralMagnitude,
        'penumbralMagnitude': l.penumbralMagnitude,
      },
    if (elongationDegrees != null) 'elongationDegrees': elongationDegrees,
    if (elongationDirection != null) 'elongationDirection': elongationDirection,
    if (minimumSeparationDegrees != null)
      'minimumSeparationDegrees': minimumSeparationDegrees,
    if (separations.isNotEmpty) 'separations': separations,
    if (epochUtc != null) 'epochUtc': epochUtc!.toUtc().toIso8601String(),
  };

  factory SkyGraphicAstronomy.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> map(String k) =>
        Map<String, dynamic>.from(j[k] as Map);
    List<List<double>> rows(String k) => (j[k] as List? ?? const [])
        .map(
          (r) => (r as List)
              .map((v) => (v as num).toDouble())
              .toList(growable: false),
        )
        .toList(growable: false);
    return SkyGraphicAstronomy(
      source: j['source'] as String,
      sourceVersion: j['sourceVersion'] as String,
      calculationVersion: j['calculationVersion'] as String,
      provisional: j['provisional'] as bool? ?? false,
      meteor: j['meteor'] == null
          ? null
          : MeteorPhysics.fromJson(map('meteor')),
      planets: (j['planets'] as List? ?? const [])
          .map(
            (p) =>
                PlanetAppearance.fromJson(Map<String, dynamic>.from(p as Map)),
          )
          .toList(growable: false),
      solarEclipse: j['solarEclipse'] == null
          ? null
          : SolarEclipsePhysics.fromJson(map('solarEclipse')),
      lunarEclipse: j['lunarEclipse'] == null
          ? null
          : LunarEclipsePhysics.fromJson(map('lunarEclipse')),
      elongationDegrees: (j['elongationDegrees'] as num?)?.toDouble(),
      elongationDirection: j['elongationDirection'] as String?,
      minimumSeparationDegrees: (j['minimumSeparationDegrees'] as num?)
          ?.toDouble(),
      separations: rows('separations'),
      epochUtc: j['epochUtc'] == null
          ? null
          : DateTime.parse(j['epochUtc'] as String),
    );
  }
}

class MeteorSkySample {
  const MeteorSkySample({
    required this.at,
    required this.radiantAzimuth,
    required this.radiantAltitude,
    required this.moonAltitude,
    required this.moonIllumination,
    required this.sunAltitude,
    this.moonAzimuth = 0,
    this.sunAzimuth = 0,
  });
  final DateTime at;
  final double radiantAzimuth,
      radiantAltitude,
      moonAltitude,
      moonIllumination,
      sunAltitude;
  final double moonAzimuth, sunAzimuth;
  double get moonInterference =>
      moonIllumination * math.sin(math.max(0, moonAltitude) * math.pi / 180);
  double get darkness => ((-sunAltitude - 4) / 14).clamp(0, 1);
  double get radiantQuality =>
      math.sin(math.max(0, radiantAltitude) * math.pi / 180);
  double get faintVisibility => (1 - 0.82 * moonInterference) * darkness;
  MeteorSkySample atTime(DateTime value) => MeteorSkySample(
    at: value,
    radiantAzimuth: radiantAzimuth,
    radiantAltitude: radiantAltitude,
    moonAltitude: moonAltitude,
    moonIllumination: moonIllumination,
    sunAltitude: sunAltitude,
    moonAzimuth: moonAzimuth,
    sunAzimuth: sunAzimuth,
  );
}

class SkyInstrumentAstronomy {
  const SkyInstrumentAstronomy({
    required this.facts,
    required this.anchor,
    this.peakUncertaintyHours = 0,
    this.meteorSamples = const [],
  });
  final SkyGraphicAstronomy facts;
  final DateTime anchor;
  final double peakUncertaintyHours;
  final List<MeteorSkySample> meteorSamples;

  MeteorSkySample? meteorAt(DateTime at) {
    if (meteorSamples.isEmpty) return null;
    if (!at.isAfter(meteorSamples.first.at)) return meteorSamples.first;
    for (var i = 1; i < meteorSamples.length; i++) {
      final b = meteorSamples[i];
      if (at.isAfter(b.at)) continue;
      final a = meteorSamples[i - 1];
      final f =
          at.difference(a.at).inMilliseconds /
          b.at.difference(a.at).inMilliseconds;
      double mix(double x, double y) => x + (y - x) * f;
      // Interpolate horizon unit vectors, not azimuth angles: a radiant near
      // zenith can change azimuth rapidly while moving only a small distance.
      List<double> vector(double azimuth, double altitude) {
        final az = azimuth * math.pi / 180;
        final alt = altitude * math.pi / 180;
        return [
          math.cos(alt) * math.sin(az),
          math.cos(alt) * math.cos(az),
          math.sin(alt),
        ];
      }

      ({double az, double alt}) position(
        double azA,
        double altA,
        double azB,
        double altB,
      ) {
        final av = vector(azA, altA), bv = vector(azB, altB);
        final x = mix(av[0], bv[0]),
            y = mix(av[1], bv[1]),
            z = mix(av[2], bv[2]);
        return (
          az: (math.atan2(x, y) * 180 / math.pi + 360) % 360,
          alt: math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi,
        );
      }

      final r = position(
        a.radiantAzimuth,
        a.radiantAltitude,
        b.radiantAzimuth,
        b.radiantAltitude,
      );
      final m = position(
        a.moonAzimuth,
        a.moonAltitude,
        b.moonAzimuth,
        b.moonAltitude,
      );
      final s = position(
        a.sunAzimuth,
        a.sunAltitude,
        b.sunAzimuth,
        b.sunAltitude,
      );
      return MeteorSkySample(
        at: at,
        radiantAzimuth: r.az,
        radiantAltitude: r.alt,
        moonAltitude: m.alt,
        moonAzimuth: m.az,
        sunAltitude: s.alt,
        sunAzimuth: s.az,
        moonIllumination: mix(a.moonIllumination, b.moonIllumination),
      );
    }
    return meteorSamples.last;
  }

  double activityAt(DateTime at) =>
      facts.meteor?.activity(
        at.difference(anchor).inMilliseconds / 3600000,
        uncertaintyHours: peakUncertaintyHours,
      ) ??
      0;
  double? separationAt(DateTime at) {
    final rows = facts.separations;
    if (rows.isEmpty) return facts.minimumSeparationDegrees;
    final hour = at.difference(anchor).inMilliseconds / 3600000;
    if (hour <= rows.first[0]) return rows.first[1];
    for (var i = 1; i < rows.length; i++) {
      if (hour > rows[i][0]) continue;
      final a = rows[i - 1], b = rows[i];
      return a[1] + (b[1] - a[1]) * (hour - a[0]) / (b[0] - a[0]);
    }
    return rows.last[1];
  }
}
