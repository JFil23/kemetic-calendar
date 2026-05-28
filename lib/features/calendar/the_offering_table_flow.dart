import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dawn_house_rite_flow.dart';
import 'maat_flow_identity.dart';
import 'track_sky_flow.dart';

const String kOfferingTableFlowKey = 'the-offering-table';
const String kOfferingTableTitle = 'The Offering Table';
const String kOfferingTableGlyph = '𓇋𓏏𓄣';
const String kOfferingTableTagline = 'Feed what needs to be fed.';
const int kOfferingTableDurationMinutes = 3;
const int kOfferingTableCompletionDurationMinutes = 5;
const int kOfferingTableDefaultHour = 7;
const int kOfferingTableDefaultMinute = 30;

const String kOfferingTableOverview =
    'Daily morning provision on the calendar: water first, then food, rest, and care, so basic life-support does not quietly collapse into Isfet. '
    'The Offering Table is a very low-burden thirty-day Ma\'at flow with one sitting each morning, moving through the Personal Table, Household Table, and Flowing Table. '
    'It is not a meal tracker, sleep app, wellness costume, or optimization flow; it is a practice of feeding what needs to be fed.';

const String kOfferingTableEnrollmentCopy =
    'Required: place water and speak the line. Everything else is optional. Two minutes is enough.';

enum OfferingTableLens { neutral, hapy, ausar }

extension OfferingTableLensX on OfferingTableLens {
  String get key {
    switch (this) {
      case OfferingTableLens.neutral:
        return 'neutral';
      case OfferingTableLens.hapy:
        return 'hapy';
      case OfferingTableLens.ausar:
        return 'ausar';
    }
  }

  String get label {
    switch (this) {
      case OfferingTableLens.neutral:
        return 'Neutral';
      case OfferingTableLens.hapy:
        return 'Hapy';
      case OfferingTableLens.ausar:
        return 'Ausar';
    }
  }

  String get detailLine {
    switch (this) {
      case OfferingTableLens.neutral:
        return '';
      case OfferingTableLens.hapy:
        return 'Let Hapy frame the table as flow: what nourishes you is meant to keep moving.';
      case OfferingTableLens.ausar:
        return 'Let Ausar frame the table as restoration: what has gone dry can be returned to life in small portions.';
    }
  }
}

class OfferingTableDay {
  final int dayNumber;
  final String section;
  final String title;
  final String purpose;
  final String provisionAct;
  final List<String> optionalSteps;
  final String? sourceNote;
  final int durationMinutes;
  final bool sharePromptOnComplete;

  const OfferingTableDay({
    required this.dayNumber,
    required this.section,
    required this.title,
    required this.purpose,
    required this.provisionAct,
    this.optionalSteps = const <String>[],
    this.sourceNote,
    this.durationMinutes = kOfferingTableDurationMinutes,
    this.sharePromptOnComplete = false,
  });
}

class OfferingTableOccurrenceSchedule {
  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool usedFallback;
  final bool clampedToDawn;
  final TrackSkyTimeZone timezone;
  final String referenceLocationName;
  final int configuredHour;
  final int configuredMinute;

  const OfferingTableOccurrenceSchedule({
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
    required this.usedFallback,
    required this.clampedToDawn,
    required this.timezone,
    required this.referenceLocationName,
    required this.configuredHour,
    required this.configuredMinute,
  });
}

const String _offeringTablePersonalLine =
    'Wash yourself and your Ka will wash itself. Your Ka will sit and eat bread with you without ceasing.';
const String _offeringTableHouseholdLine =
    'The provisions of all mankind flow from abundance. To do Ma\'at is the breath of the nostrils.';
const String _offeringTableFlowingLine =
    'Your bread is present every day. Water shall provide nurture for you. What is given does not leave - it returns.';

