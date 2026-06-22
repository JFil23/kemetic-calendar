part of 'calendar_page.dart';

/* ─────────── Flows (routines) – models & rules ─────────── */

// ============================================================================
// NUTRITION-TO-FLOW CONVERSION TYPES
// ============================================================================

/// Callback type for creating a reminder from nutrition schedule data
typedef CreateNutritionReminder =
    Future<void> Function(NutritionReminderIntent intent);
typedef _ReminderOccurrenceRow = ({
  String id,
  String? clientEventId,
  String title,
  String? detail,
  String? location,
  bool allDay,
  DateTime startsAtUtc,
  DateTime? endsAtUtc,
  String? calendarId,
  int? flowLocalId,
  String? category,
});

/// Intent data for creating a reminder from a nutrition item schedule
class NutritionReminderIntent {
  final String itemId;
  final String title;
  final String? detail;
  final bool isWeekdayMode;
  final Set<int> weekdays; // 1-7 for weekdays (Mon=1, Sun=7)
  final Set<int> decanDays; // 1-10 for decan days
  final TimeOfDay timeOfDay;
  final bool repeat;
  final int alertOffsetMinutes;

  const NutritionReminderIntent({
    required this.itemId,
    required this.title,
    this.detail,
    required this.isWeekdayMode,
    required this.weekdays,
    required this.decanDays,
    required this.timeOfDay,
    required this.repeat,
    this.alertOffsetMinutes = _alertNoneMinutes,
  });
}

/// Rules attach their own time window (all-day or start/end).
abstract class FlowRule {
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;
  const FlowRule({this.allDay = true, this.start, this.end});

  /// True if rule hits for the given Kemetic date and its Gregorian equivalent.
  bool matches({
    required int ky,
    required int km,
    required int kd,
    required DateTime g,
  });
}

/// Kemetic Decan rule.
class _RuleDecan extends FlowRule {
  final Set<int> months; // 1..12
  final Set<int> decans; // 1..3
  final Set<int> daysInDecan; // 1..10 (optional)
  const _RuleDecan({
    required this.months,
    required this.decans,
    this.daysInDecan = const {},
    super.allDay = true,
    super.start,
    super.end,
  });
  @override
  bool matches({
    required int ky,
    required int km,
    required int kd,
    required DateTime g,
  }) {
    if (km == 13) return false;
    if (!months.contains(km)) return false;
    final dIndex = ((kd - 1) ~/ 10) + 1; // 1..3
    final dIn = ((kd - 1) % 10) + 1; // 1..10
    if (!decans.contains(dIndex)) return false;
    if (daysInDecan.isNotEmpty && !daysInDecan.contains(dIn)) return false;
    return true;
  }
}

/// Gregorian weekday rule (Mon=1 .. Sun=7).
class _RuleWeek extends FlowRule {
  final Set<int> weekdays; // 1..7
  const _RuleWeek({
    required this.weekdays,
    super.allDay = true,
    super.start,
    super.end,
  });
  @override
  bool matches({
    required int ky,
    required int km,
    required int kd,
    required DateTime g,
  }) {
    return weekdays.contains(g.weekday);
  }
}

// ============================================================================
// REPEATING NOTES - UI ENUMS
// ============================================================================

/// UI-level repeat options for individual notes.
enum NoteRepeatOption {
  never,
  everyDay,
  everyWeek,
  every2Weeks,
  everyMonth,
  everyYear,
  custom,
}

/// How the repeating series should end.
enum NoteRepeatEndType { never, onDate, afterCount }

/// Generic recurrence frequency to map into FlowRule.
enum SimpleRecurrenceFrequency { daily, weekly, monthly, yearly }

/// Explicit Gregorian dates rule (date-only). Used when customizing per decan/week.
class _RuleDates extends FlowRule {
  final Set<DateTime> dates; // store as DateUtils.dateOnly
  const _RuleDates({
    required this.dates,
    super.allDay = true,
    super.start,
    super.end,
  });
  @override
  bool matches({
    required int ky,
    required int km,
    required int kd,
    required DateTime g,
  }) {
    return dates.contains(DateUtils.dateOnly(g));
  }
}

