import '../../widgets/kemetic_date_picker.dart' show KemeticMath;
import 'decan_metadata.dart';
import 'kemetic_month_metadata.dart';

/// Local day-ten gate; the input represents a civil date, even when UTC-tagged.
DateTime decanReflectionAvailableAt(DateTime start) =>
    DateTime(start.year, start.month, start.day + 9, 20);

({
  DateTime start,
  DateTime end,
  String decanName,
  String? decanTheme,
  String decanContextKey,
  int kMonth,
  int kYear,
})?
latestCompletedDecanReflectionWindow(
  DateTime now, {
  bool availableOnly = false,
}) {
  // A manual invitation always refers to a period the normal reader accepts.
  // Before 20:00 on its last day, the preceding decan is the latest available.
  if (availableOnly && now.hour < 20) {
    now = DateTime(now.year, now.month, now.day - 1, 20);
  }
  final kem = KemeticMath.fromGregorian(now);

  // Skip epagomenal days (month 13) for reflection generation; fall back to month 12.
  int kMonth = kem.kMonth;
  int kYear = kem.kYear;
  int completedDecan = kem.kDay ~/ 10; // 1-based decan completion count

  if (kMonth == 13) {
    kMonth = 12;
    completedDecan = 3;
  }

  if (completedDecan == 0) {
    if (kMonth <= 1) {
      kYear -= 1;
      kMonth = 12;
    } else {
      kMonth -= 1;
    }
    completedDecan = 3;
  }

  completedDecan = completedDecan.clamp(1, 3);
  if (kMonth == 13) return null; // guard epagomenal month fallback

  final decanStartDay = ((completedDecan - 1) * 10) + 1;
  final decanEndDay = completedDecan * 10;

  final start = KemeticMath.toGregorian(kYear, kMonth, decanStartDay);
  final end = KemeticMath.toGregorian(kYear, kMonth, decanEndDay);
  final todayLocal = DateTime(now.year, now.month, now.day);
  if (DateTime(end.year, end.month, end.day).isAfter(todayLocal)) {
    return null; // only after completion
  }

  final decanLabel = DecanMetadata.decanNameFor(
    kMonth: kMonth,
    kDay: decanEndDay,
    expanded: true,
  );
  final monthLabel = getMonthById(kMonth).displayShort;

  return (
    start: start,
    end: end,
    decanName: '$monthLabel — $decanLabel',
    decanTheme: decanLabel,
    decanContextKey: '$kMonth-$completedDecan',
    kMonth: kMonth,
    kYear: kYear,
  );
}

/// Invite accounts only in a later decan, for periods since their signup decan.
/// The verified Auth creation date works across devices without a cache reset.
bool isAccountEligibleForDecanReflection({
  required DateTime? accountCreatedAt,
  required DateTime now,
  required DateTime windowStart,
}) {
  if (accountCreatedAt == null) return false;
  DateTime start(DateTime date) {
    final k = KemeticMath.fromGregorian(date);
    return KemeticMath.toGregorian(
      k.kYear,
      k.kMonth == 13 ? 12 : k.kMonth,
      k.kMonth == 13 ? 21 : ((k.kDay - 1) ~/ 10) * 10 + 1,
    );
  }

  final joined = start(accountCreatedAt);
  return start(now).isAfter(joined) &&
      !DateTime(
        windowStart.year,
        windowStart.month,
        windowStart.day,
      ).isBefore(DateTime(joined.year, joined.month, joined.day));
}
