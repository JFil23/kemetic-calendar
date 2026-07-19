import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/completion_status.dart';
import 'package:mobile/core/composition/composition_engine.dart';
import 'package:mobile/core/composition/composition_models.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/decan_composition_claim_deriver.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/decan_reflection_composer.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/decan_reflection_phrase_bank.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/maat_flow_cross_flow_analyzer.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/maat_flow_decan_fact_collector.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/maat_flow_profile_catalog.dart';

void main() {
  test('stable fingerprint is independent of map insertion order', () {
    final first = stableCompositionFingerprint(<String, Object?>{
      'b': 2,
      'a': <String, Object?>{'d': 4, 'c': 3},
    });
    final second = stableCompositionFingerprint(<String, Object?>{
      'a': <String, Object?>{'c': 3, 'd': 4},
      'b': 2,
    });
    expect(first, second);
  });

  test('phrase requiring a missing claim cannot be selected', () {
    final output = _claimGateEngine.compose(
      facts: _claimGateFacts,
      claimPlan: _claimPlan(<CompositionClaimId>{
        CompositionClaimId.lowEvidence,
      }),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(output, isNotNull);
    expect(output!.phraseIds, <String>['low_opening']);
    expect(output.text, 'Low evidence opening.');
  });

  test('phrase requiring a present claim can be selected', () {
    final output = _claimGateEngine.compose(
      facts: _claimGateFacts,
      claimPlan: _claimPlan(<CompositionClaimId>{
        CompositionClaimId.steadyPresence,
      }),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(output, isNotNull);
    expect(output!.phraseIds, <String>['steady_opening']);
    expect(output.text, 'Steady opening.');
  });

  test('opening evidence phrases cannot use unsupported claims', () {
    final output = _claimGateEngine.compose(
      facts: _claimGateFacts,
      claimPlan: _claimPlan(<CompositionClaimId>{
        CompositionClaimId.skippedGateTooHeavy,
      }),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(output, isNull);
  });

  test('same claim plan produces the same derived intent and use case', () {
    final claimPlan = _claimPlan(<CompositionClaimId>{
      CompositionClaimId.steadyPresence,
    }, reflectionShape: ReflectionShape.steadyContinuation);
    final first = _shapeIntentEngine.compose(
      facts: _shapeIntentFacts(const <String>{'many_skips'}),
      claimPlan: claimPlan,
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );
    final second = _shapeIntentEngine.compose(
      facts: _shapeIntentFacts(const <String>{'mostly_partial'}),
      claimPlan: claimPlan,
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.intentId, 'shape_steady');
    expect(second!.intentId, first.intentId);
    expect(second.text, first.text);
    expect(second.phraseIds, first.phraseIds);
  });

  test('intent is derived from claim shape instead of raw signals', () {
    final output = _shapeIntentEngine.compose(
      facts: _shapeIntentFacts(const <String>{'many_skips'}),
      claimPlan: _claimPlan(<CompositionClaimId>{
        CompositionClaimId.steadyPresence,
      }, reflectionShape: ReflectionShape.steadyContinuation),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(output, isNotNull);
    expect(output!.intentId, 'shape_steady');
    expect(output.phraseIds, <String>['steady_shape_phrase']);
  });

  test('zero-data decan produces no reflection', () {
    final facts = MaatFlowDecanFactCollector.snapshotFromCompletions(
      completions: const <MaatFlowDecanCompletion>[],
      decanStart: DateTime(2026, 6, 1),
      decanEnd: DateTime(2026, 6, 10),
      surface: kDecanReflectionSurface,
    );
    final output = const DecanReflectionComposer().compose(
      facts: facts,
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );
    expect(output, isNull);
  });

  test('low-data decan only selects low claim-strength phrases', () {
    final facts = MaatFlowDecanFactCollector.snapshotFromCompletions(
      completions: <MaatFlowDecanCompletion>[
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 2),
          completionStatus: CompletionStatus.observed,
          flowKey: 'the-weighing',
        ),
      ],
      decanStart: DateTime(2026, 6, 1),
      decanEnd: DateTime(2026, 6, 10),
      surface: kDecanReflectionSurface,
    );
    final composition = const DecanReflectionComposer().compose(
      facts: facts,
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(composition, isNotNull);
    expect(composition!.output.intentId, 'decan_low_data');
    final phrasesById = {
      for (final phrase in kDecanReflectionPhrases) phrase.id: phrase,
    };
    for (final phraseId in composition.output.phraseIds) {
      expect(
        phrasesById[phraseId]?.claimStrength,
        CompositionClaimStrength.low,
      );
    }
    expect(composition.output.text, isNot(contains('maintained')));
    expect(
      composition.output.text.split('. '),
      hasLength(greaterThanOrEqualTo(4)),
    );
    expect(composition.output.text, contains('The Plain Record'));
    expect(composition.output.text, contains('honest review'));
    expect(composition.output.phraseIds, contains('flow_weighing_light'));
    expect(
      composition.output.phraseIds,
      isNot(contains('flow_weighing_depth')),
    );
    expect(composition.output.text, isNot(contains('{')));
    expect(composition.output.text, isNot(contains(r'$1')));
    expect(
      composition.output.recommendation.type,
      CompositionRecommendationType.library,
    );
    expect(composition.output.recommendation.key, 'the-plain-record');
  });

  test('flow intention entries cover finite Ma_at flow keys', () {
    final flowIntentionCounts = <String, int>{};
    for (final phrase in kDecanReflectionPhrases) {
      if (!phrase.tags.contains('flow_intention')) continue;
      final flowKey = phrase.optionalFlowKey;
      if (flowKey == null) continue;
      flowIntentionCounts[flowKey] = (flowIntentionCounts[flowKey] ?? 0) + 1;
    }

    for (final flowKey in _finiteMaatFlowKeys) {
      expect(
        flowIntentionCounts[flowKey],
        greaterThanOrEqualTo(3),
        reason: flowKey,
      );
    }
  });

  test('flow intention entries are plain and evidence calibrated', () {
    const forbiddenShorthand = <String>[
      'sky-witness',
      'scale-work',
      'boundary-witness',
      'pattern-witness',
      'reckoning',
      'carried the pattern',
      'deepened through repetition',
    ];

    for (final phrase in kDecanReflectionPhrases) {
      if (!phrase.tags.contains('flow_intention')) continue;
      expect(phrase.text, contains(':'), reason: phrase.id);
      final explanation = phrase.text.split(':').skip(1).join(':').trim();
      expect(explanation, isNotEmpty, reason: phrase.id);

      final lower = phrase.text.toLowerCase();
      for (final forbidden in forbiddenShorthand) {
        expect(lower, isNot(contains(forbidden)), reason: phrase.id);
      }

      if (phrase.tags.contains('flow_intention_light')) {
        expect(phrase.text, contains(' points toward '), reason: phrase.id);
        expect(phrase.text, isNot(startsWith('This flow')), reason: phrase.id);
        expect(phrase.text, isNot(contains('You practiced')));
      } else {
        expect(phrase.text, startsWith('Through '), reason: phrase.id);
        expect(phrase.text, contains(', you practiced '), reason: phrase.id);
      }
    }
  });

  test('phrase bank omits usefulness-audit filler phrases', () {
    const forbiddenStarters = <String>[
      'The lesson is',
      'The useful lesson is',
      'The useful pattern is',
    ];
    const forbiddenFragments = <String>[
      'protect the setup that made return possible',
      'keep the next step close to the conditions that already worked',
      'support the return before asking for expansion',
      'let the rhythm prove itself again',
    ];

    for (final phrase in kDecanReflectionPhrases) {
      final text = phrase.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      for (final starter in forbiddenStarters) {
        expect(text, isNot(startsWith(starter)), reason: phrase.id);
      }
      final lower = text.toLowerCase();
      for (final fragment in forbiddenFragments) {
        expect(lower, isNot(contains(fragment)), reason: phrase.id);
      }
    }
  });

  test('dominant flow changes intention substance beyond title', () {
    final composer = const DecanReflectionComposer();
    final track = composer.compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'track-the-sky'),
        _completion(3, CompletionStatus.observed, 'track-the-sky'),
        _completion(5, CompletionStatus.observed, 'track-the-sky'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );
    final weighing = composer.compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'the-weighing'),
        _completion(3, CompletionStatus.observed, 'the-weighing'),
        _completion(5, CompletionStatus.observed, 'the-weighing'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(track, isNotNull);
    expect(weighing, isNotNull);
    expect(track!.output.phraseIds, contains('flow_track_sky_depth'));
    expect(weighing!.output.phraseIds, contains('flow_weighing_depth'));
    expect(
      track.output.text,
      contains('Through Track the Sky, you practiced steady attention'),
    );
    expect(track.output.text, contains('visible'));
    expect(
      weighing.output.text,
      contains('Through The Weighing, you practiced honest review'),
    );
    expect(weighing.output.text, contains('correction'));
    expect(
      track.output.text.replaceAll('Track the Sky', 'The Weighing'),
      isNot(weighing.output.text),
    );
  });

  test('strong flow intention requires more than two interactions', () {
    final twoMarks = const DecanReflectionComposer().compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'track-the-sky'),
        _completion(3, CompletionStatus.observed, 'track-the-sky'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(twoMarks, isNotNull);
    expect(twoMarks!.output.phraseIds, isNot(contains('flow_track_sky_depth')));
    expect(
      twoMarks.output.text.toLowerCase(),
      isNot(contains('you practiced steady attention')),
    );
  });

  test('low-data skipped names flow purpose without claiming practice', () {
    final composition = const DecanReflectionComposer().compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(4, CompletionStatus.skipped, 'track-the-sky'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(composition, isNotNull);
    expect(composition!.output.phraseIds, contains('flow_track_sky_light'));
    expect(composition.output.text, contains('Track the Sky points toward'));
    expect(composition.output.text, contains('steady attention'));
    expect(
      composition.output.text.toLowerCase(),
      isNot(contains('you practiced')),
    );
  });

  test('recent phrase usage gives similar fact sets some wording range', () {
    final facts = MaatFlowDecanFactCollector.snapshotFromCompletions(
      completions: <MaatFlowDecanCompletion>[
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 1),
          completionStatus: CompletionStatus.observed,
          flowKey: 'track-the-sky',
        ),
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 3),
          completionStatus: CompletionStatus.observed,
          flowKey: 'track-the-sky',
        ),
      ],
      decanStart: DateTime(2026, 6, 1),
      decanEnd: DateTime(2026, 6, 10),
      surface: kDecanReflectionSurface,
    );
    final composer = const DecanReflectionComposer();
    final first = composer.compose(
      facts: facts,
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );
    final second = composer.compose(
      facts: facts,
      usageHistory: first!.output.phraseIds
          .map(
            (phraseId) => CompositionUsageRecord(
              phraseId: phraseId,
              date: DateTime(2026, 6, 11),
              surface: kDecanReflectionSurface,
            ),
          )
          .toList(growable: false),
      generatedAt: DateTime(2026, 6, 12),
    );

    expect(second, isNotNull);
    expect(second!.output.phraseIds, isNot(first.output.phraseIds));
    expect(second.output.text, isNot(first.output.text));
  });

  test('compositional provenance excludes generated body text', () {
    final facts = MaatFlowDecanFactCollector.snapshotFromCompletions(
      completions: <MaatFlowDecanCompletion>[
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 1),
          completionStatus: CompletionStatus.observed,
          flowKey: 'track-the-sky',
        ),
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 3),
          completionStatus: CompletionStatus.observed,
          flowKey: 'track-the-sky',
        ),
      ],
      decanStart: DateTime(2026, 6, 1),
      decanEnd: DateTime(2026, 6, 10),
      surface: kDecanReflectionSurface,
    );
    final composition = const DecanReflectionComposer().compose(
      facts: facts,
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );
    final raw = composition!.renderMetadata.raw;

    expect(raw['engine_version'], kCompositionEngineVersion);
    expect(raw['phrase_bank_version'], kDecanReflectionPhraseBankVersion);
    expect(raw['claim_deriver_version'], kDecanCompositionClaimDeriverVersion);
    expect(raw['claimDeriverVersion'], kDecanCompositionClaimDeriverVersion);
    expect(
      raw['recommendation_policy_version'],
      kDecanReflectionRecommendationPolicyVersion,
    );
    expect(
      raw['recommendationPolicyVersion'],
      kDecanReflectionRecommendationPolicyVersion,
    );
    expect(raw, contains('fact_fingerprint'));
    expect(raw, contains('claim_fingerprint'));
    expect(raw, contains('claimFingerprint'));
    expect(raw['claim_ids'], contains('single_flow_depth'));
    expect(raw['claimIds'], contains('flow_ready'));
    expect(raw['reflection_shape'], 'single_thread_continuation');
    expect(raw['reflectionShape'], 'single_thread_continuation');
    expect(raw, contains('intent_id'));
    expect(raw, contains('phrase_ids'));
    expect(raw['recommendation_type'], 'flow');
    expect(raw['recommendation_key'], 'track-the-sky');
    expect(raw, isNot(contains('claims')));
    expect(raw, isNot(contains('detail_body')));
    expect(raw, isNot(contains('badge_body')));
    final rawText = jsonEncode(raw);
    expect(rawText, isNot(contains(composition.output.text)));
    expect(rawText, isNot(contains('journal_text')));
    expect(rawText, isNot(contains('private_notes')));
    expect(rawText, isNot(contains('reflection_text')));
  });

  test('cross-flow provenance is metadata-only when inference is used', () {
    final withoutInference = const DecanReflectionComposer().compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'track-the-sky'),
        _completion(3, CompletionStatus.observed, 'track-the-sky'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );
    final withInference = const DecanReflectionComposer().compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'the-weighing'),
        _completion(2, CompletionStatus.observed, 'the-true-name'),
        _completion(3, CompletionStatus.observed, 'the-autobiography'),
        _completion(4, CompletionStatus.observed, 'the-living-record'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(withoutInference, isNotNull);
    expect(
      withoutInference!.renderMetadata.raw,
      isNot(contains('cross_flow_inference')),
    );
    expect(
      withoutInference.renderMetadata.raw,
      isNot(contains('cross_flow_analyzer_version')),
    );

    expect(withInference, isNotNull);
    final raw = withInference!.renderMetadata.raw;
    expect(
      raw['cross_flow_analyzer_version'],
      kMaatFlowCrossFlowAnalyzerVersion,
    );
    expect(raw['flow_profile_catalog_version'], kMaatFlowProfileCatalogVersion);
    expect(
      raw['cross_flow_claim_ids'],
      contains('cross_flow_shared_intention'),
    );
    expect(
      raw['cross_flow_claim_ids'],
      contains('cross_flow_intention_holding'),
    );

    final crossFlow = raw['cross_flow_inference'];
    expect(crossFlow, isA<Map>());
    expect((crossFlow as Map)['type'], 'shared_intention_holding');
    expect(crossFlow['axis'], 'practice_type');
    expect(crossFlow['value'], 'record_keeping');
    final crossFlowText = jsonEncode(crossFlow);
    expect(crossFlowText, isNot(contains(withInference.output.text)));
    expect(crossFlowText, isNot(contains('journal_text')));
    expect(crossFlowText, isNot(contains('private_notes')));
    expect(crossFlowText, isNot(contains('reflection_text')));
    expect(crossFlowText, isNot(contains('AIReflectionService')));
  });

  test('cross-flow phrases are gated by cross-flow claims', () {
    final crossFlowPhrases = kDecanReflectionPhrases
        .where((phrase) => phrase.id.startsWith('cross_flow_'))
        .toList(growable: false);

    expect(crossFlowPhrases, isNotEmpty);
    for (final phrase in crossFlowPhrases) {
      expect(
        phrase.requiresClaims.any(_isCrossFlowClaimId),
        isTrue,
        reason: phrase.id,
      );
    }

    final thin = const DecanReflectionComposer().compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'the-weighing'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );
    final singleFlow = const DecanReflectionComposer().compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'track-the-sky'),
        _completion(3, CompletionStatus.observed, 'track-the-sky'),
        _completion(5, CompletionStatus.observed, 'track-the-sky'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(thin, isNotNull);
    expect(singleFlow, isNotNull);
    expect(_hasCrossFlowPhrase(thin!), isFalse);
    expect(_hasCrossFlowPhrase(singleFlow!), isFalse);
    expect(thin.renderMetadata.raw, isNot(contains('cross_flow_inference')));
    expect(
      singleFlow.renderMetadata.raw,
      isNot(contains('cross_flow_inference')),
    );
  });

  test(
    'cross-flow holding names shared intention in multi-flow reflection',
    () {
      final composition = const DecanReflectionComposer().compose(
        facts: _decanFacts(<MaatFlowDecanCompletion>[
          _completion(1, CompletionStatus.observed, 'the-weighing'),
          _completion(2, CompletionStatus.observed, 'the-true-name'),
          _completion(3, CompletionStatus.observed, 'the-autobiography'),
          _completion(4, CompletionStatus.observed, 'the-living-record'),
        ]),
        usageHistory: const [],
        generatedAt: DateTime(2026, 6, 11),
      );

      expect(composition, isNotNull);
      expect(composition!.output.text, contains('record-keeping'));
      expect(
        composition.output.phraseIds,
        contains('cross_flow_holding_consequence'),
      );
    },
  );

  test('cross-flow partial and friction phrases calibrate follow-through', () {
    final partial = const DecanReflectionComposer().compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'the-weighing'),
        _completion(2, CompletionStatus.observed, 'the-true-name'),
        _completion(3, CompletionStatus.partial, 'the-autobiography'),
        _completion(4, CompletionStatus.partial, 'the-living-record'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );
    final friction = const DecanReflectionComposer().compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'the-weighing'),
        _completion(2, CompletionStatus.observed, 'the-true-name'),
        _completion(3, CompletionStatus.skipped, 'the-autobiography'),
        _completion(4, CompletionStatus.skipped, 'the-living-record'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(partial, isNotNull);
    expect(
      partial!.output.phraseIds,
      contains('cross_flow_partial_interpretation'),
    );
    expect(partial.output.text, contains('record-keeping'));
    expect(partial.output.text, contains('needs easier completion'));

    expect(friction, isNotNull);
    expect(
      friction!.output.phraseIds,
      contains('cross_flow_friction_interpretation'),
    );
    expect(friction.output.text, contains('record-keeping'));
    expect(friction.output.text, contains('gate is breaking'));
  });

  test('cross-flow uncentered names lack of shared center', () {
    final composition = const DecanReflectionComposer().compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'track-the-sky'),
        _completion(2, CompletionStatus.observed, 'the-open-hand'),
        _completion(3, CompletionStatus.observed, 'the-first-arrangement'),
        _completion(4, CompletionStatus.observed, 'the-kept-word'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(composition, isNotNull);
    expect(
      composition!.output.phraseIds,
      contains('cross_flow_uncentered_interpretation'),
    );
    expect(composition.output.text, contains('several directions'));
    expect(
      composition.output.text,
      contains('no single practice held the center'),
    );
  });

  test('cross-flow user-facing copy avoids schema language', () {
    const bannedFragments = <String>[
      'shared intention',
      'structure is holding',
      'traction',
      'axis',
      'value',
      'solitary practice structure',
    ];

    for (final composition
        in _smokeScenarioCompositions()
            .whereType<DecanReflectionComposition>()) {
      for (final fragment in bannedFragments) {
        expect(
          composition.output.text.toLowerCase(),
          isNot(contains(fragment)),
          reason: composition.output.text,
        );
      }
    }

    final strongFinish = _smokeScenarioCompositions()
        .whereType<DecanReflectionComposition>()
        .firstWhere(
          (composition) => composition.output.phraseIds.contains(
            'steady_obs_return_after_interruption',
          ),
        );
    expect(
      strongFinish.output.phraseIds.where(
        (phraseId) => phraseId.startsWith('cross_flow_'),
      ),
      isEmpty,
    );
  });

  test('skipped-heavy and partial decans recommend Library support', () {
    final skippedFacts = MaatFlowDecanFactCollector.snapshotFromCompletions(
      completions: <MaatFlowDecanCompletion>[
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 1),
          completionStatus: CompletionStatus.skipped,
          flowKey: 'track-the-sky',
        ),
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 2),
          completionStatus: CompletionStatus.skipped,
          flowKey: 'track-the-sky',
        ),
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 3),
          completionStatus: CompletionStatus.observed,
          flowKey: 'track-the-sky',
        ),
      ],
      decanStart: DateTime(2026, 6, 1),
      decanEnd: DateTime(2026, 6, 10),
      surface: kDecanReflectionSurface,
    );
    final partialFacts = MaatFlowDecanFactCollector.snapshotFromCompletions(
      completions: <MaatFlowDecanCompletion>[
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 1),
          completionStatus: CompletionStatus.partial,
          flowKey: 'track-the-sky',
        ),
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 2),
          completionStatus: CompletionStatus.partial,
          flowKey: 'track-the-sky',
        ),
      ],
      decanStart: DateTime(2026, 6, 1),
      decanEnd: DateTime(2026, 6, 10),
      surface: kDecanReflectionSurface,
    );
    final composer = const DecanReflectionComposer();
    final skipped = composer.compose(
      facts: skippedFacts,
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );
    final partial = composer.compose(
      facts: partialFacts,
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(
      skipped?.output.recommendation.type,
      CompositionRecommendationType.library,
    );
    expect(skipped?.output.recommendation.key, 'small-gates');
    expect(
      partial?.output.recommendation.type,
      CompositionRecommendationType.library,
    );
    expect(partial?.output.recommendation.key, 'keeping-the-measure');
  });

  test(
    'steady and broad observed decans recommend Ma_at Flow continuation',
    () {
      final steadyFacts = MaatFlowDecanFactCollector.snapshotFromCompletions(
        completions: <MaatFlowDecanCompletion>[
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 1),
            completionStatus: CompletionStatus.observed,
            flowKey: 'track-the-sky',
          ),
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 2),
            completionStatus: CompletionStatus.observed,
            flowKey: 'track-the-sky',
          ),
        ],
        decanStart: DateTime(2026, 6, 1),
        decanEnd: DateTime(2026, 6, 10),
        surface: kDecanReflectionSurface,
      );
      final broadFacts = MaatFlowDecanFactCollector.snapshotFromCompletions(
        completions: <MaatFlowDecanCompletion>[
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 1),
            completionStatus: CompletionStatus.observed,
            flowKey: 'track-the-sky',
          ),
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 2),
            completionStatus: CompletionStatus.observed,
            flowKey: 'the-weighing',
          ),
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 3),
            completionStatus: CompletionStatus.observed,
            flowKey: 'reading-house',
          ),
        ],
        decanStart: DateTime(2026, 6, 1),
        decanEnd: DateTime(2026, 6, 10),
        surface: kDecanReflectionSurface,
      );
      final composer = const DecanReflectionComposer();
      final steady = composer.compose(
        facts: steadyFacts,
        usageHistory: const [],
        generatedAt: DateTime(2026, 6, 11),
      );
      final broad = composer.compose(
        facts: broadFacts,
        usageHistory: const [],
        generatedAt: DateTime(2026, 6, 11),
      );

      expect(
        steady?.output.recommendation.type,
        CompositionRecommendationType.flow,
      );
      expect(steady?.output.recommendation.key, 'track-the-sky');
      expect(
        broad?.output.recommendation.type,
        CompositionRecommendationType.flow,
      );
      expect(broad?.output.recommendation.key, 'the-weighing');
    },
  );

  test(
    'claim-routed recommendations cover single-flow, mixed, and one skip',
    () {
      final singleFlowFacts =
          MaatFlowDecanFactCollector.snapshotFromCompletions(
            completions: <MaatFlowDecanCompletion>[
              MaatFlowDecanCompletion(
                completedOn: DateTime(2026, 6, 1),
                completionStatus: CompletionStatus.observed,
                flowKey: 'reading-house',
              ),
              MaatFlowDecanCompletion(
                completedOn: DateTime(2026, 6, 2),
                completionStatus: CompletionStatus.observed,
                flowKey: 'reading-house',
              ),
            ],
            decanStart: DateTime(2026, 6, 1),
            decanEnd: DateTime(2026, 6, 10),
            surface: kDecanReflectionSurface,
          );
      final mixedFacts = MaatFlowDecanFactCollector.snapshotFromCompletions(
        completions: <MaatFlowDecanCompletion>[
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 1),
            completionStatus: CompletionStatus.observed,
            flowKey: 'track-the-sky',
          ),
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 2),
            completionStatus: CompletionStatus.partial,
            flowKey: 'track-the-sky',
          ),
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 3),
            completionStatus: CompletionStatus.skipped,
            flowKey: 'the-weighing',
          ),
        ],
        decanStart: DateTime(2026, 6, 1),
        decanEnd: DateTime(2026, 6, 10),
        surface: kDecanReflectionSurface,
      );
      final oneSkipFacts = MaatFlowDecanFactCollector.snapshotFromCompletions(
        completions: <MaatFlowDecanCompletion>[
          MaatFlowDecanCompletion(
            completedOn: DateTime(2026, 6, 1),
            completionStatus: CompletionStatus.skipped,
            flowKey: 'track-the-sky',
          ),
        ],
        decanStart: DateTime(2026, 6, 1),
        decanEnd: DateTime(2026, 6, 10),
        surface: kDecanReflectionSurface,
      );
      final composer = const DecanReflectionComposer();
      final singleFlow = composer.compose(
        facts: singleFlowFacts,
        usageHistory: const [],
        generatedAt: DateTime(2026, 6, 11),
      );
      final mixed = composer.compose(
        facts: mixedFacts,
        usageHistory: const [],
        generatedAt: DateTime(2026, 6, 11),
      );
      final oneSkip = composer.compose(
        facts: oneSkipFacts,
        usageHistory: const [],
        generatedAt: DateTime(2026, 6, 11),
      );

      expect(
        singleFlow?.output.recommendation.type,
        CompositionRecommendationType.flow,
      );
      expect(singleFlow?.output.recommendation.key, 'reading-house');
      expect(singleFlow?.output.recommendation.title, 'Reading House');
      expect(
        mixed?.output.recommendation.type,
        CompositionRecommendationType.library,
      );
      expect(mixed?.output.recommendation.key, 'returning-without-force');
      expect(
        oneSkip?.output.recommendation.type,
        CompositionRecommendationType.library,
      );
      expect(oneSkip?.output.recommendation.key, 'the-plain-record');
    },
  );

  test('copy pass keeps openings capability-led and recommendations clean', () {
    final scenarios = <List<MaatFlowDecanCompletion>>[
      <MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.partial, 'balance'),
        _completion(2, CompletionStatus.partial, 'balance'),
        _completion(3, CompletionStatus.observed, 'balance'),
      ],
      <MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.skipped, 'truth'),
        _completion(2, CompletionStatus.skipped, 'truth'),
        _completion(3, CompletionStatus.observed, 'truth'),
      ],
      <MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.skipped, 'order'),
      ],
      <MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'truth'),
        _completion(2, CompletionStatus.partial, 'balance'),
        _completion(3, CompletionStatus.skipped, 'truth'),
      ],
    ];
    final composer = const DecanReflectionComposer();

    for (final completions in scenarios) {
      final composition = composer.compose(
        facts: _decanFacts(completions),
        usageHistory: const [],
        generatedAt: DateTime(2026, 6, 11),
      );
      final text = composition?.output.text ?? '';
      final opening = _firstSentence(text).toLowerCase();
      final recommendation = _lastSentence(text).toLowerCase();

      expect(composition, isNotNull);
      expect(opening, isNot(startsWith('skipped')));
      expect(opening, isNot(startsWith('most of this')));
      expect(opening, isNot(contains('not enough evidence')));
      expect(recommendation, isNot(contains(' because ')));
    }
  });

  test('dominant principle inflects the interpretation line', () {
    final composer = const DecanReflectionComposer();
    final truth = composer.compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'truth'),
        _completion(2, CompletionStatus.observed, 'truth'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );
    final order = composer.compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'order'),
        _completion(2, CompletionStatus.observed, 'order'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );
    final balance = composer.compose(
      facts: _decanFacts(<MaatFlowDecanCompletion>[
        _completion(1, CompletionStatus.observed, 'balance'),
        _completion(2, CompletionStatus.observed, 'balance'),
      ]),
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(truth?.output.text, contains('Truth deepens through repetition'));
    expect(order?.output.text, contains('Order deepens when repetition'));
    expect(balance?.output.text, contains('Balance keeps depth proportional'));
  });

  test(
    'steady record with interruption differs from generic mostly observed',
    () {
      final composer = const DecanReflectionComposer();
      final generic = composer.compose(
        facts: _decanFacts(<MaatFlowDecanCompletion>[
          _completion(1, CompletionStatus.observed, 'track-the-sky'),
          _completion(2, CompletionStatus.observed, 'the-weighing'),
          _completion(4, CompletionStatus.observed, 'track-the-sky'),
          _completion(6, CompletionStatus.observed, 'the-weighing'),
        ]),
        usageHistory: const [],
        generatedAt: DateTime(2026, 6, 11),
      );
      final interrupted = composer.compose(
        facts: _decanFacts(<MaatFlowDecanCompletion>[
          _completion(1, CompletionStatus.skipped, 'track-the-sky'),
          _completion(7, CompletionStatus.observed, 'the-weighing'),
          _completion(8, CompletionStatus.observed, 'the-weighing'),
          _completion(10, CompletionStatus.observed, 'track-the-sky'),
        ]),
        usageHistory: const [],
        generatedAt: DateTime(2026, 6, 11),
      );

      expect(generic?.output.intentId, 'decan_steady_presence');
      expect(interrupted?.output.intentId, 'decan_steady_presence');
      expect(
        interrupted?.output.phraseIds,
        contains('steady_obs_return_after_interruption'),
      );
      expect(interrupted?.output.text, isNot(generic?.output.text));
    },
  );

  test('ten-scenario smoke matrix exposes distinct information', () {
    final compositions = _smokeScenarioCompositions();

    expect(compositions.first, isNull);
    final nonZero = compositions.whereType<DecanReflectionComposition>().toList(
      growable: false,
    );
    expect(nonZero, hasLength(9));

    final seenSentences = <String>{};
    final duplicateSentences = <String>[];
    final principleSentences = <String>[];
    for (final composition in nonZero) {
      for (final sentence in _sentences(composition.output.text)) {
        expect(
          _startsWithUsefulnessAuditFiller(sentence),
          isFalse,
          reason: composition.output.text,
        );
        if (!seenSentences.add(sentence)) {
          duplicateSentences.add(sentence);
        }
        if (_isPrincipleSentence(sentence)) {
          principleSentences.add(sentence);
        }
      }
    }
    expect(duplicateSentences, isEmpty);

    final openings = nonZero
        .map((composition) => _firstSentence(composition.output.text))
        .toList(growable: false);
    final maatOpeningCount = openings
        .where((opening) => opening.toLowerCase().contains('ma’at'))
        .length;
    expect(maatOpeningCount, lessThanOrEqualTo(2));

    final carrierCounts = <String, int>{};
    for (final opening in openings) {
      final carrier = _openingCarrier(opening);
      carrierCounts[carrier] = (carrierCounts[carrier] ?? 0) + 1;
    }
    expect(
      carrierCounts.keys,
      containsAll(<String>[
        'count',
        'flow',
        'active_day_span',
        'record',
        'principle',
      ]),
    );
    expect(carrierCounts.values.reduce((a, b) => a > b ? a : b), lessThan(4));

    final broad = nonZero.firstWhere(
      (composition) => composition.output.intentId == 'decan_broad_flow_spread',
    );
    expect(broad.output.text, contains('reached in several directions'));
    expect(broad.output.text, contains('no single practice held the center'));
    expect(
      broad.output.phraseIds.where((phraseId) => phraseId.startsWith('flow_')),
      isEmpty,
    );

    final singleFlow = nonZero.firstWhere(
      (composition) => composition.output.intentId == 'decan_single_flow_depth',
    );
    expect(
      singleFlow.output.text,
      contains('Repeat “Track the Sky” for one more decan.'),
    );

    final repeatedPrincipleSentences = <String>[];
    final seenPrincipleSentences = <String>{};
    for (final sentence in principleSentences) {
      if (!seenPrincipleSentences.add(sentence)) {
        repeatedPrincipleSentences.add(sentence);
      }
    }
    expect(repeatedPrincipleSentences, isEmpty);
    expect(
      principleSentences,
      isNot(
        contains(
          'Order shows itself as return: the next shape can be smaller, clearer, and easier to keep.',
        ),
      ),
    );
    expect(
      principleSentences,
      isNot(
        contains(
          'Balance keeps the record in proportion: contact, range, and limits can be read together.',
        ),
      ),
    );

    for (final composition in nonZero) {
      final sentences = _sentences(composition.output.text);
      for (var i = 0; i < sentences.length - 1; i++) {
        expect(
          _sharedCountPhrases(sentences[i], sentences[i + 1]),
          isEmpty,
          reason: composition.output.text,
        );
        expect(
          _sharedQuotedFlowTitles(sentences[i], sentences[i + 1]),
          isEmpty,
          reason: composition.output.text,
        );
        expect(
          _sharedPrinciples(sentences[i], sentences[i + 1]),
          isEmpty,
          reason: composition.output.text,
        );
      }
    }
  });

  test('same facts and history produce the same output', () {
    final facts = MaatFlowDecanFactCollector.snapshotFromCompletions(
      completions: <MaatFlowDecanCompletion>[
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 1),
          completionStatus: CompletionStatus.observed,
          flowKey: 'track-the-sky',
        ),
        MaatFlowDecanCompletion(
          completedOn: DateTime(2026, 6, 3),
          completionStatus: CompletionStatus.observed,
          flowKey: 'track-the-sky',
        ),
      ],
      decanStart: DateTime(2026, 6, 1),
      decanEnd: DateTime(2026, 6, 10),
      surface: kDecanReflectionSurface,
    );
    final composer = const DecanReflectionComposer();
    final first = composer.compose(
      facts: facts,
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );
    final second = composer.compose(
      facts: facts,
      usageHistory: const [],
      generatedAt: DateTime(2026, 6, 11),
    );

    expect(first?.output.text, second?.output.text);
    expect(first?.output.phraseIds, second?.output.phraseIds);
  });
}

