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
}
