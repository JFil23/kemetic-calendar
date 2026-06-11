import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/ai_reflection_service.dart';

void main() {
  test('parses deterministic spectrum response metadata', () {
    final response = AIReflectionResponse.fromJson({
      'success': true,
      'reflection': 'Full deterministic reflection body.',
      'modelUsed': 'deterministic_spectrum',
      'badgeCount': 6,
      'branch': 'decan',
      'renderer': 'deterministic_spectrum',
      'used_llm': false,
      'llm_cost': 0,
      'spectrum_flow_key': 'the-weighing',
      'reflection_id': 'reflection-1',
      'reflection_generation_id': 'generation-1',
      'outputControl': {
        'renderer': {
          'renderer': 'deterministic_spectrum',
          'used_llm': false,
          'llm_cost': 0,
          'spectrum_flow_key': 'the-weighing',
          'anthropic_attempted': false,
          'deterministic_response': {
            'badgeBody': 'The sitting was entered but not completed.',
            'detailBody':
                'The scale was approached. The sitting was entered but not completed.',
            'selectedSeed': {
              'tier': 'partial',
              'seed': 'The sitting was entered but not completed.',
            },
          },
        },
      },
    });

    expect(response.success, isTrue);
    expect(response.reflectionId, 'reflection-1');
    expect(response.reflectionGenerationId, 'generation-1');
    expect(response.renderMetadata?.renderer, 'deterministic_spectrum');
    expect(response.renderMetadata?.usedLlm, isFalse);
    expect(response.renderMetadata?.llmCost, 0);
    expect(response.renderMetadata?.spectrumFlowKey, 'the-weighing');
    expect(response.renderMetadata?.anthropicAttempted, isFalse);
    expect(
      response.renderMetadata?.badgeBody,
      'The sitting was entered but not completed.',
    );
    expect(
      response.renderMetadata?.detailBody,
      'The scale was approached. The sitting was entered but not completed.',
    );
  });
}
