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
  });
}
