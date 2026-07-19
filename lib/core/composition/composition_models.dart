enum CompositionPosition {
  observation,
  meaning,
  guidance,
  interpretation,
  consequence,
  nextStep,
  recommendation,
}

enum CompositionTone { grounding, affirming, challenging, still }

enum CompositionEnergy { low, neutral, high }

enum CompositionClaimStrength { low, medium, high }

enum CompositionPrivacyClass { publicPattern, privateSafe, sensitiveBlocked }

enum CompositionClaimId {
  lowEvidence,
  firstContact,
  recordedContact,
  steadyPresence,
  partialContactMaintained,
  skippedGateTooHeavy,
  supportBeforeExpansion,
  singleFlowDepth,
  breadthAsRange,
  breadthNeedsCenter,
  flowReady,
  librarySupportRecommended,
  zeroEvidence,
  crossFlowSharedIntention,
  crossFlowIntentionHolding,
  crossFlowIntentionFriction,
  crossFlowIntentionPartial,
  crossFlowIntentionUncentered,
}

enum CompositionClaimPolarity { supportive, cautionary, neutral }

enum CompositionClaimPrivacyClass { behavioralAggregate, recommendation }

enum ReflectionShape {
  silentOrInvitation,
  supportiveRecalibration,
  steadyContinuation,
  singleThreadContinuation,
  breadthCentering,
  lowEvidenceReturn,
}

extension CompositionPositionX on CompositionPosition {
  String get wireName => switch (this) {
    CompositionPosition.observation => 'observation',
    CompositionPosition.meaning => 'meaning',
    CompositionPosition.guidance => 'guidance',
    CompositionPosition.interpretation => 'interpretation',
    CompositionPosition.consequence => 'consequence',
    CompositionPosition.nextStep => 'next_step',
    CompositionPosition.recommendation => 'recommendation',
  };
}

extension CompositionToneX on CompositionTone {
  String get wireName => switch (this) {
    CompositionTone.grounding => 'grounding',
    CompositionTone.affirming => 'affirming',
    CompositionTone.challenging => 'challenging',
    CompositionTone.still => 'still',
  };
}

extension CompositionEnergyX on CompositionEnergy {
  String get wireName => switch (this) {
    CompositionEnergy.low => 'low',
    CompositionEnergy.neutral => 'neutral',
    CompositionEnergy.high => 'high',
  };
}

extension CompositionClaimStrengthX on CompositionClaimStrength {
  String get wireName => switch (this) {
    CompositionClaimStrength.low => 'low',
    CompositionClaimStrength.medium => 'medium',
    CompositionClaimStrength.high => 'high',
  };
}

extension CompositionClaimIdX on CompositionClaimId {
  String get wireName => switch (this) {
    CompositionClaimId.lowEvidence => 'low_evidence',
    CompositionClaimId.firstContact => 'first_contact',
    CompositionClaimId.recordedContact => 'recorded_contact',
    CompositionClaimId.steadyPresence => 'steady_presence',
    CompositionClaimId.partialContactMaintained => 'partial_contact_maintained',
    CompositionClaimId.skippedGateTooHeavy => 'skipped_gate_too_heavy',
    CompositionClaimId.supportBeforeExpansion => 'support_before_expansion',
    CompositionClaimId.singleFlowDepth => 'single_flow_depth',
    CompositionClaimId.breadthAsRange => 'breadth_as_range',
    CompositionClaimId.breadthNeedsCenter => 'breadth_needs_center',
    CompositionClaimId.flowReady => 'flow_ready',
    CompositionClaimId.librarySupportRecommended =>
      'library_support_recommended',
    CompositionClaimId.zeroEvidence => 'zero_evidence',
    CompositionClaimId.crossFlowSharedIntention =>
      'cross_flow_shared_intention',
    CompositionClaimId.crossFlowIntentionHolding =>
      'cross_flow_intention_holding',
    CompositionClaimId.crossFlowIntentionFriction =>
      'cross_flow_intention_friction',
    CompositionClaimId.crossFlowIntentionPartial =>
      'cross_flow_intention_partial',
    CompositionClaimId.crossFlowIntentionUncentered =>
      'cross_flow_intention_uncentered',
  };
}

