import 'package:mobile/core/composition/composition_engine.dart';
import 'package:mobile/core/composition/composition_models.dart';

const String kDecanCompositionClaimDeriverVersion = 'decan_claim_deriver_v1';

class DecanCompositionClaimDeriver implements CompositionClaimDeriver {
  const DecanCompositionClaimDeriver();

  @override
  CompositionClaimPlan derive(CompositionFactSnapshot facts) {
    final total = _intFact(facts, 'total_interactions');
    final observed = _intFact(facts, 'observed_count');
    final partial = _intFact(facts, 'partial_count');
    final skipped = _intFact(facts, 'skipped_count');
    final activeDays = _intFact(facts, 'active_days_count');
    final distinctFlows = _intFact(facts, 'distinct_flow_count');
    final signals = facts.signals;

    if (total == 0 || signals.contains('zero_data')) {
      return _plan(
        facts: facts,
        claims: <CompositionClaim>[
          _claim(
            id: CompositionClaimId.zeroEvidence,
            strength: CompositionClaimStrength.low,
            evidenceCount: 0,
            evidenceSummary: '0 Ma’at Flow interactions recorded',
            sourceSignalIds: const <String>['zero_data'],
            polarity: CompositionClaimPolarity.neutral,
            tags: const <String>{'zero_evidence', 'silent'},
          ),
        ],
        reflectionShape: ReflectionShape.silentOrInvitation,
        primaryClaimId: CompositionClaimId.zeroEvidence,
      );
    }

    final claims = <CompositionClaim>[];
    ReflectionShape shape;
    CompositionClaimId primaryClaimId;

    if (total == 1 && observed == 1) {
      claims.addAll(<CompositionClaim>[
        _claim(
          id: CompositionClaimId.firstContact,
          strength: CompositionClaimStrength.low,
          evidenceCount: 1,
          evidenceSummary: '1 observed completion across $distinctFlows flow',
          sourceSignalIds: const <String>['low_data'],
          polarity: CompositionClaimPolarity.supportive,
          tags: const <String>{'capability', 'contact'},
        ),
        _lowEvidenceClaim(total),
        _librarySupportClaim(total),
      ]);
      shape = ReflectionShape.lowEvidenceReturn;
      primaryClaimId = CompositionClaimId.firstContact;
    } else if (signals.contains('many_skips')) {
      claims.addAll(<CompositionClaim>[
        _recordedContactClaim(
          total: total,
          observed: observed,
          partial: partial,
          skipped: skipped,
          activeDays: activeDays,
          distinctFlows: distinctFlows,
          sourceSignalIds: _presentSignals(signals, const <String>[
            'many_skips',
            'has_skipped',
          ]),
        ),
        _claim(
          id: CompositionClaimId.skippedGateTooHeavy,
          strength: CompositionClaimStrength.medium,
          evidenceCount: skipped,
          evidenceSummary: '$skipped skipped marks out of $total interactions',
          sourceSignalIds: _presentSignals(signals, const <String>[
            'many_skips',
            'has_skipped',
          ]),
          polarity: CompositionClaimPolarity.cautionary,
          tags: const <String>{'calibration', 'right_sizing'},
        ),
        _supportBeforeExpansionClaim(facts, total),
        _librarySupportClaim(total),
      ]);
      shape = ReflectionShape.supportiveRecalibration;
      primaryClaimId = CompositionClaimId.recordedContact;
    } else if (signals.contains('mostly_partial')) {
      claims.addAll(<CompositionClaim>[
        _claim(
          id: CompositionClaimId.partialContactMaintained,
          strength: CompositionClaimStrength.medium,
          evidenceCount: partial,
          evidenceSummary:
              '$partial partial completions across $activeDays active days',
          sourceSignalIds: _presentSignals(signals, const <String>[
            'mostly_partial',
            'has_partial',
          ]),
          polarity: CompositionClaimPolarity.supportive,
          tags: const <String>{'capability', 'contact'},
        ),
        if (total == 1) _lowEvidenceClaim(total),
        _supportBeforeExpansionClaim(facts, total),
        _librarySupportClaim(total),
      ]);
      shape = ReflectionShape.supportiveRecalibration;
      primaryClaimId = CompositionClaimId.partialContactMaintained;
    } else if (signals.contains('broad_flow_spread') &&
        signals.contains('mostly_observed')) {
      claims.addAll(<CompositionClaim>[
        _claim(
          id: CompositionClaimId.breadthAsRange,
          strength: CompositionClaimStrength.medium,
          evidenceCount: total,
          evidenceSummary:
              '$distinctFlows flows touched across $observed observed completions',
          sourceSignalIds: _presentSignals(signals, const <String>[
            'broad_flow_spread',
            'mostly_observed',
          ]),
          polarity: CompositionClaimPolarity.supportive,
          tags: const <String>{'capability', 'range'},
        ),
        _claim(
          id: CompositionClaimId.breadthNeedsCenter,
          strength: CompositionClaimStrength.medium,
          evidenceCount: total,
          evidenceSummary:
              '$distinctFlows completed flows indicate range; center selection can improve structure',
          sourceSignalIds: _presentSignals(signals, const <String>[
            'broad_flow_spread',
            'mostly_observed',
          ]),
          polarity: CompositionClaimPolarity.neutral,
          tags: const <String>{'calibration', 'centering'},
        ),
        _flowReadyClaim(observed, distinctFlows),
      ]);
      shape = ReflectionShape.breadthCentering;
      primaryClaimId = CompositionClaimId.breadthAsRange;
    } else if (signals.contains('single_flow_depth') &&
        signals.contains('mostly_observed')) {
      final dominantFlow = facts.dominantFlowKey ?? 'one flow';
      claims.addAll(<CompositionClaim>[
        _claim(
          id: CompositionClaimId.singleFlowDepth,
          strength: CompositionClaimStrength.medium,
          evidenceCount: total,
          evidenceSummary:
              '$total interactions returned to $dominantFlow across $activeDays active days',
          sourceSignalIds: _presentSignals(signals, const <String>[
            'single_flow_depth',
            'mostly_observed',
          ]),
          polarity: CompositionClaimPolarity.supportive,
          tags: const <String>{'capability', 'depth'},
        ),
        _flowReadyClaim(observed, distinctFlows),
      ]);
      shape = ReflectionShape.singleThreadContinuation;
      primaryClaimId = CompositionClaimId.singleFlowDepth;
    } else if (signals.contains('mostly_observed')) {
      claims.addAll(<CompositionClaim>[
        _claim(
          id: CompositionClaimId.steadyPresence,
          strength: CompositionClaimStrength.medium,
          evidenceCount: observed,
          evidenceSummary:
              '$observed observed completions across $distinctFlows flows',
          sourceSignalIds: const <String>['mostly_observed'],
          polarity: CompositionClaimPolarity.supportive,
          tags: const <String>{'capability', 'continuation'},
        ),
        _flowReadyClaim(observed, distinctFlows),
      ]);
      shape = ReflectionShape.steadyContinuation;
      primaryClaimId = CompositionClaimId.steadyPresence;
    } else {
      claims.addAll(<CompositionClaim>[
        _recordedContactClaim(
          total: total,
          observed: observed,
          partial: partial,
          skipped: skipped,
          activeDays: activeDays,
          distinctFlows: distinctFlows,
          sourceSignalIds: _presentSignals(signals, const <String>[
            'has_partial',
            'has_skipped',
            'low_follow_through',
          ]),
        ),
        if (total == 1) _lowEvidenceClaim(total),
        _supportBeforeExpansionClaim(facts, total),
        _librarySupportClaim(total),
      ]);
      shape = total == 1
          ? ReflectionShape.lowEvidenceReturn
          : ReflectionShape.supportiveRecalibration;
      primaryClaimId = CompositionClaimId.recordedContact;
    }

    claims.addAll(_crossFlowClaims(facts.crossFlowInference));
    return _plan(
      facts: facts,
      claims: claims,
      reflectionShape: shape,
      primaryClaimId: primaryClaimId,
    );
  }

