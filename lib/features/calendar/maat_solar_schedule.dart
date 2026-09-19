import 'dart:math' as math;

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'track_sky_flow.dart';

const int kMaatDefaultEveningFallbackMinutes = 20 * 60;

class MaatSolarReferenceLocation {
  const MaatSolarReferenceLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

class MaatSolarOccurrenceSchedule {
  const MaatSolarOccurrenceSchedule({
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
    required this.usedFallback,
    required this.timezone,
    required this.referenceLocation,
    this.fallbackMinutesAfterMidnight,
  });

  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool usedFallback;
  final TrackSkyTimeZone timezone;
  final MaatSolarReferenceLocation referenceLocation;
  final int? fallbackMinutesAfterMidnight;
}

class MaatDailyOccurrenceSchedule {
  const MaatDailyOccurrenceSchedule({
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
    required this.usedFallback,
    required this.timezone,
    required this.referenceLocationName,
    required this.scheduleType,
    required this.fallback,
    this.middayHour,
    this.middayMinute,
  });

  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool usedFallback;
  final TrackSkyTimeZone timezone;
  final String referenceLocationName;
  final String scheduleType;
  final String fallback;
  final int? middayHour;
  final int? middayMinute;
}

const Map<TrackSkyTimeZone, MaatSolarReferenceLocation>
kMaatSolarReferenceLocations = <TrackSkyTimeZone, MaatSolarReferenceLocation>{
  TrackSkyTimeZone.pacific: MaatSolarReferenceLocation(
    name: 'Los Angeles',
    latitude: 34.0522,
    longitude: -118.2437,
  ),
  TrackSkyTimeZone.mountain: MaatSolarReferenceLocation(
    name: 'Denver',
    latitude: 39.7392,
    longitude: -104.9903,
  ),
  TrackSkyTimeZone.central: MaatSolarReferenceLocation(
    name: 'Chicago',
    latitude: 41.8781,
    longitude: -87.6298,
  ),
  TrackSkyTimeZone.eastern: MaatSolarReferenceLocation(
    name: 'New York',
    latitude: 40.7128,
    longitude: -74.0060,
  ),
};

bool _maatSolarTimeZonesInitialized = false;

void _ensureMaatSolarTimeZonesInitialized() {
  if (_maatSolarTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _maatSolarTimeZonesInitialized = true;
}

DateTime maatNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureMaatSolarTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromZonedDateTime(zoned);
}

MaatSolarOccurrenceSchedule maatDawnScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  int durationMinutes = 3,
}) {
  _ensureMaatSolarTimeZonesInitialized();
  final localDate = DateTime(date.year, date.month, date.day);
  final reference = kMaatSolarReferenceLocations[timezone]!;
  final astronomicalDawnUtc = _solarRisingUtc(
    localDate,
    reference,
    zenithDegrees: 108,
  );
  final sunriseUtc = _solarRisingUtc(
    localDate,
    reference,
    zenithDegrees: 90.833,
  );
  final startUtc =
      astronomicalDawnUtc ??
      sunriseUtc?.subtract(const Duration(minutes: 15)) ??
      tz.TZDateTime(
        tz.getLocation(timezone.ianaName),
        localDate.year,
        localDate.month,
        localDate.day,
        6,
      ).toUtc();
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return MaatSolarOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: astronomicalDawnUtc == null,
    timezone: timezone,
    referenceLocation: reference,
  );
}

MaatSolarOccurrenceSchedule maatSunsetScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  int durationMinutes = 3,
  int minutesAfterSunset = 20,
  int fallbackMinutesAfterMidnight = kMaatDefaultEveningFallbackMinutes,
}) {
  _ensureMaatSolarTimeZonesInitialized();
  final localDate = DateTime(date.year, date.month, date.day);
  final reference = kMaatSolarReferenceLocations[timezone]!;
  final sunsetUtc = _solarSettingUtc(
    localDate,
    reference,
    timezone: timezone,
    zenithDegrees: 90.833,
  );
  final location = tz.getLocation(timezone.ianaName);
  final fallbackHour = fallbackMinutesAfterMidnight ~/ 60;
  final fallbackMinute = fallbackMinutesAfterMidnight % 60;
  final fallbackStartUtc = tz.TZDateTime(
    location,
    localDate.year,
    localDate.month,
    localDate.day,
    fallbackHour,
    fallbackMinute,
  ).toUtc();
  final startUtc =
      sunsetUtc?.add(Duration(minutes: minutesAfterSunset)) ?? fallbackStartUtc;
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  return MaatSolarOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: sunsetUtc == null,
    timezone: timezone,
    referenceLocation: reference,
    fallbackMinutesAfterMidnight: fallbackMinutesAfterMidnight,
  );
}

