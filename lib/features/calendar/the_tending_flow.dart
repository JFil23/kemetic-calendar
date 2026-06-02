import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dawn_house_rite_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'maat_flow_identity.dart';
import 'track_sky_flow.dart';

const String kTheTendingFlowKey = 'the-tending';
const String kTheTendingTitle = 'The Tending';
const String kTheTendingGlyph = '𓇐';
const String kTheTendingTagline = 'Find who needs you. Do the labor.';
const String kTheTendingEnrollmentCopy =
    'Not perfect caregiving - look at who is in your care and complete one specific act per sitting. The looking is the first labor.';
const int kTheTendingDefaultMiddayHour = 11;
const int kTheTendingDefaultMiddayMinute = 0;
const int kTheTendingEveningFallbackMinutes =
    kEveningThresholdDefaultFallbackMinutes + 20;

const String kTheTendingOverview =
    'Three times per decan, see who is in your care, complete one specific tending act, and repair what was missed. '
    'The Tending is a low-burden thirty-day Ma\'at flow with nine sittings: Find and See, Gather and Attend, and Stand and Restore. '
    'It is not a parenting app, a guilt loop for burned-out caregivers, or warmth-without-labor sentiment; it is a practice of care made specific.';

enum TheTendingTimingSlot { openMorning, checkMidday, sealEvening }

extension TheTendingTimingSlotX on TheTendingTimingSlot {
  String get key {
    switch (this) {
      case TheTendingTimingSlot.openMorning:
        return 'open_morning';
      case TheTendingTimingSlot.checkMidday:
        return 'check_midday';
      case TheTendingTimingSlot.sealEvening:
        return 'seal_evening';
    }
  }

  String get label {
    switch (this) {
      case TheTendingTimingSlot.openMorning:
        return 'Dawn + 30 min';
      case TheTendingTimingSlot.checkMidday:
        return '11:00 local';
      case TheTendingTimingSlot.sealEvening:
        return 'Sunset + 30 min';
    }
  }
}

enum TheTendingLocalPromptKind {
  none,
  careInventory,
  heardOneSentence,
  sealSeeingStatuses,
  day11Commitment,
  day15Check,
  day21RepairCommit,
  day25RepairCheck,
  closePerPerson,
}

extension TheTendingLocalPromptKindX on TheTendingLocalPromptKind {
  String get key {
    switch (this) {
      case TheTendingLocalPromptKind.none:
        return 'none';
      case TheTendingLocalPromptKind.careInventory:
        return 'care_inventory';
      case TheTendingLocalPromptKind.heardOneSentence:
        return 'heard_one_sentence';
      case TheTendingLocalPromptKind.sealSeeingStatuses:
        return 'seal_seeing_statuses';
      case TheTendingLocalPromptKind.day11Commitment:
        return 'day11_commitment';
      case TheTendingLocalPromptKind.day15Check:
        return 'day15_check';
      case TheTendingLocalPromptKind.day21RepairCommit:
        return 'day21_repair_commit';
      case TheTendingLocalPromptKind.day25RepairCheck:
        return 'day25_repair_check';
      case TheTendingLocalPromptKind.closePerPerson:
        return 'close_per_person';
    }
  }

  String get label {
    switch (this) {
      case TheTendingLocalPromptKind.none:
        return '';
      case TheTendingLocalPromptKind.careInventory:
        return 'Care inventory';
      case TheTendingLocalPromptKind.heardOneSentence:
        return 'What you heard';
      case TheTendingLocalPromptKind.sealSeeingStatuses:
        return 'Seeing statuses';
      case TheTendingLocalPromptKind.day11Commitment:
        return 'Tending commitment';
      case TheTendingLocalPromptKind.day15Check:
        return 'Commitment check';
      case TheTendingLocalPromptKind.day21RepairCommit:
        return 'Repair commitment';
      case TheTendingLocalPromptKind.day25RepairCheck:
        return 'Repair check';
      case TheTendingLocalPromptKind.closePerPerson:
        return 'Closing tending record';
    }
  }

