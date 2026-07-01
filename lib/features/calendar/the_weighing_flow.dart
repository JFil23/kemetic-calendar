import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dawn_house_rite_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'maat_flow_identity.dart';
import 'track_sky_flow.dart';

const String kTheWeighingFlowKey = 'the-weighing';
const String kTheWeighingTitle = 'The Weighing';
const String kTheWeighingGlyph = '𓍝';
const String kTheWeighingTagline = 'Sit with what is true.';
const int kTheWeighingDefaultMiddayHour = 11;
const int kTheWeighingDefaultMiddayMinute = 0;
const int kTheWeighingEveningFallbackMinutes =
    kEveningThresholdDefaultFallbackMinutes + 20;

const String kTheWeighingOverview =
    'The Weighing is a thirty-day Ma’at reckoning flow with nine sittings across material records, spoken records, and conduct. It asks the user to place one real thing on the scale, name one gap, and choose one correction without turning the practice into shame, confession, or self-punishment.';

enum TheWeighingTimingSlot { openMorning, checkMidday, sealEvening }

extension TheWeighingTimingSlotX on TheWeighingTimingSlot {
  String get key {
    switch (this) {
      case TheWeighingTimingSlot.openMorning:
        return 'open_morning';
      case TheWeighingTimingSlot.checkMidday:
        return 'check_midday';
      case TheWeighingTimingSlot.sealEvening:
        return 'seal_evening';
    }
  }

  String get label {
    switch (this) {
      case TheWeighingTimingSlot.openMorning:
        return '30 minutes after dawn';
      case TheWeighingTimingSlot.checkMidday:
        return 'around 11 AM where you are';
      case TheWeighingTimingSlot.sealEvening:
        return '30 minutes after sunset';
    }
  }
}

enum TheWeighingLens { neutral, djehuty }

extension TheWeighingLensX on TheWeighingLens {
  String get key {
    switch (this) {
      case TheWeighingLens.neutral:
        return 'neutral';
      case TheWeighingLens.djehuty:
        return 'djehuty';
    }
  }

  String get label {
    switch (this) {
      case TheWeighingLens.neutral:
        return 'Neutral';
      case TheWeighingLens.djehuty:
        return 'Djehuty';
    }
  }

  String get detailLine {
    switch (this) {
      case TheWeighingLens.neutral:
        return '';
      case TheWeighingLens.djehuty:
        return 'Let Djehuty stand as keeper of the record: not judge, not accuser, only witness to what actually occurred.';
    }
  }
}

class TheWeighingEvent {
  final int eventNumber;
  final int flowDay;
  final String decanSection;
  final String title;
  final TheWeighingTimingSlot slot;
  final int durationMinutesMin;
  final int durationMinutesMax;
  final String spokenLine;
  final List<String> steps;
  final String? sourceNote;
  final List<String> optionalSteps;
  final bool sharePromptOnComplete;

  const TheWeighingEvent({
    required this.eventNumber,
    required this.flowDay,
    required this.decanSection,
    required this.title,
    required this.slot,
    required this.durationMinutesMin,
    required this.durationMinutesMax,
    required this.spokenLine,
    required this.steps,
    this.sourceNote,
    this.optionalSteps = const <String>[],
    this.sharePromptOnComplete = false,
  });
}

class TheWeighingOccurrenceSchedule {
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

