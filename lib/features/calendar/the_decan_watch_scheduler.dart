import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../widgets/kemetic_date_picker.dart';
import 'decan_id.dart';
import 'decan_metadata.dart';
import 'the_decan_watch_flow.dart';
import 'track_sky_flow.dart';

bool _decanWatchTimeZonesInitialized = false;

void _ensureDecanWatchTimeZonesInitialized() {
  if (_decanWatchTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _decanWatchTimeZonesInitialized = true;
}

class DecanWatchScheduleTime {
  final int hour;
  final int minute;

  const DecanWatchScheduleTime({required this.hour, required this.minute});
}

bool isDecanOpeningKemeticDay(int kMonth, int kDay) {
  return kMonth >= 1 && kMonth <= 12 && (kDay == 1 || kDay == 11 || kDay == 21);
}

int decanWatchDecanIndexForStartDay(int decanStartDay) {
  return ((decanStartDay - 1) ~/ 10) + 1;
}

DecanWatchScheduleTime normalizeDecanWatchScheduleTime({
  int hour = kDecanWatchDefaultHour,
  int minute = kDecanWatchDefaultMinute,
}) {
  if (hour < kDecanWatchEditableFromHour) {
    return const DecanWatchScheduleTime(
      hour: kDecanWatchEditableFromHour,
      minute: 0,
    );
  }
  if (hour > kDecanWatchEditableToHour) {
    return const DecanWatchScheduleTime(
      hour: kDecanWatchEditableToHour,
      minute: 59,
    );
  }
  return DecanWatchScheduleTime(
    hour: hour,
    minute: minute.clamp(0, 59).toInt(),
  );
}

DateTime decanWatchNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureDecanWatchTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromZonedDateTime(zoned);
}

DecanWatchOccurrence decanWatchOccurrenceFor({
  required int kYear,
  required int kMonth,
  required int decanStartDay,
  required TrackSkyTimeZone timezone,
  int hour = kDecanWatchDefaultHour,
  int minute = kDecanWatchDefaultMinute,
}) {
  if (!isDecanOpeningKemeticDay(kMonth, decanStartDay)) {
    throw ArgumentError.value(
      decanStartDay,
      'decanStartDay',
      'Decan Watch only schedules Month 1-12 days 1, 11, or 21.',
    );
  }
  _ensureDecanWatchTimeZonesInitialized();
  final schedule = normalizeDecanWatchScheduleTime(hour: hour, minute: minute);
  final date = KemeticMath.toGregorian(kYear, kMonth, decanStartDay);
  final location = tz.getLocation(timezone.ianaName);
  final startZoned = tz.TZDateTime(
    location,
    date.year,
    date.month,
    date.day,
    schedule.hour,
    schedule.minute,
  );
  final startUtc = startZoned.toUtc();
  final endUtc = startUtc.add(
    const Duration(minutes: kDecanWatchDurationMinutes),
  );
  final decanIndex = decanWatchDecanIndexForStartDay(decanStartDay);
  return DecanWatchOccurrence(
    kYear: kYear,
    kMonth: kMonth,
    decanIndex: decanIndex,
    decanStartDay: decanStartDay,
    globalDecanId: decanIdFromMonthAndIndex(
      monthIndex: kMonth,
      decanInMonth: decanIndex,
    ),
    decanName: DecanMetadata.decanNameFor(
      kMonth: kMonth,
      kDay: decanStartDay,
      expanded: true,
    ),
    eventDateIso: _isoDate(date),
    timezone: timezone,
    scheduleHour: schedule.hour,
    scheduleMinute: schedule.minute,
    startLocal: _fromZonedDateTime(startZoned),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
  );
}

List<DecanWatchOccurrence> upcomingDecanWatchOccurrences({
  required TrackSkyTimeZone timezone,
  DateTime? fromLocal,
  int count = 3,
  int hour = kDecanWatchDefaultHour,
  int minute = kDecanWatchDefaultMinute,
  bool includeCurrentOpening = true,
}) {
  if (count <= 0) return const <DecanWatchOccurrence>[];
  final nowLocal = fromLocal ?? decanWatchNowInZone(timezone);
  final start = _dateOnly(nowLocal);
  final result = <DecanWatchOccurrence>[];
  for (var offset = 0; offset < 430 && result.length < count; offset++) {
    final date = start.add(Duration(days: offset));
    final k = KemeticMath.fromGregorian(date);
    if (!isDecanOpeningKemeticDay(k.kMonth, k.kDay)) continue;
    final occurrence = decanWatchOccurrenceFor(
      kYear: k.kYear,
      kMonth: k.kMonth,
      decanStartDay: k.kDay,
      timezone: timezone,
      hour: hour,
      minute: minute,
    );
    final isCurrentDate = _sameDate(date, start);
    if (!includeCurrentOpening && occurrence.startLocal.isBefore(nowLocal)) {
      continue;
    }
    if (!isCurrentDate && occurrence.startLocal.isBefore(nowLocal)) {
      continue;
    }
    result.add(occurrence);
  }
  return result;
}

DateTime defaultDecanWatchStartDate(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final next = upcomingDecanWatchOccurrences(
    timezone: timezone,
    fromLocal: decanWatchNowInZone(timezone, now: now),
    count: 1,
  ).first;
  return _dateOnly(next.startLocal);
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
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

String _isoDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
