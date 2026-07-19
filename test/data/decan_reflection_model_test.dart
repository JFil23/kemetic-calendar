import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/decan_reflection_model.dart';

void main() {
  test('parses reflection destination fallback node into graph hints', () {
    final hints = DecanReflectionGraphHints.fromGenerationJson({
      'anchor_nodes': <String>[],
      'metadata': {
        'output_control': {
          'reflection_destination': {
            'type': 'flow_template',
            'ref': 'the-tending',
            'label': 'Open suggested flow',
            'fallback': {
              'ctaType': 'node',
              'ctaRef': 'instruction_amenemope',
              'ctaLabel': 'Read the guiding node',
            },
          },
        },
      },
    });

    expect(hints.cta?.type, 'flow_template');
    expect(hints.cta?.ref, 'the-tending');
    expect(hints.cta?.label, 'Open suggested flow');
    expect(hints.fallbackNode?.ref, 'instruction_amenemope');
    expect(hints.fallbackNode?.label, 'Read the guiding node');
  });

  test('ignores non-node fallback destinations for graph suggestions', () {
    final hints = DecanReflectionGraphHints.fromGenerationJson({
      'anchor_nodes': <String>[],
      'metadata': {
        'output_control': {
          'reflection_destination': {
            'type': 'flow_template',
            'ref': 'the-tending',
            'fallback': {'ctaType': 'flow_template', 'ctaRef': 'the-course'},
          },
        },
      },
    });

    expect(hints.cta?.type, 'flow_template');
    expect(hints.fallbackNode, isNull);
  });

  test('parses primary node destination into CTA metadata', () {
    final hints = DecanReflectionGraphHints.fromGenerationJson({
      'anchor_nodes': <String>[],
      'metadata': {
        'output_control': {
          'reflection_destination': {
            'type': 'node',
            'ref': 'maat',
            'label': 'Read the guiding node',
            'reason': 'reflection_alignment:truth:node_default',
            'source': 'reflection_judgment',
            'confidence': 0.72,
          },
        },
      },
    });

    expect(hints.cta?.type, 'node');
    expect(hints.cta?.ref, 'maat');
    expect(hints.cta?.label, 'Read the guiding node');
    expect(hints.fallbackNode, isNull);
  });

  test('parses canonical library node contract from compiled package', () {
    final hints = DecanReflectionGraphHints.fromGenerationJson({
      'anchor_nodes': <String>[],
      'metadata': {
        'output_control': {
          'compiled_output_package': {
            'node_ref': 'renenutet',
            'node_deep_link': '/nodes/renenutet',
            'node_title': 'Renenutet',
            'node_source': 'graph.anchor',
          },
        },
      },
    });

    expect(hints.canonicalNode?.ref, 'renenutet');
    expect(hints.canonicalNode?.label, 'Renenutet');
  });

  test('parses deterministic spectrum render metadata from generation rows', () {
    final metadata = DecanReflectionRenderMetadata.fromGenerationJson({
      'metadata': {
        'renderer': 'deterministic_spectrum',
        'used_llm': false,
        'llm_cost': 0,
        'spectrum_flow_key': 'the-weighing',
        'output_control': {
          'renderer': {
            'renderer': 'deterministic_spectrum',
            'anthropic_attempted': false,
            'deterministic_response': {
              'badgeBody': 'The record was brought to the scale.',
              'detailBody':
                  'The scale was approached. The record was brought to the scale.',
              'centralTension': 'The scale was approached.',
              'selectedSeed': {
                'tier': 'observed',
                'seed': 'The record was brought to the scale.',
              },
            },
          },
        },
      },
    });

    expect(metadata.renderer, 'deterministic_spectrum');
    expect(metadata.usedLlm, isFalse);
    expect(metadata.llmCost, 0);
    expect(metadata.spectrumFlowKey, 'the-weighing');
    expect(metadata.isTheWeighingSpectrum, isTrue);
    expect(metadata.anthropicAttempted, isFalse);
    expect(metadata.badgeBody, 'The record was brought to the scale.');
    expect(
      metadata.detailBody,
      'The scale was approached. The record was brought to the scale.',
    );
    expect(metadata.centralTension, 'The scale was approached.');
    expect(metadata.selectedTier, 'observed');
    expect(metadata.selectedSeed, 'The record was brought to the scale.');
  });

  test('generation metadata preserves compositional claim provenance', () {
    final metadata = DecanReflectionRenderMetadata.maybeFromGenerationJson({
      'metadata': {
        'renderer': 'compositional_v1',
        'used_llm': false,
        'llm_cost': 0,
        'engine_version': 'composition_engine_v2',
        'phrase_bank_version': 'decan_reflection_phrase_bank_v2',
        'claim_deriver_version': 'decan_claim_deriver_v1',
        'claimDeriverVersion': 'decan_claim_deriver_v1',
        'claim_fingerprint': 'abc123',
        'claimFingerprint': 'abc123',
        'claim_ids': <String>['steady_presence', 'flow_ready'],
        'claimIds': <String>['steady_presence', 'flow_ready'],
        'reflection_shape': 'steady_continuation',
        'reflectionShape': 'steady_continuation',
        'recommendation_policy_version': 'decan_recommendation_policy_v1',
        'recommendationPolicyVersion': 'decan_recommendation_policy_v1',
      },
      'source_snapshot': {
        'decan_reflection_id': 'reflection-1',
        'claim_fingerprint': 'abc123',
      },
    });

    expect(metadata, isNotNull);
    expect(metadata!.renderer, 'compositional_v1');
    final rawMetadata = Map<String, dynamic>.from(
      metadata.raw['metadata'] as Map,
    );
    expect(rawMetadata['claim_deriver_version'], 'decan_claim_deriver_v1');
    expect(rawMetadata['claimDeriverVersion'], 'decan_claim_deriver_v1');
    expect(rawMetadata['claim_fingerprint'], 'abc123');
    expect(rawMetadata['claimFingerprint'], 'abc123');
    expect(rawMetadata['claim_ids'], <String>['steady_presence', 'flow_ready']);
    expect(rawMetadata['claimIds'], <String>['steady_presence', 'flow_ready']);
    expect(rawMetadata['reflection_shape'], 'steady_continuation');
    expect(rawMetadata['reflectionShape'], 'steady_continuation');
    expect(
      rawMetadata['recommendation_policy_version'],
      'decan_recommendation_policy_v1',
    );
    expect(
      rawMetadata['recommendationPolicyVersion'],
      'decan_recommendation_policy_v1',
    );
  });
}
