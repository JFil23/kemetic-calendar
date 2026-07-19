import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dawn_house_rite_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'maat_flow_identity.dart';
import 'track_sky_flow.dart';

const String kTheOpenHandFlowKey = 'the-open-hand';
const String kTheOpenHandTitle = 'The Open Hand';
const String kTheOpenHandGlyph = '𓂧';
const String kTheOpenHandTagline =
    'The righteous individual is he by whom others are sustained.';
const int kOpenHandDefaultMiddayHour = 11;
const int kOpenHandDefaultMiddayMinute = 0;
const int kOpenHandEveningFallbackMinutes =
    kEveningThresholdDefaultFallbackMinutes + 20;

const String kOpenHandConfidenceLabel =
    'Draws on the bread-water-clothing-boat formula across Kemetic biography and Spell 125.';

const String kOpenHandOverview =
    'The Open Hand is a thirty-day outward provision flow with nine sittings. It asks the user to see a real need, give something usable beyond obligation, and confirm what moved without turning generosity into performance.';

enum OpenHandTimingSlot { openMorning, checkMidday, sealEvening }

extension OpenHandTimingSlotX on OpenHandTimingSlot {
  String get key {
    switch (this) {
      case OpenHandTimingSlot.openMorning:
        return 'open_morning';
      case OpenHandTimingSlot.checkMidday:
        return 'check_midday';
      case OpenHandTimingSlot.sealEvening:
        return 'seal_evening';
    }
  }

  String get label {
    switch (this) {
      case OpenHandTimingSlot.openMorning:
        return 'Dawn + 30 min';
      case OpenHandTimingSlot.checkMidday:
        return '11:00 local';
      case OpenHandTimingSlot.sealEvening:
        return 'Sunset + 30 min';
    }
  }
}

enum OpenHandLens { neutral, hapy }

extension OpenHandLensX on OpenHandLens {
  String get key {
    switch (this) {
      case OpenHandLens.neutral:
        return 'neutral';
      case OpenHandLens.hapy:
        return 'hapy';
    }
  }

  String get label {
    switch (this) {
      case OpenHandLens.neutral:
        return 'Neutral';
      case OpenHandLens.hapy:
        return 'Hapy';
    }
  }

  String get detailLine {
    switch (this) {
      case OpenHandLens.neutral:
        return '';
      case OpenHandLens.hapy:
        return 'Let Hapy be the model: provision arrives as floodwater and does not stop at one field.';
    }
  }
}

enum ProvisionKind { bread, water, clothing, boat, time }

extension ProvisionKindX on ProvisionKind {
  String get key {
    switch (this) {
      case ProvisionKind.bread:
        return 'bread';
      case ProvisionKind.water:
        return 'water';
      case ProvisionKind.clothing:
        return 'clothing';
      case ProvisionKind.boat:
        return 'boat';
      case ProvisionKind.time:
        return 'time';
    }
  }

  String get label {
    switch (this) {
      case ProvisionKind.bread:
        return 'Bread';
      case ProvisionKind.water:
        return 'Water';
      case ProvisionKind.clothing:
        return 'Clothing';
      case ProvisionKind.boat:
        return 'Boat';
      case ProvisionKind.time:
        return 'Time';
    }
  }
}

enum OpenHandLocalPromptKind {
  needInventory,
  firstActRecord,
  carriedNeed,
  threeActs,
  strangerAct,
  commitmentStatuses,
  flowThreshold,
  changedObservation,
  closingPractice,
}

extension OpenHandLocalPromptKindX on OpenHandLocalPromptKind {
  String get key {
    switch (this) {
      case OpenHandLocalPromptKind.needInventory:
        return 'need_inventory';
      case OpenHandLocalPromptKind.firstActRecord:
        return 'first_act_record';
      case OpenHandLocalPromptKind.carriedNeed:
        return 'carried_need';
      case OpenHandLocalPromptKind.threeActs:
        return 'three_acts';
      case OpenHandLocalPromptKind.strangerAct:
        return 'stranger_act';
      case OpenHandLocalPromptKind.commitmentStatuses:
        return 'commitment_statuses';
      case OpenHandLocalPromptKind.flowThreshold:
        return 'flow_threshold';
      case OpenHandLocalPromptKind.changedObservation:
        return 'changed_observation';
      case OpenHandLocalPromptKind.closingPractice:
        return 'closing_practice';
    }
  }

