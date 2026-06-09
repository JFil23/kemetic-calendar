import 'package:mobile/core/completion_status.dart';

enum MaatFlowActivityTier { low, partial, consistent, strong }

class MaatFlowReflectionMetadata {
  const MaatFlowReflectionMetadata({
    required this.flowId,
    this.eventId,
    required this.theme,
    required this.ritualAction,
    required this.reflectionIntent,
    required this.completionResponseHints,
    required this.alignmentNotificationHints,
    required this.lowActivityResponseHint,
    required this.partialActivityResponseHint,
    required this.consistentActivityResponseHint,
    required this.strongActivityResponseHint,
  });

  final String flowId;
  final String? eventId;
  final String theme;
  final String ritualAction;
  final String reflectionIntent;
  final List<String> completionResponseHints;
  final List<String> alignmentNotificationHints;
  final String lowActivityResponseHint;
  final String partialActivityResponseHint;
  final String consistentActivityResponseHint;
  final String strongActivityResponseHint;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'flowId': flowId,
      if (eventId != null) 'eventId': eventId,
      'theme': theme,
      'ritualAction': ritualAction,
      'reflectionIntent': reflectionIntent,
      'completionResponseHints': completionResponseHints,
      'alignmentNotificationHints': alignmentNotificationHints,
      'lowActivityResponseHint': lowActivityResponseHint,
      'partialActivityResponseHint': partialActivityResponseHint,
      'consistentActivityResponseHint': consistentActivityResponseHint,
      'strongActivityResponseHint': strongActivityResponseHint,
    };
  }
}

MaatFlowReflectionMetadata resolveMaatFlowReflectionMetadata({
  required String flowId,
  String? eventId,
  String? flowTitle,
  String? eventTitle,
  String? theme,
  String? ritualAction,
  String? reflectionIntent,
}) {
  final cleanFlowTitle = flowTitle?.trim();
  final cleanEventTitle = eventTitle?.trim();
  final resolvedTheme = (theme?.trim().isNotEmpty ?? false)
      ? theme!.trim()
      : _themeForFlow(flowId, cleanFlowTitle);
  final resolvedAction = (ritualAction?.trim().isNotEmpty ?? false)
      ? ritualAction!.trim()
      : _ritualActionForFlow(flowId, cleanEventTitle);
  final intent = (reflectionIntent?.trim().isNotEmpty ?? false)
      ? reflectionIntent!.trim()
      : 'Notice what this practice asked you to receive, name, or return.';

  return MaatFlowReflectionMetadata(
    flowId: flowId,
    eventId: eventId,
    theme: resolvedTheme,
    ritualAction: resolvedAction,
    reflectionIntent: intent,
    completionResponseHints: <String>[
      'What happened in the practice?',
      'What support, resistance, or return did you notice?',
    ],
    alignmentNotificationHints: <String>[resolvedTheme, resolvedAction],
    lowActivityResponseHint:
        'Name one thing that carried you today. That is enough.',
    partialActivityResponseHint:
        'You caught part of the practice. Keep the thread: what support did you notice?',
    consistentActivityResponseHint:
        'You have been returning to the work. Today\'s act asks you to notice what has been carrying you.',
    strongActivityResponseHint:
        'A pattern is forming: you are not only receiving support, you are beginning to return it.',
  );
}

MaatFlowReflectionMetadata resolveMaatFlowReflectionMetadataFromPayload(
  Map<String, dynamic>? payload, {
  String? flowTitle,
  String? eventTitle,
}) {
  final flowId = payload?['flow_key']?.toString().trim();
  final eventNumber = payload?['event_number']?.toString().trim();
  final flowDay = payload?['flow_day']?.toString().trim();
  return resolveMaatFlowReflectionMetadata(
    flowId: flowId == null || flowId.isEmpty ? 'maat_flow' : flowId,
    eventId: eventNumber == null || eventNumber.isEmpty
        ? null
        : 'event-$eventNumber',
    flowTitle: flowTitle,
    eventTitle: eventTitle,
    theme: payload?['reflection_guidance'] is Map
        ? (payload!['reflection_guidance'] as Map)['theme']?.toString()
        : null,
    ritualAction: payload?['reflection_guidance'] is Map
        ? (payload!['reflection_guidance'] as Map)['ritualAction']?.toString()
        : flowDay == null || flowDay.isEmpty
        ? null
        : 'Return to the day $flowDay practice.',
    reflectionIntent: payload?['reflection_guidance'] is Map
        ? (payload!['reflection_guidance'] as Map)['reflectionIntent']
              ?.toString()
        : null,
  );
}

String resolveMaatFlowResponseHint({
  required MaatFlowReflectionMetadata metadata,
  required CompletionStatus completionStatus,
  required MaatFlowActivityTier activityTier,
}) {
  if (completionStatus == CompletionStatus.skipped) {
    return metadata.lowActivityResponseHint;
  }
  if (completionStatus == CompletionStatus.partial) {
    return metadata.partialActivityResponseHint;
  }
  switch (activityTier) {
    case MaatFlowActivityTier.low:
      return metadata.lowActivityResponseHint;
    case MaatFlowActivityTier.partial:
      return metadata.partialActivityResponseHint;
    case MaatFlowActivityTier.consistent:
      return metadata.consistentActivityResponseHint;
    case MaatFlowActivityTier.strong:
      return metadata.strongActivityResponseHint;
  }
}

String _themeForFlow(String flowId, String? flowTitle) {
  final key = flowId.trim().toLowerCase();
  if (key.contains('offering')) return 'Reciprocal support';
  if (key.contains('tending')) return 'Care and return';
  if (key.contains('weighing')) return 'Truthful measure';
  if (key.contains('open-hand')) return 'Provision and generosity';
  if (key.contains('djed')) return 'Stability under pressure';
  if (key.contains('sky') || key.contains('decan')) {
    return 'Attentive witnessing';
  }
  return flowTitle?.trim().isNotEmpty == true
      ? flowTitle!.trim()
      : 'Ma\'at practice';
}

String _ritualActionForFlow(String flowId, String? eventTitle) {
  final title = eventTitle?.trim();
  if (title != null && title.isNotEmpty) return title;
  final key = flowId.trim().toLowerCase();
  if (key.contains('offering')) {
    return 'Name what was received and what can be returned.';
  }
  if (key.contains('tending')) {
    return 'Notice what needs care and what care asks back.';
  }
  if (key.contains('weighing')) return 'Set the record beside the measure.';
  if (key.contains('sky') || key.contains('decan')) {
    return 'Witness the appointed sign without forcing meaning.';
  }
  return 'Complete the appointed practice with an honest record.';
}
