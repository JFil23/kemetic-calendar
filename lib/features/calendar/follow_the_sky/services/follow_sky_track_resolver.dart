import 'dart:math' as math;

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/follow_sky_track_definition.dart';
import '../domain/observing_place.dart';
import '../domain/sky_instrument_data.dart';
import '../domain/sky_observing_night.dart';

class FollowSkyTrackResolver {
  const FollowSkyTrackResolver();

  FollowSkyTrackDefinition resolve({
    required SkyObservingNight night,
    required SkyInstrumentData instrument,
    required ObservingPlace place,
  }) {
    tzdata.initializeTimeZones();
    return switch (instrument) {
      LunarPathData value =>
        night.companion == null
            ? _fullMoon(value, place)
            : _lunarEclipse(night, value, place),
      MeteorWindowData value => _meteor(night, value, place),
      OppositionData value => _opposition(value, place),
      ElongationData value => _elongation(value),
      ConjunctionData value => _conjunction(value),
      SolarThresholdData value =>
        value.thresholdKind.name == 'equinox'
            ? _equinox(value, place)
            : _solstice(value, place),
      SolarEclipseData value => _solarEclipse(value),
    };
  }

  FollowSkyTrackDefinition _fullMoon(LunarPathData data, ObservingPlace place) {
    final geometryAvailable =
        data.rise != null && data.transit != null && data.set != null;
    final day = _dateOnly(data.viewingWindowStart);
    final solar = _solarDay(day, place);
    final nextSolar = _solarDay(day.add(const Duration(days: 1)), place);
    final start = data.rise ?? solar.sunset;
    final end = data.set ?? nextSolar.sunrise;
    final peak = data.transit ?? _midpoint(start, end);
    final samples = _normalizedAltitudeSamples(data.moonSamples);
    return FollowSkyTrackDefinition(
      mode: FollowSkyTrackMode.fullMoonNight,
      trackStart: start,
      trackEnd: end,
      astronomyAnchor: data.phaseInstant,
      experiencePeak: peak,
      visualMetric: 'lunar altitude across the observing night',
      dataQuality: geometryAvailable
          ? FollowSkyTrackDataQuality.observerCalculated
          : FollowSkyTrackDataQuality.catalogEnvelope,
      metricSamples: samples,
    );
  }

  FollowSkyTrackDefinition _lunarEclipse(
    SkyObservingNight night,
    LunarPathData data,
    ObservingPlace place,
  ) {
    final contacts =
        data.eclipseContacts
            .where((contact) => contact.locallyVisible)
            .toList(growable: false)
          ..sort((left, right) => left.at.compareTo(right.at));
    final astronomyAnchor =
        contacts
            .where((contact) => contact.kind == LunarEclipseContactKind.maximum)
            .map((contact) => contact.at)
            .firstOrNull ??
        _wallInstant(night.companion!.primaryInstantUtc, place.ianaTimeZone);
    final start =
        data.rise ??
        (contacts.isEmpty
            ? astronomyAnchor.subtract(const Duration(hours: 2))
            : contacts.first.at);
    final end =
        data.set ??
        (contacts.isEmpty
            ? astronomyAnchor.add(const Duration(hours: 2))
            : contacts.last.at);
    return FollowSkyTrackDefinition(
      mode: FollowSkyTrackMode.lunarEclipse,
      trackStart: start,
      trackEnd: end,
      astronomyAnchor: astronomyAnchor,
      experiencePeak: astronomyAnchor.clampTo(start, end),
      visualMetric: 'Earth-shadow coverage across lunar eclipse contacts',
      dataQuality: contacts.isEmpty
          ? FollowSkyTrackDataQuality.globalTimingEnvelope
          : FollowSkyTrackDataQuality.observerCalculated,
      metricSamples: contacts.isEmpty
          ? const <FollowSkyTrackSample>[]
          : <FollowSkyTrackSample>[
              FollowSkyTrackSample(at: start, value: 0),
              ...contacts.map(
                (contact) => FollowSkyTrackSample(
                  at: contact.at,
                  value: contact.kind == LunarEclipseContactKind.maximum
                      ? 1
                      : 0,
                ),
              ),
              FollowSkyTrackSample(at: end, value: 0),
            ],
    );
  }

