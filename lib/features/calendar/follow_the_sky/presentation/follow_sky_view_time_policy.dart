import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/follow_sky_track_definition.dart';

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

bool isFollowSkyTrackLiveTime({
  required DateTime now,
  required FollowSkyTrackDefinition track,
}) {
  return !now.isBefore(track.trackStart) && !now.isAfter(track.trackEnd);
}

/// Shared session-local view-time state for all seven instrument families.
///
/// It never writes calendar time. Manual selection disables live following
/// only for this controller's lifetime; reopening creates a fresh controller.
class FollowSkyViewTimeController extends ValueNotifier<DateTime> {
  FollowSkyViewTimeController({required this.track, required DateTime now})
    : super(
        track.clamp(
          isFollowSkyTrackLiveTime(now: now, track: track)
              ? now
              : track.experiencePeak,
        ),
      );

  final FollowSkyTrackDefinition track;
  bool _manual = false;

  bool get isManual => _manual;

  double get selectedFraction => fractionFor(value);

  DateTime timeAtFraction(double fraction) => track.timeAtFraction(fraction);

  double fractionFor(DateTime at) => track.fractionFor(at);

  FollowSkyVisualState stateAt(DateTime at) => track.stateAt(at);

  void selectFraction(double fraction) {
    _manual = true;
    _set(timeAtFraction(fraction));
  }

  void selectTime(DateTime selectedAt, {bool manual = true}) {
    if (manual) _manual = true;
    _set(selectedAt);
  }

  void followClock(DateTime now) {
    if (_manual) return;
    _set(now);
  }

  void _set(DateTime selectedAt) {
    final next = track.clamp(selectedAt);
    final minute = DateTime(
      next.year,
      next.month,
      next.day,
      next.hour,
      next.minute,
    );
    if (minute == value) return;
    value = minute;
  }
}