  const TheWeighingOccurrenceSchedule({
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

const List<TheWeighingEvent> kTheWeighingEvents = <TheWeighingEvent>[
  TheWeighingEvent(
    eventNumber: 1,
    flowDay: 1,
    decanSection: 'Material Ledger',
    title: 'Open the Material Ledger',
    slot: TheWeighingTimingSlot.openMorning,
    durationMinutesMin: 5,
    durationMinutesMax: 8,
    spokenLine: 'I open my record without fear. What is here is what is true.',
    steps: <String>[
      'Place a cup of water on your surface before you begin.',
      'Keep the water there while you write.',
      'Speak the line before opening any record.',
      'Write one number you have not looked at directly in the last ten days: a balance, debt, supply, or physical record.',
      'Name one thing you received in the last ten days by saying plainly: I received ___.',
    ],
    sourceNote:
        'The Kemite placed water first because the record must be witnessed before it can be weighed — not examined, not solved, but witnessed. What sustains you is named before anything else is counted.',
  ),
  TheWeighingEvent(
    eventNumber: 2,
    flowDay: 5,
    decanSection: 'Material Ledger',
    title: 'Check the Material Scale',
    slot: TheWeighingTimingSlot.checkMidday,
    durationMinutesMin: 3,
    durationMinutesMax: 3,
    spokenLine:
        'The measure is the eye of Re. I do not adjust it to favor myself.',
    steps: <String>[
      'Name one place in the last five days where the actual count was softened.',
      'Choose one small restorative act before Day 10 closes if the imbalance is correctable.',
    ],
    sourceNote:
        'Amenemope\'s Chapter 17 is specific: the grain measure belongs to Re, and tampering with it is theft from the god, not just from the transaction. The midpoint check is the moment the scale speaks again, without interference.',
  ),
  TheWeighingEvent(
    eventNumber: 3,
    flowDay: 9,
    decanSection: 'Material Ledger',
    title: 'Seal the Material Record',
    slot: TheWeighingTimingSlot.sealEvening,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'I seal this period with what is true. I have not added to the weight of the balance. I have not subtracted from what is owed.',
    steps: <String>[
      'Complete one financial, nutritional, physical, or domestic record that has been left open.',
      'Write one closing line naming the actual state of this thing.',
      'Name one resource you will handle with more accuracy in the next ten-day section.',
    ],
    optionalSteps: <String>['Extinguish a light when you complete the event.'],
    sourceNote:
        'The Declaration of Innocence names false balance and tampered scales in the same breath as murder and theft. The Kemite treated the distorted record as harm to the world, not as an inconvenience to the individual.',
  ),
  TheWeighingEvent(
    eventNumber: 4,
    flowDay: 11,
    decanSection: 'Spoken Record',
    title: 'Open the Spoken Record',
    slot: TheWeighingTimingSlot.openMorning,
    durationMinutesMin: 5,
    durationMinutesMax: 8,
    spokenLine:
        'My tongue is the plummet. My heart is the weight. I do not utter falsehood, for I am a balance.',
    steps: <String>[
      'Place water on your surface before sitting.',
      'Speak the line before writing anything.',
      'Name one promise or agreement that remains open from the last ten days.',
      'State what was said.',
      'State what has been done.',
      'State what remains undone.',
      'Name one account you softened, exaggerated, or framed to favor yourself.',
    ],
    sourceNote:
        'The Eloquent Peasant calls the honest person a balance whose tongue, heart, and lips carry the measure. A balance adjusted for convenience is no longer a balance — it is a prop. This sitting asks whether the spoken record has been a real balance.',
  ),
  TheWeighingEvent(
    eventNumber: 5,
    flowDay: 15,
    decanSection: 'Spoken Record',
    title: 'Check the Spoken Scale',
    slot: TheWeighingTimingSlot.checkMidday,
    durationMinutesMin: 3,
    durationMinutesMax: 3,
    spokenLine:
        'Do not lead a man astray with reed pen on papyrus. It is the abomination of God.',
    steps: <String>[
      'Name one person whose understanding of an agreement with you may differ from yours.',
      'Write one sentence about the difference.',
      'Only if the gap can close with one clear message, send it before this ten-day section ends.',
    ],
    sourceNote:
        'Amenemope treats written false witness as a grave disorder — not because writing is sacred, but because what is written persists and shapes what follows. The spoken and written record do the same damage when they drift from what was actually agreed.',
  ),
  TheWeighingEvent(
    eventNumber: 6,
    flowDay: 19,
    decanSection: 'Spoken Record',
    title: 'Seal the Spoken Record',
    slot: TheWeighingTimingSlot.sealEvening,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'I have not slandered a servant to his superior. I have not caused weeping. I seal my spoken record with what I know to be true.',
    steps: <String>[
      'Name one spoken obligation from the second ten days that was fulfilled.',
      'Say it fully: I said I would ___, and I did ___.',
      'Name one spoken obligation that remains open.',
      'State that this obligation is being carried into the final ten days.',
    ],
    optionalSteps: <String>[
      'Write the one thing you are carrying forward on paper, not a screen.',
    ],
    sourceNote:
        'Spell 125 names slander and causing unnecessary pain alongside larger violations because Kemetic moral accounting treated them as the same category: disorder introduced into another person\'s life. The seal closes honestly about what the spoken record actually produced.',
  ),
  TheWeighingEvent(
    eventNumber: 7,
    flowDay: 21,
    decanSection: 'Record You Leave',
    title: 'Open the Record You Leave',
    slot: TheWeighingTimingSlot.openMorning,
    durationMinutesMin: 5,
    durationMinutesMax: 8,
    spokenLine:
        'I have come before you, my lord, bringing Truth, having repelled for you falsehood.',
    steps: <String>[
      'Stand before reading the four lines.',
      'Speak the line before reading the four lines.',
      'Read slowly: I have not caused avoidable hunger in those who depend on me.',
      'Read slowly: I have not diverted what should have flowed.',
      'Read slowly: I have not made my record better than my conduct.',
      'Read slowly: I have not taken more than is due.',
      'Write one corrective act you can complete before this final ten-day section closes if any line required a pause.',
    ],
    sourceNote:
        'The Declaration of Innocence was spoken before the 42 Assessors as a formal account of conduct, not a confession. Each line was weighed on its own. A pause at any line is information, not judgment — it shows where the record needs attention before it is sealed.',
  ),
  TheWeighingEvent(
    eventNumber: 8,
    flowDay: 25,
    decanSection: 'Record You Leave',
    title: 'Check the Living Record',
    slot: TheWeighingTimingSlot.checkMidday,
    durationMinutesMin: 3,
    durationMinutesMax: 3,
    spokenLine:
        'Do not go off course, for you are impartiality. If the balance wavers, then you will waver.',
    steps: <String>[
      'Ask whether someone with less power in a relationship would give a significantly different account of the last three weeks.',
      'Sit with that possibility for one minute without arguing against it.',
      'Write one sentence about what you think they would say.',
    ],
    sourceNote:
        'The Eloquent Peasant says impartiality is a condition of truthful speech — the judge who favors one side cannot call themselves a balance. This midpoint check asks whether the living record has applied the same measure to those with less and those with more.',
  ),
  TheWeighingEvent(
    eventNumber: 9,
    flowDay: 29,
    decanSection: 'Record You Leave',
    title: 'Seal the Record',
    slot: TheWeighingTimingSlot.sealEvening,
    durationMinutesMin: 8,
    durationMinutesMax: 10,
    spokenLine: 'I am pure. I am pure. I am pure. I am pure.',
    steps: <String>[
      'Speak only the truth-check lines you can speak honestly.',
      'Remain silent on any truth-check line that is not accurate.',
      'Say, if true: The material record of this ten-day section was kept without distortion.',
      'Say, if true: The spoken record of this ten-day section was kept without distortion.',
      'Say, if true: What I carried forward, I carried forward clearly.',
      'Say, if true: I did not take more than was due.',
      'Say, if true: I did not leave unprovided those in my care.',
      'Say, if true: I did not adjust the scale to favor myself.',
      'Speak the closing declaration after the truth-check lines.',
      'Name one thing from this cycle that you will hold differently in the next.',
      'Name one thing the record shows you did well.',
      'Place a cup of water on your surface.',
      'Let the water stand as the final offering.',
    ],
    sourceNote:
        'The Weighing of the Heart did not require perfection — it required honesty. The heart heavier or lighter than the feather had been inaccurate, not evil. The seal closes the record so continuation can begin from truth rather than pretense.',
    sharePromptOnComplete: true,
  ),
];

bool _theWeighingTimeZonesInitialized = false;

void _ensureTheWeighingTimeZonesInitialized() {
  if (_theWeighingTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _theWeighingTimeZonesInitialized = true;
}

DateTime defaultTheWeighingStartDate(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = theWeighingNowInZone(timezone, now: now);
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final todayStart = weighingMorningScheduleForDate(
    today,
    timezone,
    durationMinutes: kTheWeighingEvents.first.durationMinutesMax,
  ).startLocal;
  if (!todayStart.isBefore(nowLocal)) return today;
  return today.add(const Duration(days: 1));
}

DateTime theWeighingNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureTheWeighingTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromZonedDateTime(zoned);
}

TheWeighingOccurrenceSchedule theWeighingScheduleForDate(
  TheWeighingEvent event,
  DateTime date,
  TrackSkyTimeZone timezone, {
  int middayHour = kTheWeighingDefaultMiddayHour,
  int middayMinute = kTheWeighingDefaultMiddayMinute,
}) {
  switch (event.slot) {
    case TheWeighingTimingSlot.openMorning:
      return weighingMorningScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
    case TheWeighingTimingSlot.checkMidday:
      return weighingMiddayScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
        hour: middayHour,
        minute: middayMinute,
      );
    case TheWeighingTimingSlot.sealEvening:
      return weighingEveningScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
  }
}

TheWeighingOccurrenceSchedule weighingMorningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = dawnHouseRiteScheduleForDate(date, timezone);
  final startUtc = base.startUtc.add(const Duration(minutes: 30));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return TheWeighingOccurrenceSchedule(
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

TheWeighingOccurrenceSchedule weighingMiddayScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
  int hour = kTheWeighingDefaultMiddayHour,
  int minute = kTheWeighingDefaultMiddayMinute,
}) {
  _ensureTheWeighingTimeZonesInitialized();
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
  return TheWeighingOccurrenceSchedule(
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

TheWeighingOccurrenceSchedule weighingEveningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = eveningThresholdScheduleForDate(
    date,
    timezone,
    fallbackMinutesAfterMidnight: kTheWeighingEveningFallbackMinutes,
  );
  final startUtc = base.startUtc.add(const Duration(minutes: 10));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return TheWeighingOccurrenceSchedule(
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

String theWeighingEventTitle(TheWeighingEvent event) {
  return 'Weighing ${event.eventNumber}: ${event.title}';
}

String theWeighingActionId(TheWeighingEvent event) {
  return 'the-weighing-event-${event.eventNumber.toString().padLeft(2, '0')}';
}

TheWeighingEvent? theWeighingEventByNumber(int? eventNumber) {
  if (eventNumber == null) return null;
  for (final event in kTheWeighingEvents) {
    if (event.eventNumber == eventNumber) return event;
  }
  return null;
}

TheWeighingLens? theWeighingLensFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final lens in TheWeighingLens.values) {
    if (lens.key == normalized) return lens;
  }
  return null;
}

TheWeighingLens theWeighingLensFromNotes(
  String? notes, {
  TheWeighingLens fallback = TheWeighingLens.neutral,
}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('weighing_lens=')) continue;
    return theWeighingLensFromKey(trimmed.substring('weighing_lens='.length)) ??
        fallback;
  }
  return fallback;
}

