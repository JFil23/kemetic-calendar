import 'ask_haw_flow_contract.dart';

enum AskHawIntent {
  event,
  find,
  explain,
  next,
  fit,
  plan,
  move,
  shorten,
  skip,
  pause,
  resume,
  preferences,
  clarify,
  unsupported,
}

class AskHawRequest {
  const AskHawRequest({
    required this.intent,
    required this.raw,
    this.query = '',
    this.minutes,
    this.targetText,
    this.temporalText,
    this.explicitTemporal = false,
    this.contentId,
    this.learned = false,
  });

  final AskHawIntent intent;
  final String raw, query;
  final int? minutes;
  final String? targetText, temporalText, contentId;
  final bool explicitTemporal, learned;
  bool get isEvent => intent == AskHawIntent.event;
  bool get requiresAccount => const {
    AskHawIntent.next,
    AskHawIntent.plan,
    AskHawIntent.move,
    AskHawIntent.shorten,
    AskHawIntent.skip,
    AskHawIntent.pause,
    AskHawIntent.resume,
    AskHawIntent.preferences,
  }.contains(intent);
}

enum AskHawContentKind { library, maatFlow, flow }

class AskHawContent {
  const AskHawContent({
    required this.id,
    required this.kind,
    required this.title,
    required this.summary,
    this.explanation,
    this.aliases = const [],
    this.topics = const [],
    this.durationMinutes,
    this.commitment,
    this.beginner,
    this.active = false,
    this.paused = false,
    this.maatFlowKey,
    this.editable = false,
    this.flowId,
    this.contract,
  });
  final String id, title, summary;
  final String? explanation;
  final AskHawContentKind kind;
  final List<String> aliases, topics;
  final int? durationMinutes, flowId;
  final String? commitment;
  final bool? beginner;
  final bool active, paused, editable;
  final String? maatFlowKey;
  final AskHawFlowContract? contract;
  String get optionId => 'open:$id';
}

class AskHawMatch {
  const AskHawMatch({
    required this.content,
    required this.score,
    required this.reason,
    this.matchedTerms = const [],
  });
  final AskHawContent content;
  final int score;
  final String reason;
  final List<String> matchedTerms;
}

class AskHawEvent {
  const AskHawEvent({
    required this.id,
    required this.title,
    required this.startUtc,
    required this.endUtc,
    this.clientEventId,
    this.allDay = false,
    this.durationKnown = true,
    this.eventRevision,
    this.flowId,
    this.editable = false,
    this.calendarId,
    this.stepId,
    this.completion = AskHawCompletion.unknown,
  });
  final String id, title;
  final String? clientEventId, eventRevision, calendarId, stepId;
  final DateTime startUtc, endUtc;
  final bool allDay, durationKnown, editable;
  final int? flowId;
  final AskHawCompletion completion;
}

/// A proposed practice supplied by its existing Flow owner. Unknown duration or
/// missing authored capabilities never becomes permission to adapt a practice.
class AskHawActivity {
  const AskHawActivity({
    required this.id,
    required this.title,
    required this.flowId,
    required this.stepId,
    required this.contract,
    this.revision = '',
    this.completions = const {},
    this.priority = 0,
    this.preferredMinutes,
    this.preferredStartUtc,
    this.paused = false,
  });
  final String id, title, stepId, revision;
  final int flowId, priority;
  final int? preferredMinutes;
  final AskHawFlowContract contract;
  final Map<String, AskHawCompletion> completions;
  final DateTime? preferredStartUtc;
  final bool paused;
}

class AskHawWindow {
  const AskHawWindow({required this.startUtc, required this.endUtc});
  final DateTime startUtc, endUtc;
  bool get valid => startUtc.isUtc && endUtc.isUtc && endUtc.isAfter(startUtc);
  bool overlaps(DateTime start, DateTime end) =>
      start.isBefore(endUtc) && end.isAfter(startUtc);
}

/// Coverage describes all authorized busy sources, including connected calendars
/// whether displayed or hidden. A warm preview is never complete coverage.
class AskHawContext {
  AskHawContext({
    required DateTime nowUtc,
    this.timezone = 'UTC',
    this.dateMode = 'gregorian',
    this.selectedEventId,
    this.selectedFlowId,
    this.events = const [],
    this.activities = const [],
    this.windows = const [],
    this.coverageComplete = false,
    this.coverageStartUtc,
    this.coverageEndUtc,
    this.coverageRevision = '',
    this.accountId,
  }) : nowUtc = nowUtc.toUtc();
  final DateTime nowUtc;
  final String timezone, dateMode, coverageRevision;
  final String? selectedEventId, accountId;
  final int? selectedFlowId;
  final List<AskHawEvent> events;
  final List<AskHawActivity> activities;
  final List<AskHawWindow> windows;
  final bool coverageComplete;
  final DateTime? coverageStartUtc, coverageEndUtc;

  bool covers(AskHawWindow window) =>
      coverageComplete &&
      coverageStartUtc != null &&
      coverageEndUtc != null &&
      !window.startUtc.isBefore(coverageStartUtc!) &&
      !window.endUtc.isAfter(coverageEndUtc!);
}
