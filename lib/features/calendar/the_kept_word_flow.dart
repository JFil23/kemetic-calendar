import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dawn_house_rite_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'maat_flow_identity.dart';
import 'track_sky_flow.dart';

const String kKeptWordFlowKey = 'the-kept-word';
const String kKeptWordTitle = 'The Kept Word';
const String kKeptWordGlyph = '𓂋';
const String kKeptWordTagline =
    'What you speak within your house determines its order.';
const String kKeptWordEnrollmentCopy =
    'Decan 2 needs a conversation with another person. You name the break; you are not responsible for their response.';
const int kKeptWordDefaultMiddayHour = 11;
const int kKeptWordDefaultMiddayMinute = 0;
const int kKeptWordEveningFallbackMinutes =
    kEveningThresholdDefaultFallbackMinutes + 20;

const String kKeptWordOverview =
    'Three times per decan, name agreements and shared rhythms, bring one break to a direct conversation, and confirm renewed order in plain words. '
    'The Kept Word is a low-medium burden thirty-day Ma\'at flow with nine sittings: Name the State, Bring to Process, and Confirm the Order. '
    'It practices speaking what is true inside the closest sphere while keeping the response of the other person outside your control.';

enum KeptWordTimingSlot { openMorning, checkMidday, sealEvening }

extension KeptWordTimingSlotX on KeptWordTimingSlot {
  String get key {
    switch (this) {
      case KeptWordTimingSlot.openMorning:
        return 'open_morning';
      case KeptWordTimingSlot.checkMidday:
        return 'check_midday';
      case KeptWordTimingSlot.sealEvening:
        return 'seal_evening';
    }
  }

  String get label {
    switch (this) {
      case KeptWordTimingSlot.openMorning:
        return 'Dawn + 30 min';
      case KeptWordTimingSlot.checkMidday:
        return '11:00 local';
      case KeptWordTimingSlot.sealEvening:
        return 'Sunset + 30 min';
    }
  }
}

enum KeptWordLocalPromptKind {
  none,
  agreementInventory,
  sharedRhythm,
  sealSeeingGreedCheck,
  conversationPrep,
  conversationRecord,
  sealNaming,
  renewedAgreement,
  rhythmCheck,
  closeInventory,
}

extension KeptWordLocalPromptKindX on KeptWordLocalPromptKind {
  String get key {
    switch (this) {
      case KeptWordLocalPromptKind.none:
        return 'none';
      case KeptWordLocalPromptKind.agreementInventory:
        return 'agreement_inventory';
      case KeptWordLocalPromptKind.sharedRhythm:
        return 'shared_rhythm';
      case KeptWordLocalPromptKind.sealSeeingGreedCheck:
        return 'seal_seeing_greed_check';
      case KeptWordLocalPromptKind.conversationPrep:
        return 'conversation_prep';
      case KeptWordLocalPromptKind.conversationRecord:
        return 'conversation_record';
      case KeptWordLocalPromptKind.sealNaming:
        return 'seal_naming';
      case KeptWordLocalPromptKind.renewedAgreement:
        return 'renewed_agreement';
      case KeptWordLocalPromptKind.rhythmCheck:
        return 'rhythm_check';
      case KeptWordLocalPromptKind.closeInventory:
        return 'close_inventory';
    }
  }

  String get label {
    switch (this) {
      case KeptWordLocalPromptKind.none:
        return '';
      case KeptWordLocalPromptKind.agreementInventory:
        return 'Agreement inventory';
      case KeptWordLocalPromptKind.sharedRhythm:
        return 'Shared rhythm';
      case KeptWordLocalPromptKind.sealSeeingGreedCheck:
        return 'First seeing seal';
      case KeptWordLocalPromptKind.conversationPrep:
        return 'Conversation prep';
      case KeptWordLocalPromptKind.conversationRecord:
        return 'Conversation record';
      case KeptWordLocalPromptKind.sealNaming:
        return 'Naming seal';
      case KeptWordLocalPromptKind.renewedAgreement:
        return 'Renewed agreement';
      case KeptWordLocalPromptKind.rhythmCheck:
        return 'Rhythm check';
      case KeptWordLocalPromptKind.closeInventory:
        return 'Closing word';
    }
  }

