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

/// One Gregorian calendar month, independent of the Kemetic section domain.
final class GregorianMonthRef implements Comparable<GregorianMonthRef> {
  const GregorianMonthRef({required this.year, required this.month})
    : assert(month >= 1 && month <= 12);

  final int year;
  final int month;

  GregorianMonthRef get predecessor => month == 1
      ? GregorianMonthRef(year: year - 1, month: 12)
      : GregorianMonthRef(year: year, month: month - 1);

  GregorianMonthRef get successor => month == 12
      ? GregorianMonthRef(year: year + 1, month: 1)
      : GregorianMonthRef(year: year, month: month + 1);

  @override
  int compareTo(GregorianMonthRef other) {
    final yearOrder = year.compareTo(other.year);
    return yearOrder != 0 ? yearOrder : month.compareTo(other.month);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GregorianMonthRef &&
            year == other.year &&
            month == other.month;
  }

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'GregorianMonthRef($year-$month)';
}

/// Physical leading edge of an inline Gregorian month transition row.
final class CalendarGregorianMonthBoundary {
  const CalendarGregorianMonthBoundary({
    required this.month,
    required this.leading,
  });

  final GregorianMonthRef month;
  final double leading;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CalendarGregorianMonthBoundary &&
            month == other.month &&
            leading == other.leading;
  }

  @override
  int get hashCode => Object.hash(month, leading);
}

/// Identity of the pinned weekday sequence for one scrolling-calendar row.
///
/// Regular months expose three ten-day decan rows. Heriu Renpet has one shorter
/// day row, represented by index zero so the pinned weekday strip can use the
/// same geometry path across the year boundary.
final class CalendarWeekdayRowRef {
  const CalendarWeekdayRowRef({required this.month, required this.rowIndex});

  final MonthRef month;
  final int rowIndex;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CalendarWeekdayRowRef &&
            month == other.month &&
            rowIndex == other.rowIndex;
  }

  @override
  int get hashCode => Object.hash(month, rowIndex);

  @override
  String toString() => 'CalendarWeekdayRowRef($month, row $rowIndex)';
}

/// Physical trailing edge of a rendered day-number row.
///
/// Regular months publish the bottom of each ten-day row. Heriu Renpet
/// publishes the bottom of its sole five- or six-day row. The pinned weekday
/// strip changes at this coordinate, not at the preceding decan label.
final class CalendarWeekdayRowBoundary {
  const CalendarWeekdayRowBoundary({required this.row, required this.trailing});

  final CalendarWeekdayRowRef row;
  final double trailing;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CalendarWeekdayRowBoundary &&
            row == other.row &&
            trailing == other.trailing;
  }

  @override
  int get hashCode => Object.hash(row, trailing);
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
  const CalendarSectionGeometry({
    required this.month,
    required this.extent,
    this.bodyLeading,
    this.finalDayBlockLeading,
  });

  final MonthRef month;
  final CalendarCanonicalExtent extent;

  /// Canonical leading edge of the actual month card inside [extent].
  ///
  /// Content between [extent.leading] and this coordinate is the divider and
  /// optional season header owned by this following month. It is diagnostic
  /// geometry, not a second ownership boundary.
  final double? bodyLeading;

  /// Canonical handoff edge before this month's final visible day block.
  ///
  /// For ordinary months this is immediately after the third-decan label and
  /// before the label-to-day-grid gap. For Heriu Renpet it is the leading edge
  /// of the single epagomenal day block.
  /// Banner policy may use this physical fact as the handoff to the logical
  /// successor; section ownership itself remains [extent]-based.
  final double? finalDayBlockLeading;

  bool activationIsInLeadingInterstitial(double coordinate) {
    final body = bodyLeading;
    return body != null && extent.contains(coordinate) && coordinate < body;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CalendarSectionGeometry &&
            month == other.month &&
            extent == other.extent &&
            bodyLeading == other.bodyLeading &&
            finalDayBlockLeading == other.finalDayBlockLeading;
  }

  @override
  int get hashCode =>
      Object.hash(month, extent, bodyLeading, finalDayBlockLeading);
}

