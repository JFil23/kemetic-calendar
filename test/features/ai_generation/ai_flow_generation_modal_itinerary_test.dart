import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_generation/ai_flow_generation_modal.dart';
import 'package:mobile/models/ai_flow_generation_response.dart';

void main() {
  testWidgets(
    'NYC itinerary imports locally and never invokes AIFlowService.generate',
    (tester) async {
      var generateCalls = 0;
      final debugLogs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) debugLogs.add(message);
      };

      late final AIFlowGenerationResponse? result;
      try {
        result = await _runModal(
          tester,
          prompt: _nycItineraryOneLine,
          generateFlowForTesting:
              ({
                required description,
                required startDate,
                required endDate,
                flowColor,
                timezone,
                sourceText,
              }) async {
                generateCalls += 1;
                throw StateError('generic AI generation should not run');
              },
        );
      } finally {
        debugPrint = originalDebugPrint;
      }

      expect(generateCalls, 0);
      expect(result, isNotNull);
      expect(result!.flowName, 'NYC Itinerary');
      expect(result.requestedStartDate, DateTime(2026, 6, 4));
      expect(result.requestedEndDate, DateTime(2026, 6, 7));

      final notes = jsonDecode(result.notes!) as List<dynamic>;
      expect(notes, hasLength(23));
      expect(
        notes.any(
          (note) =>
              note is Map &&
              note['title'] == 'Jordyn, October, and Monroe Uber to JFK' &&
              note['start_time'] == '03:45',
        ),
        isTrue,
      );

      expect(debugLogs, contains('[AI Modal] promptType=itinerarySchedule'));
      expect(
        debugLogs,
        contains(
          '[AI Modal] using deterministic itinerary import events=23 range=2026-06-04..2026-06-07',
        ),
      );
      expect(
        debugLogs.any(
          (line) => line.contains('About to call _service.generate'),
        ),
        isFalse,
      );
    },
  );

  testWidgets('non-itinerary prompts still use generic AI generation', (
    tester,
  ) async {
    var generateCalls = 0;

    final result = await _runModal(
      tester,
      prompt: 'Create a 10-day Ma\u2019at flow for grounding.',
      generateFlowForTesting:
          ({
            required description,
            required startDate,
            required endDate,
            flowColor,
            timezone,
            sourceText,
          }) async {
            generateCalls += 1;
            return AIFlowGenerationResponse(
              success: true,
              flowName: 'Grounding Flow',
              flowColor: flowColor,
              notes: '[]',
              notesCount: 0,
            );
          },
    );

    expect(generateCalls, 1);
    expect(result, isNotNull);
    expect(result!.flowName, 'Grounding Flow');
    expect(result.requestedStartDate, DateTime(2026, 6, 2));
    expect(result.requestedEndDate, DateTime(2026, 6, 11));
  });
}

Future<AIFlowGenerationResponse?> _runModal(
  WidgetTester tester, {
  required String prompt,
  required AIFlowGenerateCallback generateFlowForTesting,
}) async {
  final completer = Completer<AIFlowGenerationResponse?>();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showModalBottomSheet<AIFlowGenerationResponse>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AIFlowGenerationModal(
                    initialStartDate: DateTime(2026, 6, 2),
                    generateFlowForTesting: generateFlowForTesting,
                  ),
                ).then(completer.complete);
              },
              child: const Text('Open modal'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open modal'));
  await tester.pumpAndSettle();
  expect(find.text('Gregorian'), findsOneWidget);

  await tester.enterText(find.byType(TextFormField), prompt);
  await tester.pump();

  await tester.ensureVisible(find.text('Generate Flow'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Generate Flow'));
  await tester.pumpAndSettle();

  return completer.future.timeout(const Duration(seconds: 1));
}

const _nycItineraryOneLine =
    'NYC ITINERARY \u2728\uD83D\uDDFD HOTEL Embassy Suites by Hilton New York Manhattan Times Square '
    '60 W 37th St, New York, NY 10018 For Subway Travel Setup Metro Tap https://omny.info/register '
    'THURSDAY \u2022 JUNE 4 10:30 AM Arrive in NYC 12:30 PM Arrive/check in at hotel '
    '1:30 PM Lunch at Rubirosa 235 Mulberry St, New York, NY 10012 '
    '4:30 PM Museum of Ice Cream 558 Broadway, New York, NY 10012 '
    '7:00 PM Dinner at Gayle\u2019s Broadway Rose 250 W 49th St, New York, NY 10019 '
    '8:00 PM Walk Times Square FRIDAY \u2022 JUNE 5 8:00 AM Free Hotel Breakfast '
    '9:15 AM Walk around Harlem + Apollo Theater Area '
    '10:30 AM Walk Rockefeller Center + Visit FAO Schwarz 30 Rockefeller Plaza, New York, NY 10111 '
    '2:00 PM Lunch at Shirokuro 103 2nd Ave, New York, NY 10003 https://yelp.to/1TU8xzuP3w '
    '4:00 PM Color Factory 251 Spring St, New York, NY 10013 '
    '6:30 PM Dinner at John\u2019s of Bleecker Street 278 Bleecker St, New York, NY 10014 https://yelp.to/lKE2Jwxkc3 '
    'SATURDAY \u2022 JUNE 6 7:30 AM Free hotel breakfast '
    '9:15 AM October leaves for Carnegie Hall 10:45 AM October checks in for rehearsal '
    '11:30 AM Everyone arrives at Carnegie Hall 12:00 PM \u2013 3:00 PM October\u2019s Performance '
    'Carnegie Hall 881 7th Ave, New York, NY 10019 4:00 PM Late lunch at Carmine\u2019s https://yelp.to/pNx9V5BnLi '
    '5:45 PM Leave for Battery Park + Statue of Liberty View Battery Pl, New York, NY 10004 '
    '6:30 PM \u2013 Sunset Walk Battery Park, enjoy harbor views, and see the Statue of Liberty '
    '7:30 PM Head back toward Midtown / Hotel SUNDAY \u2022 JUNE 7 '
    '3:45 AM Jordyn, October, and Monroe Uber to JFK 8:00 AM Free hotel breakfast';
