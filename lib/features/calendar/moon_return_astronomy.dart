import 'dart:math' as math;

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dawn_house_rite_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'moon_return_flow.dart';
import 'track_sky_flow.dart';

const double _kSynodicMonthDays = 29.530588853;
final DateTime _kKnownNewMoonUtc = DateTime.utc(2000, 1, 6, 18, 14);

bool _moonReturnTimeZonesInitialized = false;

void _ensureMoonReturnTimeZonesInitialized() {
  if (_moonReturnTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _moonReturnTimeZonesInitialized = true;
}

DateTime moonReturnNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureMoonReturnTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromZonedDateTime(zoned);
}

DateTime moonReturnDefaultStartDate(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final window = moonReturnNextEnrollmentWindow(timezone, now: now);
  return _dateOnly(window.opensAtLocal);
}

MoonReturnEnrollmentWindow moonReturnNextEnrollmentWindow(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = moonReturnNowInZone(timezone, now: now);
  final fromUtc = (now ?? DateTime.now()).toUtc().subtract(
    const Duration(days: 4),
  );
  final phases = _moonPhasesBetween(
    fromUtc: fromUtc,
    toUtc: fromUtc.add(const Duration(days: 430)),
    timezone: timezone,
  ).where((phase) => phase.kind == MoonReturnEventKind.emptyEye);
  for (final phase in phases) {
    final window = _windowForNewMoonPhase(phase, timezone);
    if (!window.closesAtLocal.isBefore(nowLocal)) return window;
  }
  throw StateError('No Moon Return enrollment window found.');
}