  String get helperText {
    switch (this) {
      case KeptWordLocalPromptKind.none:
        return '';
      case KeptWordLocalPromptKind.agreementInventory:
        return 'List two or three people and the current agreements between you. Mark each kept, drifted, or broken.';
      case KeptWordLocalPromptKind.sharedRhythm:
        return 'Name one shared rhythm that drifted or stopped, and one sentence about when or why.';
      case KeptWordLocalPromptKind.sealSeeingGreedCheck:
        return 'Choose one drifted or broken agreement or rhythm to bring into Decan 2.';
      case KeptWordLocalPromptKind.conversationPrep:
        return 'Write the exact break, the other person\'s possible account, and when you will speak before Day 15.';
      case KeptWordLocalPromptKind.conversationRecord:
        return 'After the conversation, record what you said, what they said, and what was agreed.';
      case KeptWordLocalPromptKind.sealNaming:
        return 'Mark the break resolved, in process, or named but unresolved. Write the next concrete step.';
      case KeptWordLocalPromptKind.renewedAgreement:
        return 'Write the current agreement plainly enough that both people would recognize it.';
      case KeptWordLocalPromptKind.rhythmCheck:
        return 'Check whether the renewed agreement or rhythm is holding in practice.';
      case KeptWordLocalPromptKind.closeInventory:
        return 'Close with one private line that is now true. Do not share names or agreement text.';
    }
  }
}

enum KeptWordLens { neutral, djehuty, maat }

extension KeptWordLensX on KeptWordLens {
  String get key {
    switch (this) {
      case KeptWordLens.neutral:
        return 'neutral';
      case KeptWordLens.djehuty:
        return 'djehuty';
      case KeptWordLens.maat:
        return 'maat';
    }
  }

  String get label {
    switch (this) {
      case KeptWordLens.neutral:
        return 'Neutral';
      case KeptWordLens.djehuty:
        return 'Djehuty';
      case KeptWordLens.maat:
        return 'Ma\'at';
    }
  }

  String get detailLine {
    switch (this) {
      case KeptWordLens.neutral:
        return '';
      case KeptWordLens.djehuty:
        return 'Let Djehuty frame the conversation as an accurate record: what was said, what was heard, and what now stands.';
      case KeptWordLens.maat:
        return 'Let Ma\'at frame the work as right order made speakable inside the closest sphere.';
    }
  }
}

class KeptWordEvent {
  final int eventNumber;
  final int flowDay;
  final String decanSection;
  final String title;
  final KeptWordTimingSlot slot;
  final int durationMinutesMin;
  final int durationMinutesMax;
  final String spokenLine;
  final List<String> steps;
  final List<String> optionalSteps;
  final String? sourceNote;
  final bool sharePromptOnComplete;
  final bool requiresConversation;
  final KeptWordLocalPromptKind localPrompt;

  const KeptWordEvent({
    required this.eventNumber,
    required this.flowDay,
    required this.decanSection,
    required this.title,
    required this.slot,
    required this.durationMinutesMin,
    required this.durationMinutesMax,
    required this.spokenLine,
    required this.steps,
    required this.localPrompt,
    this.optionalSteps = const <String>[],
    this.sourceNote,
    this.sharePromptOnComplete = false,
    this.requiresConversation = false,
  });
}

class KeptWordOccurrenceSchedule {
  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool usedFallback;
  final TrackSkyTimeZone timezone;
  final String referenceLocationName;
  final String scheduleType;
  final String fallback;
  final int? middayHour;
  final int? middayMinute;

  const KeptWordOccurrenceSchedule({
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
    required this.usedFallback,
    required this.timezone,
    required this.referenceLocationName,
    required this.scheduleType,
    required this.fallback,
    this.middayHour,
    this.middayMinute,
  });
}

