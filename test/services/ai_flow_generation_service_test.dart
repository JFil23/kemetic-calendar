import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/ai_flow_generation_service.dart';

void main() {
  group('aiFlowSanitizeSourceTextForInvoke', () {
    test('removes telemetry-only blocks before invoke', () {
      const raw = '''
{
  "event_message": "booted (time: 39ms)",
  "deployment_id": "abc",
  "execution_id": "def",
  "timestamp": "2026-04-29T11:00:14.016Z",
  "region": "us-west-1"
}

Turn this into a 10 day flow:

Daily anchors:
- Eggs
- Greens
- Hydration
''';

      final sanitized = aiFlowSanitizeSourceTextForInvoke(raw);

      expect(sanitized, isNotNull);
      expect(sanitized, isNot(contains('"event_message"')));
      expect(sanitized, contains('Turn this into a 10 day flow:'));
      expect(sanitized, contains('Daily anchors:'));
    });

    test('keeps prompt text when telemetry and flow content share a block', () {
      const raw = '''
[
  {
    "event_message": "shutdown",
    "event_type": "Shutdown",
    "execution_id": "abc",
    "function_id": "def",
    "timestamp": 1779738352369000
  }
]
Create a 90-day learning flow called Daily Math Visuals.
Schedule: 12 noon every day.

Day 1 - Area of Square
Watch: https://www.youtube.com/shorts/Y9EynW7GVn8
Prompt: What does area mean?
''';

      final sanitized = aiFlowSanitizeSourceTextForInvoke(raw);

      expect(sanitized, isNotNull);
      expect(sanitized, contains('Create a 90-day learning flow'));
      expect(sanitized, contains('Day 1 - Area of Square'));
    });

    test(
      'condenses very large source text without dropping key boundary blocks',
      () {
        final intro = 'Turn this into a 10 day flow.';
        final outro = 'Right now this is your blueprint.';
        final middleBlocks = List<String>.generate(
          40,
          (i) =>
              'Phase ${i + 1}: keep protein, fiber, hydration, and meal rhythm '
              'tight for day ${i + 1}. Include concrete foods, counts, and timing.',
        );
        final raw = [intro, ...middleBlocks, outro].join('\n\n');

        final sanitized = aiFlowSanitizeSourceTextForInvoke(
          raw,
          maxChars: 900,
          maxBlocks: 8,
        );

        expect(sanitized, isNotNull);
        expect(sanitized!.length, lessThanOrEqualTo(900));
        expect(sanitized, contains(intro));
        expect(sanitized, contains(outro));
        expect(sanitized, contains('Phase 1'));
      },
    );

    test('keeps a 90-day linked video prompt intact under invoke limit', () {
      final days = List<String>.generate(90, (i) {
        final day = i + 1;
        final id = day.toString().padLeft(11, 'A');
        return 'Day $day - Visual Math Topic $day\n'
            'Watch: https://www.youtube.com/shorts/$id\n'
            'Prompt: What did this video help me see?';
      });
      final raw = [
        'Create a 90-day learning flow called Daily Math Visuals.',
        'Schedule: one task per day for 90 days. Time: 12 noon every day.',
        ...days,
      ].join('\n\n');

      final sanitized = aiFlowSanitizeSourceTextForInvoke(raw);

      expect(sanitized, isNotNull);
      expect(sanitized, contains('Day 1 - Visual Math Topic 1'));
      expect(sanitized, contains('Day 90 - Visual Math Topic 90'));
      expect(
        RegExp(r'\bDay \d+ - Visual Math Topic').allMatches(sanitized!).length,
        90,
      );
    });
  });

  group('aiFlowBestErrorMessage', () {
    test('prefers nested message over placeholder error labels', () {
      final message = aiFlowBestErrorMessage({
        'error': 'client_error',
        'message': 'Payload exceeded edge gateway limit.',
      });

      expect(message, 'Payload exceeded edge gateway limit.');
    });

    test('extracts nested backend message from JSON string payload', () {
      final message = aiFlowBestErrorMessage(
        '{"error":{"message":"Model output failed validation after retry."}}',
      );

      expect(message, 'Model output failed validation after retry.');
    });

    test('hides raw note validation paths for guitar generation failures', () {
      final message = aiFlowBestErrorMessage({
        'message':
            'notes[31].details too generic: riff guidance needs fret, string, tab, timestamp, or technique anchors: "intro riff"',
      });

      expect(
        message,
        'The generated guitar plan was too vague in one section. Try again, or build manually while we improve this generator path.',
      );
      expect(message, isNot(contains('notes[31].details')));
      expect(message, isNot(contains('intro riff')));
    });
  });
}
