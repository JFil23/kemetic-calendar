import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/ics_parser.dart';

void main() {
  group('IcsParser.parseString', () {
    test('parses timezone-parameterized DTSTART keys', () {
      final events = IcsParser.parseString('''
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:Morning Ritual
DTSTART;TZID=America/New_York:20260415T090000
DTEND;TZID=America/New_York:20260415T093000
LOCATION:Temple
END:VEVENT
END:VCALENDAR
''');

      expect(events, hasLength(1));
      expect(events.first.title, 'Morning Ritual');
      expect(events.first.startTime.year, 2026);
      expect(events.first.startTime.month, 4);
      expect(events.first.startTime.day, 15);
      expect(events.first.startTime.hour, 9);
      expect(events.first.isAllDay, isFalse);
    });

    test('parses all-day VALUE=DATE events', () {
      final events = IcsParser.parseString('''
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:Festival Day
DTSTART;VALUE=DATE:20260415
DTEND;VALUE=DATE:20260416
END:VEVENT
END:VCALENDAR
''');

      expect(events, hasLength(1));
      expect(events.first.isAllDay, isTrue);
      expect(events.first.startTime, DateTime(2026, 4, 15));
      expect(events.first.endTime, DateTime(2026, 4, 16));
    });

    test('unfolds folded lines and decodes escaped text', () {
      final events = IcsParser.parseString(r'''
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:Shared Meal
DTSTART:20260415T180000
DESCRIPTION:Bring fruit\, water\, and tea.\nContinue in stillness
 folded guidance here.
END:VEVENT
END:VCALENDAR
''');

      expect(events, hasLength(1));
      expect(
        events.first.description,
        'Bring fruit, water, and tea.\nContinue in stillnessfolded guidance here.',
      );
    });
  });
}