extension CompositionClaimPolarityX on CompositionClaimPolarity {
  String get wireName => switch (this) {
    CompositionClaimPolarity.supportive => 'supportive',
    CompositionClaimPolarity.cautionary => 'cautionary',
    CompositionClaimPolarity.neutral => 'neutral',
  };
}

extension CompositionClaimPrivacyClassX on CompositionClaimPrivacyClass {
  String get wireName => switch (this) {
    CompositionClaimPrivacyClass.behavioralAggregate => 'behavioral_aggregate',
    CompositionClaimPrivacyClass.recommendation => 'recommendation',
  };
}

extension ReflectionShapeX on ReflectionShape {
  String get wireName => switch (this) {
    ReflectionShape.silentOrInvitation => 'silent_or_invitation',
    ReflectionShape.supportiveRecalibration => 'supportive_recalibration',
    ReflectionShape.steadyContinuation => 'steady_continuation',
    ReflectionShape.singleThreadContinuation => 'single_thread_continuation',
    ReflectionShape.breadthCentering => 'breadth_centering',
    ReflectionShape.lowEvidenceReturn => 'low_evidence_return',
  };
}

extension CompositionPrivacyClassX on CompositionPrivacyClass {
  String get wireName => switch (this) {
    CompositionPrivacyClass.publicPattern => 'public_pattern',
    CompositionPrivacyClass.privateSafe => 'private_safe',
    CompositionPrivacyClass.sensitiveBlocked => 'sensitive_blocked',
  };
}

class CompositionPhrase {
  const CompositionPhrase({
    required this.id,
    required this.text,
    required this.position,
    required this.tone,
    required this.energy,
    required this.useCases,
    this.tags = const <String>{},
    this.weight = 1,
    this.minimumEvidence = 1,
    this.claimStrength = CompositionClaimStrength.medium,
    this.requiresSignals = const <String>{},
    this.avoidSignals = const <String>{},
    this.requiresClaims = const <CompositionClaimId>{},
    this.avoidClaims = const <CompositionClaimId>{},
    this.privacyClass = CompositionPrivacyClass.privateSafe,
    this.cooldownGroup,
    this.optionalFlowKey,
  });

  final String id;
  final String text;
  final CompositionPosition position;
  final CompositionTone tone;
  final CompositionEnergy energy;
  final Set<String> useCases;
  final Set<String> tags;
  final int weight;
  final int minimumEvidence;
  final CompositionClaimStrength claimStrength;
  final Set<String> requiresSignals;
  final Set<String> avoidSignals;
  final Set<CompositionClaimId> requiresClaims;
  final Set<CompositionClaimId> avoidClaims;
  final CompositionPrivacyClass privacyClass;
  final String? cooldownGroup;
  final String? optionalFlowKey;
}

class CompositionIntent {
  const CompositionIntent({
    required this.id,
    required this.priority,
    required this.useCase,
    required this.preferredTone,
    required this.energy,
    this.reflectionShape,
    this.requiredClaims = const <CompositionClaimId>{},
    this.avoidClaims = const <CompositionClaimId>{},
    this.requiredSignals = const <String>{},
    this.avoidSignals = const <String>{},
  });

  final String id;
  final int priority;
  final String useCase;
  final CompositionTone preferredTone;
  final CompositionEnergy energy;
  final ReflectionShape? reflectionShape;
  final Set<CompositionClaimId> requiredClaims;
  final Set<CompositionClaimId> avoidClaims;
  final Set<String> requiredSignals;
  final Set<String> avoidSignals;
}

class CompositionShape {
  const CompositionShape({
    required this.id,
    required this.positions,
    this.maxLength = 260,
  });

  final String id;
  final List<CompositionPosition> positions;
  final int maxLength;
}

