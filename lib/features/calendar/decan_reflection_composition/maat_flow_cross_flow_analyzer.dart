import 'package:mobile/core/completion_status.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/maat_flow_decan_fact_collector.dart';
import 'package:mobile/features/calendar/decan_reflection_composition/maat_flow_profile_catalog.dart';

const String kMaatFlowCrossFlowAnalyzerVersion =
    'maat_flow_cross_flow_analyzer_v1';

enum MaatFlowCrossFlowInferenceType {
  sharedIntentionHolding,
  sharedIntentionFriction,
  sharedIntentionPartial,
  sharedIntentionUncentered,
}

extension MaatFlowCrossFlowInferenceTypeX on MaatFlowCrossFlowInferenceType {
  String get wireName {
    return switch (this) {
      MaatFlowCrossFlowInferenceType.sharedIntentionHolding =>
        'shared_intention_holding',
      MaatFlowCrossFlowInferenceType.sharedIntentionFriction =>
        'shared_intention_friction',
      MaatFlowCrossFlowInferenceType.sharedIntentionPartial =>
        'shared_intention_partial',
      MaatFlowCrossFlowInferenceType.sharedIntentionUncentered =>
        'shared_intention_uncentered',
    };
  }
}

enum MaatFlowCrossFlowEvidenceStrength { low, medium, high }

extension MaatFlowCrossFlowEvidenceStrengthX
    on MaatFlowCrossFlowEvidenceStrength {
  String get wireName {
    return switch (this) {
      MaatFlowCrossFlowEvidenceStrength.low => 'low',
      MaatFlowCrossFlowEvidenceStrength.medium => 'medium',
      MaatFlowCrossFlowEvidenceStrength.high => 'high',
    };
  }
}

class MaatFlowCrossFlowInference {
  const MaatFlowCrossFlowInference({
    required this.type,
    required this.axis,
    required this.value,
    required this.supportingFlowKeys,
    required this.observedCount,
    required this.partialCount,
    required this.skippedCount,
    required this.confidence,
    required this.evidenceStrength,
    required this.supportRatio,
    this.catalogVersion = kMaatFlowProfileCatalogVersion,
    this.analyzerVersion = kMaatFlowCrossFlowAnalyzerVersion,
  });

  final MaatFlowCrossFlowInferenceType type;
  final MaatFlowProfileAxis axis;
  final String value;
  final List<String> supportingFlowKeys;
  final int observedCount;
  final int partialCount;
  final int skippedCount;
  final double confidence;
  final MaatFlowCrossFlowEvidenceStrength evidenceStrength;
  final double supportRatio;
  final String catalogVersion;
  final String analyzerVersion;

  int get totalCount => observedCount + partialCount + skippedCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.wireName,
    'axis': axis.wireName,
    'value': value,
    'supporting_flow_keys': supportingFlowKeys,
    'observed_count': observedCount,
    'partial_count': partialCount,
    'skipped_count': skippedCount,
    'total_count': totalCount,
    'confidence': confidence,
    'evidence_strength': evidenceStrength.wireName,
    'support_ratio': supportRatio,
    'analyzer_version': analyzerVersion,
    'catalog_version': catalogVersion,
  };
}

class MaatFlowCrossFlowAnalyzer {
  const MaatFlowCrossFlowAnalyzer({
    this.profiles = kMaatFlowStaticProfiles,
    this.minimumDistinctFlows = 2,
    this.minimumInteractions = 4,
    this.minimumObserved = 2,
    this.minimumSupportRatio = 0.6,
  });

  final Map<String, MaatFlowStaticProfile> profiles;
  final int minimumDistinctFlows;
  final int minimumInteractions;
  final int minimumObserved;
  final double minimumSupportRatio;

