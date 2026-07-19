import 'package:mobile/core/composition/composition_engine.dart';
import 'package:mobile/core/composition/composition_models.dart';
import 'package:mobile/data/decan_reflection_model.dart';

import 'decan_composition_claim_deriver.dart';
import 'decan_reflection_phrase_bank.dart';

const String kDecanReflectionSurface = 'decan_reflection';
const String kDecanReflectionCompositionalRenderer = 'compositional_v1';
const String kDecanReflectionRecommendationPolicyVersion =
    'decan_recommendation_policy_v1';

class DecanReflectionComposition {
  const DecanReflectionComposition({
    required this.output,
    required this.renderMetadata,
  });

  final CompositionOutput output;
  final DecanReflectionRenderMetadata renderMetadata;
}

class DecanReflectionComposer {
  const DecanReflectionComposer({
    this.engine = const CompositionEngine(
      phraseBankVersion: kDecanReflectionPhraseBankVersion,
      phrases: kDecanReflectionPhrases,
      intents: kDecanReflectionIntents,
      shape: kDecanReflectionShape,
    ),
    this.claimDeriver = const DecanCompositionClaimDeriver(),
  });

  final CompositionEngine engine;
  final CompositionClaimDeriver claimDeriver;

  DecanReflectionComposition? compose({
    required CompositionFactSnapshot facts,
    required List<CompositionUsageRecord> usageHistory,
    required DateTime generatedAt,
  }) {
    final claimPlan = claimDeriver.derive(facts);
    final preparedFacts = _withRecommendation(facts, claimPlan);
    final output = engine.compose(
      facts: preparedFacts,
      usageHistory: usageHistory,
      generatedAt: generatedAt,
      claimPlan: claimPlan,
    );
    if (output == null) return null;
    return DecanReflectionComposition(
      output: output,
      renderMetadata: renderMetadataForOutput(output, claimPlan: claimPlan),
    );
  }

  static DecanReflectionRenderMetadata renderMetadataForOutput(
    CompositionOutput output, {
    CompositionClaimPlan? claimPlan,
  }) {
    final dominantFlowKey = output.factSummary['dominant_flow_key']
        ?.toString()
        .trim();
    final claimIds = claimPlan?.claimIds
        .map((claimId) => claimId.wireName)
        .toList(growable: false);
    final crossFlowClaimIds =
        claimIds
            ?.where((claimId) => claimId.startsWith('cross_flow_'))
            .toList(growable: false) ??
        const <String>[];
    final reflectionShape = claimPlan?.reflectionShape.wireName;
    final claimFingerprint = claimPlan?.claimFingerprint;
    final crossFlowInference = claimPlan?.crossFlowInference;
    final raw = <String, dynamic>{
      'renderer': kDecanReflectionCompositionalRenderer,
      'used_llm': false,
      'llm_cost': 0,
      'engine_version': output.engineVersion,
      'phrase_bank_version': output.phraseBankVersion,
      'claim_deriver_version': kDecanCompositionClaimDeriverVersion,
      'claimDeriverVersion': kDecanCompositionClaimDeriverVersion,
      'recommendation_policy_version':
          kDecanReflectionRecommendationPolicyVersion,
      'recommendationPolicyVersion':
          kDecanReflectionRecommendationPolicyVersion,
      'surface': output.surface,
      'intent_id': output.intentId,
      'shape_id': output.shapeId,
      'phrase_ids': output.phraseIds,
      'signals': output.signals.toList()..sort(),
      'fallback_levels_used': output.fallbackLevelsUsed,
      'fact_fingerprint': output.factFingerprint,
      if (claimFingerprint != null) 'claim_fingerprint': claimFingerprint,
      if (claimFingerprint != null) 'claimFingerprint': claimFingerprint,
      if (claimIds != null) 'claim_ids': claimIds,
      if (claimIds != null) 'claimIds': claimIds,
      if (reflectionShape != null) 'reflection_shape': reflectionShape,
      if (reflectionShape != null) 'reflectionShape': reflectionShape,
      if (crossFlowInference != null)
        'cross_flow_inference': crossFlowInference,
      if (crossFlowInference != null)
        'cross_flow_analyzer_version': crossFlowInference['analyzer_version'],
      if (crossFlowInference != null)
        'flow_profile_catalog_version': crossFlowInference['catalog_version'],
      if (crossFlowClaimIds.isNotEmpty)
        'cross_flow_claim_ids': crossFlowClaimIds,
      'fact_summary': output.factSummary,
      ...output.recommendation.toJson(),
      'recommendation': output.recommendation.toJson(),
      'trace': output.trace,
      'generated_at': output.generatedAt.toUtc().toIso8601String(),
      if (dominantFlowKey != null && dominantFlowKey.isNotEmpty)
        'spectrum_flow_key': dominantFlowKey,
    };
    return DecanReflectionRenderMetadata(
      renderer: kDecanReflectionCompositionalRenderer,
      usedLlm: false,
      llmCost: 0,
      spectrumFlowKey: dominantFlowKey == null || dominantFlowKey.isEmpty
          ? null
          : dominantFlowKey,
      responseKind: output.intentId,
      selectedTier: null,
      selectedSeed: output.phraseIds.join('|'),
      raw: raw,
    );
  }