const Set<String> _finiteMaatFlowKeys = <String>{
  'track-the-sky',
  'dawn-house-rite',
  'evening_threshold',
  'evening-threshold-rite',
  'the-weighing',
  'the-offering-table',
  'the-tending',
  'the-kept-word',
  'the-course',
  'the-moon-return',
  'the-wag',
  'the-decan-watch',
  'the-days-outside-the-year',
  'the-open-hand',
  'the-djed',
  'reading-house',
  'the-reading-house',
  'the-fair-hearing',
  'the-house-of-life',
  'the-boundary-stone',
  'hotep',
  'the-open-mouth',
  'the-living-record',
  'het-heru',
  'the-shore',
  'the-autobiography',
  'the-first-arrangement',
  'the-living-pattern',
  'the-true-name',
  'the-living-text',
  'the-clearing',
  'the-wandering',
  'the-khat',
  'the-oracle',
};

CompositionFactSnapshot _decanFacts(List<MaatFlowDecanCompletion> completions) {
  return MaatFlowDecanFactCollector.snapshotFromCompletions(
    completions: completions,
    decanStart: DateTime(2026, 6, 1),
    decanEnd: DateTime(2026, 6, 10),
    surface: kDecanReflectionSurface,
  );
}

List<DecanReflectionComposition?> _smokeScenarioCompositions() {
  final composer = const DecanReflectionComposer();
  final scenarios = <List<MaatFlowDecanCompletion>>[
    const <MaatFlowDecanCompletion>[],
    <MaatFlowDecanCompletion>[
      _completion(2, CompletionStatus.observed, 'the-weighing'),
    ],
    <MaatFlowDecanCompletion>[
      _completion(1, CompletionStatus.observed, 'track-the-sky'),
      _completion(2, CompletionStatus.observed, 'the-weighing'),
      _completion(4, CompletionStatus.observed, 'track-the-sky'),
      _completion(6, CompletionStatus.observed, 'the-weighing'),
      _completion(8, CompletionStatus.partial, 'track-the-sky'),
    ],
    <MaatFlowDecanCompletion>[
      _completion(1, CompletionStatus.partial, 'track-the-sky'),
      _completion(3, CompletionStatus.partial, 'the-weighing'),
      _completion(4, CompletionStatus.partial, 'track-the-sky'),
      _completion(7, CompletionStatus.observed, 'the-weighing'),
    ],
    <MaatFlowDecanCompletion>[
      _completion(1, CompletionStatus.skipped, 'track-the-sky'),
      _completion(2, CompletionStatus.skipped, 'track-the-sky'),
      _completion(5, CompletionStatus.partial, 'the-weighing'),
      _completion(8, CompletionStatus.skipped, 'the-weighing'),
    ],
    <MaatFlowDecanCompletion>[
      _completion(1, CompletionStatus.observed, 'track-the-sky'),
      _completion(3, CompletionStatus.observed, 'track-the-sky'),
      _completion(5, CompletionStatus.observed, 'track-the-sky'),
      _completion(8, CompletionStatus.partial, 'track-the-sky'),
    ],
    <MaatFlowDecanCompletion>[
      _completion(1, CompletionStatus.observed, 'track-the-sky'),
      _completion(3, CompletionStatus.observed, 'the-weighing'),
      _completion(5, CompletionStatus.observed, 'small-gates'),
      _completion(7, CompletionStatus.partial, 'the-plain-record'),
    ],
    <MaatFlowDecanCompletion>[
      _completion(1, CompletionStatus.observed, 'track-the-sky'),
      _completion(2, CompletionStatus.partial, 'the-weighing'),
      _completion(5, CompletionStatus.skipped, 'track-the-sky'),
      _completion(9, CompletionStatus.observed, 'the-weighing'),
    ],
    <MaatFlowDecanCompletion>[
      _completion(2, CompletionStatus.skipped, 'track-the-sky'),
      _completion(7, CompletionStatus.observed, 'the-weighing'),
      _completion(8, CompletionStatus.observed, 'the-weighing'),
      _completion(10, CompletionStatus.observed, 'the-weighing'),
    ],
    <MaatFlowDecanCompletion>[
      _completion(4, CompletionStatus.skipped, 'track-the-sky'),
    ],
  ];
  return scenarios
      .map(
        (completions) => composer.compose(
          facts: _decanFacts(completions),
          usageHistory: const [],
          generatedAt: DateTime(2026, 6, 11),
        ),
      )
      .toList(growable: false);
}

