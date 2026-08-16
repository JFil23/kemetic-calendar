import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_geometry_snapshot.dart';
import 'package:mobile/features/calendar/calendar_section_index.dart';

void main() {
  group('canonical coordinate normalization', () {
    test('normalizes the nearest past section against center zero', () {
      final extent = normalizePastSectionExtent(
        precedingScrollExtent: 0,
        sectionExtent: 120,
      );

      expect(extent.leading, -120);
      expect(extent.trailing, 0);
    });

    test('reverses accumulated past extents into chronological order', () {
      final nearest = normalizePastSectionExtent(
        precedingScrollExtent: 0,
        sectionExtent: 120,
      );
      final earlier = normalizePastSectionExtent(
        precedingScrollExtent: 120,
        sectionExtent: 80,
      );

      expect(earlier, _extent(-200, -120));
      expect(nearest, _extent(-120, 0));
      expect(earlier.trailing, nearest.leading);
      expect(earlier.leading, lessThan(nearest.leading));
    });

    test('joins past, center, and future in one monotonic domain', () {
      final past = normalizePastSectionExtent(
        precedingScrollExtent: 0,
        sectionExtent: 75,
      );
      final center = normalizeCenterOrFutureSectionExtent(
        precedingScrollExtent: 0,
        sectionExtent: 100,
      );
      final future = normalizeCenterOrFutureSectionExtent(
        precedingScrollExtent: 100,
        sectionExtent: 125,
      );

      expect(past, _extent(-75, 0));
      expect(center, _extent(0, 100));
      expect(future, _extent(100, 225));
    });

    test('rejects non-physical normalization inputs', () {
      expect(
        () => normalizePastSectionExtent(
          precedingScrollExtent: -1,
          sectionExtent: 10,
        ),
        throwsRangeError,
      );
      expect(
        () => normalizePastSectionExtent(
          precedingScrollExtent: 0,
          sectionExtent: 0,
        ),
        throwsRangeError,
      );
      expect(
        () => normalizeCenterOrFutureSectionExtent(
          precedingScrollExtent: double.infinity,
          sectionExtent: 10,
        ),
        throwsArgumentError,
      );
    });
  });

  group('CalendarCanonicalExtent', () {
    test('uses half-open edge ownership', () {
      final extent = _extent(10, 20);

      expect(extent.contains(10), isTrue);
      expect(extent.contains(19.999), isTrue);
      expect(extent.contains(20), isFalse);
    });

    test('edge-only contact is not an intersection', () {
      expect(_extent(0, 10).intersects(_extent(10, 20)), isFalse);
      expect(_extent(0, 10).intersects(_extent(9, 20)), isTrue);
    });
  });

  group('CalendarGeometrySnapshot', () {
    test('is immutable, generation-tagged, and boundary deterministic', () {
      final source = <CalendarSectionGeometry>[
        _geometry(4, 12, -100, 0),
        _geometry(4, 13, 0, 25),
        _geometry(5, 1, 25, 125),
      ];
      final snapshot = CalendarGeometrySnapshot(
        generation: 7,
        sections: source,
      );
      source.clear();

      expect(snapshot.generation, 7);
      expect(snapshot.sections, hasLength(3));
      expect(snapshot.ownerAt(-0.001), MonthRef(year: 4, month: 12));
      expect(snapshot.ownerAt(0), MonthRef(year: 4, month: 13));
      expect(snapshot.ownerAt(25), MonthRef(year: 5, month: 1));
      expect(
        () => snapshot.sections.add(_geometry(5, 2, 125, 225)),
        throwsUnsupportedError,
      );
    });

    test('allows unmounted gaps and returns no invented owner inside them', () {
      final snapshot = CalendarGeometrySnapshot(
        generation: 1,
        sections: [_geometry(1, 1, 0, 100), _geometry(1, 3, 200, 300)],
      );

      expect(snapshot.ownerAt(150), isNull);
      expect(snapshot.ownerAt(250), MonthRef(year: 1, month: 3));
    });

    test('resolves Gregorian months at their measured inline boundaries', () {
      const may = GregorianMonthRef(year: 2026, month: 5);
      const june = GregorianMonthRef(year: 2026, month: 6);
      final snapshot = CalendarGeometrySnapshot(
        generation: 1,
        sections: [_geometry(1, 1, 0, 100), _geometry(1, 2, 100, 200)],
        gregorianMonthBoundaries: const [
          CalendarGregorianMonthBoundary(month: may, leading: 40),
          CalendarGregorianMonthBoundary(month: june, leading: 140),
        ],
      );

      expect(
        snapshot.gregorianMonthAt(0),
        const GregorianMonthRef(year: 2026, month: 4),
      );
      expect(snapshot.gregorianMonthAt(39.999), may.predecessor);
      expect(snapshot.gregorianMonthAt(40), may);
      expect(snapshot.gregorianMonthAt(139.999), may);
      expect(snapshot.gregorianMonthAt(140), june);
    });

    test('does not invent a Gregorian month inside an unmounted gap', () {
      final snapshot = CalendarGeometrySnapshot(
        generation: 1,
        sections: [_geometry(1, 1, 0, 100), _geometry(1, 3, 200, 300)],
        gregorianMonthBoundaries: const [
          CalendarGregorianMonthBoundary(
            month: GregorianMonthRef(year: 2026, month: 5),
            leading: 40,
          ),
        ],
      );

      expect(snapshot.gregorianMonthAt(150), isNull);
    });

    test('rejects invalid Gregorian boundary order and placement', () {
      const may = GregorianMonthRef(year: 2026, month: 5);
      const june = GregorianMonthRef(year: 2026, month: 6);
      final sections = [_geometry(1, 1, 0, 100)];

      expect(
        () => CalendarGeometrySnapshot(
          generation: 1,
          sections: sections,
          gregorianMonthBoundaries: const [
            CalendarGregorianMonthBoundary(month: june, leading: 20),
            CalendarGregorianMonthBoundary(month: may, leading: 40),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => CalendarGeometrySnapshot(
          generation: 1,
          sections: sections,
          gregorianMonthBoundaries: const [
            CalendarGregorianMonthBoundary(month: may, leading: 100),
          ],
        ),
        throwsArgumentError,
      );
    });

    test(
      'identifies following-month interstitial without changing ownership',
      () {
        final month = MonthRef(year: 1, month: 2);
        final snapshot = CalendarGeometrySnapshot(
          generation: 1,
          sections: [
            CalendarSectionGeometry(
              month: month,
              extent: _extent(100, 200),
              bodyLeading: 130,
            ),
          ],
        );
        final geometry = snapshot.geometryFor(month)!;

        expect(snapshot.ownerAt(110), month);
        expect(geometry.activationIsInLeadingInterstitial(110), isTrue);
        expect(geometry.activationIsInLeadingInterstitial(130), isFalse);
      },
    );

    test('retains final-day-block handoff geometry without changing owner', () {
      final month = MonthRef(year: 1, month: 2);
      final snapshot = CalendarGeometrySnapshot(
        generation: 1,
        sections: [
          CalendarSectionGeometry(
            month: month,
            extent: _extent(100, 200),
            bodyLeading: 120,
            finalDayBlockLeading: 170,
          ),
        ],
      );
      final geometry = snapshot.geometryFor(month)!;

      expect(snapshot.ownerAt(170), month);
      expect(geometry.finalDayBlockLeading, 170);
    });

    test('canonicalizes only floating-point drift at adjacent boundaries', () {
      final snapshot = CalendarGeometrySnapshot(
        generation: 1,
        sections: [
          _geometry(1, 1, 0, 100.0000000000003),
          _geometry(1, 2, 100, 200),
        ],
      );

      expect(snapshot.sections[1].extent.leading, 100.0000000000003);
      expect(
        snapshot.sections[0].extent.trailing,
        snapshot.sections[1].extent.leading,
      );
      expect(snapshot.ownerAt(100.0000000000003), MonthRef(year: 1, month: 2));
    });

    test('rejects duplicate, reversed, and overlapping entries', () {
      expect(
        () => CalendarGeometrySnapshot(
          generation: 1,
          sections: [_geometry(1, 1, 0, 100), _geometry(1, 1, 100, 200)],
        ),
        throwsArgumentError,
      );
      expect(
        () => CalendarGeometrySnapshot(
          generation: 1,
          sections: [_geometry(1, 1, 0, 100), _geometry(1, 2, 99.999, 200)],
        ),
        throwsArgumentError,
      );
      expect(
        () => CalendarGeometrySnapshot(
          generation: 1,
          sections: [_geometry(1, 2, 0, 100), _geometry(1, 1, 100, 200)],
        ),
        throwsArgumentError,
      );
      expect(
        () => CalendarGeometrySnapshot(
          generation: 1,
          sections: [_geometry(1, 1, 0, 100), _geometry(1, 2, 99, 200)],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a month-body boundary outside its section', () {
      expect(
        () => CalendarGeometrySnapshot(
          generation: 1,
          sections: [
            CalendarSectionGeometry(
              month: MonthRef(year: 1, month: 1),
              extent: _extent(0, 100),
              bodyLeading: 101,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects an invalid final-day-block handoff edge', () {
      expect(
        () => CalendarGeometrySnapshot(
          generation: 1,
          sections: [
            CalendarSectionGeometry(
              month: MonthRef(year: 1, month: 1),
              extent: _extent(0, 100),
              finalDayBlockLeading: 100,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => CalendarGeometrySnapshot(
          generation: 1,
          sections: [
            CalendarSectionGeometry(
              month: MonthRef(year: 1, month: 1),
              extent: _extent(0, 100),
              bodyLeading: 30,
              finalDayBlockLeading: 20,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative generation', () {
      expect(
        () => CalendarGeometrySnapshot(generation: -1, sections: const []),
        throwsRangeError,
      );
    });
  });
}

CalendarCanonicalExtent _extent(num leading, num trailing) {
  return CalendarCanonicalExtent(
    leading: leading.toDouble(),
    trailing: trailing.toDouble(),
  );
}

CalendarSectionGeometry _geometry(
  int year,
  int month,
  num leading,
  num trailing,
) {
  return CalendarSectionGeometry(
    month: MonthRef(year: year, month: month),
    extent: _extent(leading, trailing),
  );
}