/// A Flow (routine). Occurrences are computed on demand from rules.
class _Flow {
  int id; // assigned by app
  String? calendarId;
  String name;
  Color color;
  bool active;
  bool isSaved;
  DateTime? savedAt;
  DateTime? start; // inclusive (Gregorian local)
  DateTime? end; // inclusive (Gregorian local)
  final List<FlowRule> rules;
  String? notes; // optional description
  String? shareId; // NEW: Track original share if imported from inbox
  bool isHidden; // Client-only flag for UI filtering (repeating notes)
  bool isReminder; // Flag for reminder-backed flows
  String? reminderUuid;
  _Flow({
    required this.id,
    this.calendarId,
    required this.name,
    required this.color,
    required this.active,
    this.isSaved = false,
    this.savedAt,
    required this.rules,
    this.start,
    this.end,
    this.notes,
    this.shareId, // Optional: null for user-created flows
    this.isHidden = false, // Default to visible
    this.isReminder = false,
    this.reminderUuid,
  });
}

class _MyFlowsFilingSnapshot {
  const _MyFlowsFilingSnapshot({
    required this.flows,
    required this.activeFlowIds,
    required this.savedFlowIds,
    required this.totalEventCounts,
    required this.remainingEventCounts,
  });

  final List<_Flow> flows;
  final Set<int> activeFlowIds;
  final Set<int> savedFlowIds;
  final Map<int, int> totalEventCounts;
  final Map<int, int> remainingEventCounts;

  static const empty = _MyFlowsFilingSnapshot(
    flows: <_Flow>[],
    activeFlowIds: <int>{},
    savedFlowIds: <int>{},
    totalEventCounts: <int, int>{},
    remainingEventCounts: <int, int>{},
  );
}

typedef _MaatFlowCompletionStatus = ({double progress, String label});

/// One resolved instance of a flow on a day.
class _FlowOccurrence {
  final _Flow flow;
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;
  const _FlowOccurrence({
    required this.flow,
    required this.allDay,
    this.start,
    this.end,
  });
}

class _DaySheetScheduledFlowRow {
  final int? flowId;
  final String name;
  final Color color;
  final bool allDay;
  final TimeOfDay? start;
  final TimeOfDay? end;

  const _DaySheetScheduledFlowRow({
    required this.flowId,
    required this.name,
    required this.color,
    required this.allDay,
    this.start,
    this.end,
  });
}

class _CandidateEvent {
  final String clientEventId;
  final String title;
  final DateTime startsAtUtc;
  final DateTime? endsAtUtc;
  final String? calendarId;
  final String? detail;
  final String? location;
  final bool allDay;
  final int flowLocalId;
  final String? category;
  const _CandidateEvent({
    required this.clientEventId,
    required this.title,
    required this.startsAtUtc,
    this.endsAtUtc,
    this.calendarId,
    this.detail,
    this.location,
    required this.allDay,
    required this.flowLocalId,
    this.category,
  });
}

/// Tiny helpers
Set<int> _fullRange(int from, int to) => {for (var i = from; i <= to; i++) i};

/* ───────────────────────── KEMETIC MATH ───────────────────────── */

class KemeticMath {
  // Repeating 4-year cycle lengths starting at Year 1: [365, 365, 366, 365]
  static const List<int> _cycle = [365, 365, 366, 365];
  static const int _cycleSum = 1461; // 365*4 + 1

  static int _mod(int a, int n) => ((a % n) + n) % n;

  static int _daysBeforeYear(int kYear) {
    if (kYear == 1) return 0;
    final y = kYear - 1;

    if (y > 0) {
      final full = y ~/ 4;
      final rem = y % 4;
      var sum = full * _cycleSum;
      for (int i = 0; i < rem; i++) {
        sum += _cycle[i];
      }
      return sum;
    } else {
      final n = -y;
      final full = n ~/ 4;
      final rem = n % 4;
      var sum = full * _cycleSum;
      for (int i = 0; i < rem; i++) {
        sum += _cycle[3 - i];
      }
      return -sum;
    }
  }