MaatFlowDecanCompletion _completion(
  int day,
  CompletionStatus status,
  String flowKey,
) {
  return MaatFlowDecanCompletion(
    completedOn: DateTime(2026, 6, day),
    completionStatus: status,
    flowKey: flowKey,
  );
}

String _firstSentence(String text) {
  final index = text.indexOf('.');
  return index == -1 ? text : text.substring(0, index + 1);
}

String _lastSentence(String text) {
  final sentences = text
      .split('.')
      .map((sentence) => sentence.trim())
      .where((sentence) => sentence.isNotEmpty)
      .toList(growable: false);
  return sentences.isEmpty ? text : sentences.last;
}

List<String> _sentences(String text) {
  return text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((sentence) => sentence.trim())
      .where((sentence) => sentence.isNotEmpty)
      .toList(growable: false);
}

bool _isPrincipleSentence(String sentence) {
  return sentence.startsWith('Truth ') ||
      sentence.startsWith('Order ') ||
      sentence.startsWith('Balance ');
}

bool _startsWithUsefulnessAuditFiller(String sentence) {
  return sentence.startsWith('The lesson is') ||
      sentence.startsWith('The useful lesson is') ||
      sentence.startsWith('The useful pattern is');
}

bool _hasCrossFlowPhrase(DecanReflectionComposition composition) {
  return composition.output.phraseIds.any(
    (phraseId) => phraseId.startsWith('cross_flow_'),
  );
}