  String get label {
    switch (this) {
      case OpenHandLocalPromptKind.needInventory:
        return 'Needs and first commitment';
      case OpenHandLocalPromptKind.firstActRecord:
        return 'First act record';
      case OpenHandLocalPromptKind.carriedNeed:
        return 'Need carried forward';
      case OpenHandLocalPromptKind.threeActs:
        return 'Three acts for this ten-day section';
      case OpenHandLocalPromptKind.strangerAct:
        return 'Stranger act record';
      case OpenHandLocalPromptKind.commitmentStatuses:
        return 'Commitment statuses';
      case OpenHandLocalPromptKind.flowThreshold:
        return 'Where provision stops';
      case OpenHandLocalPromptKind.changedObservation:
        return 'What has changed';
      case OpenHandLocalPromptKind.closingPractice:
        return 'Continuing practice';
    }
  }

  String get placeholder {
    switch (this) {
      case OpenHandLocalPromptKind.needInventory:
        return 'Three specific needs, then: This ten-day section, I will give ___ to ___.';
      case OpenHandLocalPromptKind.firstActRecord:
        return 'I gave ___ to ___. It was received / not received / changed in this way...';
      case OpenHandLocalPromptKind.carriedNeed:
        return 'One need I saw but did not act on is...';
      case OpenHandLocalPromptKind.threeActs:
        return 'Day 11: ...\nDay 15: ...\nDay 19: ...';
      case OpenHandLocalPromptKind.strangerAct:
        return 'What was given, to whom or what situation, and what resistance I noticed...';
      case OpenHandLocalPromptKind.commitmentStatuses:
        return 'Given as committed / modified / not given, with the honest reason.';
      case OpenHandLocalPromptKind.flowThreshold:
        return 'Provision tends to stop with me at...';
      case OpenHandLocalPromptKind.changedObservation:
        return 'One honest sentence about what has changed in 25 days...';
      case OpenHandLocalPromptKind.closingPractice:
        return 'One recurring practice of outward provision I will continue...';
    }
  }
}

class OpenHandEvent {
  final int eventNumber;
  final int flowDay;
  final String decanSection;
  final String title;
  final OpenHandTimingSlot slot;
  final int durationMinutesMin;
  final int durationMinutesMax;
  final String spokenLine;
  final List<String> steps;
  final String? sourceNote;
  final bool requiresOutwardAct;
  final bool strangerAct;
  final bool sharePromptOnComplete;
  final OpenHandLocalPromptKind localPrompt;

  const OpenHandEvent({
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
    this.sourceNote,
    this.requiresOutwardAct = false,
    this.strangerAct = false,
    this.sharePromptOnComplete = false,
  });
}

class OpenHandOccurrenceSchedule {
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