  FollowSkyTrackDefinition _meteor(
    SkyObservingNight night,
    MeteorWindowData data,
    ObservingPlace place,
  ) {
    final astronomyAnchor = _wallInstant(
      night.windowSource.primaryInstantUtc,
      place.ianaTimeZone,
    );
    final midpoint = _midpoint(data.peakWindowStart, data.peakWindowEnd);
    final peak = astronomyAnchor.clampTo(
      data.peakWindowStart,
      data.peakWindowEnd,
      fallback: midpoint,
    );
    return FollowSkyTrackDefinition(
      mode: FollowSkyTrackMode.meteorActivity,
      trackStart: data.peakWindowStart,
      trackEnd: data.peakWindowEnd,
      astronomyAnchor: astronomyAnchor,
      experiencePeak: peak,
      visualMetric: 'normalized observable meteor activity envelope',
      dataQuality: FollowSkyTrackDataQuality.catalogEnvelope,
    );
  }

  FollowSkyTrackDefinition _opposition(
    OppositionData data,
    ObservingPlace place,
  ) {
    final nightDay = _dateOnly(data.viewingWindowStart);
    final solar = _solarDay(nightDay, place);
    final nextSolar = _solarDay(nightDay.add(const Duration(days: 1)), place);
    final start = solar.sunset;
    final end = nextSolar.sunrise;
    final samples = _normalizedAltitudeSamples(data.altitudeSamples);
    return FollowSkyTrackDefinition(
      mode: FollowSkyTrackMode.oppositionNight,
      trackStart: start,
      trackEnd: end,
      astronomyAnchor: data.closestApproach,
      experiencePeak: _midpoint(start, end),
      visualMetric: 'planet altitude while the Sun remains opposite',
      dataQuality: samples.isEmpty
          ? FollowSkyTrackDataQuality.catalogEnvelope
          : FollowSkyTrackDataQuality.observerCalculated,
      sunrise: end,
      sunset: start,
      metricSamples: samples,
    );
  }

  FollowSkyTrackDefinition _elongation(ElongationData data) {
    final halfWindow = data.bodyName.toLowerCase().contains('venus')
        ? const Duration(days: 28)
        : const Duration(days: 14);
    return FollowSkyTrackDefinition(
      mode: FollowSkyTrackMode.elongationCycle,
      trackStart: data.maximumAt.subtract(halfWindow),
      trackEnd: data.maximumAt.add(halfWindow),
      astronomyAnchor: data.maximumAt,
      experiencePeak: data.maximumAt,
      visualMetric: 'planet-to-Sun angular separation across the apparition',
      dataQuality: FollowSkyTrackDataQuality.catalogEnvelope,
    );
  }

  FollowSkyTrackDefinition _conjunction(ConjunctionData data) {
    return FollowSkyTrackDefinition(
      mode: FollowSkyTrackMode.conjunctionApproach,
      trackStart: data.closestApproach.subtract(const Duration(days: 3)),
      trackEnd: data.closestApproach.add(const Duration(days: 3)),
      astronomyAnchor: data.closestApproach,
      experiencePeak: data.closestApproach,
      visualMetric: 'separation as the two bodies approach and part',
      dataQuality: data.separationSamples.length >= 3
          ? FollowSkyTrackDataQuality.observerCalculated
          : FollowSkyTrackDataQuality.catalogEnvelope,
    );
  }

  FollowSkyTrackDefinition _equinox(
    SolarThresholdData data,
    ObservingPlace place,
  ) {
    final day = _dateOnly(data.thresholdInstant);
    final solar = _solarDay(day, place);
    return FollowSkyTrackDefinition(
      mode: FollowSkyTrackMode.equinoxDayNight,
      trackStart: day,
      trackEnd: day.add(const Duration(days: 1)),
      astronomyAnchor: data.thresholdInstant,
      experiencePeak: solar.sunset,
      visualMetric: 'local night-to-day-to-night light state',
      dataQuality: FollowSkyTrackDataQuality.locallyDerived,
      sunrise: solar.sunrise,
      sunset: solar.sunset,
    );
  }

