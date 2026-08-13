import 'package:mobile/widgets/kemetic_date_picker.dart' show KemeticMath;

/// Stable logical identity for one of the thirteen months in a Kemetic year.
final class MonthRef implements Comparable<MonthRef> {
  factory MonthRef({required int year, required int month}) {
    if (month < 1 || month > CalendarSectionIndex.monthsPerYear) {
      throw RangeError.range(
        month,
        1,
        CalendarSectionIndex.monthsPerYear,
        'month',
      );
    }
    return MonthRef._(year: year, month: month);
  }

  const MonthRef._({required this.year, required this.month});

  final int year;
  final int month;

  @override
  int compareTo(MonthRef other) {
    final yearOrder = year.compareTo(other.year);
    return yearOrder != 0 ? yearOrder : month.compareTo(other.month);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MonthRef && year == other.year && month == other.month;
  }

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'MonthRef(year: $year, month: $month)';
}

/// A validated day identity within a logical month.
final class DayRef {
  const DayRef._({required this.month, required this.day});

  final MonthRef month;
  final int day;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DayRef && month == other.month && day == other.day;
  }

  @override
  int get hashCode => Object.hash(month, day);

  @override
  String toString() => 'DayRef(month: $month, day: $day)';
}

/// Layout-bearing pieces that are owned by a calendar month section.
///
/// Dividers and season headers are leading content: their owner is the month
/// after the boundary, never the month before it.
enum CalendarSectionPart { leadingDivider, leadingSeasonHeader, monthBody }

/// Logical identity for a piece of a month section.
final class CalendarSectionPartRef {
  const CalendarSectionPartRef({required this.owner, required this.part});

  final MonthRef owner;
  final CalendarSectionPart part;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CalendarSectionPartRef &&
            owner == other.owner &&
            part == other.part;
  }

  @override
  int get hashCode => Object.hash(owner, part);
}

/// One logical month section, including its authoritative day count.
final class CalendarSectionRef {
  const CalendarSectionRef({required this.month, required this.dayCount});

  final MonthRef month;
  final int dayCount;

  CalendarSectionPartRef part(CalendarSectionPart part) {
    return CalendarSectionPartRef(owner: month, part: part);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CalendarSectionRef &&
            month == other.month &&
            dayCount == other.dayCount;
  }

  @override
  int get hashCode => Object.hash(month, dayCount);
}

/// Pure logical index for all calendar sections.
///
/// [KemeticMath] is the sole authority for the fixed
/// `[365, 365, 366, 365]` year cycle. This index deliberately does not depend
/// on converter output, rendered children, or day-card data.
final class CalendarSectionIndex {
  const CalendarSectionIndex();

  static const int monthsPerYear = 13;
  static const int ordinaryMonthLength = 30;

  int ordinalOf(MonthRef month) {
    return month.year * monthsPerYear + (month.month - 1);
  }

  MonthRef monthAtOrdinal(int ordinal) {
    final zeroBasedMonth = ordinal % monthsPerYear;
    final year = (ordinal - zeroBasedMonth) ~/ monthsPerYear;
    return MonthRef(year: year, month: zeroBasedMonth + 1);
  }

  MonthRef successor(MonthRef month) {
    return monthAtOrdinal(ordinalOf(month) + 1);
  }

  MonthRef predecessor(MonthRef month) {
    return monthAtOrdinal(ordinalOf(month) - 1);
  }

  int distance(MonthRef from, MonthRef to) {
    return ordinalOf(to) - ordinalOf(from);
  }

  Iterable<MonthRef> rangeInclusive(MonthRef first, MonthRef last) sync* {
    final firstOrdinal = ordinalOf(first);
    final lastOrdinal = ordinalOf(last);
    if (lastOrdinal < firstOrdinal) {
      throw ArgumentError.value(last, 'last', 'must not precede $first');
    }
    for (var ordinal = firstOrdinal; ordinal <= lastOrdinal; ordinal++) {
      yield monthAtOrdinal(ordinal);
    }
  }

  int dayCount(MonthRef month) {
    if (month.month != monthsPerYear) return ordinaryMonthLength;
    return KemeticMath.isLeapKemeticYear(month.year) ? 6 : 5;
  }

  CalendarSectionRef section(MonthRef month) {
    return CalendarSectionRef(month: month, dayCount: dayCount(month));
  }

  bool isValidDay(MonthRef month, int day) {
    return day >= 1 && day <= dayCount(month);
  }

  DayRef day(MonthRef month, int day) {
    final maximum = dayCount(month);
    if (day < 1 || day > maximum) {
      throw RangeError.range(day, 1, maximum, 'day');
    }
    return DayRef._(month: month, day: day);
  }

  int normalizeDay(MonthRef month, int day) {
    return day.clamp(1, dayCount(month));
  }

  DayRef normalizedDay(MonthRef month, int day) {
    return DayRef._(month: month, day: normalizeDay(month, day));
  }

  CalendarSectionPartRef divider({
    required MonthRef before,
    required MonthRef after,
  }) {
    final expectedAfter = successor(before);
    if (after != expectedAfter) {
      throw ArgumentError.value(
        after,
        'after',
        'must immediately follow $before (expected $expectedAfter)',
      );
    }
    return CalendarSectionPartRef(
      owner: after,
      part: CalendarSectionPart.leadingDivider,
    );
  }

  CalendarSectionPartRef seasonHeader(MonthRef firstMonthInSeason) {
    return CalendarSectionPartRef(
      owner: firstMonthInSeason,
      part: CalendarSectionPart.leadingSeasonHeader,
    );
  }
}
