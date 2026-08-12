import 'package:flutter/foundation.dart';

@immutable
class CalendarMonthViewportBounds {
  const CalendarMonthViewportBounds({
    required this.kYear,
    required this.kMonth,
    required this.top,
    required this.bottom,
  });

  final int kYear;
  final int kMonth;
  final double top;
  final double bottom;
}

@immutable
class CalendarVisibleMonthRange {
  const CalendarVisibleMonthRange({
    required this.firstKYear,
    required this.firstKMonth,
    required this.lastKYear,
    required this.lastKMonth,
  });

  final int firstKYear;
  final int firstKMonth;
  final int lastKYear;
  final int lastKMonth;
}

/// Returns every Kemetic month intersecting the viewport, collapsed to the
/// earliest/latest chronological month. Touching an edge without occupying a
/// visible pixel is not an intersection.
CalendarVisibleMonthRange? visibleKemeticMonthRange({
  required double viewportTop,
  required double viewportBottom,
  required Iterable<CalendarMonthViewportBounds> mountedMonths,
}) {
  if (viewportBottom <= viewportTop) return null;
  final visible =
      mountedMonths
          .where(
            (month) => month.bottom > viewportTop && month.top < viewportBottom,
          )
          .toList(growable: false)
        ..sort((a, b) {
          final yearOrder = a.kYear.compareTo(b.kYear);
          return yearOrder != 0 ? yearOrder : a.kMonth.compareTo(b.kMonth);
        });
  if (visible.isEmpty) return null;
  return CalendarVisibleMonthRange(
    firstKYear: visible.first.kYear,
    firstKMonth: visible.first.kMonth,
    lastKYear: visible.last.kYear,
    lastKMonth: visible.last.kMonth,
  );
}
