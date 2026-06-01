import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dawn_house_rite_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'maat_flow_identity.dart';
import 'track_sky_flow.dart';

const String kTheOpenHandFlowKey = 'the-open-hand';
const String kTheOpenHandTitle = 'The Open Hand';
const String kTheOpenHandGlyph = '𓂧𓆄';
const String kTheOpenHandTagline =
    'The righteous individual is he by whom others are sustained.';
const int kOpenHandDefaultMiddayHour = 11;
const int kOpenHandDefaultMiddayMinute = 0;
const int kOpenHandEveningFallbackMinutes =
    kEveningThresholdDefaultFallbackMinutes + 20;

const String kOpenHandConfidenceLabel =
    'The bread-water-clothing-boat formula is historically attested across Kemetic biography and Spell 125. This nine-sitting household form is a careful modern reconstruction.';

const String kOpenHandOverview =
    'Nine sittings across thirty days: see specific need, give something real beyond your circle, and confirm that provision is flowing through you like the flood. '
    'The Open Hand is outward provision, not a donation platform, public virtue feed, or replacement for The Offering Table.';

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
        return 'Three acts for this decan';
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
        return 'Three specific needs, then: This decan, I will give ___ to ___.';
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
      'Choose one as the first act of this flow: This decan, I will give ___ to ___.',
    ],
    localPrompt: OpenHandLocalPromptKind.needInventory,
    sourceNote:
        'Drawn from Spell 125 and the virtue autobiography pattern: provision is recorded as specific action, not general intention.',
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
      'After the act, write one sentence about what was done and what happened.',
      'Return to the Day 1 list and note whether another need is ready to be addressed this decan.',
    ],
    localPrompt: OpenHandLocalPromptKind.firstActRecord,
    requiresOutwardAct: true,
    sourceNote:
        'Drawn from the Instruction of Ptahhotep, Maxim 22: righteousness is measured by whether others are sustained through you.',
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
      'Name one act of giving in this decan that surprised you.',
      'Name one need you saw but did not act on. It carries into Decan 2 without excuse or editing.',
    ],
    localPrompt: OpenHandLocalPromptKind.carriedNeed,
    sourceNote:
        'Drawn from The Eloquent Peasant, where satisfaction ending hunger and clothing ending nakedness are forms of restoring order.',
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
      'Write three named acts of outward provision for this decan: one for Day 11, one for Day 15, and one for Day 19.',
      'Make them proportionate to your actual resources: real enough to count, not theatrical enough to collapse.',
      'At least one act belongs to someone outside your immediate circle of obligation.',
    ],
    localPrompt: OpenHandLocalPromptKind.threeActs,
    sourceNote:
        'Drawn from Harkhuf and Hapidjefa, who recorded bread, clothing, transport, grain, and advocacy as evidence of Ma’at.',
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
      'Complete the provision act directed to someone outside your immediate circle before marking this event observed.',
      'Notice any resistance. Giving to a stranger is supported by the principle, not by relationship.',
      'Record what was given, to whom or what situation, and what you felt in giving it.',
      'If skipped, name a specific future date for the stranger act instead of dissolving the commitment.',
    ],
    localPrompt: OpenHandLocalPromptKind.strangerAct,
    requiresOutwardAct: true,
    strangerAct: true,
    sourceNote:
        'Drawn from The Eloquent Peasant, Third Appeal: provision should move like the flood, not stop at the nearest field.',
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
      'Name one thing the giving of this decan taught you about capacity, resistance, or need.',
    ],
    localPrompt: OpenHandLocalPromptKind.commitmentStatuses,
    sourceNote:
        'The scribe records what is: the gift, the modification, and the gap between commitment and completion.',
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
      'Ask whether giving feels like a practice now or still like isolated decisions.',
      'Name the threshold where provision tends to stop with you.',
      'Name one domain where provision could flow in the final decan that has not yet been addressed.',
    ],
    localPrompt: OpenHandLocalPromptKind.flowThreshold,
    sourceNote:
        'Hapy is a model of provision as movement. A flood that stops at one field is not generous; it is broken.',
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
      'Speak only the truth-check lines that apply: I saw need; I gave outside obligation; I gave to someone I do not know; provision is less blocked.',
      'Name one specific recurring practice of outward provision that will continue past the flow.',
      'Speak the final line: To do Ma’at is the breath of the nostrils. The flow continues.',
    ],
    localPrompt: OpenHandLocalPromptKind.closingPractice,
    sharePromptOnComplete: true,
    sourceNote:
        'The flow closes by making a record in the manner of the virtue autobiographies: what was given is real, and what is real endures.',
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
    'Private note: keep names, needs, and recipient details in your local journal unless you intentionally choose to share them.',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
    'Confidence\n$kOpenHandConfidenceLabel',
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
      return 'Begin by seeing specific local need before deciding what to give.';
    case 2:
      return 'Make the first provision act real and record what happened.';
    case 3:
      return 'Close the first seeing by naming what was seen, given, and carried forward.';
    case 4:
      return 'Open the second decan by naming three specific acts of provision.';
    case 5:
      return 'Move provision beyond the circle of obligation to the stranger, community, or unknown recipient.';
    case 6:
      return 'Seal the second decan by recording whether each promised act was given.';
    case 7:
      return 'Ask whether provision has begun to flow through you or still stops at familiar thresholds.';
    case 8:
      return 'Check what has changed because provision moved.';
    case 9:
      return 'Close the flow by naming what was given and what practice continues.';
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
