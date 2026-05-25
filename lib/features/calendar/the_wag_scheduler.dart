import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../widgets/kemetic_date_picker.dart';
import 'dawn_house_rite_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'the_wag_flow.dart';
import 'track_sky_flow.dart';

const int kWagAnytimeDefaultHour = 11;
const int kWagAnytimeDefaultMinute = 0;
const int kWagFeastDefaultHour = 9;
const int kWagFeastDefaultMinute = 0;

bool _wagTimeZonesInitialized = false;

void _ensureWagTimeZonesInitialized() {
  if (_wagTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _wagTimeZonesInitialized = true;
}

class WagOccurrenceSchedule {
  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool usedFallback;
  final TrackSkyTimeZone timezone;
  final String referenceLocationName;
  final String scheduleType;

  const WagOccurrenceSchedule({
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

DateTime wagEventGregorian(int kYear, int kemeticDay) {
  return KemeticMath.toGregorian(kYear, 1, kemeticDay);
}

DateTime wagYearStartGregorian(int kYear) {
  return wagEventGregorian(kYear, 1);
}

DateTime wagYearEndGregorian(int kYear) {
  return wagEventGregorian(kYear, 29);
}

DateTime wagNextFeastGregorian(int kYear) {
  return wagEventGregorian(kYear + 1, 18);
}

WagOccurrenceSchedule wagScheduleForEvent({
  required WagEvent event,
  required int kYear,
  required TrackSkyTimeZone timezone,
}) {
  final date = wagEventGregorian(kYear, event.kemeticDay);
  switch (event.schedule) {
    case WagScheduleKind.solarDawn:
      return _wagDawnScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
    case WagScheduleKind.anytime:
      return _wagFixedLocalScheduleForDate(
        date,
        timezone,
        hour: kWagAnytimeDefaultHour,
        minute: kWagAnytimeDefaultMinute,
        durationMinutes: event.durationMinutesMax,
        scheduleType: 'fixed_local_anytime_default',
      );
    case WagScheduleKind.solarDusk:
      return _wagDuskScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
    case WagScheduleKind.feastMorning:
      return _wagFixedLocalScheduleForDate(
        date,
        timezone,
        hour: kWagFeastDefaultHour,
        minute: kWagFeastDefaultMinute,
        durationMinutes: event.durationMinutesMax,
        scheduleType: 'fixed_local_feast_morning',
      );
  }
}

String wagClientEventId({
  required int flowId,
  required int kYear,
  required WagEvent event,
}) {
  return 'wag:$flowId:$kYear:event-${event.eventNumber.toString().padLeft(2, '0')}';
}

WagOccurrenceSchedule _wagDawnScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = dawnHouseRiteScheduleForDate(date, timezone);
  final endUtc = base.startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return WagOccurrenceSchedule(
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

WagOccurrenceSchedule _wagDuskScheduleForDate(
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
  return WagOccurrenceSchedule(
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

WagOccurrenceSchedule _wagFixedLocalScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int hour,
  required int minute,
  required int durationMinutes,
  required String scheduleType,
}) {
  _ensureWagTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final localDate = DateTime(date.year, date.month, date.day);
  final startUtc = tz.TZDateTime(
    location,
    localDate.year,
    localDate.month,
    localDate.day,
    hour.clamp(0, 23).toInt(),
    minute.clamp(0, 59).toInt(),
  ).toUtc();
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  return WagOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: false,
    timezone: timezone,
    referenceLocationName: timezone.label,
    scheduleType: scheduleType,
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