  CompositionClaimPlan _plan({
    required CompositionFactSnapshot facts,
    required List<CompositionClaim> claims,
    required ReflectionShape reflectionShape,
    required CompositionClaimId primaryClaimId,
  }) {
    final supportingClaimIds = claims
        .map((claim) => claim.id)
        .where((claimId) => claimId != primaryClaimId)
        .toList(growable: false);
    final claimFingerprint = stableCompositionFingerprint(<String, Object?>{
      'version': kDecanCompositionClaimDeriverVersion,
      'fact_fingerprint': facts.factFingerprint,
      'reflection_shape': reflectionShape.wireName,
      'primary_claim_id': primaryClaimId.wireName,
      'claims': claims
          .map(
            (claim) => <String, Object?>{
              'id': claim.id.wireName,
              'strength': claim.strength.wireName,
              'evidence_count': claim.evidenceCount,
              'source_signal_ids': claim.sourceSignalIds,
              'tags': claim.tags.toList()..sort(),
            },
          )
          .toList(growable: false),
      if (facts.crossFlowInference != null)
        'cross_flow_inference': facts.crossFlowInference,
    });
    return CompositionClaimPlan(
      claims: claims,
      reflectionShape: reflectionShape,
      primaryClaimId: primaryClaimId,
      supportingClaimIds: supportingClaimIds,
      claimFingerprint: claimFingerprint,
      crossFlowInference: facts.crossFlowInference,
    );
  }