const List<OfferingTableDay> kOfferingTableDays = <OfferingTableDay>[
  OfferingTableDay(
    dayNumber: 1,
    section: 'Personal Table',
    title: 'The First Water',
    purpose: 'Begin with the simplest proof that life is being provisioned.',
    provisionAct:
        'Before food, phone, or work, fill the cup. Name one basic need that has been unmet for three days or more.',
    optionalSteps: <String>[
      'Write the need in one sentence without explaining it away.',
    ],
    sourceNote:
        'Kemetic offering ritual begins with water before bread, oil, or incense. The table starts by acknowledging what sustains life first.',
  ),
  OfferingTableDay(
    dayNumber: 2,
    section: 'Personal Table',
    title: 'The Cup Before the Noise',
    purpose:
        'Let water be the first intake before the day starts taking from you.',
    provisionAct:
        'Drink water before opening any feed, message thread, or task list. Name what you want your first input to be today.',
    optionalSteps: <String>[
      'Move the phone or laptop one arm-length away while you drink.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 3,
    section: 'Personal Table',
    title: 'Bread Enough',
    purpose: 'Treat food as provision, not as background fuel.',
    provisionAct:
        'Name your first real food for the day. If it is not planned, choose one reachable option before the morning moves on.',
    optionalSteps: <String>[
      'Place or prepare one food item where you will see it.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 4,
    section: 'Personal Table',
    title: 'The Body Washed',
    purpose: 'Give the body one visible sign that it has not been neglected.',
    provisionAct:
        'Wash face, hands, or mouth with attention. Name one body-care task that has been delayed and choose its smallest version.',
    optionalSteps: <String>[
      'Set out the item needed for that care: towel, medicine, lotion, clean clothes, or shoes.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 5,
    section: 'Personal Table',
    title: 'The Midpoint: Rest',
    purpose: 'Make rest factual before exhaustion gets renamed as virtue.',
    provisionAct:
        'Name last night\'s sleep hours as a fact. Name one thing likely to shorten sleep tonight, and reduce it by one small amount.',
    optionalSteps: <String>[
      'Set one evening boundary now: time, screen, food, work, or conversation.',
    ],
    sourceNote:
        'Provision is not only food. The Ka is sustained by repeated supports, and rest is one of the supports that disappears when it is not counted.',
  ),
  OfferingTableDay(
    dayNumber: 6,
    section: 'Personal Table',
    title: 'The Small Supply',
    purpose: 'Check the material supports your body quietly depends on.',
    provisionAct:
        'Check one supply: medication, water bottle, groceries, soap, clean clothes, or transit fare. Refill or list the next concrete step.',
    optionalSteps: <String>[
      'Put the item on a visible surface or add one direct reminder.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 7,
    section: 'Personal Table',
    title: 'Dignity at the Table',
    purpose: 'Provision includes the conditions that let you remain human.',
    provisionAct:
        'Choose one act that protects dignity today: clean clothing, a seat to eat, a real pause, or not mocking your own need.',
    optionalSteps: <String>[
      'Say: I am allowed to be provisioned without proving exhaustion first.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 8,
    section: 'Personal Table',
    title: 'The Quiet Hunger',
    purpose: 'Notice the need hidden under being fine.',
    provisionAct:
        'Name one hunger that is not food: sleep, touch, silence, medical care, sunlight, movement, or help. Give it one small portion.',
    optionalSteps: <String>[
      'If no portion is possible now, schedule the first honest opening for it.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 9,
    section: 'Personal Table',
    title: 'The First Repair',
    purpose: 'Close one small gap before the personal table seals.',
    provisionAct:
        'Choose one provision repair completable before noon: drink, eat, wash, stretch, rest ten minutes, refill, or ask for help.',
    optionalSteps: <String>[
      'Mark it done only after the body has actually received it.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 10,
    section: 'Personal Table',
    title: 'The Personal Table Sealed',
    purpose: 'Carry a plain account of how you sustained yourself.',
    provisionAct:
        'Name one personal need that was fed this decan and one need still asking for provision. Keep both statements short.',
    optionalSteps: <String>[
      'Prepare tomorrow\'s first water before the day closes.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 11,
    section: 'Household Table',
    title: 'The Household Table Opens',
    purpose: 'Turn from self-provision to the people and beings in your care.',
    provisionAct:
        'Name one dependent, housemate, elder, child, animal, plant, or shared space. Name one unmet need at that table.',
    optionalSteps: <String>[
      'Make one small provision act now if it can be done without drama.',
    ],
    sourceNote:
        'Offering lists in tombs and temples are records of sustained relationship. Provision is not private when others depend on the table.',
  ),
  OfferingTableDay(
    dayNumber: 12,
    section: 'Household Table',
    title: 'The Dependent Named',
    purpose: 'Make care specific enough to be answered.',
    provisionAct:
        'Choose one being who depends on you. Name what they need today in concrete terms: food, attention, money, medicine, safety, time, or repair.',
    optionalSteps: <String>[
      'Send one clear check-in or complete one simple care task.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 13,
    section: 'Household Table',
    title: 'The Fair Share',
    purpose: 'Look at whether the table is being carried evenly enough.',
    provisionAct:
        'Name one household resource you use: food, money, time, labor, attention, or space. Ask if you are taking, giving, or avoiding your share.',
    optionalSteps: <String>[
      'Adjust one share today: pay, clean, refill, thank, cover, or release.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 14,
    section: 'Household Table',
    title: 'The Waiting Bowl',
    purpose: 'Notice what has been left empty because no one named it.',
    provisionAct:
        'Find one empty or low thing in the household: pantry item, soap, patience, pet bowl, laundry, calendar space. Name the refill.',
    optionalSteps: <String>['Do the refill if it takes under three minutes.'],
  ),
  OfferingTableDay(
    dayNumber: 15,
    section: 'Household Table',
    title: 'The Midpoint: Attention',
    purpose: 'Treat attention as provision, not decoration.',
    provisionAct:
        'Name one person or responsibility that has received your leftover attention. Give it one undistracted minute today.',
    optionalSteps: <String>['Place the phone face down during that minute.'],
    sourceNote:
        'In offering scenes, the table is visible because provision must be seen and carried. Attention is one way a household table becomes visible.',
  ),
  OfferingTableDay(
    dayNumber: 16,
    section: 'Household Table',
    title: 'The Cost Named',
    purpose: 'Stop pretending provision has no cost.',
    provisionAct:
        'Name one care cost honestly: money, time, patience, transport, planning, or recovery. Decide where that cost will be held today.',
    optionalSteps: <String>[
      'Ask for one help, trade, or boundary if the cost is too hidden.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 17,
    section: 'Household Table',
    title: 'The Care Message',
    purpose: 'Use speech to keep a provision line open.',
    provisionAct:
        'Send or speak one practical care message: I have this, I need this, I will bring this, or I cannot do this today.',
    optionalSteps: <String>[
      'Keep it plain. Do not turn it into apology theater.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 18,
    section: 'Household Table',
    title: 'The Shared Rest',
    purpose: 'Protect rest as a household resource.',
    provisionAct:
        'Name one way your pace affects someone else\'s rest. Make one adjustment: volume, timing, chore, expectation, or interruption.',
    optionalSteps: <String>[
      'Choose a quiet hour or quiet corner for the household today.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 19,
    section: 'Household Table',
    title: 'The Unseen Labor',
    purpose: 'Bring hidden provision into the record.',
    provisionAct:
        'Name one unseen labor that keeps your life or household functioning. If it is yours, acknowledge it. If it is another\'s, thank or lighten it.',
    optionalSteps: <String>[
      'Do one unannounced task that makes someone else\'s load smaller.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 20,
    section: 'Household Table',
    title: 'The Household Table Sealed',
    purpose: 'Close the household decan with one true account.',
    provisionAct:
        'Name one household provision that improved and one that still leaks. Choose the next smallest patch.',
    optionalSteps: <String>[
      'Put the patch on today\'s calendar or task list before moving on.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 21,
    section: 'Flowing Table',
    title: 'The Flowing Table Opens',
    purpose:
        'Turn toward the sources that feed you and what you block for others.',
    provisionAct:
        'Name one unacknowledged source: income, land, water, relationship, skill, ancestor, teacher, or public service. Ask if you block flow for someone else.',
    optionalSteps: <String>[
      'Make one acknowledgement or remove one small obstruction.',
    ],
    sourceNote:
        'Hapy personifies the Nile flood as abundance that moves. Provision becomes disorder when flow is hoarded, blocked, or denied.',
  ),
  OfferingTableDay(
    dayNumber: 22,
    section: 'Flowing Table',
    title: 'The Source Named',
    purpose: 'Remember that today\'s provision arrived through a chain.',
    provisionAct:
        'Trace one thing you will use today back one step: who grew it, sent it, taught it, paid it, carried it, or kept it available?',
    optionalSteps: <String>[
      'Offer thanks, payment, credit, or care to one visible part of that chain.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 23,
    section: 'Flowing Table',
    title: 'The River Unblocked',
    purpose: 'Remove one unnecessary stop in the flow of support.',
    provisionAct:
        'Find one thing delayed by you: reply, payment, return, permission, food, help, or information. Move it one step downstream.',
    optionalSteps: <String>[
      'If it cannot move today, tell the affected person what is true.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 24,
    section: 'Flowing Table',
    title: 'The Hoard Checked',
    purpose: 'Ask whether holding more is preventing enough somewhere else.',
    provisionAct:
        'Name one surplus: object, food, money, attention, credit, time, or control. Decide whether any portion should circulate.',
    optionalSteps: <String>[
      'Give, return, share, compost, donate, or release one small portion.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 25,
    section: 'Flowing Table',
    title: 'The Midpoint: Hapy',
    purpose: 'Let abundance be tested by movement.',
    provisionAct:
        'Name one place where provision flowed to you this week. Name one place where you can let provision flow onward without self-erasure.',
    optionalSteps: <String>[
      'Choose an act that keeps the channel open: share, pay, refill, introduce, teach, or carry.',
    ],
    sourceNote:
        'Hymns to Hapy praise the flood because it feeds fields and households. Flow is provision made visible across more than one table.',
  ),
  OfferingTableDay(
    dayNumber: 26,
    section: 'Flowing Table',
    title: 'The Return Given',
    purpose: 'Practice reversion: what is offered returns through living use.',
    provisionAct:
        'Let one support return through action. Eat the food, drink the water, use the help, accept the rest, or put the tool to work.',
    optionalSteps: <String>[
      'Do not leave provision as a symbol if it can nourish the day.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 27,
    section: 'Flowing Table',
    title: 'The Land Remembered',
    purpose: 'Include place and environment in the table.',
    provisionAct:
        'Name one way land, water, weather, or public infrastructure provisions you today. Make one small return of care or restraint.',
    optionalSteps: <String>[
      'Pick up, conserve, water, repair, recycle, walk, or reduce one waste.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 28,
    section: 'Flowing Table',
    title: 'The Relationship Fed',
    purpose: 'Feed a bond before it has to survive on memory.',
    provisionAct:
        'Choose one relationship that sustains you. Give it one provision: honest thanks, time, food, help, repair, or a clean boundary.',
    optionalSteps: <String>[
      'Make the provision concrete enough that the other person can receive it.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 29,
    section: 'Flowing Table',
    title: 'The Flow Prepared',
    purpose:
        'Prepare tomorrow\'s provision so the cycle can begin honestly again.',
    provisionAct:
        'Set up one support for the next morning: water, breakfast, medicine, clothes, message, money, or cleared space.',
    optionalSteps: <String>[
      'Name what will be easier because you prepared it.',
    ],
  ),
  OfferingTableDay(
    dayNumber: 30,
    section: 'Flowing Table',
    title: 'The Table Is Complete',
    purpose: 'Complete the thirty-day table with truth, not perfection.',
    provisionAct:
        'Speak only the lines that are true:\n- My water was placed with attention.\n- Food, rest, or care was not treated as imaginary.\n- I fed one need before it became collapse.\n- I noticed who else depends on the table.\n- What flowed to me was allowed to return.\nThen name one shortfall and one provision that surprised you.',
    optionalSteps: <String>[
      'Sit for one quiet breath after drinking the water.',
      'Share only this prompt if you choose: one thing the table held that I did not expect.',
    ],
    sourceNote:
        'The offering table is not an end point. The water is consumed, the support returns to life, and the next cycle starts from what is now known.',
    durationMinutes: kOfferingTableCompletionDurationMinutes,
    sharePromptOnComplete: true,
  ),
];

bool _offeringTableTimeZonesInitialized = false;

void _ensureOfferingTableTimeZonesInitialized() {
  if (_offeringTableTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _offeringTableTimeZonesInitialized = true;
}

DateTime defaultOfferingTableStartDate(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = offeringTableNowInZone(timezone, now: now);
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final todayStart = offeringTableScheduleForDate(
    kOfferingTableDays.first,
    today,
    timezone,
  ).startLocal;
  if (!todayStart.isBefore(nowLocal)) return today;
  return today.add(const Duration(days: 1));
}

DateTime offeringTableNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureOfferingTableTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromZonedDateTime(zoned);
}

OfferingTableOccurrenceSchedule offeringTableScheduleForDate(
  OfferingTableDay day,
  DateTime date,
  TrackSkyTimeZone timezone, {
  int hour = kOfferingTableDefaultHour,
  int minute = kOfferingTableDefaultMinute,
}) {
  _ensureOfferingTableTimeZonesInitialized();
  final localDate = DateTime(date.year, date.month, date.day);
  final dawn = dawnHouseRiteScheduleForDate(localDate, timezone);
  final clampedHour = hour.clamp(0, 23).toInt();
  final clampedMinute = minute.clamp(0, 59).toInt();
  final configuredLocal = DateTime(
    localDate.year,
    localDate.month,
    localDate.day,
    clampedHour,
    clampedMinute,
  );
  final clampedToDawn = configuredLocal.isBefore(dawn.startLocal);
  final startLocal = clampedToDawn ? dawn.startLocal : configuredLocal;
  final endLocal = startLocal.add(Duration(minutes: day.durationMinutes));
  final startUtc = _localToUtc(startLocal, timezone);
  final endUtc = startUtc.add(Duration(minutes: day.durationMinutes));
  return OfferingTableOccurrenceSchedule(
    startLocal: startLocal,
    endLocal: endLocal,
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: dawn.usedFallback,
    clampedToDawn: clampedToDawn,
    timezone: timezone,
    referenceLocationName: dawn.referenceLocation.name,
    configuredHour: clampedHour,
    configuredMinute: clampedMinute,
  );
}

String offeringTableDecanLine(int dayNumber) {
  if (dayNumber <= 10) return _offeringTablePersonalLine;
  if (dayNumber <= 20) return _offeringTableHouseholdLine;
  return _offeringTableFlowingLine;
}

String offeringTableEventTitle(OfferingTableDay day) {
  return 'Day ${day.dayNumber}: ${day.title}';
}

String offeringTableActionId(OfferingTableDay day) {
  return 'the-offering-table-day-${day.dayNumber.toString().padLeft(2, '0')}';
}

OfferingTableDay? offeringTableDayByNumber(int? dayNumber) {
  if (dayNumber == null) return null;
  for (final day in kOfferingTableDays) {
    if (day.dayNumber == dayNumber) return day;
  }
  return null;
}

OfferingTableLens? offeringTableLensFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final lens in OfferingTableLens.values) {
    if (lens.key == normalized) return lens;
  }
  return null;
}

OfferingTableLens offeringTableLensFromNotes(
  String? notes, {
  OfferingTableLens fallback = OfferingTableLens.neutral,
}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('offering_lens=')) continue;
    return offeringTableLensFromKey(
          trimmed.substring('offering_lens='.length),
        ) ??
        fallback;
  }
  return fallback;
}

bool offeringTableNoCupModeFromNotes(String? notes, {bool fallback = false}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim().toLowerCase();
    if (trimmed == 'no_cup_mode=1' || trimmed == 'no_cup_mode=true') {
      return true;
    }
    if (trimmed == 'no_cup_mode=0' || trimmed == 'no_cup_mode=false') {
      return false;
    }
  }
  return fallback;
}

bool isOfferingTableFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.offeringTable,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

OfferingTableDay? offeringTableDayForEvent({
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  int? parseDay(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  final payloadDay = offeringTableDayByNumber(
    parseDay(behaviorPayload?['day']),
  );
  if (payloadDay != null) return payloadDay;

  final actionMatch = RegExp(
    r'the-offering-table-day-(\d{1,2})',
    caseSensitive: false,
  ).firstMatch(actionId?.trim() ?? '');
  final actionDay = offeringTableDayByNumber(parseDay(actionMatch?.group(1)));
  if (actionDay != null) return actionDay;

  final titleMatch = RegExp(
    r'^\s*Day\s+(\d{1,2})\s*:',
    caseSensitive: false,
  ).firstMatch(title?.trim() ?? '');
  return offeringTableDayByNumber(parseDay(titleMatch?.group(1)));
}

String? canonicalOfferingTableDetailTextForEvent({
  String? flowName,
  String? flowNotes,
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  if (!isOfferingTableFlowReference(
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  )) {
    return null;
  }
  final day = offeringTableDayForEvent(
    title: title,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
  if (day == null) return null;
  final lens =
      offeringTableLensFromKey(behaviorPayload?['lens']?.toString()) ??
      offeringTableLensFromNotes(flowNotes);
  final rawNoCup = behaviorPayload?['no_cup_mode'];
  final noCupMode = rawNoCup is bool
      ? rawNoCup
      : offeringTableNoCupModeFromNotes(flowNotes);
  return offeringTableDetailText(day, lens: lens, noCupMode: noCupMode);
}

Map<String, dynamic> offeringTableBehaviorPayload({
  required OfferingTableDay day,
  required OfferingTableOccurrenceSchedule schedule,
  required OfferingTableLens lens,
  required bool noCupMode,
}) {
  return <String, dynamic>{
    'kind': 'maat_offering_table_day',
    'flow_key': kOfferingTableFlowKey,
    'day': day.dayNumber,
    'decan_section': day.section,
    'duration_minutes': day.durationMinutes,
    'burden': day.dayNumber == 30 ? 'low' : 'very_low',
    'props_profile': <String, dynamic>{
      'required': noCupMode ? <String>[] : <String>['water_cup'],
      'alternative': noCupMode ? 'hold_existing_cup' : null,
      'optional': const <String>['paper'],
    },
    'completion_options': const <String>[
      'observed',
      'observed_partly',
      'skipped',
    ],
    'missed_event_rule': 'expire_quietly',
    'share_prompt_on_complete': day.sharePromptOnComplete,
    'schedule': <String, dynamic>{
      'type': 'fixed_local_morning_clamped_to_dawn',
      'default_notification': 'event_start',
      'default_hour': kOfferingTableDefaultHour,
      'default_minute': kOfferingTableDefaultMinute,
      'configured_hour': schedule.configuredHour,
      'configured_minute': schedule.configuredMinute,
      'clamped_to_dawn': schedule.clampedToDawn,
      'used_dawn_fallback': schedule.usedFallback,
      'timezone': schedule.timezone.key,
      'iana_timezone': schedule.timezone.ianaName,
      'reference_location': schedule.referenceLocationName,
    },
    'lens': lens.key,
    'no_cup_mode': noCupMode,
  };
}

String offeringTableDetailText(
  OfferingTableDay day, {
  required OfferingTableLens lens,
  required bool noCupMode,
}) {
  final optional = day.optionalSteps.map((step) => '- $step').join('\n').trim();
  final lensLine = lens.detailLine.trim();
  return <String>[
    'Purpose\n${day.purpose}',
    'Water\n${noCupMode ? 'Hold the cup you are already using, or pause with water as soon as one is available.' : 'Place a cup of water before food, phone, or work.'}',
    'Words\n"${offeringTableDecanLine(day.dayNumber)}"',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
    'Provision\n${day.provisionAct}',
    if (optional.isNotEmpty) 'Optional\n$optional',
    'Drink\nDrink the water. This is reversion: provision returns through the living body, not left on the table.',
    if ((day.sourceNote ?? '').trim().isNotEmpty)
      'Source\n${day.sourceNote!.trim()}',
  ].join('\n\n');
}

String offeringTableTimingLabel(OfferingTableDay day) {
  return 'Day ${day.dayNumber} · 7:30 local, not before dawn';
}

DateTime _localToUtc(DateTime local, TrackSkyTimeZone timezone) {
  _ensureOfferingTableTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  return tz.TZDateTime(
    location,
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
    local.microsecond,
  ).toUtc();
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
