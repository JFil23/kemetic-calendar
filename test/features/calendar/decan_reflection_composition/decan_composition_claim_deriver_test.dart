import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/core/composition/composition_models.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/decan_composition_claim_deriver.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/decan_reflection_composer.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/maat_flow_decan_fact_collector.dart';

void main() {
  const deriver = DecanCompositionClaimDeriver();

  test('zero data derives zeroEvidence without output claims', () {
    final plan = deriver.derive(_facts(const <MaatFlowDecanCompletion>[]));

    expect(_claimIds(plan), <String>['zero_evidence']);
    expect(plan.reflectionShape, ReflectionShape.silentOrInvitation);
    expect(plan.primaryClaimId, CompositionClaimId.zeroEvidence);
    expect(plan.supportingClaimIds, isEmpty);
    expect(plan.claimFingerprint, isNotEmpty);
  });

  test(
    'one observed derives firstContact, lowEvidence, and Library support',
    () {
      final plan = deriver.derive(
        _facts(<MaatFlowDecanCompletion>[
          _completion(day: 1, status: CompletionStatus.observed, flow: 'truth'),
        ]),
      );

      expect(_claimIds(plan), <String>[
        'first_contact',
        'low_evidence',
        'library_support_recommended',
      ]);
      expect(plan.reflectionShape, ReflectionShape.lowEvidenceReturn);
      expect(plan.primaryClaimId, CompositionClaimId.firstContact);
      expect(_supportingClaimIds(plan), <String>[
        'low_evidence',
        'library_support_recommended',
      ]);
      expect(plan.claims.first.polarity, CompositionClaimPolarity.supportive);
    },
  );

  test('one skipped derives recordedContact, lowEvidence, and support', () {
    final plan = deriver.derive(
      _facts(<MaatFlowDecanCompletion>[
        _completion(day: 1, status: CompletionStatus.skipped, flow: 'truth'),
      ]),
    );

    expect(_claimIds(plan), <String>[
      'recorded_contact',
      'low_evidence',
      'support_before_expansion',
      'library_support_recommended',
    ]);
    expect(plan.reflectionShape, ReflectionShape.lowEvidenceReturn);
    expect(plan.primaryClaimId, CompositionClaimId.recordedContact);
    _expectCautionIsBalanced(plan);
  });

  test('mostly observed derives steadyPresence and flowReady', () {
    final plan = deriver.derive(
      _facts(<MaatFlowDecanCompletion>[
        _completion(day: 1, status: CompletionStatus.observed, flow: 'truth'),
        _completion(day: 2, status: CompletionStatus.observed, flow: 'balance'),
        _completion(day: 3, status: CompletionStatus.observed, flow: 'truth'),
      ]),
    );

    expect(_claimIds(plan), <String>['steady_presence', 'flow_ready']);
    expect(plan.reflectionShape, ReflectionShape.steadyContinuation);
    expect(plan.primaryClaimId, CompositionClaimId.steadyPresence);
  });

  test('mostly partial derives maintained contact and support', () {
    final plan = deriver.derive(
      _facts(<MaatFlowDecanCompletion>[
        _completion(day: 1, status: CompletionStatus.partial, flow: 'truth'),
        _completion(day: 2, status: CompletionStatus.partial, flow: 'truth'),
        _completion(day: 3, status: CompletionStatus.observed, flow: 'truth'),
      ]),
    );

    expect(_claimIds(plan), <String>[
      'partial_contact_maintained',
      'support_before_expansion',
      'library_support_recommended',
    ]);
    expect(plan.reflectionShape, ReflectionShape.supportiveRecalibration);
    expect(plan.primaryClaimId, CompositionClaimId.partialContactMaintained);
    _expectCautionIsBalanced(plan);
  });

  test(
    'many skips with completion derives skippedGateTooHeavy after contact',
    () {
      final plan = deriver.derive(
        _facts(<MaatFlowDecanCompletion>[
          _completion(day: 1, status: CompletionStatus.skipped, flow: 'truth'),
          _completion(day: 2, status: CompletionStatus.skipped, flow: 'truth'),
          _completion(day: 3, status: CompletionStatus.observed, flow: 'truth'),
        ]),
      );

      expect(_claimIds(plan), <String>[
        'recorded_contact',
        'skipped_gate_too_heavy',
        'support_before_expansion',
        'library_support_recommended',
      ]);
      expect(plan.reflectionShape, ReflectionShape.supportiveRecalibration);
      expect(plan.primaryClaimId, CompositionClaimId.recordedContact);
      _expectCautionIsBalanced(plan);
    },
  );

  test('single-flow depth derives singleFlowDepth and flowReady', () {
    final plan = deriver.derive(
      _facts(<MaatFlowDecanCompletion>[
        _completion(day: 1, status: CompletionStatus.observed, flow: 'order'),
        _completion(day: 2, status: CompletionStatus.observed, flow: 'order'),
        _completion(day: 3, status: CompletionStatus.observed, flow: 'order'),
      ]),
    );

    expect(_claimIds(plan), <String>['single_flow_depth', 'flow_ready']);
    expect(plan.reflectionShape, ReflectionShape.singleThreadContinuation);
    expect(plan.primaryClaimId, CompositionClaimId.singleFlowDepth);
  });

  test('broad spread derives range, centering, and flowReady', () {
    final plan = deriver.derive(
      _facts(<MaatFlowDecanCompletion>[
        _completion(day: 1, status: CompletionStatus.observed, flow: 'truth'),
        _completion(day: 2, status: CompletionStatus.observed, flow: 'balance'),
        _completion(day: 3, status: CompletionStatus.observed, flow: 'order'),
      ]),
    );

    expect(_claimIds(plan), <String>[
      'breadth_as_range',
      'breadth_needs_center',
      'flow_ready',
    ]);
    expect(plan.reflectionShape, ReflectionShape.breadthCentering);
    expect(plan.primaryClaimId, CompositionClaimId.breadthAsRange);
  });

  test('mixed record derives recordedContact and supportBeforeExpansion', () {
    final plan = deriver.derive(
      _facts(<MaatFlowDecanCompletion>[
        _completion(day: 1, status: CompletionStatus.observed, flow: 'truth'),
        _completion(day: 2, status: CompletionStatus.partial, flow: 'balance'),
        _completion(day: 3, status: CompletionStatus.skipped, flow: 'truth'),
      ]),
    );

    expect(_claimIds(plan), <String>[
      'recorded_contact',
      'support_before_expansion',
      'library_support_recommended',
    ]);
    expect(plan.reflectionShape, ReflectionShape.supportiveRecalibration);
    expect(plan.primaryClaimId, CompositionClaimId.recordedContact);
    _expectCautionIsBalanced(plan);
  });

  test('null cross-flow inference leaves claim plan unchanged', () {
    final facts = _facts(<MaatFlowDecanCompletion>[
      _completion(day: 1, status: CompletionStatus.observed, flow: 'truth'),
    ]);

    expect(facts.crossFlowInference, isNull);
    final plan = deriver.derive(facts);

    expect(_claimIds(plan), <String>[
      'first_contact',
      'low_evidence',
      'library_support_recommended',
    ]);
    expect(plan.crossFlowInference, isNull);
    expect(
      _claimIds(plan).where((claimId) => claimId.startsWith('cross_flow_')),
      isEmpty,
    );
  });

  test('holding inference adds shared-intention and holding claims', () {
    final facts = _facts(<MaatFlowDecanCompletion>[
      _completion(
        day: 1,
        status: CompletionStatus.observed,
        flow: 'the-weighing',
      ),
      _completion(
        day: 2,
        status: CompletionStatus.observed,
        flow: 'the-true-name',
      ),
      _completion(
        day: 3,
        status: CompletionStatus.observed,
        flow: 'the-autobiography',
      ),
      _completion(
        day: 4,
        status: CompletionStatus.observed,
        flow: 'the-living-record',
      ),
    ]);

    final plan = deriver.derive(facts);

    expect(facts.crossFlowInference?['type'], 'shared_intention_holding');
    expect(_claimIds(plan), contains('cross_flow_shared_intention'));
    expect(_claimIds(plan), contains('cross_flow_intention_holding'));
    expect(
      _claimById(plan, CompositionClaimId.crossFlowSharedIntention)?.polarity,
      CompositionClaimPolarity.supportive,
    );
    expect(
      _claimById(plan, CompositionClaimId.crossFlowIntentionHolding)?.polarity,
      CompositionClaimPolarity.supportive,
    );
    expect(plan.crossFlowInference?['value'], 'record_keeping');
  });

  test('friction inference adds paired capability and cautionary claims', () {
    final plan = deriver.derive(
      _facts(<MaatFlowDecanCompletion>[
        _completion(
          day: 1,
          status: CompletionStatus.observed,
          flow: 'the-weighing',
        ),
        _completion(
          day: 2,
          status: CompletionStatus.observed,
          flow: 'the-true-name',
        ),
        _completion(
          day: 3,
          status: CompletionStatus.skipped,
          flow: 'the-autobiography',
        ),
        _completion(
          day: 4,
          status: CompletionStatus.skipped,
          flow: 'the-living-record',
        ),
      ]),
    );

    final claimIds = plan.claimIds;
    final sharedIndex = claimIds.indexOf(
      CompositionClaimId.crossFlowSharedIntention,
    );
    final frictionIndex = claimIds.indexOf(
      CompositionClaimId.crossFlowIntentionFriction,
    );

    expect(sharedIndex, isNonNegative);
    expect(frictionIndex, isNonNegative);
    expect(sharedIndex, lessThan(frictionIndex));
    expect(
      _claimById(plan, CompositionClaimId.crossFlowSharedIntention)?.polarity,
      CompositionClaimPolarity.supportive,
    );
    expect(
      _claimById(plan, CompositionClaimId.crossFlowIntentionFriction)?.polarity,
      CompositionClaimPolarity.cautionary,
    );
    _expectCautionIsBalanced(plan);
  });

  test('partial inference adds paired capability and partial claims', () {
    final plan = deriver.derive(
      _facts(<MaatFlowDecanCompletion>[
        _completion(
          day: 1,
          status: CompletionStatus.observed,
          flow: 'the-weighing',
        ),
        _completion(
          day: 2,
          status: CompletionStatus.observed,
          flow: 'the-true-name',
        ),
        _completion(
          day: 3,
          status: CompletionStatus.partial,
          flow: 'the-autobiography',
        ),
        _completion(
          day: 4,
          status: CompletionStatus.partial,
          flow: 'the-living-record',
        ),
      ]),
    );

    final claimIds = plan.claimIds;
    final sharedIndex = claimIds.indexOf(
      CompositionClaimId.crossFlowSharedIntention,
    );
    final partialIndex = claimIds.indexOf(
      CompositionClaimId.crossFlowIntentionPartial,
    );

    expect(sharedIndex, isNonNegative);
    expect(partialIndex, isNonNegative);
    expect(sharedIndex, lessThan(partialIndex));
    expect(
      _claimById(plan, CompositionClaimId.crossFlowIntentionPartial)?.polarity,
      CompositionClaimPolarity.cautionary,
    );
    _expectCautionIsBalanced(plan);
  });

  test('uncentered inference adds neutral uncentered claim', () {
    final plan = deriver.derive(
      _facts(<MaatFlowDecanCompletion>[
        _completion(
          day: 1,
          status: CompletionStatus.observed,
          flow: 'track-the-sky',
        ),
        _completion(
          day: 2,
          status: CompletionStatus.observed,
          flow: 'the-open-hand',
        ),
        _completion(
          day: 3,
          status: CompletionStatus.observed,
          flow: 'the-first-arrangement',
        ),
        _completion(
          day: 4,
          status: CompletionStatus.observed,
          flow: 'the-kept-word',
        ),
      ]),
    );

    expect(_claimIds(plan), contains('cross_flow_intention_uncentered'));
    expect(_claimIds(plan), isNot(contains('cross_flow_shared_intention')));
    expect(
      _claimById(
        plan,
        CompositionClaimId.crossFlowIntentionUncentered,
      )?.polarity,
      CompositionClaimPolarity.neutral,
    );
  });

  test('claim fingerprint changes when inference payload version changes', () {
    final facts = _facts(<MaatFlowDecanCompletion>[
      _completion(
        day: 1,
        status: CompletionStatus.observed,
        flow: 'the-weighing',
      ),
      _completion(
        day: 2,
        status: CompletionStatus.observed,
        flow: 'the-true-name',
      ),
      _completion(
        day: 3,
        status: CompletionStatus.observed,
        flow: 'the-autobiography',
      ),
      _completion(
        day: 4,
        status: CompletionStatus.observed,
        flow: 'the-living-record',
      ),
    ]);
    final changedPayload = <String, Object?>{
      ...facts.crossFlowInference!,
      'analyzer_version': 'maat_flow_cross_flow_analyzer_v2',
    };

    final first = deriver.derive(facts);
    final second = deriver.derive(
      facts.copyWith(crossFlowInference: changedPayload),
    );

    expect(first.claimFingerprint, isNot(second.claimFingerprint));
  });

  test('claim fingerprint is stable for the same fact snapshot', () {
    final facts = _facts(<MaatFlowDecanCompletion>[
      _completion(day: 1, status: CompletionStatus.observed, flow: 'truth'),
      _completion(day: 2, status: CompletionStatus.partial, flow: 'balance'),
      _completion(day: 3, status: CompletionStatus.skipped, flow: 'truth'),
    ]);

    final first = deriver.derive(facts);
    final second = deriver.derive(facts);

    expect(first.claimFingerprint, second.claimFingerprint);
  });

  test('claim fingerprint is stable across deriver instances', () {
    final facts = _facts(<MaatFlowDecanCompletion>[
      _completion(day: 1, status: CompletionStatus.observed, flow: 'truth'),
      _completion(day: 2, status: CompletionStatus.observed, flow: 'balance'),
      _completion(day: 3, status: CompletionStatus.observed, flow: 'order'),
    ]);

    final first = const DecanCompositionClaimDeriver().derive(facts);
    final second = const DecanCompositionClaimDeriver().derive(facts);

    expect(first.claimFingerprint, second.claimFingerprint);
    expect(first.claimIds, second.claimIds);
    expect(first.reflectionShape, second.reflectionShape);
  });
}