  MaatFlowCrossFlowInference? analyze(
    Iterable<MaatFlowDecanCompletion> completions,
  ) {
    final usable = completions
        .where((row) => row.completionStatus != CompletionStatus.none)
        .toList(growable: false);
    if (usable.isEmpty) return null;
    if (usable.length < minimumInteractions) return null;

    final distinctFlowKeys = usable.map((row) => row.flowKey).toSet();
    if (distinctFlowKeys.length < minimumDistinctFlows) return null;

    final observedCount = _count(usable, CompletionStatus.observed);
    if (observedCount < minimumObserved) return null;

    final profiled = usable
        .where((row) => profiles.containsKey(row.flowKey))
        .toList(growable: false);
    if (profiled.length < minimumInteractions) return null;

    final profiledFlowKeys = profiled.map((row) => row.flowKey).toSet();
    if (profiledFlowKeys.length < minimumDistinctFlows) return null;

    final candidate = _strongestSharedAttribute(profiled);
    final partialCount = _count(profiled, CompletionStatus.partial);
    final skippedCount = _count(profiled, CompletionStatus.skipped);
    final profiledObservedCount = _count(profiled, CompletionStatus.observed);
    if (candidate == null) {
      if (profiledFlowKeys.length < 3) return null;
      return _buildInference(
        type: MaatFlowCrossFlowInferenceType.sharedIntentionUncentered,
        axis: MaatFlowProfileAxis.primaryIntention,
        value: 'no_shared_center',
        supportingFlowKeys: profiledFlowKeys.toList()..sort(),
        observedCount: profiledObservedCount,
        partialCount: partialCount,
        skippedCount: skippedCount,
        supportRatio: 0,
      );
    }

    return _buildInference(
      type: _relationshipType(
        observedCount: profiledObservedCount,
        partialCount: partialCount,
        skippedCount: skippedCount,
      ),
      axis: candidate.attribute.axis,
      value: candidate.attribute.value,
      supportingFlowKeys: candidate.supportingFlowKeys,
      observedCount: profiledObservedCount,
      partialCount: partialCount,
      skippedCount: skippedCount,
      supportRatio: candidate.supportRatio,
    );
  }

  _SharedAttributeCandidate? _strongestSharedAttribute(
    List<MaatFlowDecanCompletion> completions,
  ) {
    final totalWeight = completions.fold<double>(
      0,
      (sum, row) => sum + _completionWeight(row.completionStatus),
    );
    if (totalWeight <= 0) return null;

    final candidates = <String, _SharedAttributeCandidate>{};
    for (final row in completions) {
      final profile = profiles[row.flowKey];
      if (profile == null) continue;
      final weight = _completionWeight(row.completionStatus);
      for (final attribute in profile.attributes) {
        if (_cannotBePrimaryInsight(attribute)) continue;
        final existing = candidates[attribute.key];
        final candidate =
            existing ??
            _SharedAttributeCandidate(attribute: attribute, totalWeight: 0);
        candidates[attribute.key] = candidate.add(row.flowKey, weight);
      }
    }

    final eligible = candidates.values
        .where(
          (candidate) =>
              candidate.flowKeys.length >= minimumDistinctFlows &&
              candidate.supportWeight / totalWeight >= minimumSupportRatio,
        )
        .toList(growable: false);
    if (eligible.isEmpty) return null;

    eligible.sort((a, b) {
      final weightCompare = b.supportWeight.compareTo(a.supportWeight);
      if (weightCompare != 0) return weightCompare;
      final flowCountCompare = b.flowKeys.length.compareTo(a.flowKeys.length);
      if (flowCountCompare != 0) return flowCountCompare;
      final axisCompare = _axisPriority(
        a.attribute.axis,
      ).compareTo(_axisPriority(b.attribute.axis));
      if (axisCompare != 0) return axisCompare;
      return a.attribute.value.compareTo(b.attribute.value);
    });

    return eligible.first.withSupportRatio(
      eligible.first.supportWeight / totalWeight,
    );
  }

  static int _count(
    Iterable<MaatFlowDecanCompletion> completions,
    CompletionStatus status,
  ) {
    return completions.where((row) => row.completionStatus == status).length;
  }

  static double _completionWeight(CompletionStatus status) {
    return switch (status) {
      CompletionStatus.observed => 1,
      CompletionStatus.partial => 0.6,
      CompletionStatus.skipped => 0.25,
      CompletionStatus.none => 0,
    };
  }