  const OpenHandOccurrenceSchedule({
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

const List<OpenHandEvent> kOpenHandEvents = <OpenHandEvent>[
  OpenHandEvent(
    eventNumber: 1,
    flowDay: 1,
    decanSection: 'See the Need',
    title: 'Look Directly',
    slot: OpenHandTimingSlot.openMorning,
    durationMinutesMin: 5,
    durationMinutesMax: 8,
    spokenLine:
        'I have given bread to the hungry, water to the thirsty, clothing to the naked, and a boat to the boatless.',
    steps: <String>[
      'Write three names or descriptions of people or situations in your immediate environment where a specific need is present.',
      'For each, name the specific need: food, transport, shelter, attention, connection, skill, or another concrete provision.',
      'Choose one as the first act of this flow.',
      'Write: This ten-day section, I will give ___ to ___.',
    ],
    localPrompt: OpenHandLocalPromptKind.needInventory,
    sourceNote:
        'Spell 125 and the virtue autobiographies named specific categories of provision because specificity was the evidence. "I was generous" is not a record. "I gave bread to the hungry" is. This sitting produces the record that the second decan will enact.',
  ),
  OpenHandEvent(
    eventNumber: 2,
    flowDay: 5,
    decanSection: 'See the Need',
    title: 'The First Act',
    slot: OpenHandTimingSlot.checkMidday,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine: 'The righteous individual is he by whom others are sustained.',
    steps: <String>[
      'Complete the act of provision identified on Day 1 before marking this event observed.',
      'Record what was given and what changed for the other person, even if the change was small.',
      'Name whether any further provision is genuinely yours to continue.',
    ],
    localPrompt: OpenHandLocalPromptKind.firstActRecord,
    requiresOutwardAct: true,
    sourceNote:
        'Ptahhotep\'s Maxim 22 defines righteousness by whether others are actually sustained through the person. The record here is the act completed — what changed in someone else\'s situation because of what you did.',
  ),
  OpenHandEvent(
    eventNumber: 3,
    flowDay: 9,
    decanSection: 'See the Need',
    title: 'Close the First Seeing',
    slot: OpenHandTimingSlot.sealEvening,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'He who fosters goodness is a destroyer of evil — as when satisfaction comes and ends hunger, as when clothing ends nakedness, as when water quenches thirst.',
    steps: <String>[
      'Name one local need you had been moving past without seeing.',
      'Name one act of giving in this ten-day section that surprised you.',
      'Name one need you saw but did not act on.',
      'Carry it into the second ten-day section without excuse or editing.',
    ],
    localPrompt: OpenHandLocalPromptKind.carriedNeed,
    sourceNote:
        'The Eloquent Peasant\'s Third Appeal compares provision to the natural order restoring itself: satisfaction ending hunger, clothing ending nakedness — specific and physical. The closing names where the restoration was real and where it was only witnessed.',
  ),
  OpenHandEvent(
    eventNumber: 4,
    flowDay: 11,
    decanSection: 'Give Specifically',
    title: "Name What You're Giving",
    slot: OpenHandTimingSlot.openMorning,
    durationMinutesMin: 5,
    durationMinutesMax: 8,
    spokenLine:
        'I gave bread to the hungry and I clothed the naked. I brought to land the one who had no rowboat. I measured out grain from my own estate for the hungry I found.',
    steps: <String>[
      'Write three named acts of outward provision for this ten-day section.',
      'For each act, write what will be given and who or what receives it.',
      'Write when each act will happen before Day 19.',
      'Mark which act is easiest, which is most needed, and which one resists you.',
    ],
    localPrompt: OpenHandLocalPromptKind.threeActs,
    sourceNote:
        'Harkhuf and Hapidjefa named specific recipients and specific provisions. The specificity was the evidence. This sitting produces that specificity before the acts happen so they can be measured against what was promised.',
  ),
  OpenHandEvent(
    eventNumber: 5,
    flowDay: 15,
    decanSection: 'Give Specifically',
    title: 'Give to the Stranger',
    slot: OpenHandTimingSlot.checkMidday,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'The provisions of all mankind flow from the flood. You are Hapy who makes verdant the fields and revives the desert. To do Ma’at is the breath of the nostrils.',
    steps: <String>[
      'Choose one act from the Day 11 list that benefits someone outside your circle of obligation.',
      'Name any resistance to giving without a relational claim.',
      'Complete the act before marking this event observed.',
      'If it cannot be completed today, write the exact date it will be completed instead of claiming it as done.',
    ],
    localPrompt: OpenHandLocalPromptKind.strangerAct,
    requiresOutwardAct: true,
    strangerAct: true,
    sourceNote:
        'The Eloquent Peasant invokes Hapy specifically because the flood provision moved without stopping at relationship — it reached whoever was in the field. The stranger act follows the flood, not the family.',
  ),
  OpenHandEvent(
    eventNumber: 6,
    flowDay: 19,
    decanSection: 'Give Specifically',
    title: 'Seal the Giving',
    slot: OpenHandTimingSlot.sealEvening,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'I have given bread to the hungry, water to the thirsty, clothing to the naked, and a boat to the boatless.',
    steps: <String>[
      'Return to the three commitments from Day 11.',
      'For each, record: given as committed, modified, or not given, with the honest reason.',
      'Name one thing the giving of this ten-day section taught you about capacity, resistance, or need.',
    ],
    localPrompt: OpenHandLocalPromptKind.commitmentStatuses,
    sourceNote:
        'The Kemetic scribe recorded what was — not what should have been. The seal works the same way. What was modified is noted as modified. What was not given is noted with the honest reason. The record stays accurate.',
  ),
  OpenHandEvent(
    eventNumber: 7,
    flowDay: 21,
    decanSection: 'Confirm the Flow',
    title: 'Is Provision Flowing?',
    slot: OpenHandTimingSlot.openMorning,
    durationMinutesMin: 5,
    durationMinutesMax: 8,
    spokenLine:
        'You are Hapy who makes verdant the fields and revives the desert. The provisions of all mankind flow from you as from the flood. To do Ma’at is the breath of the nostrils.',
    steps: <String>[
      'Map one kind of provision that entered your life this month: money, food, attention, skill, help, access, or time.',
      'Name the threshold where provision tends to stop with you as a material observation, not self-criticism.',
      'Choose one specific act that moves provision beyond you in the final ten-day section.',
    ],
    localPrompt: OpenHandLocalPromptKind.flowThreshold,
    sourceNote:
        'The Hymns to Hapy praise the flood\'s movement as its defining virtue. Provision that reaches is provision doing its work. Provision that accumulates has lost its Hapy quality. This sitting asks where the current is pooling.',
  ),
  OpenHandEvent(
    eventNumber: 8,
    flowDay: 25,
    decanSection: 'Confirm the Flow',
    title: 'What Has Changed',
    slot: OpenHandTimingSlot.checkMidday,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine: 'The righteous individual is he by whom others are sustained.',
    steps: <String>[
      'Name one person or situation that received provision through this flow and what changed as a result.',
      'Name one person you know who practices outward provision consistently and what you notice in them.',
      'Estimate honestly what would change if one named act of outward provision continued every five days for a year.',
    ],
    localPrompt: OpenHandLocalPromptKind.changedObservation,
    sourceNote:
        'The midpoint asks for record, not aspiration: what has changed in you and around you because provision moved?',
  ),
  OpenHandEvent(
    eventNumber: 9,
    flowDay: 29,
    decanSection: 'Confirm the Flow',
    title: 'The Flow Confirmed',
    slot: OpenHandTimingSlot.sealEvening,
    durationMinutesMin: 5,
    durationMinutesMax: 8,
    spokenLine:
        'I have given bread to the hungry, water to the thirsty, clothing to the naked, and a boat to the boatless. I am the righteous individual by whom others are sustained.',
    steps: <String>[
      'Name three acts from the flow: the one that cost the most, the one that surprised you, and the one you will remember.',
      'Speak only the truth-check lines that are true.',
      'Say, if true: I saw need.',
      'Say, if true: I gave outside obligation.',
      'Say, if true: I gave to someone I do not know.',
      'Say, if true: Provision is less blocked.',
      'Name one specific recurring practice of outward provision that will continue past the flow.',
      'Say the final line: To do Ma’at is the breath of the nostrils. The flow continues.',
    ],
    localPrompt: OpenHandLocalPromptKind.closingPractice,
    sharePromptOnComplete: true,
    sourceNote:
        'The virtue autobiographies accumulated through a lifetime. This closing names what continues: the one act of outward provision that is now regular enough to be part of the record rather than an exception to it.',
  ),
];

bool _openHandTimeZonesInitialized = false;

void _ensureOpenHandTimeZonesInitialized() {
  if (_openHandTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _openHandTimeZonesInitialized = true;
}

DateTime openHandEventDate(DateTime startDate, OpenHandEvent event) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  return DateTime(start.year, start.month, start.day + event.flowDay - 1);
}

DateTime openHandNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureOpenHandTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromZonedDateTime(zoned);
}

OpenHandOccurrenceSchedule openHandScheduleForEvent(
  OpenHandEvent event,
  DateTime flowStart,
  TrackSkyTimeZone timezone, {
  int middayHour = kOpenHandDefaultMiddayHour,
  int middayMinute = kOpenHandDefaultMiddayMinute,
}) {
  final date = openHandEventDate(flowStart, event);
  switch (event.slot) {
    case OpenHandTimingSlot.openMorning:
      return openHandMorningScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
    case OpenHandTimingSlot.checkMidday:
      return openHandMiddayScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
        hour: middayHour,
        minute: middayMinute,
      );
    case OpenHandTimingSlot.sealEvening:
      return openHandEveningScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
  }
}

OpenHandOccurrenceSchedule openHandMorningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = dawnHouseRiteScheduleForDate(date, timezone);
  final startUtc = base.startUtc.add(const Duration(minutes: 30));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return OpenHandOccurrenceSchedule(
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

OpenHandOccurrenceSchedule openHandMiddayScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
  int hour = kOpenHandDefaultMiddayHour,
  int minute = kOpenHandDefaultMiddayMinute,
}) {
  _ensureOpenHandTimeZonesInitialized();
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
  return OpenHandOccurrenceSchedule(
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

OpenHandOccurrenceSchedule openHandEveningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = eveningThresholdScheduleForDate(
    date,
    timezone,
    fallbackMinutesAfterMidnight: kOpenHandEveningFallbackMinutes,
  );
  final startUtc = base.startUtc.add(const Duration(minutes: 10));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return OpenHandOccurrenceSchedule(
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

String openHandEventTitle(OpenHandEvent event) {
  return 'Open Hand ${event.eventNumber}: ${event.title}';
}

String openHandActionId(OpenHandEvent event) {
  return 'the-open-hand-event-${event.eventNumber.toString().padLeft(2, '0')}';
}

String openHandClientEventId({
  required int flowId,
  required OpenHandEvent event,
}) {
  return 'open-hand:$flowId:event-${event.eventNumber}';
}

OpenHandEvent? openHandEventByNumber(int? eventNumber) {
  if (eventNumber == null) return null;
  for (final event in kOpenHandEvents) {
    if (event.eventNumber == eventNumber) return event;
  }
  return null;
}

OpenHandLens? openHandLensFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final lens in OpenHandLens.values) {
    if (lens.key == normalized) return lens;
  }
  return null;
}

OpenHandLens openHandLensFromNotes(
  String? notes, {
  OpenHandLens fallback = OpenHandLens.neutral,
}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('oh_lens=')) continue;
    return openHandLensFromKey(trimmed.substring('oh_lens='.length)) ??
        fallback;
  }
  return fallback;
}