bool _isCrossFlowClaimId(CompositionClaimId claimId) {
  return claimId.wireName.startsWith('cross_flow_');
}

Set<String> _sharedCountPhrases(String first, String second) {
  final firstCounts = _countPhrases(first);
  final secondCounts = _countPhrases(second);
  return firstCounts.intersection(secondCounts);
}

Set<String> _countPhrases(String sentence) {
  return RegExp(
    r'\b(one|two|three|four|five|six|seven|eight|nine|ten) '
    r'(observed completions?|partial marks?|skipped marks?|interactions?|active days?|flows?)\b',
    caseSensitive: false,
  ).allMatches(sentence).map((match) => match.group(0)!.toLowerCase()).toSet();
}

Set<String> _sharedQuotedFlowTitles(String first, String second) {
  final firstTitles = _quotedFlowTitles(first);
  final secondTitles = _quotedFlowTitles(second);
  return firstTitles.intersection(secondTitles);
}

Set<String> _quotedFlowTitles(String sentence) {
  return RegExp(
    r'“([^”]+)”',
  ).allMatches(sentence).map((match) => match.group(1)!).toSet();
}

Set<String> _sharedPrinciples(String first, String second) {
  final firstPrinciples = _principleNames(first);
  final secondPrinciples = _principleNames(second);
  return firstPrinciples.intersection(secondPrinciples);
}

