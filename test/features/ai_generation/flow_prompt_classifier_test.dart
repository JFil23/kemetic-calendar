import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_generation/flow_prompt_classifier.dart';

void main() {
  group('classifyFlowPrompt', () {
    test('detects a dense NYC itinerary with dates times and addresses', () {
      const prompt = '''
NYC ITINERARY
HOTEL
Embassy Suites by Hilton New York Manhattan Times Square
60 W 37th St, New York, NY 10018

THURSDAY JUNE 4
10:30 AM Arrive in NYC
12:30 PM Arrive/check in at hotel
1:30 PM Lunch at Rubirosa
235 Mulberry St, New York, NY 10012
''';

      expect(classifyFlowPrompt(prompt), FlowPromptType.itinerarySchedule);
    });

    test('detects the NYC itinerary when pasted as one dense line', () {
      final prompt =
          '''
NYC ITINERARY
HOTEL
Embassy Suites by Hilton New York Manhattan Times Square
60 W 37th St, New York, NY 10018
For Subway Travel Setup Metro Tap https://omny.info/register
THURSDAY JUNE 4
10:30 AM Arrive in NYC
12:30 PM Arrive/check in at hotel
1:30 PM Lunch at Rubirosa
235 Mulberry St, New York, NY 10012
4:30 PM Museum of Ice Cream
558 Broadway, New York, NY 10012
FRIDAY JUNE 5
8:00 AM Free Hotel Breakfast
9:15 AM Walk around Harlem
'''
              .split('\n')
              .map((line) => line.trim())
              .join(' ');

      expect(classifyFlowPrompt(prompt), FlowPromptType.itinerarySchedule);
    });

    test('detects a wedding weekend schedule without month dates', () {
      const prompt = '''
Wedding weekend schedule
FRIDAY
5:00 PM Rehearsal
7:00 PM Welcome dinner
SATURDAY
2:00 PM Ceremony
5:30 PM Reception
SUNDAY
10:00 AM Farewell brunch
''';

      expect(classifyFlowPrompt(prompt), FlowPromptType.itinerarySchedule);
    });

    test('detects a conference agenda with sessions and room names', () {
      const prompt = '''
Conference agenda
Monday June 8
9:00 AM Opening keynote
10:15 AM Product track - Room A
1:30 PM Workshop - Room C
Tuesday June 9
9:30 AM Customer panel
11:00 AM Closing session
''';

      expect(classifyFlowPrompt(prompt), FlowPromptType.itinerarySchedule);
    });

    test('detects a school field trip schedule from dense time blocks', () {
      const prompt = '''
School field trip schedule
Wed 5/20
8:30 AM Bus leaves school
9:15 AM Museum arrival
10:00 AM Guided tour
12:00 PM Lunch
1:30 PM Bus returns
''';

      expect(classifyFlowPrompt(prompt), FlowPromptType.itinerarySchedule);
    });

    test('does not classify a Maat guided request as an itinerary', () {
      const prompt = 'Create a 10-day Ma\u2019at flow for grounding.';

      expect(classifyFlowPrompt(prompt), FlowPromptType.maatGuidedFlow);
    });

    test(
      'does not classify a math learning flow with one time as itinerary',
      () {
        const prompt = 'Create a 30-day math flow for my son at 9 AM.';

        expect(classifyFlowPrompt(prompt), FlowPromptType.studyLearning);
      },
    );

    test('keeps a one-day morning routine out of itinerary mode', () {
      const prompt =
          'I want a morning routine: 6 AM wake, 6:30 AM workout, 7 AM breakfast.';

      expect(classifyFlowPrompt(prompt), FlowPromptType.routineHabit);
    });

    test('preserves explicit edit prompts as editExistingFlow', () {
      const prompt = 'Edit this flow and move the 9 AM event to 10 AM.';

      expect(classifyFlowPrompt(prompt), FlowPromptType.editExistingFlow);
    });
  });
}