const List<KeptWordEvent> kKeptWordEvents = <KeptWordEvent>[
  KeptWordEvent(
    eventNumber: 1,
    flowDay: 1,
    decanSection: 'Name the State',
    title: 'The Inventory of Agreements',
    slot: KeptWordTimingSlot.openMorning,
    durationMinutesMin: 8,
    durationMinutesMax: 10,
    spokenLine:
        'Speak Ma\'at within your palace, so that those around you may respect you. An upright heart is becoming to a lord; it is the front of a house which creates respect for the back.',
    steps: <String>[
      'Write the two or three people with whom you share the most significant household or working agreements.',
      'For each person, write the current agreements: who handles what, who said what, and what was last promised.',
      'Mark each agreement kept, drifted, or broken. Mark any drifted or broken agreement for Decan 2.',
    ],
    sourceNote:
        'The Teaching for King Merikare treats the palace as the immediate sphere where public order begins. The front of the house determines the back.',
    localPrompt: KeptWordLocalPromptKind.agreementInventory,
  ),
  KeptWordEvent(
    eventNumber: 2,
    flowDay: 5,
    decanSection: 'Name the State',
    title: 'Name the Shared Rhythm',
    slot: KeptWordTimingSlot.checkMidday,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'Do not utter falsehood, for you are a balance. Do not go off course, for you are impartiality. If it wavers, then you will waver.',
    steps: <String>[
      'Name one shared rhythm that used to hold the household or relationship together and has drifted or stopped.',
      'Write one sentence about when it stopped and why, without assigning blame.',
      'Carry this named rhythm into Decan 2 with the broken agreements from Day 1.',
    ],
    sourceNote:
        'The Eloquent Peasant names the person as a balance. This sitting treats shared rhythm as part of the household measure.',
    localPrompt: KeptWordLocalPromptKind.sharedRhythm,
  ),
  KeptWordEvent(
    eventNumber: 3,
    flowDay: 9,
    decanSection: 'Name the State',
    title: 'Seal the First Seeing',
    slot: KeptWordTimingSlot.sealEvening,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'Guard yourself against the blemish of greediness. It creates dissension among fathers, mothers, and maternal brothers; it embitters beloved friends; it isolates a wife from her husband.',
    steps: <String>[
      'Review each drifted or broken agreement.',
      'Ask whether the break came from changed circumstances or from someone taking more than their agreed share.',
      'Choose one agreement or shared rhythm to address first in Decan 2.',
    ],
    optionalSteps: <String>[
      'Before the decan closes, tell the person involved that you want a clear conversation about one thing in the next ten days.',
    ],
    sourceNote:
        'Ptahhotep names greed as a force that creates dissension inside families and close bonds.',
    localPrompt: KeptWordLocalPromptKind.sealSeeingGreedCheck,
  ),
  KeptWordEvent(
    eventNumber: 4,
    flowDay: 11,
    decanSection: 'Bring to Process',
    title: 'The Conversation: Name the Break',
    slot: KeptWordTimingSlot.openMorning,
    durationMinutesMin: 5,
    durationMinutesMax: 10,
    spokenLine:
        'Deliver the message exactly as it was given. Observe the truth; do not surpass it.',
    steps: <String>[
      'Write the specific fact: We agreed to X. What has been happening is Y. I want to understand the gap.',
      'Write what you think the other person\'s honest account may be.',
      'Commit to a time for the conversation before Day 15.',
    ],
    optionalSteps: <String>[
      'If the conversation is not safe or possible, pause the flow locally and seek appropriate support.',
    ],
    sourceNote:
        'Ptahhotep instructs the messenger to carry the message exactly as given. This event applies that discipline to a broken agreement.',
    requiresConversation: true,
    localPrompt: KeptWordLocalPromptKind.conversationPrep,
  ),
  KeptWordEvent(
    eventNumber: 5,
    flowDay: 15,
    decanSection: 'Bring to Process',
    title: 'The Conversation: Confirm It Was Had',
    slot: KeptWordTimingSlot.checkMidday,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine: 'The dispute between Truth and Falsehood was settled.',
    steps: <String>[
      'If the conversation happened, write three private sentences: what I said, what they said, and what was agreed.',
      'If it has not happened, mark conversation pending and schedule it before Decan 2 closes.',
      'Name one thing that surprised you, if anything did.',
    ],
    optionalSteps: <String>[
      'If no conversation can happen safely, keep the flow paused locally rather than forcing contact.',
    ],
    requiresConversation: true,
    localPrompt: KeptWordLocalPromptKind.conversationRecord,
  ),
  KeptWordEvent(
    eventNumber: 6,
    flowDay: 19,
    decanSection: 'Bring to Process',
    title: 'Seal the Naming',
    slot: KeptWordTimingSlot.sealEvening,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine: 'He was found still alive. The dispute was settled.',
    steps: <String>[
      'Name the current status of the break: resolved, in process, or named but unresolved.',
      'If it remains unresolved, write the next concrete step as an agreement: who does what by when.',
      'Name one accurate thing the other person said that you had been holding differently.',
    ],
    sourceNote:
        'In The Blinding of Truth by Falsehood, the dispute is settled by bringing what was hidden into process.',
    requiresConversation: true,
    localPrompt: KeptWordLocalPromptKind.sealNaming,
  ),
  KeptWordEvent(
    eventNumber: 7,
    flowDay: 21,
    decanSection: 'Confirm the Order',
    title: 'Confirm the Renewed Agreement',
    slot: KeptWordTimingSlot.openMorning,
    durationMinutesMin: 8,
    durationMinutesMax: 10,
    spokenLine:
        'Observe Ma\'at, that you may endure long upon the earth. An upright heart is becoming to a lord.',
    steps: <String>[
      'Write the current agreement in plain language both people would recognize.',
      'For the shared rhythm from Decan 1, name whether it was restored, replaced, or still blocked.',
      'Read the written agreement aloud so the word becomes operative.',
    ],
    localPrompt: KeptWordLocalPromptKind.renewedAgreement,
  ),
  KeptWordEvent(
    eventNumber: 8,
    flowDay: 25,
    decanSection: 'Confirm the Order',
    title: 'The Rhythm Check',
    slot: KeptWordTimingSlot.checkMidday,
    durationMinutesMin: 3,
    durationMinutesMax: 3,
    spokenLine:
        'Do not be selfish with respect to your relatives, for greater is the claim of the good-natured man than that of the assertive. He who forsakes his relatives is truly poor.',
    steps: <String>[
      'Check whether anyone in the renewed agreement is carrying more than their share in practice.',
      'If the weight has shifted, name the small correction before Event 9.',
      'Name one thing the renewed agreement has already produced, if something has held.',
    ],
    optionalSteps: <String>[
      'Make the correction short. Healthy agreements need small adjustments as they settle.',
    ],
    sourceNote:
        'Ptahhotep treats household bonds as obligations that can be impoverished by selfishness.',
    localPrompt: KeptWordLocalPromptKind.rhythmCheck,
  ),
  KeptWordEvent(
    eventNumber: 9,
    flowDay: 29,
    decanSection: 'Confirm the Order',
    title: 'The Kept Word Closes',
    slot: KeptWordTimingSlot.sealEvening,
    durationMinutesMin: 8,
    durationMinutesMax: 10,
    spokenLine:
        'Speak Ma\'at within your palace. The front of the house determines the back. Observe Ma\'at, that you may endure long upon the earth.',
    steps: <String>[
      'Return to your Day 1 inventory and speak only the current status that is true: kept, repaired, in process, or still broken.',
      'For the shared rhythm named in Decan 1, name whether it returned and what made it possible, or what remains in the way.',
      'Write one line that is now true that was not true at the start of this flow.',
    ],
    optionalSteps: <String>[
      'If you share, share only the generic closing line. Do not share names, agreements, or conversation content.',
    ],
    sourceNote:
        'The Kept Word closes where Merikare begins: speaking Ma\'at within the immediate house so order can flow outward.',
    sharePromptOnComplete: true,
    localPrompt: KeptWordLocalPromptKind.closeInventory,
  ),
];

