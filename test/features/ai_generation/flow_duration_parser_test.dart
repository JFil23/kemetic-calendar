import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_generation/flow_duration_parser.dart';

void main() {
  group('extractFlowDurationDays', () {
    test('detects 90 day flow prompts', () {
      expect(extractFlowDurationDays('make this a 90 day flow'), 90);
    });

    test('detects hyphenated 30-day flow prompts', () {
      expect(extractFlowDurationDays('turn this into a 30-day flow'), 30);
    });

    test('detects day counts embedded in natural requests', () {
      expect(extractFlowDurationDays('create a 10 day practice'), 10);
      expect(extractFlowDurationDays('I want this over 7 days'), 7);
    });

    test('converts weeks to days', () {
      expect(extractFlowDurationDays('give me 2 weeks'), 14);
      expect(extractFlowDurationDays('make a 3-week practice'), 21);
    });

    test('ignores prompts with no duration', () {
      expect(extractFlowDurationDays('create a steady practice'), isNull);
    });
  });

  group('resolveAiFlowDateRange', () {
    final start = DateTime(2026, 6, 2);

    test('prompt with 90 day flow auto-selects a 90-day range', () {
      final range = resolveAiFlowDateRange(
        prompt: 'make this a 90 day flow',
        defaultStartDate: start,
      );

      expect(range.source, FlowDateRangeSource.prompt);
      expect(range.startDate, start);
      expect(range.endDate, DateTime(2026, 6, 2 + 89));
      expect(range.endDate.difference(range.startDate).inDays + 1, 90);
    });

    test('prompt with 30-day flow auto-selects a 30-day range', () {
      final range = resolveAiFlowDateRange(
        prompt: 'turn this into a 30-day flow',
        defaultStartDate: start,
      );

      expect(range.source, FlowDateRangeSource.prompt);
      expect(range.endDate, DateTime(2026, 6, 2 + 29));
      expect(range.durationDays, 30);
    });

    test('prompt with 2 weeks auto-selects a 14-day range', () {
      final range = resolveAiFlowDateRange(
        prompt: 'give me 2 weeks',
        defaultStartDate: start,
      );

      expect(range.source, FlowDateRangeSource.prompt);
      expect(range.endDate, DateTime(2026, 6, 2 + 13));
      expect(range.durationDays, 14);
    });

    test('prompt with no duration defaults to a 10-day range', () {
      final range = resolveAiFlowDateRange(
        prompt: 'create a steady practice',
        defaultStartDate: start,
      );

      expect(range.source, FlowDateRangeSource.defaultDuration);
      expect(range.endDate, DateTime(2026, 6, 2 + 9));
      expect(range.durationDays, defaultAiFlowDurationDays);
    });

    for (final dates in [
      (DateTime(2026, 3, 5), DateTime(2026, 3, 14)),
      (DateTime(2026, 10, 26), DateTime(2026, 11, 4)),
    ]) {
      test('ten calendar days retain midnight across ${dates.$1}', () {
        final range = resolveAiFlowDateRange(
          prompt: 'Create a 10-day flow',
          defaultStartDate: dates.$1,
        );
        expect(range.source, FlowDateRangeSource.prompt);
        expect(range.startDate, dates.$1);
        expect(range.endDate, dates.$2);
        expect(range.durationDays, 10);
        // Count the calendar labels independently of local elapsed hours.
        final first = DateTime.utc(
          range.startDate.year,
          range.startDate.month,
          range.startDate.day,
        );
        final last = DateTime.utc(
          range.endDate.year,
          range.endDate.month,
          range.endDate.day,
        );
        expect(last.difference(first).inDays + 1, 10);
      });
    }

    test('manual date picker range overrides prompt duration', () {
      final range = resolveAiFlowDateRange(
        prompt: 'make this a 90 day flow',
        defaultStartDate: start,
        manualStartDate: DateTime(2026, 7, 10),
        manualEndDate: DateTime(2026, 7, 12),
        useManualRange: true,
      );

      expect(range.source, FlowDateRangeSource.manual);
      expect(range.startDate, DateTime(2026, 7, 10));
      expect(range.endDate, DateTime(2026, 7, 12));
      expect(range.durationDays, 3);
    });

    test('itinerary date headers override the default duration', () {
      final range = resolveAiFlowDateRange(
        prompt: '''
NYC itinerary
Thursday June 4
10:30 AM Arrive
Friday June 5
8:00 AM Breakfast
Saturday June 6
12:00 PM Performance
Sunday June 7
3:45 AM Uber to JFK
''',
        defaultStartDate: start,
      );

      expect(range.source, FlowDateRangeSource.itinerarySchedule);
      expect(range.startDate, DateTime(2026, 6, 4));
      expect(range.endDate, DateTime(2026, 6, 7));
      expect(range.durationDays, 4);
    });
  });
}
