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
  const CalendarSectionGeometry({
    required this.month,
    required this.extent,
    this.bodyLeading,
  });

  final MonthRef month;
  final CalendarCanonicalExtent extent;

  /// Canonical leading edge of the actual month card inside [extent].
  ///
  /// Content between [extent.leading] and this coordinate is the divider and
  /// optional season header owned by this following month. It is diagnostic
  /// geometry, not a second ownership boundary.
  final double? bodyLeading;

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
            bodyLeading == other.bodyLeading;
  }

  @override
  int get hashCode => Object.hash(month, extent, bodyLeading);
}

/// Immutable, generation-tagged geometry published as one atomic value.
final class CalendarGeometrySnapshot {
  static const double boundaryTolerance = 0.000001;

  factory CalendarGeometrySnapshot({
    required int generation,
    required Iterable<CalendarSectionGeometry> sections,
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