/// Immutable, generation-tagged geometry published as one atomic value.
final class CalendarGeometrySnapshot {
  static const double boundaryTolerance = 0.000001;

  factory CalendarGeometrySnapshot({
    required int generation,
    required Iterable<CalendarSectionGeometry> sections,
    Iterable<CalendarGregorianMonthBoundary> gregorianMonthBoundaries =
        const <CalendarGregorianMonthBoundary>[],
    Iterable<CalendarWeekdayRowBoundary> weekdayRowBoundaries =
        const <CalendarWeekdayRowBoundary>[],
    String? presentationRevision,
    CalendarSectionIndex index = const CalendarSectionIndex(),
  }) {
    if (generation < 0) {
      throw RangeError.value(generation, 'generation', 'must be non-negative');
    }

    final source = List<CalendarSectionGeometry>.of(sections);
    final copied = <CalendarSectionGeometry>[];
    final byMonth = <MonthRef, CalendarSectionGeometry>{};
    CalendarSectionGeometry? previous;

    for (final candidate in source) {
      if (byMonth.containsKey(candidate.month)) {
        throw ArgumentError.value(
          candidate.month,
          'sections',
          'contains a duplicate month',
        );
      }
      var current = candidate;
      final candidateBodyLeading = candidate.bodyLeading;
      final candidateFinalDayBlockLeading = candidate.finalDayBlockLeading;
      if (candidateBodyLeading != null) {
        _requireFinite(candidateBodyLeading, 'bodyLeading');
        if (candidateBodyLeading <
                candidate.extent.leading - boundaryTolerance ||
            candidateBodyLeading >= candidate.extent.trailing) {
          throw ArgumentError.value(
            candidateBodyLeading,
            'bodyLeading',
            'must lie inside the section extent ${candidate.extent}',
          );
        }
        if ((candidateBodyLeading - candidate.extent.leading).abs() <=
            boundaryTolerance) {
          current = CalendarSectionGeometry(
            month: candidate.month,
            extent: candidate.extent,
            bodyLeading: candidate.extent.leading,
            finalDayBlockLeading: candidateFinalDayBlockLeading,
          );
        }
      }
      if (candidateFinalDayBlockLeading != null) {
        _requireFinite(candidateFinalDayBlockLeading, 'finalDayBlockLeading');
        if (candidateFinalDayBlockLeading <
                candidate.extent.leading - boundaryTolerance ||
            candidateFinalDayBlockLeading >= candidate.extent.trailing) {
          throw ArgumentError.value(
            candidateFinalDayBlockLeading,
            'finalDayBlockLeading',
            'must lie inside the section extent ${candidate.extent}',
          );
        }
        if (candidateBodyLeading != null &&
            candidateFinalDayBlockLeading <
                candidateBodyLeading - boundaryTolerance) {
          throw ArgumentError.value(
            candidateFinalDayBlockLeading,
            'finalDayBlockLeading',
            'must not precede bodyLeading ($candidateBodyLeading)',
          );
        }
        if ((candidateFinalDayBlockLeading - candidate.extent.leading).abs() <=
            boundaryTolerance) {
          current = CalendarSectionGeometry(
            month: current.month,
            extent: current.extent,
            bodyLeading: current.bodyLeading,
            finalDayBlockLeading: current.extent.leading,
          );
        }
      }
      if (previous case final prior?) {
        if (index.distance(prior.month, current.month) <= 0) {
          throw ArgumentError.value(
            current.month,
            'sections',
            'logical months must be strictly chronological',
          );
        }
        final boundaryDelta = current.extent.leading - prior.extent.trailing;
        if (boundaryDelta.abs() <= boundaryTolerance) {
          final bodyLeading = current.bodyLeading;
          final finalDayBlockLeading = current.finalDayBlockLeading;
          current = CalendarSectionGeometry(
            month: current.month,
            extent: CalendarCanonicalExtent(
              leading: prior.extent.trailing,
              trailing: current.extent.trailing,
            ),
            bodyLeading:
                bodyLeading != null && bodyLeading < prior.extent.trailing
                ? prior.extent.trailing
                : bodyLeading,
            finalDayBlockLeading:
                finalDayBlockLeading != null &&
                    finalDayBlockLeading < prior.extent.trailing
                ? prior.extent.trailing
                : finalDayBlockLeading,
          );
        } else if (boundaryDelta < 0) {
          throw ArgumentError.value(
            current.extent,
            'sections',
            'physical extents must not overlap',
          );
        }
      }
      copied.add(current);
      byMonth[current.month] = current;
      previous = current;
    }

    final copiedGregorianBoundaries = <CalendarGregorianMonthBoundary>[];
    CalendarGregorianMonthBoundary? previousGregorianBoundary;
    for (final boundary in gregorianMonthBoundaries) {
      _requireFinite(boundary.leading, 'gregorianMonthBoundary.leading');
      final prior = previousGregorianBoundary;
      if (prior != null) {
        if (prior.month.compareTo(boundary.month) >= 0) {
          throw ArgumentError.value(
            boundary.month,
            'gregorianMonthBoundaries',
            'months must be strictly chronological',
          );
        }
        if (boundary.leading <= prior.leading) {
          throw ArgumentError.value(
            boundary.leading,
            'gregorianMonthBoundaries',
            'physical boundaries must be strictly increasing',
          );
        }
      }
      final isInsideMountedSection = copied.any(
        (section) => section.extent.contains(boundary.leading),
      );
      if (!isInsideMountedSection) {
        throw ArgumentError.value(
          boundary.leading,
          'gregorianMonthBoundaries',
          'must lie inside a mounted section extent',
        );
      }
      copiedGregorianBoundaries.add(boundary);
      previousGregorianBoundary = boundary;
    }

    final copiedWeekdayRowBoundaries = <CalendarWeekdayRowBoundary>[];
    CalendarWeekdayRowBoundary? previousWeekdayRowBoundary;
    for (final boundary in weekdayRowBoundaries) {
      _requireFinite(boundary.trailing, 'weekdayRowBoundary.trailing');
      final row = boundary.row;
      final maxRowIndex = row.month.month == CalendarSectionIndex.monthsPerYear
          ? 0
          : 2;
      if (row.rowIndex < 0 || row.rowIndex > maxRowIndex) {
        throw RangeError.range(
          row.rowIndex,
          0,
          maxRowIndex,
          'weekdayRowBoundary.rowIndex',
        );
      }
      final owner = byMonth[row.month];
      if (owner == null ||
          !_weekdayTrailingIsInsideSection(owner.extent, boundary.trailing)) {
        throw ArgumentError.value(
          boundary.trailing,
          'weekdayRowBoundaries',
          'must lie inside its mounted month section ${row.month}',
        );
      }
      final prior = previousWeekdayRowBoundary;
      if (prior != null) {
        final monthDistance = index.distance(prior.row.month, row.month);
        final identityIsChronological =
            monthDistance > 0 ||
            (monthDistance == 0 && prior.row.rowIndex < row.rowIndex);
        if (!identityIsChronological) {
          throw ArgumentError.value(
            row,
            'weekdayRowBoundaries',
            'rows must be strictly chronological',
          );
        }
        if (boundary.trailing <= prior.trailing) {
          throw ArgumentError.value(
            boundary.trailing,
            'weekdayRowBoundaries',
            'physical boundaries must be strictly increasing',
          );
        }
      }
      copiedWeekdayRowBoundaries.add(boundary);
      previousWeekdayRowBoundary = boundary;
    }

    return CalendarGeometrySnapshot._(
      generation: generation,
      presentationRevision: presentationRevision?.trim(),
      sections: UnmodifiableListView<CalendarSectionGeometry>(copied),
      gregorianMonthBoundaries:
          UnmodifiableListView<CalendarGregorianMonthBoundary>(
            copiedGregorianBoundaries,
          ),
      weekdayRowBoundaries: UnmodifiableListView<CalendarWeekdayRowBoundary>(
        copiedWeekdayRowBoundaries,
      ),
      byMonth: UnmodifiableMapView<MonthRef, CalendarSectionGeometry>(byMonth),
    );
  }