class CompositionFactSnapshot {
  const CompositionFactSnapshot({
    required this.surface,
    required this.windowStart,
    required this.windowEnd,
    required this.facts,
    required this.signals,
    required this.factFingerprint,
    this.factSummary = const <String, Object?>{},
    this.templateValues = const <String, Object?>{},
    this.recommendation = const CompositionRecommendation.none(),
    this.crossFlowInference,
  });

  final String surface;
  final DateTime windowStart;
  final DateTime windowEnd;
  final Map<String, Object?> facts;
  final Set<String> signals;
  final String factFingerprint;
  final Map<String, Object?> factSummary;
  final Map<String, Object?> templateValues;
  final CompositionRecommendation recommendation;
  final Map<String, Object?>? crossFlowInference;

  int get evidenceCount {
    final value = facts['total_interactions'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String? get dominantFlowKey {
    final value = facts['dominant_flow_key']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  CompositionFactSnapshot copyWith({
    Map<String, Object?>? facts,
    Set<String>? signals,
    String? factFingerprint,
    Map<String, Object?>? factSummary,
    Map<String, Object?>? templateValues,
    CompositionRecommendation? recommendation,
    Map<String, Object?>? crossFlowInference,
  }) {
    return CompositionFactSnapshot(
      surface: surface,
      windowStart: windowStart,
      windowEnd: windowEnd,
      facts: facts ?? this.facts,
      signals: signals ?? this.signals,
      factFingerprint: factFingerprint ?? this.factFingerprint,
      factSummary: factSummary ?? this.factSummary,
      templateValues: templateValues ?? this.templateValues,
      recommendation: recommendation ?? this.recommendation,
      crossFlowInference: crossFlowInference ?? this.crossFlowInference,
    );
  }
}

class CompositionClaim {
  const CompositionClaim({
    required this.id,
    required this.strength,
    required this.evidenceCount,
    required this.evidenceSummary,
    required this.sourceSignalIds,
    required this.privacyClass,
    required this.polarity,
    required this.tags,
  });

  final CompositionClaimId id;
  final CompositionClaimStrength strength;
  final int evidenceCount;
  final String evidenceSummary;
  final List<String> sourceSignalIds;
  final CompositionClaimPrivacyClass privacyClass;
  final CompositionClaimPolarity polarity;
  final Set<String> tags;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id.wireName,
    'strength': strength.wireName,
    'evidence_count': evidenceCount,
    'evidence_summary': evidenceSummary,
    'source_signal_ids': sourceSignalIds,
    'privacy_class': privacyClass.wireName,
    'polarity': polarity.wireName,
    'tags': tags.toList()..sort(),
  };
}

class CompositionClaimPlan {
  const CompositionClaimPlan({
    required this.claims,
    required this.reflectionShape,
    required this.primaryClaimId,
    required this.supportingClaimIds,
    required this.claimFingerprint,
    this.crossFlowInference,
  });

  final List<CompositionClaim> claims;
  final ReflectionShape reflectionShape;
  final CompositionClaimId? primaryClaimId;
  final List<CompositionClaimId> supportingClaimIds;
  final String claimFingerprint;
  final Map<String, Object?>? crossFlowInference;

  List<CompositionClaimId> get claimIds =>
      claims.map((claim) => claim.id).toList(growable: false);

  bool contains(CompositionClaimId id) => claims.any((claim) => claim.id == id);

  Map<String, Object?> toJson() => <String, Object?>{
    'claims': claims.map((claim) => claim.toJson()).toList(growable: false),
    'reflection_shape': reflectionShape.wireName,
    if (primaryClaimId != null) 'primary_claim_id': primaryClaimId!.wireName,
    'supporting_claim_ids': supportingClaimIds
        .map((claimId) => claimId.wireName)
        .toList(growable: false),
    'claim_fingerprint': claimFingerprint,
    if (crossFlowInference != null) 'cross_flow_inference': crossFlowInference,
  };
}

abstract class CompositionClaimDeriver {
  CompositionClaimPlan derive(CompositionFactSnapshot facts);
}

enum CompositionRecommendationType { flow, library, none }

extension CompositionRecommendationTypeX on CompositionRecommendationType {
  String get wireName => switch (this) {
    CompositionRecommendationType.flow => 'flow',
    CompositionRecommendationType.library => 'library',
    CompositionRecommendationType.none => 'none',
  };
}

class CompositionRecommendation {
  const CompositionRecommendation({
    required this.type,
    this.id,
    this.key,
    this.title,
    this.reason,
  });

  const CompositionRecommendation.none()
    : type = CompositionRecommendationType.none,
      id = null,
      key = null,
      title = null,
      reason = null;

  final CompositionRecommendationType type;
  final String? id;
  final String? key;
  final String? title;
  final String? reason;

  bool get hasTarget =>
      type != CompositionRecommendationType.none &&
      ((id != null && id!.isNotEmpty) || (key != null && key!.isNotEmpty));

  Map<String, Object?> toJson() => <String, Object?>{
    'recommendation_type': type.wireName,
    if (id != null) 'recommendation_id': id,
    if (key != null) 'recommendation_key': key,
    if (title != null) 'recommendation_title': title,
    if (reason != null) 'recommendation_reason': reason,
  };
}

class CompositionUsageRecord {
  const CompositionUsageRecord({
    required this.phraseId,
    required this.date,
    required this.surface,
    this.cooldownGroup,
  });

  final String phraseId;
  final DateTime date;
  final String surface;
  final String? cooldownGroup;

  Map<String, Object?> toJson() => <String, Object?>{
    'phrase_id': phraseId,
    'date': _formatDate(date),
    'surface': surface,
    if (cooldownGroup != null) 'cooldown_group': cooldownGroup,
  };

  static CompositionUsageRecord? fromJson(Map<String, dynamic> json) {
    final phraseId = json['phrase_id']?.toString().trim();
    final surface = json['surface']?.toString().trim();
    final date = DateTime.tryParse(json['date']?.toString() ?? '');
    if (phraseId == null ||
        phraseId.isEmpty ||
        surface == null ||
        surface.isEmpty ||
        date == null) {
      return null;
    }
    final cooldownGroup = json['cooldown_group']?.toString().trim();
    return CompositionUsageRecord(
      phraseId: phraseId,
      date: date,
      surface: surface,
      cooldownGroup: cooldownGroup == null || cooldownGroup.isEmpty
          ? null
          : cooldownGroup,
    );
  }
}

class CompositionOutput {
  const CompositionOutput({
    required this.text,
    required this.engineVersion,
    required this.phraseBankVersion,
    required this.surface,
    required this.intentId,
    required this.shapeId,
    required this.phraseIds,
    required this.signals,
    required this.fallbackLevelsUsed,
    required this.factFingerprint,
    required this.factSummary,
    required this.recommendation,
    required this.trace,
    required this.generatedAt,
  });

  final String text;
  final String engineVersion;
  final String phraseBankVersion;
  final String surface;
  final String intentId;
  final String shapeId;
  final List<String> phraseIds;
  final Set<String> signals;
  final Map<String, int> fallbackLevelsUsed;
  final String factFingerprint;
  final Map<String, Object?> factSummary;
  final CompositionRecommendation recommendation;
  final List<String> trace;
  final DateTime generatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'text': text,
    'engine_version': engineVersion,
    'phrase_bank_version': phraseBankVersion,
    'surface': surface,
    'intent_id': intentId,
    'shape_id': shapeId,
    'phrase_ids': phraseIds,
    'signals': signals.toList()..sort(),
    'fallback_levels_used': fallbackLevelsUsed,
    'fact_fingerprint': factFingerprint,
    'fact_summary': factSummary,
    'recommendation': recommendation.toJson(),
    'trace': trace,
    'generated_at': generatedAt.toUtc().toIso8601String(),
  };
}

String _formatDate(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final yyyy = local.year.toString().padLeft(4, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}
