import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_generation/itinerary_prompt_parser.dart';

void main() {
  group('parseItineraryPrompt', () {
    test('extracts the NYC itinerary without inventing guided flow copy', () {
      final result = parseItineraryPrompt(
        _nycItinerary,
        selectedStartDate: DateTime(2026, 6, 2),
        now: DateTime(2026, 6, 2),
      );

      expect(result, isNotNull);
      expect(result!.flowTitle, 'NYC Itinerary');
      expect(result.startDate, DateTime(2026, 6, 4));
      expect(result.endDate, DateTime(2026, 6, 7));
      expect(result.events, hasLength(23));
      expect(
        result.context.hotelName,
        'Embassy Suites by Hilton New York Manhattan Times Square',
      );
      expect(result.context.hotelAddress, '60 W 37th St, New York, NY 10018');
      expect(result.context.setupUrls, contains('https://omny.info/register'));

      final titles = result.events.map((event) => event.title).toList();
      expect(titles.first, 'Arrive in NYC');
      expect(titles, contains('October\u2019s Performance'));
      expect(titles, contains('Jordyn, October, and Monroe Uber to JFK'));
      expect(titles, isNot(contains('Practice mindful arrival in NYC')));
      expect(titles, isNot(contains('235 Mulberry St, New York, NY 10012')));
      expect(titles, isNot(contains('THURSDAY \u2022 JUNE 4')));
    });

    test('preserves dates times ranges addresses URLs and participants', () {
      final result = parseItineraryPrompt(
        _nycItinerary,
        selectedStartDate: DateTime(2026, 6, 2),
        now: DateTime(2026, 6, 2),
      )!;

      final performance = result.events.singleWhere(
        (event) => event.title == 'October\u2019s Performance',
      );
      expect(performance.date, DateTime(2026, 6, 6));
      expect(performance.startTime.hhmm, '12:00');
      expect(performance.endTime.hhmm, '15:00');
      expect(performance.locationName, 'Carnegie Hall');
      expect(performance.address, '881 7th Ave, New York, NY 10019');

      final airport = result.events.singleWhere(
        (event) => event.title == 'Jordyn, October, and Monroe Uber to JFK',
      );
      expect(airport.date, DateTime(2026, 6, 7));
      expect(airport.startTime.hhmm, '03:45');

      final shirokuro = result.events.singleWhere(
        (event) => event.title == 'Lunch at Shirokuro',
      );
      expect(shirokuro.address, '103 2nd Ave, New York, NY 10003');
      expect(shirokuro.urls, contains('https://yelp.to/1TU8xzuP3w'));

      final batteryWalk = result.events.singleWhere(
        (event) => event.title.startsWith('Walk Battery Park'),
      );
      expect(batteryWalk.startTime.hhmm, '18:30');
      expect(batteryWalk.endMarker, 'Sunset');
      expect(batteryWalk.address, 'Battery Pl, New York, NY 10004');
    });

    test(
      'builds an AI response that imports through the existing flow path',
      () {
        final result = parseItineraryPrompt(
          _nycItinerary,
          selectedStartDate: DateTime(2026, 6, 2),
          now: DateTime(2026, 6, 2),
        )!;

        final response = result.toAIFlowGenerationResponse(
          flowColor: '#4dd0e1',
        );
        final notes = jsonDecode(response.notes!) as List<dynamic>;

        expect(response.success, isTrue);
        expect(response.flowName, 'NYC Itinerary');
        expect(
          response.overviewSummary,
          contains('Detected: Itinerary / Schedule'),
        );
        expect(response.overviewSummary, contains('Hotel:'));
        expect(
          response.overviewSummary,
          contains('https://omny.info/register'),
        );
        expect(response.requestedStartDate, DateTime(2026, 6, 4));
        expect(response.requestedEndDate, DateTime(2026, 6, 7));
        expect(notes, hasLength(23));
        expect(
          notes.any(
            (note) =>
                note is Map &&
                note['title'] == 'Dinner at John\u2019s of Bleecker Street' &&
                (note['details'] as String).contains(
                  'https://yelp.to/lKE2Jwxkc3',
                ),
          ),
          isTrue,
        );
      },
    );

    test('keeps the generated preview in chronological order', () {
      final result = parseItineraryPrompt(
        _nycItinerary,
        selectedStartDate: DateTime(2026, 6, 2),
        now: DateTime(2026, 6, 2),
      )!;

      expect(result.events.map(_eventKey).toList(), [
        '2026-06-04 10:30 Arrive in NYC',
        '2026-06-04 12:30 Arrive/check in at hotel',
        '2026-06-04 13:30 Lunch at Rubirosa',
        '2026-06-04 16:30 Museum of Ice Cream',
        '2026-06-04 19:00 Dinner at Gayle\u2019s Broadway Rose',
        '2026-06-04 20:00 Walk Times Square',
        '2026-06-05 08:00 Free Hotel Breakfast',
        '2026-06-05 09:15 Walk around Harlem + Apollo Theater Area',
        '2026-06-05 10:30 Walk Rockefeller Center + Visit FAO Schwarz',
        '2026-06-05 14:00 Lunch at Shirokuro',
        '2026-06-05 16:00 Color Factory',
        '2026-06-05 18:30 Dinner at John\u2019s of Bleecker Street',
        '2026-06-06 07:30 Free hotel breakfast',
        '2026-06-06 09:15 October leaves for Carnegie Hall',
        '2026-06-06 10:45 October checks in for rehearsal',
        '2026-06-06 11:30 Everyone arrives at Carnegie Hall',
        '2026-06-06 12:00 October\u2019s Performance',
        '2026-06-06 16:00 Late lunch at Carmine\u2019s',
        '2026-06-06 17:45 Leave for Battery Park + Statue of Liberty View',
        '2026-06-06 18:30 Walk Battery Park, enjoy harbor views, and see the Statue of Liberty',
        '2026-06-06 19:30 Head back toward Midtown / Hotel',
        '2026-06-07 03:45 Jordyn, October, and Monroe Uber to JFK',
        '2026-06-07 08:00 Free hotel breakfast',
      ]);
    });
  });

  group('resolveItineraryDate', () {
    test(
      'uses the nearest matching upcoming year when no year is supplied',
      () {
        final date = resolveItineraryDate(
          weekday: 'Thursday',
          month: 6,
          day: 4,
          now: DateTime(2026, 6, 2),
        );

        expect(date, DateTime(2026, 6, 4));
      },
    );

    test('prefers selected start year when the weekday matches', () {
      final date = resolveItineraryDate(
        weekday: 'Friday',
        month: 6,
        day: 5,
        selectedStartDate: DateTime(2026, 6, 1),
        now: DateTime(2027, 1, 1),
      );

      expect(date, DateTime(2026, 6, 5));
    });
  });
}