  static CompositionFactSnapshot _withRecommendation(
    CompositionFactSnapshot facts,
    CompositionClaimPlan claimPlan,
  ) {
    if (claimPlan.contains(CompositionClaimId.zeroEvidence)) {
      return facts.copyWith(
        recommendation: const CompositionRecommendation.none(),
      );
    }

    final recommendation = _recommendationForClaimPlan(facts, claimPlan);
    final dominantPrinciple = _dominantPrincipleForFlowKey(
      facts.dominantFlowKey,
    );
    final recommendationJson = recommendation.toJson();
    final factTemplateValues = _factTemplateValues(
      facts,
      dominantPrinciple: dominantPrinciple,
    );
    final crossFlowTemplateValues = _crossFlowTemplateValues(
      facts.crossFlowInference,
    );
    final recommendationSignals = <String>{
      ...facts.signals,
      if (recommendation.type == CompositionRecommendationType.flow)
        'recommend_flow',
      if (recommendation.type == CompositionRecommendationType.library)
        'recommend_library',
      if (dominantPrinciple != null) 'dominant_principle_$dominantPrinciple',
    };
    final augmentedFacts = <String, Object?>{
      ...facts.facts,
      ...recommendationJson,
    };
    final augmentedSummary = <String, Object?>{
      ...facts.factSummary,
      ...recommendationJson,
    };
    final templateValues = <String, Object?>{
      ...facts.templateValues,
      ...factTemplateValues,
      ...crossFlowTemplateValues,
      ...recommendationJson,
      if (dominantPrinciple != null) 'dominant_principle': dominantPrinciple,
    };
    return facts.copyWith(
      facts: augmentedFacts,
      signals: recommendationSignals,
      factSummary: augmentedSummary,
      templateValues: templateValues,
      recommendation: recommendation,
    );
  }

