import 'dart:collection';

import 'package:mobile/features/calendar/calendar_section_index.dart';

/// A half-open extent in the calendar's canonical chronological coordinates.
final class CalendarCanonicalExtent {
  factory CalendarCanonicalExtent({
    required double leading,
    required double trailing,
  }) {
    _requireFinite(leading, 'leading');
    _requireFinite(trailing, 'trailing');
    if (trailing <= leading) {
      throw ArgumentError.value(
        trailing,
        'trailing',
        'must be greater than leading ($leading)',
      );
    }
    return CalendarCanonicalExtent._(leading: leading, trailing: trailing);
  }

  const CalendarCanonicalExtent._({
    required this.leading,
    required this.trailing,
  });

  final double leading;
  final double trailing;

  double get length => trailing - leading;

  bool contains(double coordinate) {
    return coordinate >= leading && coordinate < trailing;
  }

  bool intersects(CalendarCanonicalExtent other) {
    return leading < other.trailing && other.leading < trailing;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CalendarCanonicalExtent &&
            leading == other.leading &&
            trailing == other.trailing;
  }

  @override
  int get hashCode => Object.hash(leading, trailing);

  @override
  String toString() => 'CalendarCanonicalExtent([$leading, $trailing))';
}

/// Normalizes a sliver before `CustomScrollView.center`.
///
/// Before-center slivers report a non-negative [precedingScrollExtent] that
/// grows away from the center. Negating and reversing the local interval makes
/// earlier calendar content more negative while chronological order increases.
CalendarCanonicalExtent normalizePastSectionExtent({
  required double precedingScrollExtent,
  required double sectionExtent,
  double centerOrigin = 0,
}) {
  _requireNonNegativeFinite(precedingScrollExtent, 'precedingScrollExtent');
  _requirePositiveFinite(sectionExtent, 'sectionExtent');
  _requireFinite(centerOrigin, 'centerOrigin');
  return CalendarCanonicalExtent(
    leading: centerOrigin - precedingScrollExtent - sectionExtent,
    trailing: centerOrigin - precedingScrollExtent,
  );
}

/// Normalizes the center or a future sliver into canonical coordinates.
CalendarCanonicalExtent normalizeCenterOrFutureSectionExtent({
  required double precedingScrollExtent,
  required double sectionExtent,
  double centerOrigin = 0,
}) {
  _requireNonNegativeFinite(precedingScrollExtent, 'precedingScrollExtent');
  _requirePositiveFinite(sectionExtent, 'sectionExtent');
  _requireFinite(centerOrigin, 'centerOrigin');
  return CalendarCanonicalExtent(
    leading: centerOrigin + precedingScrollExtent,
    trailing: centerOrigin + precedingScrollExtent + sectionExtent,
  );
}

/// Physical geometry for one mounted logical month section.
final class CalendarSectionGeometry {
  const CalendarSectionGeometry({required this.month, required this.extent});

  final MonthRef month;
  final CalendarCanonicalExtent extent;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CalendarSectionGeometry &&
            month == other.month &&
            extent == other.extent;
  }

  @override
  int get hashCode => Object.hash(month, extent);
}

/// Immutable, generation-tagged geometry published as one atomic value.
final class CalendarGeometrySnapshot {
  factory CalendarGeometrySnapshot({
    required int generation,
    required Iterable<CalendarSectionGeometry> sections,
    CalendarSectionIndex index = const CalendarSectionIndex(),
  }) {
    if (generation < 0) {
      throw RangeError.value(generation, 'generation', 'must be non-negative');
    }

    final copied = List<CalendarSectionGeometry>.of(sections);
    final byMonth = <MonthRef, CalendarSectionGeometry>{};
    CalendarSectionGeometry? previous;

    for (final current in copied) {
      if (byMonth.containsKey(current.month)) {
        throw ArgumentError.value(
          current.month,
          'sections',
          'contains a duplicate month',
        );
      }
      if (previous case final prior?) {
        if (index.distance(prior.month, current.month) <= 0) {
          throw ArgumentError.value(
            current.month,
            'sections',
            'logical months must be strictly chronological',
          );
        }
        if (current.extent.leading < prior.extent.trailing) {
          throw ArgumentError.value(
            current.extent,
            'sections',
            'physical extents must not overlap',
          );
        }
      }
      byMonth[current.month] = current;
      previous = current;
    }

    return CalendarGeometrySnapshot._(
      generation: generation,
      sections: UnmodifiableListView<CalendarSectionGeometry>(copied),
      byMonth: UnmodifiableMapView<MonthRef, CalendarSectionGeometry>(byMonth),
    );
  }

  const CalendarGeometrySnapshot._({
    required this.generation,
    required this.sections,
    required Map<MonthRef, CalendarSectionGeometry> byMonth,
  }) : _byMonth = byMonth;

  final int generation;
  final UnmodifiableListView<CalendarSectionGeometry> sections;
  final Map<MonthRef, CalendarSectionGeometry> _byMonth;

  CalendarSectionGeometry? geometryFor(MonthRef month) => _byMonth[month];

  MonthRef? ownerAt(double coordinate) {
    _requireFinite(coordinate, 'coordinate');
    var lower = 0;
    var upper = sections.length - 1;
    while (lower <= upper) {
      final middle = lower + ((upper - lower) >> 1);
      final candidate = sections[middle];
      if (coordinate < candidate.extent.leading) {
        upper = middle - 1;
      } else if (coordinate >= candidate.extent.trailing) {
        lower = middle + 1;
      } else {
        return candidate.month;
      }
    }
    return null;
  }
}

void _requireFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'must be finite');
  }
}

void _requireNonNegativeFinite(double value, String name) {
  _requireFinite(value, name);
  if (value < 0) {
    throw RangeError.value(value, name, 'must be non-negative');
  }
}

void _requirePositiveFinite(double value, String name) {
  _requireFinite(value, name);
  if (value <= 0) {
    throw RangeError.value(value, name, 'must be positive');
  }
}