Set<String> _principleNames(String sentence) {
  return RegExp(
    r'\b(Truth|Order|Balance)\b',
  ).allMatches(sentence).map((match) => match.group(1)!).toSet();
}

String _openingCarrier(String opening) {
  final lower = opening.toLowerCase();
  if (lower.startsWith('truth') ||
      lower.startsWith('order') ||
      lower.startsWith('balance')) {
    return 'principle';
  }
  if (lower.startsWith('one flow')) return 'flow';
  if (RegExp(
    r'^(one|two|three|four|five|six|seven|eight|nine|ten)\b',
  ).hasMatch(lower)) {
    return 'count';
  }
  if (lower.startsWith('the flow') ||
      (lower.contains('flows') && !lower.startsWith('a mixed'))) {
    return 'flow';
  }
  if (lower.contains('record')) return 'record';
  if (lower.contains('active day') || lower.startsWith('across ')) {
    return 'active_day_span';
  }
  if (lower.contains('contact')) return 'contact';
  return 'other';
}

const CompositionEngine _claimGateEngine = CompositionEngine(
  phraseBankVersion: 'claim_gate_test_bank',
  phrases: <CompositionPhrase>[
    CompositionPhrase(
      id: 'steady_opening',
      text: 'Steady opening.',
      position: CompositionPosition.observation,
      tone: CompositionTone.grounding,
      energy: CompositionEnergy.low,
      useCases: <String>{'claim_gate'},
      requiresClaims: <CompositionClaimId>{CompositionClaimId.steadyPresence},
      weight: 10,
    ),
    CompositionPhrase(
      id: 'low_opening',
      text: 'Low evidence opening.',
      position: CompositionPosition.observation,
      tone: CompositionTone.grounding,
      energy: CompositionEnergy.low,
      useCases: <String>{'claim_gate'},
      requiresClaims: <CompositionClaimId>{CompositionClaimId.lowEvidence},
      weight: 1,
    ),
  ],
  intents: <CompositionIntent>[
    CompositionIntent(
      id: 'claim_gate_intent',
      priority: 1,
      useCase: 'claim_gate',
      preferredTone: CompositionTone.grounding,
      energy: CompositionEnergy.low,
      reflectionShape: ReflectionShape.lowEvidenceReturn,
    ),
  ],
  shape: CompositionShape(
    id: 'claim_gate_shape',
    positions: <CompositionPosition>[CompositionPosition.observation],
  ),
);