  static ({int kYear, int kMonth, int kDay}) fromGregorian(DateTime gLocal) {
    // FIXED: Normalize to UTC noon first to avoid DST gaps/ambiguities
    final gUtcNoon = DateTime.utc(gLocal.year, gLocal.month, gLocal.day, 12);
    final g = toUtcDateOnly(gUtcNoon);
    final diff = epochDayFromUtc(g);

    if (diff >= 0) {
      int kYear = 1;
      int rem = diff;

      final cycles = rem ~/ _cycleSum;
      kYear += cycles * 4;
      rem -= cycles * _cycleSum;

      int idx = 0;
      while (rem >= _cycle[idx]) {
        rem -= _cycle[idx];
        kYear++;
        idx = (idx + 1) & 3;
      }

      final dayOfYear = rem;
      if (dayOfYear < 360) {
        final kMonth = (dayOfYear ~/ 30) + 1;
        final kDay = (dayOfYear % 30) + 1;
        return (kYear: kYear, kMonth: kMonth, kDay: kDay);
      } else {
        final kMonth = 13;
        final kDay = dayOfYear - 360 + 1;
        return (kYear: kYear, kMonth: kMonth, kDay: kDay);
      }
    }

    int rem = -diff - 1;
    rem %= _cycleSum;

    int year = 0;
    final rev = [_cycle[3], _cycle[2], _cycle[1], _cycle[0]];

    for (int i = 0; i < 4; i++) {
      final len = rev[i];
      if (rem < len) {
        final dayOfYear = len - 1 - rem;
        year -= i;
        if (dayOfYear < 360) {
          final kMonth = (dayOfYear ~/ 30) + 1;
          final kDay = (dayOfYear % 30) + 1;
          return (kYear: year, kMonth: kMonth, kDay: kDay);
        } else {
          final kMonth = 13;
          final kDay = dayOfYear - 360 + 1;
          return (kYear: year, kMonth: kMonth, kDay: kDay);
        }
      }
      rem -= len;
    }

    return (kYear: -3, kMonth: 13, kDay: 1);
  }

  static DateTime toGregorian(int kYear, int kMonth, int kDay) {
    if (kMonth < 1 || kMonth > 13) {
      throw ArgumentError('kMonth 1..13');
    }
    if (kMonth == 13) {
      final maxEpi = isLeapKemeticYear(kYear) ? 6 : 5;
      if (kDay < 1 || kDay > maxEpi) {
        throw ArgumentError('kDay 1..$maxEpi for epagomenal in year $kYear');
      }
    } else {
      if (kDay < 1 || kDay > 30) throw ArgumentError('kDay 1..30');
    }

    // FIXED: Use integer epoch-day arithmetic for clarity and robustness
    final base = _daysBeforeYear(kYear);
    final dayIndex = (kMonth == 13)
        ? (360 + (kDay - 1))
        : ((kMonth - 1) * 30 + (kDay - 1));
    final epochDays = base + dayIndex;
    return utcFromEpochDay(epochDays);
  }

  static bool isLeapKemeticYear(int kYear) => _mod(kYear - 1, 4) == 2;

  /// Add months to a Kemetic date, handling year rollovers and epagomenal day clamping.
  static ({int kYear, int kMonth, int kDay}) addMonths({
    required int kYear,
    required int kMonth,
    required int kDay,
    required int monthsToAdd,
  }) {
    int newYear = kYear;
    int newMonth = kMonth + monthsToAdd;

    // Handle year overflow/underflow
    while (newMonth > 13) {
      newYear += (newMonth - 1) ~/ 13;
      newMonth = ((newMonth - 1) % 13) + 1;
    }
    while (newMonth < 1) {
      newYear -= ((1 - newMonth - 1) ~/ 13) + 1;
      newMonth = 13 - ((1 - newMonth - 1) % 13);
    }

    // Clamp day to valid range for target month
    int newDay = kDay;
    if (newMonth == 13) {
      final maxEpi = isLeapKemeticYear(newYear) ? 6 : 5;
      if (newDay > maxEpi) newDay = maxEpi;
    } else {
      if (newDay > 30) newDay = 30;
    }

    return (kYear: newYear, kMonth: newMonth, kDay: newDay);
  }
}