  static CompositionRecommendation _recommendationForClaimPlan(
    CompositionFactSnapshot facts,
    CompositionClaimPlan claimPlan,
  ) {
    if (claimPlan.contains(CompositionClaimId.zeroEvidence)) {
      return const CompositionRecommendation.none();
    }

    if (claimPlan.contains(CompositionClaimId.lowEvidence) ||
        claimPlan.contains(CompositionClaimId.firstContact)) {
      return const CompositionRecommendation(
        type: CompositionRecommendationType.library,
        id: 'library:the-plain-record',
        key: 'the-plain-record',
        title: 'The Plain Record',
        reason: 'one recorded contact can be steadied before more flow work',
      );
    }

    if (claimPlan.contains(CompositionClaimId.breadthNeedsCenter)) {
      return const CompositionRecommendation(
        type: CompositionRecommendationType.flow,
        id: 'flow:the-weighing',
        key: 'the-weighing',
        title: 'The Weighing',
        reason: 'several active flows call for a clear center',
      );
    }

    if (claimPlan.contains(CompositionClaimId.singleFlowDepth)) {
      final flowKey = facts.dominantFlowKey ?? 'maat-flow';
      final flowTitle = _flowTitleForKey(flowKey);
      return CompositionRecommendation(
        type: CompositionRecommendationType.flow,
        id: 'flow:$flowKey',
        key: flowKey,
        title: flowTitle,
        reason: 'repeated return can deepen through one deliberate thread',
      );
    }

    if (claimPlan.contains(CompositionClaimId.flowReady) &&
        claimPlan.contains(CompositionClaimId.steadyPresence)) {
      return const CompositionRecommendation(
        type: CompositionRecommendationType.flow,
        id: 'flow:track-the-sky',
        key: 'track-the-sky',
        title: 'Track the Sky',
        reason: 'the observed rhythm can carry one clear continuation',
      );
    }

    if (claimPlan.contains(CompositionClaimId.supportBeforeExpansion) ||
        claimPlan.contains(CompositionClaimId.librarySupportRecommended)) {
      if (claimPlan.contains(CompositionClaimId.skippedGateTooHeavy)) {
        return const CompositionRecommendation(
          type: CompositionRecommendationType.library,
          id: 'library:small-gates',
          key: 'small-gates',
          title: 'Small Gates',
          reason: 'a smaller gate can restore support before added flow work',
        );
      }
      if (claimPlan.contains(CompositionClaimId.partialContactMaintained)) {
        return const CompositionRecommendation(
          type: CompositionRecommendationType.library,
          id: 'library:keeping-the-measure',
          key: 'keeping-the-measure',
          title: 'Keeping the Measure',
          reason: 'the measure can become easier to finish',
        );
      }
      final recordedContact = _claimById(
        claimPlan,
        CompositionClaimId.recordedContact,
      );
      if (claimPlan.contains(CompositionClaimId.lowEvidence) ||
          claimPlan.contains(CompositionClaimId.firstContact) ||
          recordedContact?.evidenceCount == 1) {
        return const CompositionRecommendation(
          type: CompositionRecommendationType.library,
          id: 'library:the-plain-record',
          key: 'the-plain-record',
          title: 'The Plain Record',
          reason: 'one recorded contact can be steadied before more flow work',
        );
      }
      return const CompositionRecommendation(
        type: CompositionRecommendationType.library,
        id: 'library:returning-without-force',
        key: 'returning-without-force',
        title: 'Returning Without Force',
        reason: 'the mixed record can settle before widening',
      );
    }

    return const CompositionRecommendation.none();
  }

  static CompositionClaim? _claimById(
    CompositionClaimPlan claimPlan,
    CompositionClaimId claimId,
  ) {
    for (final claim in claimPlan.claims) {
      if (claim.id == claimId) return claim;
    }
    return null;
  }

  static Map<String, Object?> _factTemplateValues(
    CompositionFactSnapshot facts, {
    required String? dominantPrinciple,
  }) {
    final total = _intFact(facts, 'total_interactions');
    final observed = _intFact(facts, 'observed_count');
    final partial = _intFact(facts, 'partial_count');
    final skipped = _intFact(facts, 'skipped_count');
    final activeDays = _intFact(facts, 'active_days_count');
    final distinctFlows = _intFact(facts, 'distinct_flow_count');
    final dominantFlowKey = facts.dominantFlowKey;
    final dominantFlowTitle = dominantFlowKey == null
        ? null
        : _flowTitleForKey(dominantFlowKey);

    return <String, Object?>{
      'interaction_count_label': _countLabel(total, 'interaction'),
      'interaction_count_title_label': _countLabel(
        total,
        'interaction',
        titleCase: true,
      ),
      'observed_count_label': _countLabel(observed, 'observed completion'),
      'observed_count_title_label': _countLabel(
        observed,
        'observed completion',
        titleCase: true,
      ),
      'partial_count_label': _countLabel(partial, 'partial mark'),
      'partial_count_title_label': _countLabel(
        partial,
        'partial mark',
        titleCase: true,
      ),
      'skipped_count_label': _countLabel(skipped, 'skipped mark'),
      'skipped_count_title_label': _countLabel(
        skipped,
        'skipped mark',
        titleCase: true,
      ),
      'active_days_label': _countLabel(activeDays, 'active day'),
      'active_days_title_label': _countLabel(
        activeDays,
        'active day',
        titleCase: true,
      ),
      'distinct_flow_count_label': _countLabel(distinctFlows, 'flow'),
      'distinct_flow_count_title_label': _countLabel(
        distinctFlows,
        'flow',
        titleCase: true,
      ),
      if (dominantFlowTitle != null) 'dominant_flow_title': dominantFlowTitle,
      if (dominantPrinciple != null)
        'dominant_principle_title': _titleWord(dominantPrinciple),
    };
  }