  static CompositionClaim _claim({
    required CompositionClaimId id,
    required CompositionClaimStrength strength,
    required int evidenceCount,
    required String evidenceSummary,
    required List<String> sourceSignalIds,
    required CompositionClaimPolarity polarity,
    required Set<String> tags,
    CompositionClaimPrivacyClass privacyClass =
        CompositionClaimPrivacyClass.behavioralAggregate,
  }) {
    final sortedSourceSignals = sourceSignalIds.toList()..sort();
    return CompositionClaim(
      id: id,
      strength: strength,
      evidenceCount: evidenceCount,
      evidenceSummary: evidenceSummary,
      sourceSignalIds: sortedSourceSignals,
      privacyClass: privacyClass,
      polarity: polarity,
      tags: tags,
    );
  }

  static CompositionClaim _recordedContactClaim({
    required int total,
    required int observed,
    required int partial,
    required int skipped,
    required int activeDays,
    required int distinctFlows,
    required List<String> sourceSignalIds,
  }) {
    return _claim(
      id: CompositionClaimId.recordedContact,
      strength: CompositionClaimStrength.low,
      evidenceCount: total,
      evidenceSummary:
          '$total recorded interactions across $activeDays active days and $distinctFlows flows; $observed observed, $partial partial, $skipped skipped',
      sourceSignalIds: sourceSignalIds,
      polarity: CompositionClaimPolarity.supportive,
      tags: const <String>{'capability', 'recorded_contact'},
    );
  }

  static List<CompositionClaim> _crossFlowClaims(
    Map<String, Object?>? inference,
  ) {
    if (inference == null) return const <CompositionClaim>[];
    final type = inference['type']?.toString().trim();
    if (type == null || type.isEmpty) return const <CompositionClaim>[];

    final axis = inference['axis']?.toString().trim() ?? 'intention';
    final value = inference['value']?.toString().trim() ?? 'shared_intention';
    final observed = _intPayload(inference, 'observed_count');
    final partial = _intPayload(inference, 'partial_count');
    final skipped = _intPayload(inference, 'skipped_count');
    final total = _intPayload(inference, 'total_count');
    final supportingFlowKeys = _stringListPayload(
      inference,
      'supporting_flow_keys',
    );
    final flowCount = supportingFlowKeys.length;
    final strength = _strengthFromEvidence(
      inference['evidence_strength']?.toString(),
    );
    final sourceSignalIds = <String>[
      'cross_flow_inference',
      type,
      '$axis:$value',
    ];
    final claims = <CompositionClaim>[];

    if (type != 'shared_intention_uncentered') {
      claims.add(
        _claim(
          id: CompositionClaimId.crossFlowSharedIntention,
          strength: strength,
          evidenceCount: total,
          evidenceSummary:
              '$value appeared across $flowCount profiled flows and $total interactions',
          sourceSignalIds: sourceSignalIds,
          polarity: CompositionClaimPolarity.supportive,
          tags: const <String>{'capability', 'cross_flow', 'shared_intention'},
        ),
      );
    }

    final relationshipClaim = switch (type) {
      'shared_intention_holding' => _claim(
        id: CompositionClaimId.crossFlowIntentionHolding,
        strength: strength,
        evidenceCount: observed,
        evidenceSummary:
            '$observed observed completions supported $axis:$value across $flowCount flows',
        sourceSignalIds: sourceSignalIds,
        polarity: CompositionClaimPolarity.supportive,
        tags: const <String>{'capability', 'cross_flow', 'holding'},
      ),
      'shared_intention_friction' => _claim(
        id: CompositionClaimId.crossFlowIntentionFriction,
        strength: strength,
        evidenceCount: skipped,
        evidenceSummary:
            '$skipped skipped marks appeared inside $axis:$value across $flowCount flows',
        sourceSignalIds: sourceSignalIds,
        polarity: CompositionClaimPolarity.cautionary,
        tags: const <String>{'calibration', 'cross_flow', 'right_sizing'},
      ),
      'shared_intention_partial' => _claim(
        id: CompositionClaimId.crossFlowIntentionPartial,
        strength: strength,
        evidenceCount: partial,
        evidenceSummary:
            '$partial partial marks appeared inside $axis:$value across $flowCount flows',
        sourceSignalIds: sourceSignalIds,
        polarity: CompositionClaimPolarity.cautionary,
        tags: const <String>{'calibration', 'cross_flow', 'completion_shape'},
      ),
      'shared_intention_uncentered' => _claim(
        id: CompositionClaimId.crossFlowIntentionUncentered,
        strength: strength,
        evidenceCount: total,
        evidenceSummary:
            '$flowCount profiled flows did not share one dominant intention',
        sourceSignalIds: sourceSignalIds,
        polarity: CompositionClaimPolarity.neutral,
        tags: const <String>{'cross_flow', 'range', 'centering'},
      ),
      _ => null,
    };
    if (relationshipClaim != null) claims.add(relationshipClaim);
    return claims;
  }

