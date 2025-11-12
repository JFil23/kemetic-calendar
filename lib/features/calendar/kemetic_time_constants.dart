/// Centralized Kemetic calendar epoch and time utilities.
/// All date arithmetic MUST use UTC to avoid DST bugs.

// Epoch: Kemetic Year 1, Day 1 = March 20, 2025 (UTC)
const int kEpochYear = 2025;
const int kEpochMonth = 3;
const int kEpochDay = 20;

/// CRITICAL: This epoch is in UTC to ensure date arithmetic
/// is not affected by Daylight Saving Time transitions.
final DateTime kKemeticEpochUtc = DateTime.utc(kEpochYear, kEpochMonth, kEpochDay);

/// Safe conversion from UTC DateTime to local display DateTime at noon.
/// FIXED: Properly derives local Y-M-D from UTC instant, then pins to local noon.
/// Using noon (12:00) avoids DST midnight ambiguity issues.
DateTime safeLocalDisplay(DateTime utcDate) {
  assert(utcDate.isUtc, 'safeLocalDisplay expects a UTC DateTime');
  // Step 1: Convert UTC date to local at noon UTC
  final localNoon = DateTime.utc(utcDate.year, utcDate.month, utcDate.day, 12).toLocal();
  // Step 2: Create clean local DateTime at noon using the local Y-M-D
  return DateTime(localNoon.year, localNoon.month, localNoon.day, 12);
}

/// Safe conversion from any DateTime to UTC date-only (at midnight UTC).
/// FIXED: Normalizes to UTC first before truncating to avoid misinterpretation.
DateTime toUtcDateOnly(DateTime dt) {
  final u = dt.isUtc ? dt : dt.toUtc();
  return DateTime.utc(u.year, u.month, u.day);
}

/// Integer-based epoch day math (cleaner and more robust).
/// Returns number of days since Kemetic epoch.
int epochDayFromUtc(DateTime utc) {
  return utc.difference(kKemeticEpochUtc).inDays;
}

/// Convert epoch day count to UTC DateTime at midnight.
DateTime utcFromEpochDay(int epochDay) {
  return kKemeticEpochUtc.add(Duration(days: epochDay));
}




