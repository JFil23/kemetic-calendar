import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/calendar_section_index.dart';

void main() {
  const index = CalendarSectionIndex();

  group('MonthRef', () {
    test('accepts all thirteen stable month identities', () {
      final months = [
        for (var month = 1; month <= 13; month++)
          MonthRef(year: 42, month: month),
      ];

      expect(
        months.map((month) => month.month),
        orderedEquals(List<int>.generate(13, (index) => index + 1)),
      );
      expect(months.toSet(), hasLength(13));
    });

    test('rejects identities outside months 1 through 13', () {
      expect(() => MonthRef(year: 1, month: 0), throwsRangeError);
      expect(() => MonthRef(year: 1, month: 14), throwsRangeError);
    });

    test('orders by year and then month', () {
      final values = [
        MonthRef(year: 1, month: 13),
        MonthRef(year: 0, month: 13),
        MonthRef(year: 1, month: 1),
      ]..sort();

      expect(
        values,
        orderedEquals([
          MonthRef(year: 0, month: 13),
          MonthRef(year: 1, month: 1),
          MonthRef(year: 1, month: 13),
        ]),
      );
    });
  });

  group('CalendarSectionIndex chronology', () {
    test('round-trips ordinals on both sides of year zero', () {
      for (var ordinal = -80; ordinal <= 80; ordinal++) {
        expect(index.ordinalOf(index.monthAtOrdinal(ordinal)), ordinal);
      }
    });

    test('crosses month 12, Heriu, and next-year month 1 in order', () {
      final month12 = MonthRef(year: 8, month: 12);
      final heriu = index.successor(month12);
      final nextYear = index.successor(heriu);

      expect(heriu, MonthRef(year: 8, month: 13));
      expect(nextYear, MonthRef(year: 9, month: 1));
      expect(index.predecessor(nextYear), heriu);
      expect(index.distance(month12, nextYear), 2);
    });

    test('crosses year zero without truncating negative ordinals', () {
      final lastBeforeZero = MonthRef(year: -1, month: 13);
      final firstAtZero = MonthRef(year: 0, month: 1);

      expect(index.successor(lastBeforeZero), firstAtZero);
      expect(index.predecessor(firstAtZero), lastBeforeZero);
      expect(index.monthAtOrdinal(-1), lastBeforeZero);
    });

    test('builds inclusive chronological ranges', () {
      expect(
        index.rangeInclusive(
          MonthRef(year: 2, month: 12),
          MonthRef(year: 3, month: 2),
        ),
        orderedEquals([
          MonthRef(year: 2, month: 12),
          MonthRef(year: 2, month: 13),
          MonthRef(year: 3, month: 1),
          MonthRef(year: 3, month: 2),
        ]),
      );
    });
  });

  group('authoritative day validity', () {
    test('uses the fixed 365, 365, 366, 365 KemeticMath cycle', () {
      final yearLengths = [
        for (var year = 1; year <= 8; year++)
          List.generate(
            13,
            (month) => index.dayCount(MonthRef(year: year, month: month + 1)),
          ).fold<int>(0, (sum, length) => sum + length),
      ];

      expect(
        yearLengths,
        orderedEquals([365, 365, 366, 365, 365, 365, 366, 365]),
      );
    });

    test('accepts Heriu day 6 only in the six-day year', () {
      final fiveDayHeriu = MonthRef(year: 2, month: 13);
      final sixDayHeriu = MonthRef(year: 3, month: 13);

      expect(index.dayCount(fiveDayHeriu), 5);
      expect(index.dayCount(sixDayHeriu), 6);
      expect(index.isValidDay(fiveDayHeriu, 6), isFalse);
      expect(index.isValidDay(sixDayHeriu, 6), isTrue);
      expect(() => index.day(fiveDayHeriu, 6), throwsRangeError);
      expect(index.day(sixDayHeriu, 6).day, 6);
    });

    test('normalizes restored days against the target section', () {
      expect(index.normalizedDay(MonthRef(year: 2, month: 13), 30).day, 5);
      expect(index.normalizedDay(MonthRef(year: 3, month: 13), 30).day, 6);
      expect(index.normalizedDay(MonthRef(year: 3, month: 1), 31).day, 30);
      expect(index.normalizedDay(MonthRef(year: 3, month: 1), 0).day, 1);
    });

    test('geometry domain never calls KemeticConverter', () {
      final source = File(
        'lib/features/calendar/calendar_section_index.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('KemeticConverter')));
      expect(source, contains('KemeticMath.isLeapKemeticYear'));
    });
  });

  group('leading section ownership', () {
    test('divider belongs to Heriu rather than month 12', () {
      final owner = index.divider(
        before: MonthRef(year: 6, month: 12),
        after: MonthRef(year: 6, month: 13),
      );

      expect(owner.owner, MonthRef(year: 6, month: 13));
      expect(owner.part, CalendarSectionPart.leadingDivider);
    });

    test('year-boundary divider and Akhet header belong to next Thoth', () {
      final thoth = MonthRef(year: 7, month: 1);
      final divider = index.divider(
        before: MonthRef(year: 6, month: 13),
        after: thoth,
      );
      final seasonHeader = index.seasonHeader(thoth);

      expect(divider.owner, thoth);
      expect(seasonHeader.owner, thoth);
      expect(seasonHeader.part, CalendarSectionPart.leadingSeasonHeader);
    });

    test('rejects a divider between non-adjacent months', () {
      expect(
        () => index.divider(
          before: MonthRef(year: 6, month: 12),
          after: MonthRef(year: 7, month: 1),
        ),
        throwsArgumentError,
      );
    });
  });
}