  static int _intPayload(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static List<String> _stringListPayload(
    Map<String, Object?> payload,
    String key,
  ) {
    final value = payload[key];
    if (value is! List) return const <String>[];
    return value
        .map((raw) => raw?.toString().trim())
        .whereType<String>()
        .where((raw) => raw.isNotEmpty)
        .toList(growable: false)
      ..sort();
  }

  static CompositionClaimStrength _strengthFromEvidence(String? raw) {
    return switch (raw?.trim()) {
      'high' => CompositionClaimStrength.high,
      'low' => CompositionClaimStrength.low,
      _ => CompositionClaimStrength.medium,
    };
  }

  static CompositionClaim _lowEvidenceClaim(int total) {
    return _claim(
      id: CompositionClaimId.lowEvidence,
      strength: CompositionClaimStrength.low,
      evidenceCount: total,
      evidenceSummary: '$total total interaction is below pattern threshold',
      sourceSignalIds: const <String>['low_data'],
      polarity: CompositionClaimPolarity.neutral,
      tags: const <String>{'calibration', 'low_evidence'},
    );
  }

  static CompositionClaim _supportBeforeExpansionClaim(
    CompositionFactSnapshot facts,
    int total,
  ) {
    return _claim(
      id: CompositionClaimId.supportBeforeExpansion,
      strength: CompositionClaimStrength.low,
      evidenceCount: total,
      evidenceSummary:
          'partial/skipped marks suggest entry size exceeded current conditions',
      sourceSignalIds: _presentSignals(facts.signals, const <String>[
        'low_data',
        'mostly_partial',
        'many_skips',
        'low_follow_through',
        'has_partial',
        'has_skipped',
      ]),
      polarity: CompositionClaimPolarity.cautionary,
      tags: const <String>{'calibration', 'library_support', 'right_sizing'},
    );
  }

  static CompositionClaim _librarySupportClaim(int total) {
    return _claim(
      id: CompositionClaimId.librarySupportRecommended,
      strength: CompositionClaimStrength.low,
      evidenceCount: total,
      evidenceSummary:
          'claim plan favors supportive study before more flow work',
      sourceSignalIds: const <String>[],
      privacyClass: CompositionClaimPrivacyClass.recommendation,
      polarity: CompositionClaimPolarity.neutral,
      tags: const <String>{'library_support', 'recommendation'},
    );
  }

  static CompositionClaim _flowReadyClaim(int observed, int distinctFlows) {
    return _claim(
      id: CompositionClaimId.flowReady,
      strength: CompositionClaimStrength.medium,
      evidenceCount: observed,
      evidenceSummary:
          '$observed observed completions across $distinctFlows flows support flow continuation',
      sourceSignalIds: const <String>['mostly_observed'],
      privacyClass: CompositionClaimPrivacyClass.recommendation,
      polarity: CompositionClaimPolarity.supportive,
      tags: const <String>{'flow_ready', 'continuation', 'recommendation'},
    );
  }

  static int _intFact(CompositionFactSnapshot facts, String key) {
    final value = facts.factSummary[key] ?? facts.facts[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _presentSignals(Set<String> signals, List<String> keys) {
    return keys.where(signals.contains).toList(growable: false);
  }
}