MaatDailyOccurrenceSchedule maatMorningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = maatDawnScheduleForDate(date, timezone);
  final startUtc = base.startUtc.add(const Duration(minutes: 30));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return MaatDailyOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: base.usedFallback,
    timezone: timezone,
    referenceLocationName: base.referenceLocation.name,
    scheduleType: 'local_astronomical_dawn_plus_30_minutes',
    fallback: 'sunrise_minus_15_minutes_plus_30_minutes',
  );
}

MaatDailyOccurrenceSchedule maatMiddayScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
  required int hour,
  required int minute,
}) {
  _ensureMaatSolarTimeZonesInitialized();
  final localDate = DateTime(date.year, date.month, date.day);
  final location = tz.getLocation(timezone.ianaName);
  final clampedHour = hour.clamp(0, 23).toInt();
  final clampedMinute = minute.clamp(0, 59).toInt();
  final startUtc = tz.TZDateTime(
    location,
    localDate.year,
    localDate.month,
    localDate.day,
    clampedHour,
    clampedMinute,
  ).toUtc();
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  return MaatDailyOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: false,
    timezone: timezone,
    referenceLocationName: timezone.label,
    scheduleType: 'fixed_local_midday',
    fallback: 'user_editable_local_time',
    middayHour: clampedHour,
    middayMinute: clampedMinute,
  );
}

MaatDailyOccurrenceSchedule maatEveningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = maatSunsetScheduleForDate(
    date,
    timezone,
    fallbackMinutesAfterMidnight: kMaatDefaultEveningFallbackMinutes + 20,
  );
  final startUtc = base.startUtc.add(const Duration(minutes: 10));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return MaatDailyOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: base.usedFallback,
    timezone: timezone,
    referenceLocationName: base.referenceLocation.name,
    scheduleType: 'local_sunset_plus_30_minutes',
    fallback: 'user_selected_evening_time_plus_30_minutes',
  );
}

DateTime? _solarRisingUtc(
  DateTime localDate,
  MaatSolarReferenceLocation location, {
  required double zenithDegrees,
}) {
  final dayOfYear =
      localDate.difference(DateTime(localDate.year, 1, 1)).inDays + 1;
  final lngHour = location.longitude / 15.0;
  final approximateTime = dayOfYear + ((6.0 - lngHour) / 24.0);
  final meanAnomaly = (0.9856 * approximateTime) - 3.289;
  final trueLongitude = _normalizeDegrees(
    meanAnomaly +
        (1.916 * math.sin(_degreesToRadians(meanAnomaly))) +
        (0.020 * math.sin(_degreesToRadians(2 * meanAnomaly))) +
        282.634,
  );
  var rightAscension = _radiansToDegrees(
    math.atan(0.91764 * math.tan(_degreesToRadians(trueLongitude))),
  );
  rightAscension = _normalizeDegrees(rightAscension);
  final longitudeQuadrant = (trueLongitude / 90).floor() * 90;
  final ascensionQuadrant = (rightAscension / 90).floor() * 90;
  rightAscension =
      (rightAscension + longitudeQuadrant - ascensionQuadrant) / 15;
  final sinDeclination = 0.39782 * math.sin(_degreesToRadians(trueLongitude));
  final cosDeclination = math.cos(math.asin(sinDeclination));
  final latitudeRadians = _degreesToRadians(location.latitude);
  final cosHourAngle =
      (math.cos(_degreesToRadians(zenithDegrees)) -
          (sinDeclination * math.sin(latitudeRadians))) /
      (cosDeclination * math.cos(latitudeRadians));
  if (cosHourAngle.isNaN || cosHourAngle < -1 || cosHourAngle > 1) {
    return null;
  }
  final hourAngle = (360 - _radiansToDegrees(math.acos(cosHourAngle))) / 15.0;
  final localMeanTime =
      hourAngle + rightAscension - (0.06571 * approximateTime) - 6.622;
  final utcHour = _normalizeHours(localMeanTime - lngHour);
  final minutes = (utcHour * 60).round();
  return DateTime.utc(
    localDate.year,
    localDate.month,
    localDate.day,
  ).add(Duration(minutes: minutes));
}