  static Map<String, Object?> _crossFlowTemplateValues(
    Map<String, Object?>? inference,
  ) {
    if (inference == null) return const <String, Object?>{};
    final axis = inference['axis']?.toString().trim();
    final value = inference['value']?.toString().trim();
    if (value == null || value.isEmpty) return const <String, Object?>{};
    return <String, Object?>{
      if (axis != null && axis.isNotEmpty)
        'cross_flow_axis_label': _crossFlowAxisLabel(axis),
      'cross_flow_intention_label': _crossFlowValueLabel(value, axis: axis),
      'cross_flow_intention_description': _crossFlowValueDescription(value),
    };
  }

  static String _crossFlowAxisLabel(String axis) {
    return switch (axis) {
      'primary_intention' => 'intention',
      'time_bias' => 'time pattern',
      'mode' => 'practice mode',
      'orientation' => 'orientation',
      'practice_type' => 'practice type',
      'effort_shape' => 'effort shape',
      _ => axis.replaceAll('_', ' '),
    };
  }

  static String _crossFlowValueLabel(String value, {String? axis}) {
    if (axis == 'mode' && value == 'solitary') {
      return 'quiet work you could do alone';
    }
    if (axis == 'mode' && value == 'relational') {
      return 'work that answered to relationship';
    }
    if (axis == 'mode' && value == 'household') {
      return 'care carried through place and daily order';
    }
    if (axis == 'mode' && value == 'public') {
      return 'help that had to become visible';
    }
    if (axis == 'mode' && value == 'textual') {
      return 'work with text or record';
    }
    if (axis == 'time_bias' && value == 'morning') return 'morning work';
    if (axis == 'time_bias' && value == 'evening') return 'evening review';
    if (axis == 'time_bias' && value == 'night') return 'night practice';
    if (axis == 'time_bias' && value == 'lunar') return 'lunar timing';
    if (axis == 'time_bias' && value == 'seasonal') return 'seasonal timing';
    return switch (value) {
      'record_keeping' => 'record-keeping',
      'body_care' => 'body care',
      'dream_work' => 'dream-question work',
      'small_gate' => 'a smaller gate',
      'sustained_attention' => 'sustained attention',
      'deep_work' => 'deep work',
      'embodied_action' => 'embodied action',
      'social_accountability' => 'accountable action',
      'physical_reset' => 'physical reset',
      'repeated_maintenance' => 'repeated maintenance',
      'steady_attention' => 'steady attention',
      'honest_review' => 'honest review',
      'measured_study' => 'measured study',
      'accurate_naming' => 'accurate naming',
      'no_shared_center' => 'several directions',
      _ => value.replaceAll('_', ' '),
    };
  }