  static bool _cannotBePrimaryInsight(MaatFlowProfileAttribute attribute) {
    return attribute.value == 'anytime' || attribute.value == 'mixed';
  }

  static int _axisPriority(MaatFlowProfileAxis axis) {
    return switch (axis) {
      MaatFlowProfileAxis.primaryIntention => 0,
      MaatFlowProfileAxis.practiceType => 1,
      MaatFlowProfileAxis.effortShape => 2,
      MaatFlowProfileAxis.timeBias => 3,
      MaatFlowProfileAxis.orientation => 4,
      MaatFlowProfileAxis.mode => 5,
    };
  }

  static MaatFlowCrossFlowInferenceType _relationshipType({
    required int observedCount,
    required int partialCount,
    required int skippedCount,
  }) {
    final total = observedCount + partialCount + skippedCount;
    if (total == 0) {
      return MaatFlowCrossFlowInferenceType.sharedIntentionUncentered;
    }
    if (skippedCount / total >= 0.4) {
      return MaatFlowCrossFlowInferenceType.sharedIntentionFriction;
    }
    if (partialCount / total >= 0.5 || partialCount >= observedCount) {
      return MaatFlowCrossFlowInferenceType.sharedIntentionPartial;
    }
    return MaatFlowCrossFlowInferenceType.sharedIntentionHolding;
  }

  static MaatFlowCrossFlowInference _buildInference({
    required MaatFlowCrossFlowInferenceType type,
    required MaatFlowProfileAxis axis,
    required String value,
    required List<String> supportingFlowKeys,
    required int observedCount,
    required int partialCount,
    required int skippedCount,
    required double supportRatio,
  }) {
    final total = observedCount + partialCount + skippedCount;
    final confidence = _confidence(total: total, supportRatio: supportRatio);
    return MaatFlowCrossFlowInference(
      type: type,
      axis: axis,
      value: value,
      supportingFlowKeys: supportingFlowKeys,
      observedCount: observedCount,
      partialCount: partialCount,
      skippedCount: skippedCount,
      supportRatio: supportRatio,
      confidence: confidence,
      evidenceStrength: _evidenceStrength(confidence),
    );
  }

  static double _confidence({
    required int total,
    required double supportRatio,
  }) {
    final evidenceRatio = (total / 8).clamp(0.0, 1.0);
    return ((supportRatio * 0.7) + (evidenceRatio * 0.3)).clamp(0.0, 1.0);
  }

  static MaatFlowCrossFlowEvidenceStrength _evidenceStrength(
    double confidence,
  ) {
    if (confidence >= 0.8) return MaatFlowCrossFlowEvidenceStrength.high;
    if (confidence >= 0.45) return MaatFlowCrossFlowEvidenceStrength.medium;
    return MaatFlowCrossFlowEvidenceStrength.low;
  }
}

class _SharedAttributeCandidate {
  const _SharedAttributeCandidate({
    required this.attribute,
    required this.totalWeight,
    this.flowWeights = const <String, double>{},
    this.supportRatio = 0,
  });

  final MaatFlowProfileAttribute attribute;
  final double totalWeight;
  final Map<String, double> flowWeights;
  final double supportRatio;

  Iterable<String> get flowKeys => flowWeights.keys;

  double get supportWeight =>
      flowWeights.values.fold<double>(0, (sum, weight) => sum + weight);

  List<String> get supportingFlowKeys => flowWeights.keys.toList()..sort();

  _SharedAttributeCandidate add(String flowKey, double weight) {
    return _SharedAttributeCandidate(
      attribute: attribute,
      totalWeight: totalWeight + weight,
      flowWeights: <String, double>{
        ...flowWeights,
        flowKey: (flowWeights[flowKey] ?? 0) + weight,
      },
      supportRatio: supportRatio,
    );
  }

  _SharedAttributeCandidate withSupportRatio(double value) {
    return _SharedAttributeCandidate(
      attribute: attribute,
      totalWeight: totalWeight,
      flowWeights: flowWeights,
      supportRatio: value,
    );
  }
}