  FollowSkyTrackDefinition _solstice(
    SolarThresholdData data,
    ObservingPlace place,
  ) {
    final solar = _solarDay(_dateOnly(data.thresholdInstant), place);
    return FollowSkyTrackDefinition(
      mode: FollowSkyTrackMode.solsticeSunArc,
      trackStart: solar.sunrise,
      trackEnd: solar.sunset,
      astronomyAnchor: data.thresholdInstant,
      experiencePeak: solar.solarNoon,
      visualMetric: 'solar altitude across the seasonal daylight arc',
      dataQuality: FollowSkyTrackDataQuality.locallyDerived,
      sunrise: solar.sunrise,
      sunset: solar.sunset,
    );
  }

  FollowSkyTrackDefinition _solarEclipse(SolarEclipseData data) {
    final contacts = data.contactInstants.toList(growable: false)..sort();
    final start = contacts.isEmpty
        ? data.greatestEclipse.subtract(const Duration(hours: 2))
        : contacts.first;
    final end = contacts.isEmpty
        ? data.greatestEclipse.add(const Duration(hours: 2))
        : contacts.last;
    return FollowSkyTrackDefinition(
      mode: FollowSkyTrackMode.solarEclipse,
      trackStart: start,
      trackEnd: end,
      astronomyAnchor: data.greatestEclipse,
      experiencePeak: data.greatestEclipse.clampTo(start, end),
      visualMetric: 'solar-disc coverage across eclipse contacts',
      dataQuality: contacts.isEmpty
          ? FollowSkyTrackDataQuality.globalTimingEnvelope
          : FollowSkyTrackDataQuality.observerCalculated,
    );
  }

  List<FollowSkyTrackSample> _normalizedAltitudeSamples(
    List<SkyPositionSample> values,
  ) {
    if (values.isEmpty) return const <FollowSkyTrackSample>[];
    final maximum = values
        .map((sample) => sample.altitudeDegrees)
        .fold<double>(0, math.max);
    if (maximum <= 0) return const <FollowSkyTrackSample>[];
    return values
        .map(
          (sample) => FollowSkyTrackSample(
            at: sample.at,
            value: (sample.altitudeDegrees / maximum).clamp(0.0, 1.0),
          ),
        )
        .toList(growable: false);
  }

  ({DateTime sunrise, DateTime solarNoon, DateTime sunset}) _solarDay(
    DateTime day,
    ObservingPlace place,
  ) {
    final location = tz.getLocation(place.ianaTimeZone);
    final noon = tz.TZDateTime(location, day.year, day.month, day.day, 12);
    final dayOfYear = day.difference(DateTime(day.year)).inDays + 1;
    final gamma = 2 * math.pi / 365 * (dayOfYear - 1);
    final equationOfTime =
        229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));
    final declination =
        0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);
    final latitude = place.latitude * math.pi / 180;
    final zenith = 90.833 * math.pi / 180;
    final cosHour =
        (math.cos(zenith) - math.sin(latitude) * math.sin(declination)) /
        (math.cos(latitude) * math.cos(declination));
    final hourAngle = math.acos(cosHour.clamp(-1.0, 1.0)) * 180 / math.pi;
    final offsetMinutes = noon.timeZoneOffset.inMinutes;
    final noonMinutes =
        720 - 4 * place.longitude - equationOfTime + offsetMinutes;
    DateTime atMinutes(double minutes) => day.add(
      Duration(
        milliseconds: (minutes * Duration.millisecondsPerMinute).round(),
      ),
    );
    return (
      sunrise: atMinutes(noonMinutes - hourAngle * 4),
      solarNoon: atMinutes(noonMinutes),
      sunset: atMinutes(noonMinutes + hourAngle * 4),
    );
  }

  DateTime _wallInstant(DateTime instant, String timeZone) {
    final local = tz.TZDateTime.from(instant.toUtc(), tz.getLocation(timeZone));
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _midpoint(DateTime start, DateTime end) =>
      start.add(end.difference(start) ~/ 2);
}

extension on DateTime {
  DateTime clampTo(DateTime start, DateTime end, {DateTime? fallback}) {
    if (isBefore(start) || isAfter(end)) return fallback ?? _mid(start, end);
    return this;
  }

  static DateTime _mid(DateTime start, DateTime end) =>
      start.add(end.difference(start) ~/ 2);
}