  const CalendarGeometrySnapshot._({
    required this.generation,
    required this.presentationRevision,
    required this.sections,
    required this.gregorianMonthBoundaries,
    required this.weekdayRowBoundaries,
    required Map<MonthRef, CalendarSectionGeometry> byMonth,
  }) : _byMonth = byMonth;

  final int generation;
  final String? presentationRevision;
  final UnmodifiableListView<CalendarSectionGeometry> sections;
  final UnmodifiableListView<CalendarGregorianMonthBoundary>
  gregorianMonthBoundaries;
  final UnmodifiableListView<CalendarWeekdayRowBoundary> weekdayRowBoundaries;
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

  /// Gregorian month owning the activation line at [coordinate].
  ///
  /// Each boundary is the leading edge of the inline row that introduces a
  /// new Gregorian month. Before the first mounted boundary, its immediate
  /// predecessor owns the line. This also covers the short Heriu Renpet
  /// section, which normally contains no Gregorian day one.
  GregorianMonthRef? gregorianMonthAt(double coordinate) {
    _requireFinite(coordinate, 'coordinate');
    if (ownerAt(coordinate) == null || gregorianMonthBoundaries.isEmpty) {
      return null;
    }

    var lower = 0;
    var upper = gregorianMonthBoundaries.length - 1;
    var precedingIndex = -1;
    while (lower <= upper) {
      final middle = lower + ((upper - lower) >> 1);
      final candidate = gregorianMonthBoundaries[middle];
      if (candidate.leading <= coordinate) {
        precedingIndex = middle;
        lower = middle + 1;
      } else {
        upper = middle - 1;
      }
    }
    return precedingIndex < 0
        ? gregorianMonthBoundaries.first.month.predecessor
        : gregorianMonthBoundaries[precedingIndex].month;
  }

