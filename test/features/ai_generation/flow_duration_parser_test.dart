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
  });
}
