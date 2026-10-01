import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/decan_reflection_model.dart';

void main() {
  test('parses deterministic spectrum response metadata', () {
    final response = DecanReflectionRenderMetadata.fromResponseJson({
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

    expect(response.raw['success'], isTrue);
    expect(response.raw['reflection_id'], 'reflection-1');
    expect(response.raw['reflection_generation_id'], 'generation-1');
    expect(response.renderer, 'deterministic_spectrum');
    expect(response.usedLlm, isFalse);
    expect(response.llmCost, 0);
    expect(response.spectrumFlowKey, 'the-weighing');
    expect(response.anthropicAttempted, isFalse);
    expect(response.badgeBody, 'The sitting was entered but not completed.');
    expect(
      response.detailBody,
      'The scale was approached. The sitting was entered but not completed.',
    );
  });
}
