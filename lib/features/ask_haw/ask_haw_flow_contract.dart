/// Optional authored assistance metadata. Recurrence rules remain owned by the
/// existing Flow scheduler. Future versions fail closed for adaptation only.
enum AskHawCompletion { unknown, observed, partial, skipped }

enum AskHawAdaptation { shorten, reschedule, skip, pause, resume }

class AskHawAlternative {
  const AskHawAlternative({
    required this.id,
    required this.label,
    required this.minutes,
    required this.guidance,
    this.countsAsCompletion = false,
  });
  final String id, label, guidance;
  final bool countsAsCompletion;
  final int minutes;
  factory AskHawAlternative.fromJson(Map<String, dynamic> json) =>
      AskHawAlternative(
        id: json['id'] as String,
        label: json['label'] as String,
        minutes: (json['minutes'] as num).toInt(),
        guidance: json['guidance'] as String,
        countsAsCompletion: json['countsAsCompletion'] == true,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'minutes': minutes,
    'guidance': guidance,
    'countsAsCompletion': countsAsCompletion,
  };
}

class AskHawStep {
  const AskHawStep({
    required this.id,
    required this.title,
    required this.guidance,
    this.minutes,
    this.prerequisites = const [],
    this.completionMeaning = '',
    this.alternatives = const [],
    this.recoveryGuidance = '',
  });
  final String id, title, guidance, completionMeaning, recoveryGuidance;
  final int? minutes;
  final List<String> prerequisites;
  final List<AskHawAlternative> alternatives;

  bool eligible(Map<String, AskHawCompletion> completions) =>
      prerequisites.every((id) => completions[id] == AskHawCompletion.observed);

  factory AskHawStep.fromJson(Map<String, dynamic> json) => AskHawStep(
    id: json['id'] as String,
    title: json['title'] as String,
    guidance: json['guidance'] as String,
    minutes: (json['minutes'] as num?)?.toInt(),
    prerequisites: (json['prerequisites'] as List? ?? const []).cast<String>(),
    completionMeaning: json['completionMeaning'] as String? ?? '',
    recoveryGuidance: json['recoveryGuidance'] as String? ?? '',
    alternatives: [
      for (final raw in json['alternatives'] as List? ?? const [])
        AskHawAlternative.fromJson(Map<String, dynamic>.from(raw as Map)),
    ],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'guidance': guidance,
    'minutes': minutes,
    'prerequisites': prerequisites,
    'completionMeaning': completionMeaning,
    'recoveryGuidance': recoveryGuidance,
    'alternatives': alternatives.map((value) => value.toJson()).toList(),
  };
}

class AskHawFlowContract {
  const AskHawFlowContract({
    this.version = 1,
    required this.steps,
    this.adaptations = const {},
    this.guidance = '',
  });
  final int version;
  final List<AskHawStep> steps;
  final Set<AskHawAdaptation> adaptations;
  final String guidance;
  bool get supported => version == 1 && valid;
  bool get valid {
    final ids = steps.map((value) => value.id).toSet();
    if (ids.length != steps.length || ids.contains('')) return false;
    for (final step in steps) {
      if ((step.minutes != null && step.minutes! <= 0) ||
          step.prerequisites.any((id) => !ids.contains(id) || id == step.id)) {
        return false;
      }
      final alternatives = step.alternatives.map((value) => value.id).toSet();
      if (alternatives.length != step.alternatives.length ||
          alternatives.contains('') ||
          step.alternatives.any((value) => value.minutes <= 0)) {
        return false;
      }
    }
    // A cycle can never produce a legitimate next step.
    final visiting = <String>{}, visited = <String>{};
    bool acyclic(String id) {
      if (visiting.contains(id)) return false;
      if (visited.contains(id)) return true;
      visiting.add(id);
      final current = step(id)!;
      if (!current.prerequisites.every(acyclic)) return false;
      visiting.remove(id);
      visited.add(id);
      return true;
    }

    return ids.every(acyclic);
  }

  bool permits(AskHawAdaptation adaptation) =>
      supported && adaptations.contains(adaptation);
  AskHawStep? step(String id) {
    for (final value in steps) {
      if (value.id == id) return value;
    }
    return null;
  }

  /// Malformed optional metadata disables assistance, never the underlying Flow.
  static AskHawFlowContract? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final json = Map<String, dynamic>.from(raw);
      final adaptations = <AskHawAdaptation>{};
      for (final value in json['adaptations'] as List? ?? const []) {
        final matches = AskHawAdaptation.values.where(
          (item) => item.name == value,
        );
        if (matches.isEmpty) return null;
        adaptations.add(matches.first);
      }
      final result = AskHawFlowContract(
        version: (json['version'] as num?)?.toInt() ?? 0,
        guidance: json['guidance'] as String? ?? '',
        adaptations: adaptations,
        steps: [
          for (final value in json['steps'] as List? ?? const [])
            AskHawStep.fromJson(Map<String, dynamic>.from(value as Map)),
        ],
      );
      return result.supported ? result : null;
    } on Object {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'guidance': guidance,
    'adaptations': adaptations.map((value) => value.name).toList()..sort(),
    'steps': steps.map((value) => value.toJson()).toList(),
  };
}