String _eventKey(ItineraryEvent event) {
  final date =
      '${event.date.year.toString().padLeft(4, '0')}-'
      '${event.date.month.toString().padLeft(2, '0')}-'
      '${event.date.day.toString().padLeft(2, '0')}';
  return '$date ${event.startTime.hhmm} ${event.title}';
}

const _nycItinerary = '''
NYC ITINERARY \u2728\uD83D\uDDFD
HOTEL
Embassy Suites by Hilton New York Manhattan Times Square
60 W 37th St, New York, NY 10018
For Subway Travel Setup Metro Tap https://omny.info/register

THURSDAY \u2022 JUNE 4
10:30 AM
Arrive in NYC
12:30 PM
Arrive/check in at hotel
1:30 PM
Lunch at Rubirosa
235 Mulberry St, New York, NY 10012
4:30 PM
Museum of Ice Cream
558 Broadway, New York, NY 10012
7:00 PM
Dinner at Gayle\u2019s Broadway Rose
250 W 49th St, New York, NY 10019
8:00 PM
Walk Times Square

FRIDAY \u2022 JUNE 5
8:00 AM
Free Hotel Breakfast
9:15 AM
Walk around Harlem + Apollo Theater Area
10:30 AM
Walk Rockefeller Center + Visit FAO Schwarz
30 Rockefeller Plaza, New York, NY 10111
2:00 PM
Lunch at Shirokuro
103 2nd Ave, New York, NY 10003
https://yelp.to/1TU8xzuP3w
4:00 PM
Color Factory
251 Spring St, New York, NY 10013
6:30 PM
Dinner at John\u2019s of Bleecker Street
278 Bleecker St, New York, NY 10014
https://yelp.to/lKE2Jwxkc3

SATURDAY \u2022 JUNE 6
7:30 AM
Free hotel breakfast
9:15 AM
October leaves for Carnegie Hall
10:45 AM
October checks in for rehearsal
11:30 AM
Everyone arrives at Carnegie Hall
12:00 PM \u2013 3:00 PM
October\u2019s Performance
Carnegie Hall
881 7th Ave, New York, NY 10019
4:00 PM
Late lunch at Carmine\u2019s
https://yelp.to/pNx9V5BnLi
5:45 PM
Leave for Battery Park + Statue of Liberty View
Battery Pl, New York, NY 10004
6:30 PM \u2013 Sunset
Walk Battery Park, enjoy harbor views, and see the Statue of Liberty
7:30 PM
Head back toward Midtown / Hotel

SUNDAY \u2022 JUNE 7
3:45 AM
Jordyn, October, and Monroe Uber to JFK
8:00 AM
Free hotel breakfast
''';
