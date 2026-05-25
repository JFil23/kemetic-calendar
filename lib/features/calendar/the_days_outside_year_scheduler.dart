import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../widgets/kemetic_date_picker.dart';
import 'dawn_house_rite_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'the_days_outside_year_flow.dart';
import 'track_sky_flow.dart';

bool _daysOutsideTimeZonesInitialized = false;

void _ensureDaysOutsideTimeZonesInitialized() {
  if (_daysOutsideTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _daysOutsideTimeZonesInitialized = true;
}

class DaysOutsideOccurrenceSchedule {
  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool usedFallback;
  final TrackSkyTimeZone timezone;
  final String referenceLocationName;
  final String scheduleType;

  const DaysOutsideOccurrenceSchedule({
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
    required this.usedFallback,
    required this.timezone,
    required this.referenceLocationName,
    required this.scheduleType,
  });
}

DateTime daysOutsideEventGregorian({
  required int closingKYear,
  required int kMonth,
  required int kDay,
}) {
  final eventKYear = (kMonth == 1 && kDay == 1)
      ? closingKYear + 1
      : closingKYear;
  return KemeticMath.toGregorian(eventKYear, kMonth, kDay);
}

DateTime daysOutsideEnrollmentOpenGregorian(int closingKYear) {
  return KemeticMath.toGregorian(closingKYear, 12, 28);
}

DateTime daysOutsideFlowEndGregorian(int closingKYear) {
  return daysOutsideEventGregorian(
    closingKYear: closingKYear,
    kMonth: 1,
    kDay: 1,
  );
}

DaysOutsideOccurrenceSchedule daysOutsideScheduleForEvent({
  required DaysOutsideEvent event,
  required int closingKYear,
  required TrackSkyTimeZone timezone,
}) {
  final date = daysOutsideEventGregorian(
    closingKYear: closingKYear,
    kMonth: event.kMonth,
    kDay: event.kDay,
  );
  switch (event.schedule) {
    case DaysOutsideScheduleKind.solarDusk:
      return _daysOutsideDuskScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutes,
      );
    case DaysOutsideScheduleKind.solarDawn:
      return _daysOutsideDawnScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutes,
      );
  }
}

DaysOutsideOccurrenceSchedule _daysOutsideDawnScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = dawnHouseRiteScheduleForDate(date, timezone);
  final endUtc = base.startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return DaysOutsideOccurrenceSchedule(
    startLocal: base.startLocal,
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: base.startUtc,
    endUtc: endUtc,
    usedFallback: base.usedFallback,
    timezone: timezone,
    referenceLocationName: base.referenceLocation.name,
    scheduleType: 'local_astronomical_dawn',
  );
}

DaysOutsideOccurrenceSchedule _daysOutsideDuskScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = eveningThresholdScheduleForDate(
    date,
    timezone,
    fallbackMinutesAfterMidnight: kEveningThresholdDefaultFallbackMinutes,
  );
  final startUtc = base.usedFallback
      ? base.startUtc
      : base.startUtc.subtract(const Duration(minutes: 20));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return DaysOutsideOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: base.usedFallback,
    timezone: timezone,
    referenceLocationName: base.referenceLocation.name,
    scheduleType: 'local_dusk',
  );
}

DateTime daysOutsideNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureDaysOutsideTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
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
