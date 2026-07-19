import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/maat_flow_decan_fact_collector.dart';

void main() {
  test('fromRow accepts Ma_at flow completion metadata only', () {
    final accepted = MaatFlowDecanCompletion.fromRow(<String, dynamic>{
      'completed_on': '2026-06-02',
      'metadata': <String, dynamic>{
        'source_type': 'maat_flow',
        'flow_key': 'the-weighing',
        'completion_status': 'observed',
        'flow_title': 'The Weighing',
      },
    });
    final noFlowKey = MaatFlowDecanCompletion.fromRow(<String, dynamic>{
      'completed_on': '2026-06-02',
      'metadata': <String, dynamic>{'completion_status': 'observed'},
    });
    final nonMaatSource = MaatFlowDecanCompletion.fromRow(<String, dynamic>{
      'completed_on': '2026-06-02',
      'metadata': <String, dynamic>{
        'source_type': 'calendar_event',
        'flow_key': 'the-weighing',
        'completion_status': 'observed',
      },
    });

    expect(accepted?.flowKey, 'the-weighing');
    expect(accepted?.completionStatus, CompletionStatus.observed);
    expect(noFlowKey, isNull);
    expect(nonMaatSource, isNull);
  });

  test('snapshot summarizes approved V1 facts and signals', () {
    final snapshot = MaatFlowDecanFactCollector.snapshotFromCompletions(
      completions: <MaatFlowDecanCompletion>[
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 1),
          completionStatus: CompletionStatus.partial,
          flowKey: 'the-weighing',
        ),
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 3),
          completionStatus: CompletionStatus.partial,
          flowKey: 'the-weighing',
        ),
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 4),
          completionStatus: CompletionStatus.skipped,
          flowKey: 'the-weighing',
        ),
      ],
      decanStart: DateTime(2026, 6, 1),
      decanEnd: DateTime(2026, 6, 10),
      surface: 'decan_reflection',
    );

    expect(snapshot.facts['partial_count'], 2);
    expect(snapshot.facts['skipped_count'], 1);
    expect(snapshot.facts['active_days_count'], 3);
    expect(snapshot.facts['distinct_flow_count'], 1);
    expect(snapshot.facts['dominant_flow_key'], 'the-weighing');
    expect(snapshot.signals, contains('mostly_partial'));
    expect(snapshot.signals, contains('single_flow_depth'));
    expect(snapshot.signals, isNot(contains('zero_data')));
  });

  test(
    'snapshot attaches cross-flow inference only when evidence passes gates',
    () {
      final inferred = MaatFlowDecanFactCollector.snapshotFromCompletions(
        completions: <MaatFlowDecanCompletion>[
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 1),
            completionStatus: CompletionStatus.observed,
            flowKey: 'the-weighing',
          ),
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 2),
            completionStatus: CompletionStatus.observed,
            flowKey: 'the-true-name',
          ),
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 3),
            completionStatus: CompletionStatus.observed,
            flowKey: 'the-autobiography',
          ),
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 4),
            completionStatus: CompletionStatus.observed,
            flowKey: 'the-living-record',
          ),
        ],
        decanStart: DateTime(2026, 6, 1),
        decanEnd: DateTime(2026, 6, 10),
        surface: 'decan_reflection',
      );
      final thin = MaatFlowDecanFactCollector.snapshotFromCompletions(
        completions: <MaatFlowDecanCompletion>[
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 1),
            completionStatus: CompletionStatus.observed,
            flowKey: 'the-weighing',
          ),
        ],
        decanStart: DateTime(2026, 6, 1),
        decanEnd: DateTime(2026, 6, 10),
        surface: 'decan_reflection',
      );

      expect(inferred.crossFlowInference, isNotNull);
      expect(inferred.crossFlowInference?['type'], 'shared_intention_holding');
      expect(inferred.crossFlowInference?['axis'], 'practice_type');
      expect(inferred.crossFlowInference?['value'], 'record_keeping');
      expect(
        inferred.crossFlowInference?['analyzer_version'],
        'maat_flow_cross_flow_analyzer_v1',
      );
      expect(
        inferred.crossFlowInference?['catalog_version'],
        'maat_flow_profile_catalog_v1',
      );
      expect(thin.crossFlowInference, isNull);
    },
  );
}
