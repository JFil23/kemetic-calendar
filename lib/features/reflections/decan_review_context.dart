import 'package:flutter/foundation.dart';
import '../nodes/kemetic_node_library.dart';
import '../calendar/maat_flow_catalog.dart';
import '../calendar/maat_flow_identity.dart';
import 'decan_review_models.dart';

/// Authored questions replace the interpretive phrase matrix for new reviews.
/// The catalog version is saved with the chosen question; old reviews never
/// silently acquire a different question when this list changes.
abstract final class DecanReviewQuestions {
  static const version = 1;
  static const catalog = <String, String>{
    'carry': 'What would you like to carry forward?',
    'stay': 'What stayed with you from these ten days?',
    'return': 'What would you like to return to?',
    'room': 'What would you like to make room for?',
    'notice': 'What do you notice when you look back?',
    'unrecorded': 'What mattered that went unrecorded?',
    'remember': 'What would you like to remember?',
    'open': 'What question would you like to keep open?',
  };
  static String choose({required bool hasMoments, String? previousQuestionId}) {
    if (!hasMoments)
      return previousQuestionId == 'unrecorded' ? 'room' : 'unrecorded';
    if (previousQuestionId == null) return 'carry';
    final keys = catalog.keys.toList();
    return keys[(keys.indexOf(previousQuestionId) + 1) % keys.length];
  }
}

@immutable
class DecanReviewContext {
  const DecanReviewContext({
    required this.questionId,
    required this.question,
    required this.moments,
    this.questionVersion = DecanReviewQuestions.version,
    this.questionOpen = false,
    this.dismissedSuggestions = const {},
    this.presentedSuggestions = const {},
  });
  final String questionId, question;
  final int questionVersion;
  final List<DecanMoment> moments;
  final bool questionOpen;
  final Set<String> dismissedSuggestions, presentedSuggestions;
  factory DecanReviewContext.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 1)
      throw const FormatException('Unsupported review schema');
    return DecanReviewContext(
      questionId: json['question_id'] as String,
      question: json['question'] as String,
      questionVersion: (json['question_version'] as num?)?.toInt() ?? 1,
      moments: (json['moments'] as List)
          .map((e) => DecanMoment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      questionOpen: json['question_open'] == true,
      dismissedSuggestions: (json['dismissed_suggestions'] as List? ?? [])
          .cast<String>()
          .toSet(),
      presentedSuggestions: (json['presented_suggestions'] as List? ?? [])
          .cast<String>()
          .toSet(),
    );
  }
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'question_id': questionId,
    'question': question,
    'question_version': questionVersion,
    'moments': moments.map((e) => e.toJson()).toList(),
    'question_open': questionOpen,
    'dismissed_suggestions': dismissedSuggestions.toList(),
    'presented_suggestions': presentedSuggestions.toList(),
  };
  DecanReviewContext copyWith({
    List<DecanMoment>? moments,
    bool? questionOpen,
    Set<String>? dismissedSuggestions,
    Set<String>? presentedSuggestions,
  }) => DecanReviewContext(
    questionId: questionId,
    question: question,
    questionVersion: questionVersion,
    moments: moments ?? this.moments,
    questionOpen: questionOpen ?? this.questionOpen,
    dismissedSuggestions: dismissedSuggestions ?? this.dismissedSuggestions,
    presentedSuggestions: presentedSuggestions ?? this.presentedSuggestions,
  );
}

/// A small local catalog join, not another scoring or inference service.
/// Every reason names an actual selection or an authored Library relationship.
abstract final class DecanReviewSuggestions {
  static const flowTitles = <String, String>{
    'track-the-sky': 'Follow the Sky',
    'the-offering-table': 'Offering Table',
    'the-reading-house': 'Reading House',
    'the-djed': 'Djed',
    'the-kar': 'Kꜣr',
  };
  static const flowReadings = <String, List<String>>{
    'track-the-sky': ['decans', 'nut', 'sopdet'],
    'the-offering-table': ['offering_formula', 'hotep', 'ka'],
    'the-reading-house': [
      'instruction_ptahhotep',
      'instruction_amenemope',
      'house_of_life',
    ],
    'the-djed': ['ausar', 'maat'],
    'the-kar': ['ptah', 'ka', 'hathor'],
  };
  static List<DecanContinuation> build({
    required List<DecanMoment> moments,
    Set<String> excluded = const {},
    Set<String> joinedFlowKeys = const {},
    Set<String> alreadyRead = const {},
  }) {
    final active = kDiscoverableMaatFlowKinds
        .map((kind) => kind.flowKey)
        .toSet();
    final selectedReadings = moments
        .map((m) => m.libraryId)
        .whereType<String>()
        .toSet();
    final readings = <DecanContinuation>[];
    final flows = <DecanContinuation>[];
    for (final moment in moments) {
      final reading = moment.libraryId == null
          ? null
          : KemeticNodeLibrary.resolve(moment.libraryId!);
      if (reading != null && !KemeticNodeLibrary.isRetired(reading.id)) {
        for (final link in reading.linkMap) {
          final target = KemeticNodeLibrary.resolve(link.targetId);
          if (target == null || KemeticNodeLibrary.isRetired(target.id))
            continue;
          readings.add(
            DecanContinuation(
              id: 'library:${target.id}',
              title: target.title,
              reason: 'A reading linked from ${reading.title}.',
              libraryId: target.id,
            ),
          );
        }
        for (final entry in flowReadings.entries) {
          if (entry.value.contains(reading.id))
            flows.add(
              DecanContinuation(
                id: 'flow:${entry.key}',
                title: flowTitles[entry.key]!,
                reason: 'A practice to explore alongside ${reading.title}.',
                flowKey: entry.key,
              ),
            );
        }
        // Reading House is the authored place for study of any Library reading.
        flows.add(
          DecanContinuation(
            id: 'flow:the-reading-house',
            title: 'Reading House',
            reason: 'A place to spend time with ${reading.title}.',
            flowKey: 'the-reading-house',
          ),
        );
      }
      final flowKey = moment.flowKey;
      if (flowKey != null && active.contains(flowKey)) {
        for (final id in flowReadings[flowKey] ?? <String>[]) {
          final target = KemeticNodeLibrary.resolve(id);
          if (target == null || KemeticNodeLibrary.isRetired(target.id))
            continue;
          readings.add(
            DecanContinuation(
              id: 'library:$id',
              title: target.title,
              reason: 'A reading connected with ${flowTitles[flowKey]}.',
              libraryId: id,
            ),
          );
        }
      }
    }
    final eligibleFlows = flows.where(
      (f) =>
          active.contains(f.flowKey) &&
          !joinedFlowKeys.contains(f.flowKey) &&
          !excluded.contains(f.id),
    );
    final eligibleReadings = readings.where(
      (r) =>
          !selectedReadings.contains(r.libraryId) &&
          !alreadyRead.contains(r.libraryId) &&
          !excluded.contains(r.id),
    );
    return [
      if (eligibleFlows.isNotEmpty) eligibleFlows.first,
      if (eligibleReadings.isNotEmpty) eligibleReadings.first,
    ];
  }
}