DateTime? _solarSettingUtc(
  DateTime localDate,
  MaatSolarReferenceLocation location, {
  required TrackSkyTimeZone timezone,
  required double zenithDegrees,
}) {
  final dayOfYear =
      localDate.difference(DateTime(localDate.year, 1, 1)).inDays + 1;
  final lngHour = location.longitude / 15.0;
  final approximateTime = dayOfYear + ((18.0 - lngHour) / 24.0);
  final meanAnomaly = (0.9856 * approximateTime) - 3.289;
  final trueLongitude = _normalizeDegrees(
    meanAnomaly +
        (1.916 * math.sin(_degreesToRadians(meanAnomaly))) +
        (0.020 * math.sin(_degreesToRadians(2 * meanAnomaly))) +
        282.634,
  );
  var rightAscension = _radiansToDegrees(
    math.atan(0.91764 * math.tan(_degreesToRadians(trueLongitude))),
  );
  rightAscension = _normalizeDegrees(rightAscension);
  final longitudeQuadrant = (trueLongitude / 90).floor() * 90;
  final ascensionQuadrant = (rightAscension / 90).floor() * 90;
  rightAscension =
      (rightAscension + longitudeQuadrant - ascensionQuadrant) / 15;
  final sinDeclination = 0.39782 * math.sin(_degreesToRadians(trueLongitude));
  final cosDeclination = math.cos(math.asin(sinDeclination));
  final latitudeRadians = _degreesToRadians(location.latitude);
  final cosHourAngle =
      (math.cos(_degreesToRadians(zenithDegrees)) -
          (sinDeclination * math.sin(latitudeRadians))) /
      (cosDeclination * math.cos(latitudeRadians));
  if (cosHourAngle.isNaN || cosHourAngle < -1 || cosHourAngle > 1) {
    return null;
  }
  final hourAngle = _radiansToDegrees(math.acos(cosHourAngle)) / 15.0;
  final localMeanTime =
      hourAngle + rightAscension - (0.06571 * approximateTime) - 6.622;
  final utcHour = _normalizeHours(localMeanTime - lngHour);
  final minutes = (utcHour * 60).round();
  final candidate = DateTime.utc(
    localDate.year,
    localDate.month,
    localDate.day,
  ).add(Duration(minutes: minutes));
  return _alignUtcCandidateToLocalDate(candidate, localDate, timezone);
}

DateTime _alignUtcCandidateToLocalDate(
  DateTime candidateUtc,
  DateTime localDate,
  TrackSkyTimeZone timezone,
) {
  final location = tz.getLocation(timezone.ianaName);
  final targetDate = DateTime(localDate.year, localDate.month, localDate.day);
  var aligned = candidateUtc;
  for (var i = 0; i < 3; i++) {
    final local = tz.TZDateTime.from(aligned, location);
    final candidateLocalDate = DateTime(local.year, local.month, local.day);
    final comparison = candidateLocalDate.compareTo(targetDate);
    if (comparison == 0) return aligned;
    aligned = comparison < 0
        ? aligned.add(const Duration(days: 1))
        : aligned.subtract(const Duration(days: 1));
  }
  return aligned;
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;
double _radiansToDegrees(double radians) => radians * 180.0 / math.pi;

double _normalizeDegrees(double degrees) {
  final normalized = degrees % 360.0;
  return normalized < 0 ? normalized + 360.0 : normalized;
}

double _normalizeHours(double hours) {
  final normalized = hours % 24.0;
  return normalized < 0 ? normalized + 24.0 : normalized;
}

DateTime _fromZonedDateTime(tz.TZDateTime zoned) {
  return DateTime(
    zoned.year,
    zoned.month,
    zoned.day,
    zoned.hour,
    zoned.minute,
    zoned.second,
    zoned.millisecond,
    zoned.microsecond,
  );
}