bool isTheWeighingFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.theWeighing,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

TheWeighingEvent? theWeighingEventForEvent({
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  int? parseNumber(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  final payloadEvent = theWeighingEventByNumber(
    parseNumber(behaviorPayload?['event_number']),
  );
  if (payloadEvent != null) return payloadEvent;

  final actionMatch = RegExp(
    r'the-weighing-event-(\d{1,2})',
    caseSensitive: false,
  ).firstMatch(actionId?.trim() ?? '');
  final actionEvent = theWeighingEventByNumber(
    parseNumber(actionMatch?.group(1)),
  );
  if (actionEvent != null) return actionEvent;

  final titleMatch = RegExp(
    r'^\s*Weighing\s+(\d{1,2})\s*:',
    caseSensitive: false,
  ).firstMatch(title?.trim() ?? '');
  return theWeighingEventByNumber(parseNumber(titleMatch?.group(1)));
}

String? canonicalTheWeighingDetailTextForEvent({
  String? flowName,
  String? flowNotes,
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  if (!isTheWeighingFlowReference(
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  )) {
    return null;
  }
  final event = theWeighingEventForEvent(
    title: title,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
  if (event == null) return null;
  final lens =
      theWeighingLensFromKey(behaviorPayload?['lens']?.toString()) ??
      theWeighingLensFromNotes(flowNotes);
  return theWeighingDetailText(event, lens: lens);
}

Map<String, dynamic> theWeighingBehaviorPayload({
  required TheWeighingEvent event,
  required TheWeighingOccurrenceSchedule schedule,
  required TheWeighingLens lens,
}) {
  return <String, dynamic>{
    'kind': 'maat_the_weighing_event',
    'flow_key': kTheWeighingFlowKey,
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
      'optional': <String>['water', 'paper', 'light'],
    },
    'completion_options': const <String>[
      'observed',
      'observed_partly',
      'skipped',
    ],
    'missed_event_rule': 'expire_quietly',
    'share_prompt_on_complete': event.sharePromptOnComplete,
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

String theWeighingDetailText(
  TheWeighingEvent event, {
  required TheWeighingLens lens,
}) {
  final optional = event.optionalSteps
      .map((step) => '- $step')
      .join('\n')
      .trim();
  final lensLine = lens.detailLine.trim();
  return <String>[
    'Purpose\n${_theWeighingPurpose(event)}',
    'Words\n"${event.spokenLine}"',
    'Steps\n${_numberedLines(event.steps)}',
    if (optional.isNotEmpty) 'Optional\n$optional',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
  ].join('\n\n');
}

String theWeighingTimingLabel(TheWeighingEvent event) {
  switch (event.slot) {
    case TheWeighingTimingSlot.openMorning:
      return 'Day ${event.flowDay} · 30 minutes after dawn';
    case TheWeighingTimingSlot.checkMidday:
      return 'Day ${event.flowDay} · around 11 AM where you are';
    case TheWeighingTimingSlot.sealEvening:
      return 'Day ${event.flowDay} · 30 minutes after sunset';
  }
}

String _numberedLines(List<String> lines) {
  return lines
      .asMap()
      .entries
      .map((entry) => '${entry.key + 1}. ${entry.value}')
      .join('\n');
}

String _theWeighingPurpose(TheWeighingEvent event) {
  switch (event.eventNumber) {
    case 1:
      return 'The number you have not looked at is already operating on your life. Writing does not create the weight; it places the existing weight where it can be weighed. The water witnesses the record before anything is counted.';
    case 2:
      return 'The scale that is privately adjusted is still adjusted, even if no one saw it. Amenemope said the measure belongs to Re — meaning the accurate count exists independent of what you reported.';
    case 3:
      return 'The record sealed on a half-truth carries that half-truth into the next ten-day section. The seal closes with what is actually true, not what is close enough.';
    case 4:
      return 'An agreement is a record spoken aloud. This sitting finds the gap between what was said and what has happened since, and names it in the same medium — speech — where the agreement was made. The water keeps the instrument clean before the account begins.';
    case 5:
      return 'The person who understood your agreement differently is not necessarily wrong. This sitting asks whether the gap is a disagreement or a discrepancy — and which is yours to close.';
    case 6:
      return 'The second ten-day section closes with what is actually true about the spoken record, not what was intended. Intention does not seal a record — completion does.';
    case 7:
      return 'The record you leave is not the one you intended — it is the one your conduct produced. These four lines are not aspirations. Read them as a fact-check.';
    case 8:
      return 'Someone with less power in your orbit has a different view of the same period. This sitting asks whether their account would recognize yours — not to accept it uncritically, but to check whether the gap is explainable.';
    case 9:
      return 'The truth-check lines are weighed as record, not aspiration. The fourfold closing establishes what has been witnessed. The seal closes with what was actually done, and the water ending returns the reckoning to provision, not punishment.';
  }
  return 'Sit with what is true.';
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
