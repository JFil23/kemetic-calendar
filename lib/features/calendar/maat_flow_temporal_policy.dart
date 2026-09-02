import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../widgets/kemetic_date_picker.dart';
import 'track_sky_timezone.dart';

typedef MaatFlowClock = DateTime Function();

DateTime maatFlowSystemClock() => DateTime.now().toUtc();

enum MaatFlowTemporalPolicyKind {
  relativeCalendarDays,
  nextEligibleSkyEvent,
  dawnHouseRite,
  eveningThreshold,
  eveningThresholdRite,
  theWeighing,
  theTending,
  keptWord,
  theCourse,
  moonReturn,
  nextWepRonpetWindow,
  nextDecanWindow,
  nextDaysOutsideYearWindow,
}

class MaatFlowTemporalPolicy {
  const MaatFlowTemporalPolicy._(this.kind) : dayOffset = null;

  const MaatFlowTemporalPolicy.relativeCalendarDays(this.dayOffset)
    : assert(dayOffset != null && dayOffset >= 0),
      kind = MaatFlowTemporalPolicyKind.relativeCalendarDays;

  static const nextEligibleSkyEvent = MaatFlowTemporalPolicy._(
    MaatFlowTemporalPolicyKind.nextEligibleSkyEvent,
  );
  static const dawnHouseRite = MaatFlowTemporalPolicy._(
    MaatFlowTemporalPolicyKind.dawnHouseRite,
  );
  static const eveningThreshold = MaatFlowTemporalPolicy._(
    MaatFlowTemporalPolicyKind.eveningThreshold,
  );
  static const eveningThresholdRite = MaatFlowTemporalPolicy._(
    MaatFlowTemporalPolicyKind.eveningThresholdRite,
  );
  static const theWeighing = MaatFlowTemporalPolicy._(
    MaatFlowTemporalPolicyKind.theWeighing,
  );
  static const theTending = MaatFlowTemporalPolicy._(
    MaatFlowTemporalPolicyKind.theTending,
  );
  static const keptWord = MaatFlowTemporalPolicy._(
    MaatFlowTemporalPolicyKind.keptWord,
  );
  static const theCourse = MaatFlowTemporalPolicy._(
    MaatFlowTemporalPolicyKind.theCourse,
  );
  static const moonReturn = MaatFlowTemporalPolicy._(
    MaatFlowTemporalPolicyKind.moonReturn,
  );
  static const nextWepRonpetWindow = MaatFlowTemporalPolicy._(
    MaatFlowTemporalPolicyKind.nextWepRonpetWindow,
  );
  static const nextDecanWindow = MaatFlowTemporalPolicy._(
    MaatFlowTemporalPolicyKind.nextDecanWindow,
  );
  static const nextDaysOutsideYearWindow = MaatFlowTemporalPolicy._(
    MaatFlowTemporalPolicyKind.nextDaysOutsideYearWindow,
  );

  final MaatFlowTemporalPolicyKind kind;
  final int? dayOffset;
}

/// One captured present instant and its authoritative civil/Kemetic day.
///
/// A caller creates one context per preview/enrollment operation, then passes
/// its resolved anchor forward. Calendar offsets use civil-date construction,
/// not 24-hour elapsed-time arithmetic, so DST cannot move the result.
class MaatFlowTemporalContext {
  MaatFlowTemporalContext._({
    required this.nowUtc,
    required this.timezone,
    required this.presentLocalDateTime,
    required this.presentLocalDate,
    required this.presentKemeticDate,
  });

  factory MaatFlowTemporalContext.capture({
    required TrackSkyTimeZone timezone,
    MaatFlowClock clock = maatFlowSystemClock,
  }) {
    return MaatFlowTemporalContext.fromInstant(
      nowUtc: clock().toUtc(),
      timezone: timezone,
    );
  }

  factory MaatFlowTemporalContext.fromInstant({
    required DateTime nowUtc,
    required TrackSkyTimeZone timezone,
  }) {
    _ensureMaatFlowTimeZonesInitialized();
    final instant = nowUtc.toUtc();
    final zoned = tz.TZDateTime.from(
      instant,
      tz.getLocation(timezone.ianaName),
    );
    final localDate = DateTime(zoned.year, zoned.month, zoned.day);
    return MaatFlowTemporalContext._(
      nowUtc: instant,
      timezone: timezone,
      presentLocalDateTime: DateTime(
        zoned.year,
        zoned.month,
        zoned.day,
        zoned.hour,
        zoned.minute,
        zoned.second,
        zoned.millisecond,
        zoned.microsecond,
      ),
      presentLocalDate: localDate,
      presentKemeticDate: KemeticMath.fromGregorian(localDate),
    );
  }

  final DateTime nowUtc;
  final TrackSkyTimeZone timezone;
  final DateTime presentLocalDateTime;
  final DateTime presentLocalDate;
  final ({int kYear, int kMonth, int kDay}) presentKemeticDate;

  DateTime localDateAfter(int calendarDays) => DateTime(
    presentLocalDate.year,
    presentLocalDate.month,
    presentLocalDate.day + calendarDays,
  );

  DateTime localDateForUtc(DateTime instantUtc) {
    final zoned = tz.TZDateTime.from(
      instantUtc.toUtc(),
      tz.getLocation(timezone.ianaName),
    );
    return DateTime(zoned.year, zoned.month, zoned.day);
  }

  bool hasSamePresentDay(MaatFlowTemporalContext other) =>
      timezone == other.timezone && presentLocalDate == other.presentLocalDate;
}

bool _maatFlowTimeZonesInitialized = false;

void _ensureMaatFlowTimeZonesInitialized() {
  if (_maatFlowTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _maatFlowTimeZonesInitialized = true;
}