CompositionFactSnapshot _facts(List<MaatFlowDecanCompletion> completions) {
  return MaatFlowDecanFactCollector.snapshotFromCompletions(
    completions: completions,
    decanStart: DateTime(2026, 6, 1),
    decanEnd: DateTime(2026, 6, 10),
    surface: kDecanReflectionSurface,
  );
}

MaatFlowDecanCompletion _completion({
  required int day,
  required CompletionStatus status,
  required String flow,
}) {
  return MaatFlowDecanCompletion(
    completedOn: DateTime(2026, 6, day),
    completionStatus: status,
    flowKey: flow,
  );
}

List<String> _claimIds(CompositionClaimPlan plan) {
  return plan.claimIds.map((claimId) => claimId.wireName).toList();
}

List<String> _supportingClaimIds(CompositionClaimPlan plan) {
  return plan.supportingClaimIds.map((claimId) => claimId.wireName).toList();
}

void _expectCautionIsBalanced(CompositionClaimPlan plan) {
  var supportiveSeen = false;
  for (final claim in plan.claims) {
    if (claim.polarity == CompositionClaimPolarity.supportive) {
      supportiveSeen = true;
    }
    if (claim.polarity == CompositionClaimPolarity.cautionary) {
      expect(
        supportiveSeen,
        isTrue,
        reason:
            'Cautionary claim ${claim.id.wireName} should follow a truthful capability claim.',
      );
    }
  }
}

CompositionClaim? _claimById(
  CompositionClaimPlan plan,
  CompositionClaimId claimId,
) {
  for (final claim in plan.claims) {
    if (claim.id == claimId) return claim;
  }
  return null;
}