  static String _crossFlowValueDescription(String value) {
    return switch (value) {
      'record_keeping' => 'making the work visible enough to revisit',
      'reflection' => 'turning contact into an honest account',
      'observation' => 'noticing what is present before deciding',
      'service' => 'moving care into something usable',
      'repair' => 'bringing a strained part back into right measure',
      'study' => 'staying with text or teaching long enough to keep a mark',
      'planning' => 'giving time and action a clearer order',
      'restraint' => 'making space before response becomes action',
      'sustained_attention' => 'returning attention to the same kind of work',
      'deep_work' => 'staying with a demanding practice long enough to use it',
      'social_accountability' =>
        'letting practice answer to shared obligations',
      'recovery' => 'restoring enough capacity for the next right act',
      'threshold' => 'using an edge or transition as a place to choose',
      'solitary' => 'practice that did not need an audience to be real',
      'relational' => 'practice that had to account for another person',
      'household' => 'letting place and daily order carry the work',
      'textual' => 'using text or record as the entry point',
      'cosmic' => 'taking time, sky, or season as evidence',
      'no_shared_center' => 'several directions were active without one center',
      _ => 'making the shared pattern plain enough to work with',
    };
  }

  static int _intFact(CompositionFactSnapshot facts, String key) {
    final value = facts.factSummary[key] ?? facts.facts[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String _countLabel(
    int count,
    String singular, {
    bool titleCase = false,
  }) {
    final plural = _pluralize(singular);
    final number = _numberWord(count, titleCase: titleCase);
    return '$number ${count == 1 ? singular : plural}';
  }

  static String _pluralize(String singular) {
    if (singular.endsWith('y') && singular.length > 1) {
      final preceding = singular[singular.length - 2].toLowerCase();
      if (!'aeiou'.contains(preceding)) {
        return '${singular.substring(0, singular.length - 1)}ies';
      }
    }
    return '${singular}s';
  }

  static String _numberWord(int count, {required bool titleCase}) {
    final word = switch (count) {
      0 => 'zero',
      1 => 'one',
      2 => 'two',
      3 => 'three',
      4 => 'four',
      5 => 'five',
      6 => 'six',
      7 => 'seven',
      8 => 'eight',
      9 => 'nine',
      10 => 'ten',
      _ => count.toString(),
    };
    return titleCase ? _titleWord(word) : word;
  }

  static String _titleWord(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  static String _flowTitleForKey(String flowKey) {
    switch (flowKey) {
      case 'track-the-sky':
        return 'Track the Sky';
      case 'the-weighing':
        return 'The Weighing';
      case 'reading-house':
        return 'Reading House';
      case 'moon-return':
        return 'Moon Return';
      default:
        return flowKey
            .split(RegExp(r'[-_\s]+'))
            .where((part) => part.trim().isNotEmpty)
            .map(
              (part) => part.length == 1
                  ? part.toUpperCase()
                  : '${part[0].toUpperCase()}${part.substring(1)}',
            )
            .join(' ');
    }
  }

  static String? _dominantPrincipleForFlowKey(String? flowKey) {
    switch (flowKey?.trim()) {
      case 'truth':
      case 'the-plain-record':
      case 'reading-house':
        return 'truth';
      case 'order':
      case 'track-the-sky':
      case 'small-gates':
        return 'order';
      case 'balance':
      case 'the-weighing':
      case 'keeping-the-measure':
      case 'returning-without-force':
        return 'balance';
      default:
        return null;
    }
  }
}

List<String> decanCompositionPhraseIdsFromMetadata(
  DecanReflectionRenderMetadata? metadata,
) {
  if (metadata?.renderer != kDecanReflectionCompositionalRenderer) {
    return const <String>[];
  }
  final phraseIds = metadata?.raw['phrase_ids'];
  if (phraseIds is! List) return const <String>[];
  return phraseIds
      .map((raw) => raw?.toString().trim())
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
}

int decanCompositionInteractionCountFromMetadata(
  DecanReflectionRenderMetadata? metadata,
) {
  if (metadata?.renderer != kDecanReflectionCompositionalRenderer) return 0;
  final factSummary = metadata?.raw['fact_summary'];
  if (factSummary is! Map) return 0;
  final value = factSummary['total_interactions'];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}