bool _keptWordTimeZonesInitialized = false;

void _ensureKeptWordTimeZonesInitialized() {
  if (_keptWordTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _keptWordTimeZonesInitialized = true;
}

DateTime defaultKeptWordStartDate(TrackSkyTimeZone timezone, {DateTime? now}) {
  final nowLocal = keptWordNowInZone(timezone, now: now);
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final todayStart = keptWordMorningScheduleForDate(
    today,
    timezone,
    durationMinutes: kKeptWordEvents.first.durationMinutesMax,
  ).startLocal;
  if (!todayStart.isBefore(nowLocal)) return today;
  return today.add(const Duration(days: 1));
}

DateTime keptWordNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureKeptWordTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromZonedDateTime(zoned);
}

KeptWordOccurrenceSchedule keptWordScheduleForDate(
  KeptWordEvent event,
  DateTime date,
  TrackSkyTimeZone timezone, {
  int middayHour = kKeptWordDefaultMiddayHour,
  int middayMinute = kKeptWordDefaultMiddayMinute,
}) {
  switch (event.slot) {
    case KeptWordTimingSlot.openMorning:
      return keptWordMorningScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
    case KeptWordTimingSlot.checkMidday:
      return keptWordMiddayScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
        hour: middayHour,
        minute: middayMinute,
      );
    case KeptWordTimingSlot.sealEvening:
      return keptWordEveningScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
  }
}