  String get helperText {
    switch (this) {
      case TheTendingLocalPromptKind.none:
        return '';
      case TheTendingLocalPromptKind.careInventory:
        return 'List who is in your care and one perceived need for each.';
      case TheTendingLocalPromptKind.heardOneSentence:
        return 'Write one sentence you heard or noticed without dismissing it.';
      case TheTendingLocalPromptKind.sealSeeingStatuses:
        return 'Mark each name tended, partial, or unseen. Keep the status local.';
      case TheTendingLocalPromptKind.day11Commitment:
        return 'Name one specific tending labor you will complete before Day 19.';
      case TheTendingLocalPromptKind.day15Check:
        return 'Record what was done, what is partial, and what still needs tending.';
      case TheTendingLocalPromptKind.day21RepairCommit:
        return 'Name one missed care obligation and one repair act completable before the cycle closes.';
      case TheTendingLocalPromptKind.day25RepairCheck:
        return 'Check whether the repair moved. If not, write the next smallest honest step.';
      case TheTendingLocalPromptKind.closePerPerson:
        return 'Close with one local line per person and one line naming who tended you. Do not share names.';
    }
  }
}

enum TheTendingLens { neutral, heru, aset }

extension TheTendingLensX on TheTendingLens {
  String get key {
    switch (this) {
      case TheTendingLens.neutral:
        return 'neutral';
      case TheTendingLens.heru:
        return 'heru';
      case TheTendingLens.aset:
        return 'aset';
    }
  }

  String get label {
    switch (this) {
      case TheTendingLens.neutral:
        return 'Neutral';
      case TheTendingLens.heru:
        return 'Heru';
      case TheTendingLens.aset:
        return 'Aset';
    }
  }

  String get detailLine {
    switch (this) {
      case TheTendingLens.neutral:
        return '';
      case TheTendingLens.heru:
        return 'Let Heru frame the labor as standing up for what has been entrusted to your care.';
      case TheTendingLens.aset:
        return 'Let Aset frame the labor as searching carefully, gathering what was scattered, and refusing to abandon the vulnerable.';
    }
  }
}

class TheTendingEvent {
  final int eventNumber;
  final int flowDay;
  final String decanSection;
  final String title;
  final TheTendingTimingSlot slot;
  final int durationMinutesMin;
  final int durationMinutesMax;
  final String spokenLine;
  final List<String> steps;
  final List<String> optionalSteps;
  final String? sourceNote;
  final bool sharePromptOnComplete;
  final TheTendingLocalPromptKind localPrompt;

  const TheTendingEvent({
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
  });
}

class TheTendingOccurrenceSchedule {
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

