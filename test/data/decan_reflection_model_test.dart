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

  group('reflection generation manifest v2', () {
    test('pure v2 matches v1 render, graph, CTA, and node semantics', () {
      final v1Render = DecanReflectionRenderMetadata.fromGenerationJson(
        _v1Generation,
      );
      final v2Render = DecanReflectionRenderMetadata.fromGenerationJson(
        _v2Generation,
      );
      _expectEquivalentRenderMetadata(v2Render, v1Render);

      final v1Hints = DecanReflectionGraphHints.fromGenerationJson(
        _v1Generation,
      );
      final v2Hints = DecanReflectionGraphHints.fromGenerationJson(
        _v2Generation,
      );
      _expectEquivalentGraphHints(v2Hints, v1Hints);

      expect(
        (_v2Generation['metadata'] as Map<String, dynamic>),
        isNot(contains('output_control')),
      );
      expect(
        (_v2Generation['source_snapshot'] as Map<String, dynamic>),
        isNot(contains('output_control')),
      );
    });

    test('mixed row prefers a supported v2 manifest', () {
      final mixed = <String, dynamic>{
        ..._v1Generation,
        'metadata': <String, dynamic>{
          ...(_v1Generation['metadata'] as Map<String, dynamic>),
          'manifest': <String, dynamic>{
            ..._manifestV2,
            'render': <String, dynamic>{
              ...(_manifestV2['render'] as Map<String, dynamic>),
              'badge_body': 'V2 wins.',
            },
            'graph': <String, dynamic>{
              ...(_manifestV2['graph'] as Map<String, dynamic>),
              'lead_axis': 'v2-axis',
            },
          },
        },
      };

      final render = DecanReflectionRenderMetadata.fromGenerationJson(mixed);
      final hints = DecanReflectionGraphHints.fromGenerationJson(mixed);

      expect(render.badgeBody, 'V2 wins.');
      expect(hints.leadAxis, 'v2-axis');
    });

    test('unknown manifest version falls back to unchanged v1 parsing', () {
      final unknown = <String, dynamic>{
        ..._v1Generation,
        'metadata': <String, dynamic>{
          ...(_v1Generation['metadata'] as Map<String, dynamic>),
          'manifest': <String, dynamic>{
            ..._manifestV2,
            'version': 'reflection_generation_manifest_v999',
            'render': <String, dynamic>{'badge_body': 'Must not win.'},
          },
        },
      };

      _expectEquivalentRenderMetadata(
        DecanReflectionRenderMetadata.fromGenerationJson(unknown),
        DecanReflectionRenderMetadata.fromGenerationJson(_v1Generation),
      );
      _expectEquivalentGraphHints(
        DecanReflectionGraphHints.fromGenerationJson(unknown),
        DecanReflectionGraphHints.fromGenerationJson(_v1Generation),
      );
    });
  });
}

const Map<String, dynamic> _v1Generation = <String, dynamic>{
  'anchor_nodes': <String>['maat', 'instruction_amenemope'],
  'source_snapshot': <String, dynamic>{
    'decan_reflection_id': 'reflection-paired-fixture',
  },
  'metadata': <String, dynamic>{
    'renderer': 'deterministic_spectrum',
    'used_llm': false,
    'llm_cost': 0,
    'spectrum_flow_key': 'the-weighing',
    'lead_axis': 'truth',
    'output_control': <String, dynamic>{
      'renderer': <String, dynamic>{
        'renderer': 'deterministic_spectrum',
        'anthropic_attempted': false,
        'deterministic_response': <String, dynamic>{
          'responseKind': 'witness',
          'badgeTitle': 'The balance held',
          'badgeBody': 'The record was brought to the scale.',
          'detailBody': 'The record names one clear return.',
          'centralTension': 'Measure and movement',
          'selectedSeed': <String, dynamic>{
            'tier': 'observed',
            'seed': 'The record was brought to the scale.',
          },
        },
      },
      'compiled_output_package': <String, dynamic>{
        'node_ref': 'maat',
        'node_title': 'Ma\u2019at',
        'destination': <String, dynamic>{
          'type': 'flow_template',
          'ref': 'the-tending',
          'label': 'Open suggested flow',
          'fallback': <String, dynamic>{
            'ctaType': 'node',
            'ctaRef': 'instruction_amenemope',
            'ctaLabel': 'Read the guiding node',
          },
        },
      },
    },
  },
};

