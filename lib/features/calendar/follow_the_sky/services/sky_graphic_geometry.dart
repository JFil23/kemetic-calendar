import 'dart:math' as math;
import 'package:timezone/timezone.dart' as tz;
import '../domain/observing_place.dart';
import 'sky_graphic_ephemeris.g.dart';
import '../domain/sky_event.dart';
import '../domain/sky_graphic_astronomy.dart';

/// Converts the pinned engine's EQD samples to the actual observer's horizon.
/// Geometric altitude (no atmospheric refraction); WGS84 topocentric parallax
/// is applied to nearby bodies. Sampling and interpolation affect graphics only.
SkyInstrumentAstronomy? resolveSkyGraphicAstronomy(
  SkyEvent event,
  ObservingPlace? place,
) {
  final facts = event.graphicAstronomy;
  if (facts == null) return null;
  final location = place == null ? tz.UTC : _zone(place.ianaTimeZone);
  final samples = <MeteorSkySample>[];
  final meteor = facts.meteor;
  final epoch = facts.epochUtc;
  if (place != null && meteor != null && epoch != null) {
    final ra = meteor.rightAscensionDegrees * math.pi / 180;
    final dec = meteor.declinationDegrees * math.pi / 180;
    final radiant = [
      math.cos(dec) * math.cos(ra),
      math.cos(dec) * math.sin(ra),
      math.sin(dec),
    ];
    for (final row
        in meteorGraphicEphemerides[event.id] ?? const <List<double>>[]) {
      final at = tz.TZDateTime.from(
        epoch.add(Duration(milliseconds: (row[0] * 3600000).round())),
        location,
      );
      final r = graphicHorizon(radiant, row[1], place, parallax: false);
      final m = graphicHorizon(row.sublist(2, 5), row[1], place);
      final s = graphicHorizon(row.sublist(6, 9), row[1], place);
      samples.add(
        MeteorSkySample(
          at: at,
          radiantAzimuth: r.azimuth,
          radiantAltitude: r.altitude,
          moonAltitude: m.altitude,
          moonAzimuth: m.azimuth,
          sunAzimuth: s.azimuth,
          moonIllumination: row[5],
          sunAltitude: s.altitude,
        ),
      );
    }
  }
  return SkyInstrumentAstronomy(
    facts: facts,
    anchor: tz.TZDateTime.from(event.primaryInstantUtc, location),
    peakUncertaintyHours: event.peakWindowUtc == null
        ? 0
        : event.peakWindowUtc!.endUtc
                  .difference(event.peakWindowUtc!.startUtc)
                  .inSeconds /
              3600,
    meteorSamples: List.unmodifiable(samples),
  );
}

tz.Location _zone(String name) {
  try {
    return tz.getLocation(name);
  } on Object {
    return tz.UTC;
  }
}

({double azimuth, double altitude}) graphicHorizon(
  List<double> eqd,
  double gastDegrees,
  ObservingPlace place, {
  bool parallax = true,
}) {
  final lat = place.latitude * math.pi / 180;
  final lst = (gastDegrees + place.longitude) * math.pi / 180;
  final sl = math.sin(lat),
      cl = math.cos(lat),
      st = math.sin(lst),
      ct = math.cos(lst);
  const eccentricitySquared = 0.00669437999014;
  const auKm = 149597870.7;
  final normal = 6378.137 / math.sqrt(1 - eccentricitySquared * sl * sl);
  final elevation = (place.elevationMeters ?? 0) / 1000;
  final x = eqd[0] - (parallax ? (normal + elevation) * cl * ct / auKm : 0);
  final y = eqd[1] - (parallax ? (normal + elevation) * cl * st / auKm : 0);
  final z =
      eqd[2] -
      (parallax
          ? (normal * (1 - eccentricitySquared) + elevation) * sl / auKm
          : 0);
  final east = -st * x + ct * y;
  final north = -sl * ct * x - sl * st * y + cl * z;
  final up = cl * ct * x + cl * st * y + sl * z;
  return (
    azimuth: (math.atan2(east, north) * 180 / math.pi + 360) % 360,
    altitude:
        math.atan2(up, math.sqrt(east * east + north * north)) * 180 / math.pi,
  );
}