  const TheTendingOccurrenceSchedule({
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

const List<TheTendingEvent> kTheTendingEvents = <TheTendingEvent>[
  TheTendingEvent(
    eventNumber: 1,
    flowDay: 1,
    decanSection: 'Find and See',
    title: 'The First Seeing',
    slot: TheTendingTimingSlot.openMorning,
    durationMinutesMin: 8,
    durationMinutesMax: 10,
    spokenLine:
        'Before writing anything: I look for who is in my care. I do not let need become invisible.',
    steps: <String>[
      'Name who is in your care in this season: person, animal, household, plant, place, promise, or vulnerable responsibility.',
      'Write one perceived need beside each name. Do not solve the whole list.',
      'Choose one name that should not remain unseen this decan.',
    ],
    optionalSteps: <String>[
      'If the list feels too large, circle only the name with the nearest real-world need.',
    ],
    sourceNote:
        'In the Osirian pattern, Aset and Nebet-Het search first — not because they don\'t know where Ausar is, but because searching is what begins restoration. Seeing the care field clearly is the same act: what cannot be seen cannot be gathered.',
    localPrompt: TheTendingLocalPromptKind.careInventory,
  ),
  TheTendingEvent(
    eventNumber: 2,
    flowDay: 5,
    decanSection: 'Find and See',
    title: 'Listen Without Dismissing',
    slot: TheTendingTimingSlot.checkMidday,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine: 'I hear the need before I explain it away.',
    steps: <String>[
      'Name one need expressed by someone in your care during the last week.',
      'Write the exact words, gesture, silence, or behavior that carried the need.',
      'Write the sentence without correcting, defending, or making it about yourself. The need does not require your interpretation to exist.',
    ],
    optionalSteps: <String>[
      'If direct contact is not possible, observe one concrete condition that tells the truth.',
    ],
    localPrompt: TheTendingLocalPromptKind.heardOneSentence,
  ),
  TheTendingEvent(
    eventNumber: 3,
    flowDay: 9,
    decanSection: 'Find and See',
    title: 'Seal the Seeing',
    slot: TheTendingTimingSlot.sealEvening,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine: 'What I have seen, I will not pretend not to know.',
    steps: <String>[
      'Return to the care inventory.',
      'Mark each visible need as tended, partial, or unseen.',
      'Choose one unseen name to carry explicitly into the next decan.',
    ],
    optionalSteps: <String>[
      'Send one brief message if seeing alone would become avoidance.',
    ],
    sourceNote:
        'Aset did not begin by restoring Ausar — she began by finding him. What has been found and named is what the second decan can work with.',
    localPrompt: TheTendingLocalPromptKind.sealSeeingStatuses,
  ),
  TheTendingEvent(
    eventNumber: 4,
    flowDay: 11,
    decanSection: 'Gather and Attend',
    title: 'Begin the Labor',
    slot: TheTendingTimingSlot.openMorning,
    durationMinutesMin: 8,
    durationMinutesMax: 10,
    spokenLine:
        'I gather what care requires. Warmth is not labor until it acts.',
    steps: <String>[
      'Choose one care obligation from the first decan.',
      'Name the specific labor required: call, feed, clean, carry, pay, schedule, sit with, protect, repair, or ask.',
      'Commit to one act that can be completed before Day 19.',
    ],
    optionalSteps: <String>[
      'If you are burned out, choose the smallest honest act that does not deepen harm to you.',
    ],
    sourceNote:
        'In the Heru restoration pattern, scattered reality had to be physically gathered before standing was possible. Care that remains an intention is still scattered. This decan gathers it into specific acts.',
    localPrompt: TheTendingLocalPromptKind.day11Commitment,
  ),
  TheTendingEvent(
    eventNumber: 5,
    flowDay: 15,
    decanSection: 'Gather and Attend',
    title: 'One Act, Done',
    slot: TheTendingTimingSlot.checkMidday,
    durationMinutesMin: 3,
    durationMinutesMax: 3,
    spokenLine:
        'One act of care completed is better than a feeling left unnamed.',
    steps: <String>[
      'Do one small tending act now, or name the exact time it will happen today. A time named becomes a commitment. A commitment becomes the record.',
      'Record what changed after the act, even if it was very small.',
      'If the act could not be done, name the exact blocker without self-excuse.',
    ],
    optionalSteps: <String>[
      'Ask for help if the tending requires more hands than yours.',
    ],
    localPrompt: TheTendingLocalPromptKind.day15Check,
  ),
  TheTendingEvent(
    eventNumber: 6,
    flowDay: 19,
    decanSection: 'Gather and Attend',
    title: 'Seal the Tending',
    slot: TheTendingTimingSlot.sealEvening,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine: 'I seal this labor by what was done, not by what I meant.',
    steps: <String>[
      'Review the Day 11 commitment.',
      'Name what was tended, what was partial, and what was avoided.',
      'Carry only one unfinished care obligation into the restoration decan.',
    ],
    optionalSteps: <String>[
      'If you owe repair, write the first sentence plainly: I missed ___. I will ___.',
    ],
    sourceNote:
        'Care is not sealed by intention. It is sealed by the specific act completed. What was partial is named as partial. What was avoided is named as avoided. The record stays honest so the restoration decan can start clean.',
    localPrompt: TheTendingLocalPromptKind.day15Check,
  ),
  TheTendingEvent(
    eventNumber: 7,
    flowDay: 21,
    decanSection: 'Stand and Restore',
    title: 'Begin the Restoration',
    slot: TheTendingTimingSlot.openMorning,
    durationMinutesMin: 8,
    durationMinutesMax: 10,
    spokenLine:
        'I stand where care was missed. I repair what is mine to repair.',
    steps: <String>[
      'Name one care obligation missed or only partly tended.',
      'Name the harm or strain created without exaggerating it.',
      'Choose one repair act completable before Day 29.',
    ],
    optionalSteps: <String>[
      'If repair requires apology, make it brief and specific. Do not ask the person in your care to manage your guilt.',
    ],
    sourceNote:
        'Heru\'s standing was restoration, not domination — he stood up where the order had collapsed. The repair act goes toward the damage, not away from it.',
    localPrompt: TheTendingLocalPromptKind.day21RepairCommit,
  ),
  TheTendingEvent(
    eventNumber: 8,
    flowDay: 25,
    decanSection: 'Stand and Restore',
    title: 'The Check on Repair',
    slot: TheTendingTimingSlot.checkMidday,
    durationMinutesMin: 3,
    durationMinutesMax: 3,
    spokenLine:
        'Repair is not declared complete while the need remains untouched.',
    steps: <String>[
      'Check whether the repair act named on Day 21 has actually been attempted.',
      'Write what moved, what did not move, and what still belongs to you.',
      'If the repair is blocked by another person, write what remains yours and release what is not. You are responsible only for your portion of the restoration.',
    ],
    optionalSteps: <String>[
      'If the repair is blocked by another person, write what remains yours and release what is not.',
    ],
    localPrompt: TheTendingLocalPromptKind.day25RepairCheck,
  ),
  TheTendingEvent(
    eventNumber: 9,
    flowDay: 29,
    decanSection: 'Stand and Restore',
    title: 'The Tending Is Complete',
    slot: TheTendingTimingSlot.sealEvening,
    durationMinutesMin: 8,
    durationMinutesMax: 10,
    spokenLine:
        'Before writing any closing line: I have not turned away from those placed in my care. Speak it once. Then check whether it is true.',
    steps: <String>[
      'For each name you held locally, write one private closing line: tended, partial, unseen, or repaired.',
      'Name one thing the labor of this cycle restored.',
      'Name one tending practice you will carry into the next cycle without making a vow you cannot keep.',
    ],
    optionalSteps: <String>[
      'Name who tended you in this cycle. Care is not only what leaves your hands.',
      'If you share, share only the generic restoration line. Do not share names or care-list details.',
    ],
    sourceNote:
        'Aset\'s work was not finished in one period — it continued across the mythological record. What you close is this cycle\'s portion, not the whole account.',
    sharePromptOnComplete: true,
    localPrompt: TheTendingLocalPromptKind.closePerPerson,
  ),
];

bool _theTendingTimeZonesInitialized = false;

void _ensureTheTendingTimeZonesInitialized() {
  if (_theTendingTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _theTendingTimeZonesInitialized = true;
}

DateTime defaultTheTendingStartDate(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = theTendingNowInZone(timezone, now: now);
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final todayStart = tendingMorningScheduleForDate(
    today,
    timezone,
    durationMinutes: kTheTendingEvents.first.durationMinutesMax,
  ).startLocal;
  if (!todayStart.isBefore(nowLocal)) return today;
  return today.add(const Duration(days: 1));
}

DateTime theTendingNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureTheTendingTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromZonedDateTime(zoned);
}

TheTendingOccurrenceSchedule theTendingScheduleForDate(
  TheTendingEvent event,
  DateTime date,
  TrackSkyTimeZone timezone, {
  int middayHour = kTheTendingDefaultMiddayHour,
  int middayMinute = kTheTendingDefaultMiddayMinute,
}) {
  switch (event.slot) {
    case TheTendingTimingSlot.openMorning:
      return tendingMorningScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
    case TheTendingTimingSlot.checkMidday:
      return tendingMiddayScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
        hour: middayHour,
        minute: middayMinute,
      );
    case TheTendingTimingSlot.sealEvening:
      return tendingEveningScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
  }
}

TheTendingOccurrenceSchedule tendingMorningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = dawnHouseRiteScheduleForDate(date, timezone);
  final startUtc = base.startUtc.add(const Duration(minutes: 30));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return TheTendingOccurrenceSchedule(
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

TheTendingOccurrenceSchedule tendingMiddayScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
  int hour = kTheTendingDefaultMiddayHour,
  int minute = kTheTendingDefaultMiddayMinute,
}) {
  _ensureTheTendingTimeZonesInitialized();
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
  return TheTendingOccurrenceSchedule(
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

TheTendingOccurrenceSchedule tendingEveningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = eveningThresholdScheduleForDate(
    date,
    timezone,
    fallbackMinutesAfterMidnight: kTheTendingEveningFallbackMinutes,
  );
  final startUtc = base.startUtc.add(const Duration(minutes: 10));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return TheTendingOccurrenceSchedule(
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

String theTendingEventTitle(TheTendingEvent event) {
  return 'Tending ${event.eventNumber}: ${event.title}';
}

String theTendingActionId(TheTendingEvent event) {
  return 'the-tending-event-${event.eventNumber.toString().padLeft(2, '0')}';
}

TheTendingEvent? theTendingEventByNumber(int? eventNumber) {
  if (eventNumber == null) return null;
  for (final event in kTheTendingEvents) {
    if (event.eventNumber == eventNumber) return event;
  }
  return null;
}

TheTendingLens? theTendingLensFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final lens in TheTendingLens.values) {
    if (lens.key == normalized) return lens;
  }
  return null;
}

TheTendingLens theTendingLensFromNotes(
  String? notes, {
  TheTendingLens fallback = TheTendingLens.neutral,
}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('tending_lens=')) continue;
    return theTendingLensFromKey(trimmed.substring('tending_lens='.length)) ??
        fallback;
  }
  return fallback;
}