const Map<String, dynamic> _manifestV2 = <String, dynamic>{
  'version': kReflectionGenerationManifestV2,
  'render': <String, dynamic>{
    'renderer': 'deterministic_spectrum',
    'used_llm': false,
    'llm_cost': 0,
    'spectrum_flow_key': 'the-weighing',
    'response_kind': 'witness',
    'selected_tier': 'observed',
    'selected_seed': 'The record was brought to the scale.',
    'badge_title': 'The balance held',
    'badge_body': 'The record was brought to the scale.',
    'detail_body': 'The record names one clear return.',
    'central_tension': 'Measure and movement',
    'anthropic_attempted': false,
  },
  'graph': <String, dynamic>{
    'lead_axis': 'truth',
    'destination': <String, dynamic>{
      'type': 'flow_template',
      'ref': 'the-tending',
      'label': 'Open suggested flow',
      'fallback': <String, dynamic>{
        'type': 'node',
        'ref': 'instruction_amenemope',
        'label': 'Read the guiding node',
      },
    },
    'canonical_node': <String, dynamic>{
      'node_ref': 'maat',
      'node_title': 'Ma\u2019at',
    },
  },
};

const Map<String, dynamic> _v2Generation = <String, dynamic>{
  'anchor_nodes': <String>['maat', 'instruction_amenemope'],
  'source_snapshot': <String, dynamic>{
    'decan_reflection_id': 'reflection-paired-fixture',
  },
  'metadata': <String, dynamic>{'manifest': _manifestV2},
};

void _expectEquivalentRenderMetadata(
  DecanReflectionRenderMetadata actual,
  DecanReflectionRenderMetadata expected,
) {
  expect(actual.renderer, expected.renderer);
  expect(actual.usedLlm, expected.usedLlm);
  expect(actual.llmCost, expected.llmCost);
  expect(actual.spectrumFlowKey, expected.spectrumFlowKey);
  expect(actual.responseKind, expected.responseKind);
  expect(actual.selectedTier, expected.selectedTier);
  expect(actual.selectedSeed, expected.selectedSeed);
  expect(actual.badgeTitle, expected.badgeTitle);
  expect(actual.badgeBody, expected.badgeBody);
  expect(actual.detailBody, expected.detailBody);
  expect(actual.centralTension, expected.centralTension);
  expect(actual.anthropicAttempted, expected.anthropicAttempted);
}

void _expectEquivalentGraphHints(
  DecanReflectionGraphHints actual,
  DecanReflectionGraphHints expected,
) {
  expect(actual.leadAxis, expected.leadAxis);
  expect(actual.anchorNodes, expected.anchorNodes);
  expect(actual.cta?.type, expected.cta?.type);
  expect(actual.cta?.ref, expected.cta?.ref);
  expect(actual.cta?.label, expected.cta?.label);
  expect(actual.cta?.fallbackType, expected.cta?.fallbackType);
  expect(actual.cta?.fallbackRef, expected.cta?.fallbackRef);
  expect(actual.cta?.fallbackLabel, expected.cta?.fallbackLabel);
  expect(actual.fallbackNode?.ref, expected.fallbackNode?.ref);
  expect(actual.fallbackNode?.label, expected.fallbackNode?.label);
  expect(actual.canonicalNode?.ref, expected.canonicalNode?.ref);
  expect(actual.canonicalNode?.label, expected.canonicalNode?.label);
}
