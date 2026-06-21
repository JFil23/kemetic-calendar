import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/birthday_calendar.dart';

void main() {
  group('birthday occurrence expansion', () {
    test('repeats a birthday every Gregorian year in the requested window', () {
      const item = BirthdayItem(
        id: 'birthday-1',
        userId: 'user-1',
        calendarId: 'calendar-birthdays',
        name: 'Amina',
        month: 6,
        day: 21,
        birthYear: 1990,
        alertOffsetMinutes: kBirthdayOneDayBeforeAlertMinutes,
      );

      final occurrences = expandBirthdayOccurrences(
        items: const [item],
        startUtc: DateTime.utc(2026, 1),
        endUtc: DateTime.utc(2028, 1),
      );

      expect(occurrences.map((o) => o.year), [2026, 2027]);
      expect(occurrences.map((o) => o.clientEventId), [
        'birthday:birthday-1:2026',
        'birthday:birthday-1:2027',
      ]);
      expect(occurrences.first.title, "Amina's birthday");
    });

    test('places Feb 29 birthdays on Feb 28 in non-leap years', () {
      expect(
        birthdayOccurrenceDate(year: 2024, month: 2, day: 29),
        DateTime(2024, 2, 29),
      );
      expect(
        birthdayOccurrenceDate(year: 2025, month: 2, day: 29),
        DateTime(2025, 2, 28),
      );
    });

    test('finds the next future occurrence for alert scheduling', () {
      const item = BirthdayItem(
        id: 'birthday-2',
        userId: 'user-1',
        calendarId: 'calendar-birthdays',
        name: 'Darius',
        month: 1,
        day: 3,
        alertOffsetMinutes: kBirthdayOnDayAlertMinutes,
      );

      final occurrence = nextBirthdayOccurrence(
        item: item,
        now: DateTime(2026, 1, 4),
      );

      expect(occurrence?.year, 2027);
      expect(occurrence?.localDate, DateTime(2027, 1, 3));
    });
  });
}
