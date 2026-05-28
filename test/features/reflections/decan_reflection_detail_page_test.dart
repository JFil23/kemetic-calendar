import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/data/decan_reflection_model.dart';
import 'package:mobile/data/insight_link_model.dart';
import 'package:mobile/features/reflections/decan_reflection_detail_page.dart';

void main() {
  testWidgets(
    'fallback node chip renders and routes while primary flow CTA remains',
    (tester) async {
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
      final suggestions = buildDecanReflectionSuggestedNodeLinks(
        hints,
        const <InsightLink>[],
      );
      final router = GoRouter(
        initialLocation: '/reflection',
        routes: [
          GoRoute(
            path: '/reflection',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    if (hints.cta?.hasDestination == true)
                      OutlinedButton(
                        onPressed: () {},
                        child: Text(hints.cta!.label),
                      ),
                    DecanReflectionSuggestedNodeChips(
                      suggestions: suggestions,
                      onOpenSuggestedNode: (suggestion) {
                        context.go(
                          '/nodes/${Uri.encodeComponent(suggestion.node.id)}',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/nodes/:slug',
            builder: (context, state) =>
                Scaffold(body: Text('node:${state.pathParameters['slug']}')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Open suggested flow'), findsOneWidget);
      expect(find.text('Continue in the graph'), findsOneWidget);
      expect(find.text('Instruction of Amenemope'), findsOneWidget);

      await tester.ensureVisible(find.text('Instruction of Amenemope'));
      await tester.tap(find.text('Instruction of Amenemope'));
      await tester.pumpAndSettle();

      expect(find.text('node:instruction_amenemope'), findsOneWidget);
    },
  );

  test('fallback node suggestions are de-duplicated against anchors', () {
    final hints = DecanReflectionGraphHints.fromGenerationJson({
      'anchor_nodes': <String>['instruction_amenemope'],
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

    final suggestions = buildDecanReflectionSuggestedNodeLinks(
      hints,
      const <InsightLink>[],
    );

    expect(
      suggestions
          .where((suggestion) => suggestion.node.id == 'instruction_amenemope')
          .length,
      1,
    );
  });

  test('primary node destination renders as a node suggestion', () {
    final hints = DecanReflectionGraphHints.fromGenerationJson({
      'anchor_nodes': <String>[],
      'metadata': {
        'output_control': {
          'reflection_destination': {
            'type': 'node',
            'ref': 'maat',
            'label': 'Read the guiding node',
          },
        },
      },
    });

    final suggestions = buildDecanReflectionSuggestedNodeLinks(
      hints,
      const <InsightLink>[],
    );

    expect(suggestions.map((suggestion) => suggestion.node.id), ['maat']);
    expect(suggestions.single.reason, 'Read the guiding node');
  });
}
