import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/data/choice_event_repo.dart';
import 'package:mobile/data/decan_reflection_model.dart';
import 'package:mobile/data/insight_link_model.dart';
import 'package:mobile/features/reflections/decan_reflection_detail_page.dart';

void main() {
  test(
    'detail skin preserves route title and existing link/back handlers',
    () async {
      final source = await File(
        'lib/features/reflections/decan_reflection_detail_page.dart',
      ).readAsString();

      expect(source, contains("title: 'Reflection'"));
      expect(source, contains("popOrGo(context, '/reflections')"));
      expect(source, contains('onPressed: _startLinkFlow'));
      expect(source, contains('DecanFolioMasthead'));
    },
  );

  test(
    'reflection suggested Ma’at flows keep exact Flow Studio template routing',
    () async {
      final source = await File(
        'lib/features/reflections/decan_reflection_detail_page.dart',
      ).readAsString();

      expect(source, contains("case 'flow_template':"));
      expect(source, contains("'mode': 'maatTemplate'"));
      expect(source, contains("'templateKey': cta.ref"));
      expect(source, contains("case 'flow_personalized':"));
      expect(
        source,
        contains(
          "'mode': cta.fallbackRef == null ? 'maatFlows' : 'maatTemplate'",
        ),
      );
      expect(
        source,
        contains("if (cta.fallbackRef != null) 'templateKey': cta.fallbackRef"),
      );
    },
  );

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

  test(
    'canonical node appears before graph anchors and lead-axis defaults',
    () {
      final hints = DecanReflectionGraphHints.fromGenerationJson({
        'anchor_nodes': <String>['renenutet'],
        'metadata': {
          'lead_axis': 'M',
          'output_control': {
            'compiled_output_package': {
              'node_ref': 'ptah',
              'node_title': 'Ptah',
            },
          },
        },
      });

      final suggestions = buildDecanReflectionSuggestedNodeLinks(
        hints,
        const <InsightLink>[],
      );

      expect(suggestions.map((suggestion) => suggestion.node.id), [
        'ptah',
        'renenutet',
      ]);
    },
  );

  test('graph anchors appear before lead-axis defaults', () {
    final hints = DecanReflectionGraphHints.fromGenerationJson({
      'anchor_nodes': <String>['renenutet'],
      'metadata': {'lead_axis': 'M'},
    });

    final suggestions = buildDecanReflectionSuggestedNodeLinks(
      hints,
      const <InsightLink>[],
    );

    expect(suggestions.first.node.id, 'renenutet');
    expect(suggestions.first.reason, 'From this reflection');
  });

  test(
    'successful reflection load records one opened event per page instance',
    () async {
      final tracker = _RecordingChoiceEventTracker();
      final telemetry = DecanReflectionInteractionTelemetry(tracker);
      final reflection = DecanReflection(
        id: '00000000-0000-4000-8000-000000001313',
        decanName: 'Cut 13',
        decanTheme: 'Authenticated telemetry',
        decanStart: DateTime.utc(2026, 9, 16),
        decanEnd: DateTime.utc(2026, 9, 25),
        badgeCount: 2,
        reflectionText: 'The reflection was loaded.',
        createdAt: DateTime.utc(2026, 9, 25),
      );

      await telemetry.recordOpened(reflection);
      await telemetry.recordOpened(reflection);

      expect(tracker.calls, hasLength(1));
      final call = tracker.calls.single;
      expect(call.eventType, 'reflection_opened');
      expect(call.reflectionId, reflection.id);
      expect(call.sourceSurface, 'decan_reflection_detail');
      expect(call.metadata, <String, dynamic>{
        'decan_start': '2026-09-16T00:00:00.000Z',
        'decan_end': '2026-09-25T00:00:00.000Z',
        'decan_name': 'Cut 13',
      });
    },
  );

  test(
    'suggested node relationship uses ChoiceEventTracker with canonical context',
    () async {
      final tracker = _RecordingChoiceEventTracker();
      final telemetry = DecanReflectionInteractionTelemetry(tracker);

      await telemetry.recordSuggestedNodeLink(
        reflectionId: '00000000-0000-4000-8000-000000001313',
        nodeSlug: '  maat  ',
        reason: 'From this reflection',
      );

      expect(tracker.calls, hasLength(1));
      final call = tracker.calls.single;
      expect(call.eventType, 'reflection_linked_to_node');
      expect(call.reflectionId, '00000000-0000-4000-8000-000000001313');
      expect(call.nodeSlug, 'maat');
      expect(call.sourceSurface, 'decan_reflection_library_continuation');
      expect(call.metadata, <String, dynamic>{
        'reason': 'From this reflection',
      });
    },
  );

  test(
    'reflection telemetry has no direct event insert and preserves generic tap',
    () async {
      final repoSource = await File(
        'lib/data/decan_reflection_repo.dart',
      ).readAsString();
      final detailSource = await File(
        'lib/features/reflections/decan_reflection_detail_page.dart',
      ).readAsString();

      expect(repoSource, isNot(contains("from('user_choice_events')")));
      expect(detailSource, contains("eventType: 'reflection_opened'"));
      expect(detailSource, contains("eventType: 'reflection_linked_to_node'"));
      expect(detailSource, contains("eventType: 'node_link_tapped'"));
      expect(detailSource, isNot(contains("eventType: 'reflection_saved'")));
      expect(detailSource, isNot(contains("eventType: 'reflection_rated'")));
      expect(detailSource, isNot(contains('maat_delivery_receipt_events')));
      expect(detailSource, isNot(contains('reflection_feedback')));
    },
  );
}

class _ChoiceEventCall {
  const _ChoiceEventCall({
    required this.eventType,
    this.nodeSlug,
    this.reflectionId,
    this.sourceSurface,
    this.deliveryId,
    this.metadata,
  });

  final String eventType;
  final String? nodeSlug;
  final String? reflectionId;
  final String? sourceSurface;
  final String? deliveryId;
  final Map<String, dynamic>? metadata;
}

class _RecordingChoiceEventTracker implements ChoiceEventTracker {
  final List<_ChoiceEventCall> calls = <_ChoiceEventCall>[];

  @override
  Future<void> trackChoiceEvent({
    required String eventType,
    String? nodeSlug,
    String? reflectionId,
    String? sourceSurface,
    String? deliveryId,
    Map<String, dynamic>? metadata,
  }) async {
    calls.add(
      _ChoiceEventCall(
        eventType: eventType,
        nodeSlug: nodeSlug,
        reflectionId: reflectionId,
        sourceSurface: sourceSurface,
        deliveryId: deliveryId,
        metadata: metadata,
      ),
    );
  }
}