bool isTheTendingFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.theTending,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

TheTendingEvent? theTendingEventForEvent({
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  int? parseNumber(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  final payloadEvent = theTendingEventByNumber(
    parseNumber(behaviorPayload?['event_number']),
  );
  if (payloadEvent != null) return payloadEvent;

  final actionMatch = RegExp(
    r'the-tending-event-(\d{1,2})',
    caseSensitive: false,
  ).firstMatch(actionId?.trim() ?? '');
  final actionEvent = theTendingEventByNumber(
    parseNumber(actionMatch?.group(1)),
  );
  if (actionEvent != null) return actionEvent;

  final titleMatch = RegExp(
    r'^\s*Tending\s+(\d{1,2})\s*:',
    caseSensitive: false,
  ).firstMatch(title?.trim() ?? '');
  return theTendingEventByNumber(parseNumber(titleMatch?.group(1)));
}

String? canonicalTheTendingDetailTextForEvent({
  String? flowName,
  String? flowNotes,
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  if (!isTheTendingFlowReference(
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  )) {
    return null;
  }
  final event = theTendingEventForEvent(
    title: title,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
  if (event == null) return null;
  final lens =
      theTendingLensFromKey(behaviorPayload?['lens']?.toString()) ??
      theTendingLensFromNotes(flowNotes);
  return theTendingDetailText(event, lens: lens);
}

Map<String, dynamic> theTendingBehaviorPayload({
  required TheTendingEvent event,
  required TheTendingOccurrenceSchedule schedule,
  required TheTendingLens lens,
}) {
  return <String, dynamic>{
    'kind': 'maat_the_tending_event',
    'flow_key': kTheTendingFlowKey,
    'event_number': event.eventNumber,
    'flow_day': event.flowDay,
    'decan_section': event.decanSection,
    'slot': event.slot.key,
    'duration_minutes': event.durationMinutesMax,
    'duration_minutes_min': event.durationMinutesMin,
    'duration_minutes_max': event.durationMinutesMax,
    'burden': 'low',
    'props_profile': const <String, dynamic>{
      'required': <String>[],
      'optional': <String>[],
    },
    'completion_options': const <String>[
      'observed',
      'observed_partly',
      'skipped',
    ],
    'missed_event_rule': 'expire_quietly',
    'share_prompt_on_complete': event.sharePromptOnComplete,
    'local_prompt': event.localPrompt.key,
    'privacy': const <String, dynamic>{
      'care_notes_storage': 'device_only',
      'sync_care_names': false,
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

String theTendingDetailText(
  TheTendingEvent event, {
  required TheTendingLens lens,
}) {
  final optional = event.optionalSteps
      .map((step) => '- $step')
      .join('\n')
      .trim();
  final lensLine = lens.detailLine.trim();
  return <String>[
    'Purpose\n${_theTendingPurpose(event)}',
    'Words\n"${event.spokenLine}"',
    'Steps\n${_numberedLines(event.steps)}',
    if (optional.isNotEmpty) 'Optional\n$optional',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
  ].join('\n\n');
}

String theTendingTimingLabel(TheTendingEvent event) {
  switch (event.slot) {
    case TheTendingTimingSlot.openMorning:
      return 'Day ${event.flowDay} · dawn + 30 min';
    case TheTendingTimingSlot.checkMidday:
      return 'Day ${event.flowDay} · 11:00 local';
    case TheTendingTimingSlot.sealEvening:
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

String _theTendingPurpose(TheTendingEvent event) {
  switch (event.eventNumber) {
    case 1:
      return 'Aset searched before she gathered. She gathered before she restored. The search is the first labor — not the lesser one.';
    case 2:
      return 'Explaining away a need is not the same as addressing it. This sitting distinguishes between the two.';
    case 3:
      return 'The first decan closes with a status on each name: tended, partial, or unseen. Not resolution — status. The record is honest before the labor decan begins.';
    case 4:
      return 'Warmth without labor is a feeling, not a practice. This sitting turns care that has been named into the act it requires.';
    case 5:
      return 'The midpoint check is on whether the specific act was done — not on how you feel about the care.';
    case 6:
      return 'The seal closes with what was done — not what was intended, not what would have been done under better circumstances. That is what carries forward.';
    case 7:
      return 'Standing is not standing over. Heru stood where the care had been missed and acted from there — not from safety, not from distance.';
    case 8:
      return 'The check asks one thing: did the repair act move the situation? Not resolve it — move it.';
    case 9:
      return 'The cycle closes with one honest line per person and one practice that continues. Care practiced once is a gesture. Care that continues is a practice.';
  }
  return 'Find who needs you. Do the labor.';
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
