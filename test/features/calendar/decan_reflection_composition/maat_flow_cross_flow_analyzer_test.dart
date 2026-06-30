import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/maat_flow_cross_flow_analyzer.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/maat_flow_decan_fact_collector.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/maat_flow_profile_catalog.dart';

void main() {
  const analyzer = MaatFlowCrossFlowAnalyzer();

  test(
    'same shared profile across different flow sets produces same inference',
    () {
      final first = analyzer.analyze(<MaatFlowDecanCompletion>[
        _completion(day: 1, flow: 'the-weighing'),
        _completion(day: 2, flow: 'the-true-name'),
        _completion(day: 3, flow: 'the-autobiography'),
        _completion(day: 4, flow: 'the-living-record'),
      ]);
      final second = analyzer.analyze(<MaatFlowDecanCompletion>[
        _completion(day: 1, flow: 'reading-house'),
        _completion(day: 2, flow: 'the-reading-house'),
        _completion(day: 3, flow: 'the-house-of-life'),
        _completion(day: 4, flow: 'the-living-text'),
      ]);

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(
        first!.type,
        MaatFlowCrossFlowInferenceType.sharedIntentionHolding,
      );
      expect(
        second!.type,
        MaatFlowCrossFlowInferenceType.sharedIntentionHolding,
      );
      expect(first.axis, MaatFlowProfileAxis.practiceType);
      expect(second.axis, MaatFlowProfileAxis.practiceType);
      expect(first.value, 'record_keeping');
      expect(second.value, 'record_keeping');
    },
  );

  test('same flow set derives holding when observed-heavy', () {
    final inference = analyzer.analyze(<MaatFlowDecanCompletion>[
      _completion(day: 1, flow: 'the-weighing'),
      _completion(day: 2, flow: 'the-true-name'),
      _completion(day: 3, flow: 'the-autobiography'),
      _completion(day: 4, flow: 'the-living-record'),
    ]);

    expect(inference, isNotNull);
    expect(
      inference!.type,
      MaatFlowCrossFlowInferenceType.sharedIntentionHolding,
    );
    expect(inference.observedCount, 4);
    expect(inference.partialCount, 0);
    expect(inference.skippedCount, 0);
    expect(inference.supportingFlowKeys, <String>[
      'the-autobiography',
      'the-living-record',
      'the-true-name',
      'the-weighing',
    ]);
    expect(inference.catalogVersion, kMaatFlowProfileCatalogVersion);
  });

  test('same flow set derives friction when skipped-heavy', () {
    final inference = analyzer.analyze(<MaatFlowDecanCompletion>[
      _completion(day: 1, flow: 'the-weighing'),
      _completion(day: 2, flow: 'the-true-name'),
      _completion(
        day: 3,
        flow: 'the-autobiography',
        status: CompletionStatus.skipped,
      ),
      _completion(
        day: 4,
        flow: 'the-living-record',
        status: CompletionStatus.skipped,
      ),
    ]);

    expect(inference, isNotNull);
    expect(
      inference!.type,
      MaatFlowCrossFlowInferenceType.sharedIntentionFriction,
    );
    expect(inference.observedCount, 2);
    expect(inference.skippedCount, 2);
  });

  test('partial-heavy completion produces partial inference', () {
    final inference = analyzer.analyze(<MaatFlowDecanCompletion>[
      _completion(day: 1, flow: 'the-weighing'),
      _completion(day: 2, flow: 'the-true-name'),
      _completion(
        day: 3,
        flow: 'the-autobiography',
        status: CompletionStatus.partial,
      ),
      _completion(
        day: 4,
        flow: 'the-living-record',
        status: CompletionStatus.partial,
      ),
    ]);

    expect(inference, isNotNull);
    expect(
      inference!.type,
      MaatFlowCrossFlowInferenceType.sharedIntentionPartial,
    );
    expect(inference.partialCount, 2);
  });

  test('broad profile spread without shared center produces uncentered', () {
    final inference = analyzer.analyze(<MaatFlowDecanCompletion>[
      _completion(day: 1, flow: 'track-the-sky'),
      _completion(day: 2, flow: 'the-open-hand'),
      _completion(day: 3, flow: 'the-first-arrangement'),
      _completion(day: 4, flow: 'the-kept-word'),
    ]);

    expect(inference, isNotNull);
    expect(
      inference!.type,
      MaatFlowCrossFlowInferenceType.sharedIntentionUncentered,
    );
    expect(inference.axis, MaatFlowProfileAxis.primaryIntention);
    expect(inference.value, 'no_shared_center');
    expect(inference.supportingFlowKeys, <String>[
      'the-first-arrangement',
      'the-kept-word',
      'the-open-hand',
      'track-the-sky',
    ]);
  });

  test('zero, thin, and single-flow cases produce no cross-flow inference', () {
    expect(analyzer.analyze(const <MaatFlowDecanCompletion>[]), isNull);
    expect(
      analyzer.analyze(<MaatFlowDecanCompletion>[
        _completion(day: 1, flow: 'the-weighing'),
      ]),
      isNull,
    );
    expect(
      analyzer.analyze(<MaatFlowDecanCompletion>[
        _completion(day: 1, flow: 'the-weighing'),
        _completion(day: 2, flow: 'the-true-name'),
        _completion(day: 3, flow: 'the-autobiography'),
      ]),
      isNull,
    );
    expect(
      analyzer.analyze(<MaatFlowDecanCompletion>[
        _completion(day: 1, flow: 'the-weighing'),
        _completion(day: 2, flow: 'the-weighing'),
        _completion(day: 3, flow: 'the-weighing'),
        _completion(day: 4, flow: 'the-weighing'),
      ]),
      isNull,
    );
  });

  test('missing profiles fail safely without producing inference', () {
    final inference = analyzer.analyze(<MaatFlowDecanCompletion>[
      _completion(day: 1, flow: 'future-flow-a'),
      _completion(day: 2, flow: 'future-flow-b'),
      _completion(day: 3, flow: 'future-flow-c'),
      _completion(day: 4, flow: 'future-flow-d'),
    ]);

    expect(inference, isNull);
  });

  test('static profile analyzer does not import live flow copy', () {
    final analyzerSource = File(
      'lib/features/calendar/decan_reflection_composition/'
      'maat_flow_cross_flow_analyzer.dart',
    ).readAsStringSync();
    final catalogSource = File(
      'lib/features/calendar/decan_reflection_composition/'
      'maat_flow_profile_catalog.dart',
    ).readAsStringSync();
    final combined = '$analyzerSource\n$catalogSource';

    expect(combined, isNot(contains('calendar_page.dart')));
    expect(combined, isNot(contains('maat_decan_flow.dart')));
    expect(combined, isNot(contains('_flow.dart')));
    expect(combined, isNot(contains('rootBundle')));
    expect(combined, isNot(contains('AIReflectionService')));
  });
}

MaatFlowDecanCompletion _completion({
  required int day,
  required String flow,
  CompletionStatus status = CompletionStatus.observed,
}) {
  return MaatFlowDecanCompletion(
    completedOn: DateTime(2026, 6, day),
    completionStatus: status,
    flowKey: flow,
  );
}
