import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/sky_instrument_data.dart';

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

/// One focus policy for every typed Follow Sky instrument family.
DateTime followSkyFocusInstant(SkyInstrumentData data) => switch (data) {
  LunarPathData value => _visibleLunarMaximum(value)?.at ?? value.phaseInstant,
  MeteorWindowData value => value.peakWindowStart.add(
    value.peakWindowEnd.difference(value.peakWindowStart) ~/ 2,
  ),
  OppositionData value => value.closestApproach,
  ElongationData value => value.maximumAt,
  ConjunctionData value => value.closestApproach,
  SolarThresholdData value => value.thresholdInstant,
  SolarEclipseData value => value.greatestEclipse,
};

LunarEclipseContact? _visibleLunarMaximum(LunarPathData data) {
  for (final contact in data.eclipseContacts) {
    if (contact.kind == LunarEclipseContactKind.maximum &&
        contact.locallyVisible) {
      return contact;
    }
  }
  return null;
}

DateTime initialFollowSkyInstrumentViewTime({
  required DateTime now,
  required SkyInstrumentData instrument,
  DateTime? focusInstant,
}) {
  return isFollowSkyInstrumentLiveTime(now: now, instrument: instrument)
      ? now
      : focusInstant ?? followSkyFocusInstant(instrument);
}

bool isFollowSkyInstrumentLiveTime({
  required DateTime now,
  required SkyInstrumentData instrument,
}) {
  return !now.isBefore(instrument.viewingWindowStart) &&
      !now.isAfter(instrument.viewingWindowEnd);
}

/// Shared session-local view-time state for all seven instrument families.
///
/// It never writes calendar time. Manual selection disables live following
/// only for this controller's lifetime; reopening creates a fresh controller.
class FollowSkyViewTimeController extends ValueNotifier<DateTime> {
  FollowSkyViewTimeController({
    required this.instrument,
    required this.focusInstant,
    required DateTime now,
  }) : super(
         _clamp(
           initialFollowSkyInstrumentViewTime(
             now: now,
             instrument: instrument,
             focusInstant: focusInstant,
           ),
           instrument,
         ),
       );

  final SkyInstrumentData instrument;
  final DateTime focusInstant;
  bool _manual = false;

  bool get isManual => _manual;

  double get selectedFraction => fractionFor(value);

  DateTime timeAtFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0).toDouble();
    final lunar = instrument;
    if (lunar is LunarPathData &&
        lunar.rise != null &&
        lunar.transit != null &&
        lunar.set != null) {
      final start = lunar.rise!;
      final pivot = lunar.transit!;
      final end = lunar.set!;
      final milliseconds = clamped <= 0.5
          ? pivot.difference(start).inMilliseconds * (clamped / 0.5)
          : end.difference(pivot).inMilliseconds * ((clamped - 0.5) / 0.5);
      return (clamped <= 0.5 ? start : pivot).add(
        Duration(milliseconds: milliseconds.round()),
      );
    }
    final span = instrument.viewingWindowEnd
        .difference(instrument.viewingWindowStart)
        .inMilliseconds;
    return instrument.viewingWindowStart.add(
      Duration(milliseconds: (span * clamped).round()),
    );
  }

  double fractionFor(DateTime at) {
    final clamped = _clamp(at, instrument);
    final lunar = instrument;
    if (lunar is LunarPathData &&
        lunar.rise != null &&
        lunar.transit != null &&
        lunar.set != null) {
      final start = lunar.rise!;
      final pivot = lunar.transit!;
      final end = lunar.set!;
      if (!clamped.isAfter(start)) return 0;
      if (!clamped.isBefore(end)) return 1;
      if (!clamped.isAfter(pivot)) {
        final span = pivot.difference(start).inMilliseconds;
        return span == 0
            ? 0.5
            : 0.5 * clamped.difference(start).inMilliseconds / span;
      }
      final span = end.difference(pivot).inMilliseconds;
      return span == 0
          ? 1
          : 0.5 + 0.5 * clamped.difference(pivot).inMilliseconds / span;
    }
    final span = instrument.viewingWindowEnd
        .difference(instrument.viewingWindowStart)
        .inMilliseconds;
    if (span <= 0) return 0;
    return clamped.difference(instrument.viewingWindowStart).inMilliseconds /
        span;
  }

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
    final next = _clamp(selectedAt, instrument);
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

  static DateTime _clamp(DateTime value, SkyInstrumentData instrument) {
    if (value.isBefore(instrument.viewingWindowStart)) {
      return instrument.viewingWindowStart;
    }
    if (value.isAfter(instrument.viewingWindowEnd)) {
      return instrument.viewingWindowEnd;
    }
    return value;
  }
}