MoonReturnEnrollmentWindow? resolveMoonReturnEnrollmentWindowSafely({
  required TrackSkyTimeZone timezone,
  DateTime? startDate,
  DateTime? now,
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  try {
    if (startDate == null) {
      return moonReturnNextEnrollmentWindow(timezone, now: now);
    }
    return moonReturnEnrollmentWindowForStartDate(
      startDate,
      timezone,
      now: now,
    );
  } catch (error, stackTrace) {
    onError?.call(error, stackTrace);
    return null;
  }
}

MoonReturnEnrollmentWindow? moonReturnCurrentEnrollmentWindow(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = moonReturnNowInZone(timezone, now: now);
  for (final window in moonReturnUpcomingEnrollmentWindows(
    timezone,
    now: now,
    count: 2,
    includeRecentlyClosed: true,
  )) {
    if (!nowLocal.isBefore(window.opensAtLocal) &&
        !nowLocal.isAfter(window.closesAtLocal)) {
      return window;
    }
  }
  return null;
}

bool moonReturnEnrollmentIsOpen(
  MoonReturnEnrollmentWindow window, {
  DateTime? now,
}) {
  final nowLocal = moonReturnNowInZone(window.timezone, now: now);
  return !nowLocal.isBefore(window.opensAtLocal) &&
      !nowLocal.isAfter(window.closesAtLocal);
}

List<MoonReturnEnrollmentWindow> moonReturnUpcomingEnrollmentWindows(
  TrackSkyTimeZone timezone, {
  DateTime? now,
  int count = 12,
  bool includeRecentlyClosed = false,
}) {
  final nowLocal = moonReturnNowInZone(timezone, now: now);
  final fromUtc = (now ?? DateTime.now()).toUtc().subtract(
    includeRecentlyClosed ? const Duration(days: 35) : const Duration(days: 4),
  );
  final phases = _moonPhasesBetween(
    fromUtc: fromUtc,
    toUtc: fromUtc.add(Duration(days: math.max(430, count * 35))),
    timezone: timezone,
  ).where((phase) => phase.kind == MoonReturnEventKind.emptyEye);
  final windows = <MoonReturnEnrollmentWindow>[];
  for (final phase in phases) {
    final window = _windowForNewMoonPhase(phase, timezone);
    if (includeRecentlyClosed || !window.closesAtLocal.isBefore(nowLocal)) {
      windows.add(window);
      if (windows.length >= count) break;
    }
  }
  return windows;
}

MoonReturnEnrollmentWindow? moonReturnEnrollmentWindowForStartDate(
  DateTime startDate,
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final selected = _dateOnly(startDate);
  for (final window in moonReturnUpcomingEnrollmentWindows(
    timezone,
    now: now,
    count: 18,
    includeRecentlyClosed: true,
  )) {
    if (_sameDate(_dateOnly(window.opensAtLocal), selected)) return window;
    if (_sameDate(_dateOnly(window.newMoonInstantLocal), selected)) {
      return window;
    }
  }
  return null;
}

List<MoonReturnOccurrence> moonReturnOccurrencesForWindow({
  required MoonReturnEnrollmentWindow window,
  int horizonMonths = 12,
}) {
  final fromUtc = window.newMoonInstantUtc.subtract(const Duration(days: 1));
  final toUtc = window.newMoonInstantUtc.add(
    Duration(days: math.max(31, horizonMonths * 31)),
  );
  final phases = _moonPhasesBetween(
    fromUtc: fromUtc,
    toUtc: toUtc,
    timezone: window.timezone,
  ).toList()..sort((a, b) => a.instantUtc.compareTo(b.instantUtc));
  final blueMoonCheckPhases = _moonPhasesBetween(
    fromUtc: fromUtc.subtract(const Duration(days: 35)),
    toUtc: toUtc,
    timezone: window.timezone,
  ).toList()..sort((a, b) => a.instantUtc.compareTo(b.instantUtc));
  final firstFullByMonth = <String, _MoonPhaseInstant>{};
  for (final full in blueMoonCheckPhases.where(
    (phase) => phase.kind == MoonReturnEventKind.wholeEye,
  )) {
    final key = '${full.instantLocal.year}-${full.instantLocal.month}';
    firstFullByMonth.putIfAbsent(key, () => full);
  }

  final result = <MoonReturnOccurrence>[];
  for (final phase in phases) {
    if (phase.kind == MoonReturnEventKind.emptyEye) {
      result.add(_newMoonOccurrence(phase, window.timezone));
      continue;
    }

    final monthKey = '${phase.instantLocal.year}-${phase.instantLocal.month}';
    final firstFull = firstFullByMonth[monthKey];
    final isBlueMoon =
        firstFull != null &&
        !_sameDate(
          _dateOnly(firstFull.instantLocal),
          _dateOnly(phase.instantLocal),
        );
    if (isBlueMoon && window.opensAtLocal.isAfter(firstFull.instantLocal)) {
      continue;
    }
    result.add(
      _fullMoonOccurrence(phase, window.timezone, isBonusBlueMoon: isBlueMoon),
    );
  }
  result.sort((a, b) => a.startUtc.compareTo(b.startUtc));
  return result;
}

MoonReturnOccurrence _newMoonOccurrence(
  _MoonPhaseInstant phase,
  TrackSkyTimeZone timezone,
) {
  final base = eveningThresholdScheduleForDate(
    _dateOnly(phase.instantLocal),
    timezone,
    fallbackMinutesAfterMidnight: kEveningThresholdDefaultFallbackMinutes,
  );
  final startUtc = base.usedFallback
      ? base.startUtc
      : base.startUtc.subtract(const Duration(minutes: 20));
  final endUtc = startUtc.add(
    const Duration(minutes: kMoonReturnDurationMinutes),
  );
  final location = tz.getLocation(timezone.ianaName);
  return MoonReturnOccurrence(
    kind: MoonReturnEventKind.emptyEye,
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    phaseDateIso: phase.phaseDateIso,
    variant: _newMoonVariant(phase.phaseDateIso),
    isBonusBlueMoon: false,
    timezone: timezone,
    scheduleType: 'local_dusk_new_moon',
    referenceLocationName: base.referenceLocation.name,
    usedFallback: base.usedFallback,
  );
}

MoonReturnOccurrence _fullMoonOccurrence(
  _MoonPhaseInstant phase,
  TrackSkyTimeZone timezone, {
  required bool isBonusBlueMoon,
}) {
  final reference = kEveningThresholdReferenceLocations[timezone]!;
  final moonriseUtc = _moonriseUtc(_dateOnly(phase.instantLocal), timezone);
  final fallback = eveningThresholdScheduleForDate(
    _dateOnly(phase.instantLocal),
    timezone,
    fallbackMinutesAfterMidnight: 20 * 60,
  );
  final startUtc =
      moonriseUtc ??
      (fallback.usedFallback
          ? fallback.startUtc
          : fallback.startUtc.subtract(const Duration(minutes: 20)));
  final endUtc = startUtc.add(
    const Duration(minutes: kMoonReturnDurationMinutes),
  );
  final location = tz.getLocation(timezone.ianaName);
  return MoonReturnOccurrence(
    kind: MoonReturnEventKind.wholeEye,
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    phaseDateIso: phase.phaseDateIso,
    variant: isBonusBlueMoon
        ? MoonReturnCopyVariant.blueMoonFull
        : _fullMoonVariant(phase.phaseDateIso),
    isBonusBlueMoon: isBonusBlueMoon,
    timezone: timezone,
    scheduleType: moonriseUtc == null
        ? 'estimated_full_moon_moonrise'
        : 'local_moonrise',
    referenceLocationName: reference.name,
    usedFallback: moonriseUtc == null,
  );
}

MoonReturnEnrollmentWindow _windowForNewMoonPhase(
  _MoonPhaseInstant phase,
  TrackSkyTimeZone timezone,
) {
  final localNewMoonDate = _dateOnly(phase.instantLocal);
  final openDate = localNewMoonDate.subtract(const Duration(days: 2));
  final dawn = dawnHouseRiteScheduleForDate(openDate, timezone);
  return MoonReturnEnrollmentWindow(
    opensAtLocal: dawn.startLocal,
    closesAtLocal: DateTime(
      localNewMoonDate.year,
      localNewMoonDate.month,
      localNewMoonDate.day,
      23,
      59,
      59,
      999,
    ),
    newMoonInstantLocal: phase.instantLocal,
    newMoonInstantUtc: phase.instantUtc,
    newMoonDateIso: phase.phaseDateIso,
    enrollProminence: _newMoonVariant(phase.phaseDateIso),
    timezone: timezone,
  );
}

List<_MoonPhaseInstant> _moonPhasesBetween({
  required DateTime fromUtc,
  required DateTime toUtc,
  required TrackSkyTimeZone timezone,
}) {
  _ensureMoonReturnTimeZonesInitialized();
  final from = fromUtc.toUtc();
  final to = toUtc.toUtc();
  final daysSinceEpoch =
      from.difference(_kKnownNewMoonUtc).inSeconds / Duration.secondsPerDay;
  final firstCycle = (daysSinceEpoch / _kSynodicMonthDays).floor() - 2;
  final cycleCount =
      (to.difference(from).inSeconds /
              Duration.secondsPerDay /
              _kSynodicMonthDays)
          .ceil() +
      5;
  final phases = <_MoonPhaseInstant>[];
  for (var i = 0; i <= cycleCount; i++) {
    final cycle = firstCycle + i;
    phases.add(
      _phaseForCycle(
        cycle: cycle,
        offsetCycles: 0,
        kind: MoonReturnEventKind.emptyEye,
        timezone: timezone,
      ),
    );
    phases.add(
      _phaseForCycle(
        cycle: cycle,
        offsetCycles: 0.5,
        kind: MoonReturnEventKind.wholeEye,
        timezone: timezone,
      ),
    );
  }
  return phases
      .where(
        (phase) =>
            !phase.instantUtc.isBefore(from) && !phase.instantUtc.isAfter(to),
      )
      .toList();
}

_MoonPhaseInstant _phaseForCycle({
  required int cycle,
  required double offsetCycles,
  required MoonReturnEventKind kind,
  required TrackSkyTimeZone timezone,
}) {
  final instantUtc = _trueMoonPhaseUtc(cycle + offsetCycles, kind: kind);
  final location = tz.getLocation(timezone.ianaName);
  final instantLocal = _fromZonedDateTime(
    tz.TZDateTime.from(instantUtc, location),
  );
  return _MoonPhaseInstant(
    kind: kind,
    instantUtc: instantUtc,
    instantLocal: instantLocal,
    phaseDateIso: _isoDate(_dateOnly(instantLocal)),
  );
}

DateTime _trueMoonPhaseUtc(double k, {required MoonReturnEventKind kind}) {
  final t = k / 1236.85;
  final t2 = t * t;
  final t3 = t2 * t;
  final t4 = t3 * t;
  final jde =
      2451550.09765 +
      (29.530588853 * k) +
      (0.0001337 * t2) -
      (0.000000150 * t3) +
      (0.00000000073 * t4);
  final e = 1 - (0.002516 * t) - (0.0000074 * t2);
  final m = _degToRad(
    2.5534 + (29.10535670 * k) - (0.0000014 * t2) - (0.00000011 * t3),
  );
  final mp = _degToRad(
    201.5643 +
        (385.81693528 * k) +
        (0.0107582 * t2) +
        (0.00001238 * t3) -
        (0.000000058 * t4),
  );
  final f = _degToRad(
    160.7108 +
        (390.67050284 * k) -
        (0.0016118 * t2) -
        (0.00000227 * t3) +
        (0.000000011 * t4),
  );
  final omega = _degToRad(
    124.7746 - (1.56375588 * k) + (0.0020672 * t2) + (0.00000215 * t3),
  );
  final baseCorrection =
      (kind == MoonReturnEventKind.wholeEye
          ? -0.40614 * math.sin(mp)
          : -0.40720 * math.sin(mp)) +
      (kind == MoonReturnEventKind.wholeEye
          ? 0.17302 * e * math.sin(m)
          : 0.17241 * e * math.sin(m)) +
      (kind == MoonReturnEventKind.wholeEye
          ? 0.01614 * math.sin(2 * mp)
          : 0.01608 * math.sin(2 * mp)) +
      (kind == MoonReturnEventKind.wholeEye
          ? 0.01043 * math.sin(2 * f)
          : 0.01039 * math.sin(2 * f)) +
      (kind == MoonReturnEventKind.wholeEye
          ? 0.00734 * e * math.sin(mp - m)
          : 0.00739 * e * math.sin(mp - m)) -
      (0.00515 * e * math.sin(mp + m)) +
      (kind == MoonReturnEventKind.wholeEye
          ? 0.00209 * e * e * math.sin(2 * m)
          : 0.00208 * e * e * math.sin(2 * m)) -
      (0.00111 * math.sin(mp - (2 * f))) -
      (0.00057 * math.sin(mp + (2 * f))) +
      (0.00056 * e * math.sin((2 * mp) + m)) -
      (0.00042 * math.sin(3 * mp)) +
      (0.00042 * e * math.sin(m + (2 * f))) +
      (0.00038 * e * math.sin(m - (2 * f))) -
      (0.00024 * e * math.sin((2 * mp) - m)) -
      (0.00017 * math.sin(omega)) -
      (0.00007 * math.sin(mp + (2 * m))) +
      (0.00004 * math.sin((2 * mp) - (2 * f))) +
      (0.00004 * math.sin(3 * m)) +
      (0.00003 * math.sin(mp + m - (2 * f))) +
      (0.00003 * math.sin((2 * mp) + (2 * f))) -
      (0.00003 * math.sin(mp + m + (2 * f))) +
      (0.00003 * math.sin(mp - m + (2 * f))) -
      (0.00002 * math.sin(mp - m - (2 * f))) -
      (0.00002 * math.sin((3 * mp) + m)) +
      (0.00002 * math.sin(4 * mp));
  return _julianDayToUtc(jde + baseCorrection);
}

double _degToRad(double value) {
  final normalized = value % 360;
  return normalized * math.pi / 180;
}

DateTime _julianDayToUtc(double julianDay) {
  final unixSeconds = ((julianDay - 2440587.5) * Duration.secondsPerDay)
      .round();
  // Meeus phases are dynamical time. A one-minute TT/UTC correction is enough
  // for day-window scheduling and keeps fixture dates aligned without tables.
  return DateTime.fromMillisecondsSinceEpoch(
    (unixSeconds - 75) * Duration.millisecondsPerSecond,
    isUtc: true,
  );
}

DateTime? _moonriseUtc(DateTime localDate, TrackSkyTimeZone timezone) {
  _ensureMoonReturnTimeZonesInitialized();
  final reference = kEveningThresholdReferenceLocations[timezone]!;
  final location = tz.getLocation(timezone.ianaName);
  final midnightUtc = tz.TZDateTime(
    location,
    localDate.year,
    localDate.month,
    localDate.day,
  ).toUtc();
  const horizonDegrees = 0.133;
  final horizon = _degToRad(horizonDegrees);
  double altitudeAtHour(double hour) {
    final utc = midnightUtc.add(
      Duration(milliseconds: (hour * Duration.millisecondsPerHour).round()),
    );
    return _moonAltitude(
          utc,
          latitude: reference.latitude,
          longitude: reference.longitude,
        ) -
        horizon;
  }

  var h0 = altitudeAtHour(0);
  double? riseHour;
  for (var hour = 1; hour <= 24; hour += 2) {
    final h1 = altitudeAtHour(hour.toDouble());
    final h2 = altitudeAtHour((hour + 1).toDouble());
    final a = ((h0 + h2) / 2) - h1;
    final b = (h2 - h0) / 2;
    final xe = a == 0 ? 0.0 : -b / (2 * a);
    final d = (b * b) - (4 * a * h1);
    var roots = 0;
    var x1 = 0.0;
    var x2 = 0.0;
    if (d >= 0 && a != 0) {
      final dx = math.sqrt(d) / (a.abs() * 2);
      x1 = xe - dx;
      x2 = xe + dx;
      if (x1.abs() <= 1) roots += 1;
      if (x2.abs() <= 1) roots += 1;
      if (x1 < -1) x1 = x2;
    }
    if (roots == 1 && h0 < 0) {
      riseHour = hour + x1;
      break;
    }
    if (roots == 2) {
      riseHour = hour + (h0 < 0 ? x1 : x2);
      break;
    }
    h0 = h2;
  }
  if (riseHour == null) return null;
  return midnightUtc.add(
    Duration(milliseconds: (riseHour * Duration.millisecondsPerHour).round()),
  );
}

double _moonAltitude(
  DateTime utc, {
  required double latitude,
  required double longitude,
}) {
  final d = _julianDaysSinceJ2000(utc);
  final coords = _moonCoordinates(d);
  final phi = _degToRad(latitude);
  final lw = _degToRad(-longitude);
  final sidereal = _degToRad(280.16 + (360.9856235 * d)) - lw;
  final hourAngle = sidereal - coords.rightAscension;
  return math.asin(
    (math.sin(phi) * math.sin(coords.declination)) +
        (math.cos(phi) * math.cos(coords.declination) * math.cos(hourAngle)),
  );
}

_MoonCoordinates _moonCoordinates(double d) {
  final l = _degToRad(218.316 + (13.176396 * d));
  final m = _degToRad(134.963 + (13.064993 * d));
  final f = _degToRad(93.272 + (13.229350 * d));
  final longitude = l + _degToRad(6.289) * math.sin(m);
  final latitude = _degToRad(5.128) * math.sin(f);
  const obliquity = 23.4397;
  final e = _degToRad(obliquity);
  final rightAscension = math.atan2(
    (math.sin(longitude) * math.cos(e)) - (math.tan(latitude) * math.sin(e)),
    math.cos(longitude),
  );
  final declination = math.asin(
    (math.sin(latitude) * math.cos(e)) +
        (math.cos(latitude) * math.sin(e) * math.sin(longitude)),
  );
  return _MoonCoordinates(
    rightAscension: rightAscension,
    declination: declination,
  );
}

double _julianDaysSinceJ2000(DateTime utc) {
  final julianDay =
      (utc.toUtc().millisecondsSinceEpoch / Duration.millisecondsPerDay) +
      2440587.5;
  return julianDay - 2451545.0;
}

MoonReturnCopyVariant _newMoonVariant(String phaseDateIso) {
  switch (phaseDateIso) {
    case '2026-08-12':
      return MoonReturnCopyVariant.wepRonpetNew;
    case '2025-03-29':
    case '2025-09-21':
    case '2026-02-17':
      return MoonReturnCopyVariant.solarEclipseNew;
  }
  return MoonReturnCopyVariant.standard;
}

MoonReturnCopyVariant _fullMoonVariant(String phaseDateIso) {
  switch (phaseDateIso) {
    case '2025-09-07':
    case '2026-03-03':
    case '2026-08-28':
      return MoonReturnCopyVariant.lunarEclipseFull;
    case '2026-11-24':
      return MoonReturnCopyVariant.supermoonFull;
  }
  return MoonReturnCopyVariant.standard;
}

String _isoDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

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

class _MoonPhaseInstant {
  final MoonReturnEventKind kind;
  final DateTime instantUtc;
  final DateTime instantLocal;
  final String phaseDateIso;

  const _MoonPhaseInstant({
    required this.kind,
    required this.instantUtc,
    required this.instantLocal,
    required this.phaseDateIso,
  });
}

class _MoonCoordinates {
  final double rightAscension;
  final double declination;

  const _MoonCoordinates({
    required this.rightAscension,
    required this.declination,
  });
}