final CompositionFactSnapshot _claimGateFacts = CompositionFactSnapshot(
  surface: 'claim_gate',
  windowStart: DateTime(2026, 6, 1),
  windowEnd: DateTime(2026, 6, 10),
  facts: const <String, Object?>{'total_interactions': 3},
  signals: const <String>{},
  factFingerprint: 'claim-gate-facts',
);

const CompositionEngine _shapeIntentEngine = CompositionEngine(
  phraseBankVersion: 'shape_intent_test_bank',
  phrases: <CompositionPhrase>[
    CompositionPhrase(
      id: 'steady_shape_phrase',
      text: 'Steady shape.',
      position: CompositionPosition.observation,
      tone: CompositionTone.grounding,
      energy: CompositionEnergy.low,
      useCases: <String>{'steady_shape'},
      requiresClaims: <CompositionClaimId>{CompositionClaimId.steadyPresence},
    ),
    CompositionPhrase(
      id: 'raw_signal_phrase',
      text: 'Raw signal.',
      position: CompositionPosition.observation,
      tone: CompositionTone.grounding,
      energy: CompositionEnergy.low,
      useCases: <String>{'raw_signal'},
      requiresClaims: <CompositionClaimId>{
        CompositionClaimId.skippedGateTooHeavy,
      },
    ),
  ],
  intents: <CompositionIntent>[
    CompositionIntent(
      id: 'raw_signal_many_skips',
      priority: 100,
      useCase: 'raw_signal',
      preferredTone: CompositionTone.grounding,
      energy: CompositionEnergy.low,
      reflectionShape: ReflectionShape.supportiveRecalibration,
      requiredSignals: <String>{'many_skips'},
    ),
    CompositionIntent(
      id: 'shape_steady',
      priority: 1,
      useCase: 'steady_shape',
      preferredTone: CompositionTone.grounding,
      energy: CompositionEnergy.low,
      reflectionShape: ReflectionShape.steadyContinuation,
      requiredSignals: <String>{'mostly_observed'},
    ),
  ],
  shape: CompositionShape(
    id: 'shape_intent_shape',
    positions: <CompositionPosition>[CompositionPosition.observation],
  ),
);

