import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../widgets/kemetic_date_picker.dart';

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
    required this.ianaTimeZone,
    required this.presentLocalDateTime,
    required this.presentLocalDate,
    required this.presentKemeticDate,
  });

  factory MaatFlowTemporalContext.capture({
    required String ianaTimeZone,
    MaatFlowClock clock = maatFlowSystemClock,
  }) {
    return MaatFlowTemporalContext.fromInstant(
      nowUtc: clock().toUtc(),
      ianaTimeZone: ianaTimeZone,
    );
  }

  factory MaatFlowTemporalContext.fromInstant({
    required DateTime nowUtc,
    required String ianaTimeZone,
  }) {
    _ensureMaatFlowTimeZonesInitialized();
    final instant = nowUtc.toUtc();
    final location = tz.getLocation(ianaTimeZone);
    final zoned = tz.TZDateTime.from(instant, location);
    final localDate = DateTime(zoned.year, zoned.month, zoned.day);
    return MaatFlowTemporalContext._(
      nowUtc: instant,
      ianaTimeZone: location.name,
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
  final String ianaTimeZone;
  final DateTime presentLocalDateTime;
  final DateTime presentLocalDate;
  final ({int kYear, int kMonth, int kDay}) presentKemeticDate;

  DateTime localDateAfter(int calendarDays) => DateTime(
    presentLocalDate.year,
    presentLocalDate.month,
    presentLocalDate.day + calendarDays,
  );

  DateTime localDateForUtc(DateTime instantUtc, {String? ianaTimeZone}) {
    final zoned = tz.TZDateTime.from(
      instantUtc.toUtc(),
      tz.getLocation(ianaTimeZone ?? this.ianaTimeZone),
    );
    return DateTime(zoned.year, zoned.month, zoned.day);
  }

  DateTime get nextLocalMidnightUtc {
    final location = tz.getLocation(ianaTimeZone);
    return tz.TZDateTime(
      location,
      presentLocalDate.year,
      presentLocalDate.month,
      presentLocalDate.day + 1,
    ).toUtc();
  }

  bool hasSamePresentDay(MaatFlowTemporalContext other) =>
      ianaTimeZone == other.ianaTimeZone &&
      presentLocalDate == other.presentLocalDate;
}

bool _maatFlowTimeZonesInitialized = false;

void _ensureMaatFlowTimeZonesInitialized() {
  if (_maatFlowTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _maatFlowTimeZonesInitialized = true;
}