KeptWordOccurrenceSchedule keptWordMorningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = dawnHouseRiteScheduleForDate(date, timezone);
  final startUtc = base.startUtc.add(const Duration(minutes: 30));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return KeptWordOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: base.usedFallback,
    timezone: timezone,
    referenceLocationName: base.referenceLocation.name,
    scheduleType: 'local_astronomical_dawn_plus_30_minutes',
    fallback: 'sunrise_minus_15_minutes_plus_30_minutes',
  );
}

KeptWordOccurrenceSchedule keptWordMiddayScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
  int hour = kKeptWordDefaultMiddayHour,
  int minute = kKeptWordDefaultMiddayMinute,
}) {
  _ensureKeptWordTimeZonesInitialized();
  final localDate = DateTime(date.year, date.month, date.day);
  final location = tz.getLocation(timezone.ianaName);
  final clampedHour = hour.clamp(0, 23).toInt();
  final clampedMinute = minute.clamp(0, 59).toInt();
  final startUtc = tz.TZDateTime(
    location,
    localDate.year,
    localDate.month,
    localDate.day,
    clampedHour,
    clampedMinute,
  ).toUtc();
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  return KeptWordOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: false,
    timezone: timezone,
    referenceLocationName: timezone.label,
    scheduleType: 'fixed_local_midday',
    fallback: 'user_editable_local_time',
    middayHour: clampedHour,
    middayMinute: clampedMinute,
  );
}

KeptWordOccurrenceSchedule keptWordEveningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = eveningThresholdScheduleForDate(
    date,
    timezone,
    fallbackMinutesAfterMidnight: kKeptWordEveningFallbackMinutes,
  );
  final startUtc = base.startUtc.add(const Duration(minutes: 10));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return KeptWordOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: base.usedFallback,
    timezone: timezone,
    referenceLocationName: base.referenceLocation.name,
    scheduleType: 'local_sunset_plus_30_minutes',
    fallback: 'user_selected_evening_time_plus_30_minutes',
  );
}

String keptWordEventTitle(KeptWordEvent event) {
  return 'Kept Word ${event.eventNumber}: ${event.title}';
}

String keptWordActionId(KeptWordEvent event) {
  return 'the-kept-word-event-${event.eventNumber.toString().padLeft(2, '0')}';
}

KeptWordEvent? keptWordEventByNumber(int? eventNumber) {
  if (eventNumber == null) return null;
  for (final event in kKeptWordEvents) {
    if (event.eventNumber == eventNumber) return event;
  }
  return null;
}

KeptWordLens? keptWordLensFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final lens in KeptWordLens.values) {
    if (lens.key == normalized) return lens;
  }
  return null;
}

KeptWordLens keptWordLensFromNotes(
  String? notes, {
  KeptWordLens fallback = KeptWordLens.neutral,
}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('kept_word_lens=')) continue;
    return keptWordLensFromKey(trimmed.substring('kept_word_lens='.length)) ??
        fallback;
  }
  return fallback;
}

bool isKeptWordFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.keptWord,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