bool isOpenHandFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.theOpenHand,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

OpenHandEvent? openHandEventForEvent({
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  int? parseNumber(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  final payloadEvent = openHandEventByNumber(
    parseNumber(behaviorPayload?['event_number']),
  );
  if (payloadEvent != null) return payloadEvent;

  final actionMatch = RegExp(
    r'the-open-hand-event-(\d{1,2})',
    caseSensitive: false,
  ).firstMatch(actionId?.trim() ?? '');
  final actionEvent = openHandEventByNumber(parseNumber(actionMatch?.group(1)));
  if (actionEvent != null) return actionEvent;

  final titleMatch = RegExp(
    r'^\s*Open Hand\s+(\d{1,2})\s*:',
    caseSensitive: false,
  ).firstMatch(title?.trim() ?? '');
  return openHandEventByNumber(parseNumber(titleMatch?.group(1)));
}

String? canonicalOpenHandDetailTextForEvent({
  String? flowName,
  String? flowNotes,
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  if (!isOpenHandFlowReference(
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  )) {
    return null;
  }
  final event = openHandEventForEvent(
    title: title,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
  if (event == null) return null;
  final lens =
      openHandLensFromKey(behaviorPayload?['lens']?.toString()) ??
      openHandLensFromNotes(flowNotes);
  return openHandDetailText(event, lens: lens);
}

Map<String, dynamic> openHandBehaviorPayload({
  required OpenHandEvent event,
  required OpenHandOccurrenceSchedule schedule,
  required OpenHandLens lens,
}) {
  return <String, dynamic>{
    'kind': 'maat_open_hand_event',
    'flow_key': kTheOpenHandFlowKey,
    'event_number': event.eventNumber,
    'flow_day': event.flowDay,
    'decan_section': _snake(event.decanSection),
    'timing_slot': event.slot.key,
    'requires_outward_act': event.requiresOutwardAct,
    'stranger_act': event.strangerAct,
    'missed_event_rule': 'expire_quietly',
    'completion_options': const <String>[
      'observed',
      'observed_partly',
      'skipped',
    ],
    'share_prompt_on_complete': event.sharePromptOnComplete,
    'duration_minutes': event.durationMinutesMax,
    'duration_minutes_min': event.durationMinutesMin,
    'duration_minutes_max': event.durationMinutesMax,
    'burden': 'low',
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

String openHandDetailText(OpenHandEvent event, {required OpenHandLens lens}) {
  final lensLine = lens.detailLine.trim();
  return <String>[
    'Purpose\n${_openHandPurpose(event)}',
    'Words\n"${event.spokenLine}"',
    'Steps\n${_numberedLines(event.steps)}',
    if (event.requiresOutwardAct)
      'Outward act\nComplete the provision act before marking this event observed.',
    if (event.strangerAct)
      'If skipped\nName a specific future date for the stranger act and keep the record honest.',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
  ].join('\n\n');
}

String openHandTimingLabel(OpenHandEvent event) {
  switch (event.slot) {
    case OpenHandTimingSlot.openMorning:
      return 'Day ${event.flowDay} · dawn + 30 min';
    case OpenHandTimingSlot.checkMidday:
      return 'Day ${event.flowDay} · 11:00 local';
    case OpenHandTimingSlot.sealEvening:
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

String _openHandPurpose(OpenHandEvent event) {
  switch (event.eventNumber) {
    case 1:
      return 'The Kemetic virtue autobiography recorded specific acts. Bread given to a specific hungry person. Water given to a specific thirsty one. This sitting names the specific need before deciding what to give.';
    case 2:
      return 'The act must be completed before this event is logged. Ptahhotep\'s standard was whether others were actually sustained through you — not whether you intended to sustain them.';
    case 3:
      return 'The first ten-day section closes with what was seen and given — and with one need that was seen but not acted on. That unacted-on need carries forward explicitly, not as guilt but as the next commitment.';
    case 4:
      return 'Three acts, named before they happen. Not aspirations — commitments. The virtue autobiographies recorded what was done; this sitting names what will be done so the record can close honestly.';
    case 5:
      return 'The flood did not stop at the nearest field. This act belongs to someone outside the circle of obligation — someone with no claim on you. Resistance marks where obligation has been mistaken for the edge of provision.';
    case 6:
      return 'The seal closes with what was actually done: given as committed, modified, or not given. The scribe\'s record does not editorialize.';
    case 7:
      return 'Hapy was celebrated because the flood moved — not because it collected. A flood that stops at one field is not generous; it is stuck.';
    case 8:
      return 'The midpoint keeps attention on what changed because provision moved.';
    case 9:
      return 'The flow closes with the record of what was actually done, and the one practice that continues. The continuing practice is more important than the thirty-day record.';
  }
  return 'Let provision move outward.';
}

String _snake(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
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
