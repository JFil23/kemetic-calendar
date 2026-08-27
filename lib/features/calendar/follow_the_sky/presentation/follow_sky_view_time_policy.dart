import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _timeZonesInitialized = false;

/// Returns the local wall-clock time used by fixture geometry for [instant].
///
/// The approved lunar samples are intentionally stored as local civil times.
/// This conversion keeps the fixture independent of the device timezone while
/// still honoring daylight-saving rules from its IANA timezone.
DateTime followSkyWallTime(DateTime instant, String ianaTimeZone) {
  if (!_timeZonesInitialized) {
    tzdata.initializeTimeZones();
    _timeZonesInitialized = true;
  }
  final local = tz.TZDateTime.from(
    instant.toUtc(),
    tz.getLocation(ianaTimeZone),
  );
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

/// Selects live time only while the phenomenon is above the local horizon.
DateTime initialFollowSkyViewTime({
  required DateTime now,
  required DateTime rise,
  required DateTime set,
  required DateTime peak,
}) {
  return isFollowSkyLiveTime(now: now, rise: rise, set: set) ? now : peak;
}

bool isFollowSkyLiveTime({
  required DateTime now,
  required DateTime rise,
  required DateTime set,
}) {
  return !now.isBefore(rise) && !now.isAfter(set);
}