KeptWordEvent? keptWordEventForEvent({
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  int? parseNumber(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  final payloadEvent = keptWordEventByNumber(
    parseNumber(behaviorPayload?['event_number']),
  );
  if (payloadEvent != null) return payloadEvent;

  final actionMatch = RegExp(
    r'the-kept-word-event-(\d{1,2})',
    caseSensitive: false,
  ).firstMatch(actionId?.trim() ?? '');
  final actionEvent = keptWordEventByNumber(parseNumber(actionMatch?.group(1)));
  if (actionEvent != null) return actionEvent;

  final titleMatch = RegExp(
    r'^\s*Kept\s+Word\s+(\d{1,2})\s*:',
    caseSensitive: false,
  ).firstMatch(title?.trim() ?? '');
  return keptWordEventByNumber(parseNumber(titleMatch?.group(1)));
}

String? canonicalKeptWordDetailTextForEvent({
  String? flowName,
  String? flowNotes,
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  if (!isKeptWordFlowReference(
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  )) {
    return null;
  }
  final event = keptWordEventForEvent(
    title: title,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
  if (event == null) return null;
  final lens =
      keptWordLensFromKey(behaviorPayload?['lens']?.toString()) ??
      keptWordLensFromNotes(flowNotes);
  return keptWordDetailText(event, lens: lens);
}

Map<String, dynamic> keptWordBehaviorPayload({
  required KeptWordEvent event,
  required KeptWordOccurrenceSchedule schedule,
  required KeptWordLens lens,
}) {
  return <String, dynamic>{
    'kind': 'maat_kept_word_event',
    'flow_key': kKeptWordFlowKey,
    'event_number': event.eventNumber,
    'flow_day': event.flowDay,
    'decan_section': event.decanSection,
    'slot': event.slot.key,
    'duration_minutes': event.durationMinutesMax,
    'duration_minutes_min': event.durationMinutesMin,
    'duration_minutes_max': event.durationMinutesMax,
    'burden': 'low_medium',
    'props_profile': const <String, dynamic>{
      'required': <String>[],
      'optional': <String>[],
    },
    'completion_options': <String>[
      'observed',
      'observed_partly',
      'skipped',
      if (event.eventNumber == 5) 'conversation_pending',
    ],
    'missed_event_rule': 'expire_quietly',
    'share_prompt_on_complete': event.sharePromptOnComplete,
    'requires_conversation': event.requiresConversation,
    'local_prompt': event.localPrompt.key,
    'privacy': const <String, dynamic>{
      'household_notes_storage': 'device_only',
      'sync_agreement_text': false,
      'sync_names': false,
    },
    'schedule': <String, dynamic>{
      'type': schedule.scheduleType,
      'fallback': schedule.fallback,
      'used_fallback': schedule.usedFallback,
      'timezone': schedule.timezone.key,
      'iana_timezone': schedule.timezone.ianaName,
      'reference_location': schedule.referenceLocationName,
      if (schedule.middayHour != null) 'midday_hour': schedule.middayHour,
      if (schedule.middayMinute != null) 'midday_minute': schedule.middayMinute,
    },
    'lens': lens.key,
  };
}

String keptWordDetailText(KeptWordEvent event, {required KeptWordLens lens}) {
  final optional = event.optionalSteps
      .map((step) => '- $step')
      .join('\n')
      .trim();
  final lensLine = lens.detailLine.trim();
  return <String>[
    'Purpose\n${_keptWordPurpose(event)}',
    'Words\n"${event.spokenLine}"',
    'Steps\n${_numberedLines(event.steps)}',
    if (optional.isNotEmpty) 'Optional\n$optional',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
    if (event.eventNumber == 5)
      'Completion\nIf the conversation has not been marked complete, choose Conversation pending.',
  ].join('\n\n');
}

String keptWordTimingLabel(KeptWordEvent event) {
  switch (event.slot) {
    case KeptWordTimingSlot.openMorning:
      return 'Day ${event.flowDay} · dawn + 30 min';
    case KeptWordTimingSlot.checkMidday:
      return event.eventNumber == 5
          ? 'Day ${event.flowDay} · after conversation'
          : 'Day ${event.flowDay} · 11:00 local';
    case KeptWordTimingSlot.sealEvening:
      return 'Day ${event.flowDay} · sunset + 30 min';
  }
}

String _numberedLines(List<String> lines) {
  return lines
      .asMap()
      .entries
      .map((entry) => '${entry.key + 1}. ${entry.value}')
      .join('\n');
}

String _keptWordPurpose(KeptWordEvent event) {
  switch (event.eventNumber) {
    case 1:
      return 'Begin by naming the agreements that currently govern your closest sphere.';
    case 2:
      return 'Name one shared rhythm that quietly stopped holding the house.';
    case 3:
      return 'Seal the first decan by choosing the clearest break to bring into process.';
    case 4:
      return 'Prepare the conversation by carrying the message exactly, without additions.';
    case 5:
      return 'Confirm whether the conversation happened and record only the generic outcome locally.';
    case 6:
      return 'Close the naming by stating where the break now stands.';
    case 7:
      return 'Make the renewed agreement explicit enough to hold.';
    case 8:
      return 'Check whether the renewed rhythm is holding in practice.';
    case 9:
      return 'Close with the one line that is now true, without exposing private agreements.';
  }
  return 'What you speak within your house determines its order.';
}

DateTime _fromZonedDateTime(tz.TZDateTime zoned) {
  return DateTime(
    zoned.year,
    zoned.month,
    zoned.day,
    zoned.hour,
    zoned.minute,
    zoned.second,
    zoned.millisecond,
    zoned.microsecond,
  );
}