  /// Weekday row whose day-number trailing edge is still ahead of [coordinate].
  ///
  /// Each published coordinate is the measured bottom of a rendered day-number
  /// row. The first row whose trailing edge is strictly greater than the
  /// activation line owns the pinned strip, so the next sequence wins at the
  /// previous row's bottom in both scroll directions. After the last mounted
  /// trailing edge, that last row remains the bootstrap until a successor is
  /// measured.
  CalendarWeekdayRowRef? weekdayRowAt(double coordinate) {
    _requireFinite(coordinate, 'coordinate');
    if (ownerAt(coordinate) == null || weekdayRowBoundaries.isEmpty) {
      return null;
    }

    var lower = 0;
    var upper = weekdayRowBoundaries.length - 1;
    var firstIndexAfter = weekdayRowBoundaries.length;
    while (lower <= upper) {
      final middle = lower + ((upper - lower) >> 1);
      final candidate = weekdayRowBoundaries[middle];
      if (candidate.trailing > coordinate) {
        firstIndexAfter = middle;
        upper = middle - 1;
      } else {
        lower = middle + 1;
      }
    }
    if (firstIndexAfter < weekdayRowBoundaries.length) {
      return weekdayRowBoundaries[firstIndexAfter].row;
    }
    return weekdayRowBoundaries.last.row;
  }
}

void _requireFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'must be finite');
  }
}

bool _weekdayTrailingIsInsideSection(
  CalendarCanonicalExtent extent,
  double trailing,
) {
  return trailing > extent.leading &&
      trailing <= extent.trailing + CalendarGeometrySnapshot.boundaryTolerance;
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