CompositionFactSnapshot _shapeIntentFacts(Set<String> signals) {
  return CompositionFactSnapshot(
    surface: 'shape_intent',
    windowStart: DateTime(2026, 6, 1),
    windowEnd: DateTime(2026, 6, 10),
    facts: const <String, Object?>{'total_interactions': 3},
    signals: signals,
    factFingerprint: 'shape-intent-facts',
  );
}

CompositionClaimPlan _claimPlan(
  Set<CompositionClaimId> claimIds, {
  ReflectionShape reflectionShape = ReflectionShape.lowEvidenceReturn,
}) {
  final claims = claimIds
      .map(
        (claimId) => CompositionClaim(
          id: claimId,
          strength: CompositionClaimStrength.low,
          evidenceCount: 1,
          evidenceSummary: claimId.wireName,
          sourceSignalIds: const <String>[],
          privacyClass: CompositionClaimPrivacyClass.behavioralAggregate,
          polarity: CompositionClaimPolarity.neutral,
          tags: const <String>{},
        ),
      )
      .toList(growable: false);
  return CompositionClaimPlan(
    claims: claims,
    reflectionShape: reflectionShape,
    primaryClaimId: claimIds.isEmpty ? null : claimIds.first,
    supportingClaimIds: claimIds.skip(1).toList(growable: false),
    claimFingerprint: stableCompositionFingerprint(<String, Object?>{
      'claims': claimIds.map((claimId) => claimId.wireName).toList()..sort(),
    }),
  );
}
