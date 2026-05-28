import 'dart:math' as math;

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'maat_flow_identity.dart';
import 'track_sky_flow.dart';

const String kDawnHouseRiteFlowKey = 'dawn-house-rite';
const String kDawnHouseRiteTitle = 'Dawn House Rite';
const int kDawnHouseRiteDurationMinutes = 3;

const String kDawnHouseRiteOverview =
    'The Dawn House Rite is grounded in one of the clearest Egyptian sacred time-patterns: at dawn, the world returns to visible order. '
    'In the Pyramid Texts of Unas, washing, purification, the Lake of Dawn, and the appearance of Re are linked, making morning not just a beginning but a renewal of creation. '
    'This thirty-day flow turns that ancient pattern into a simple house observance: cleanse the hands or face, set water, greet the returning light, speak ma’at, and choose one act that brings order into the day. '
    'Its three ten-day movements—personal ma’at, household ma’at, and communal ma’at—echo the Egyptian thirty-day month divided into three ten-day periods, carrying dawn renewal from the body to the home to the wider world.';

enum DawnHouseRiteLens {
  neutral,
  solar,
  ancestor,
  household,
  thothic,
  protection,
}

extension DawnHouseRiteLensX on DawnHouseRiteLens {
  String get key {
    switch (this) {
      case DawnHouseRiteLens.neutral:
        return 'neutral';
      case DawnHouseRiteLens.solar:
        return 'solar';
      case DawnHouseRiteLens.ancestor:
        return 'ancestor';
      case DawnHouseRiteLens.household:
        return 'household';
      case DawnHouseRiteLens.thothic:
        return 'thothic';
      case DawnHouseRiteLens.protection:
        return 'protection';
    }
  }

  String get label {
    switch (this) {
      case DawnHouseRiteLens.neutral:
        return 'Neutral';
      case DawnHouseRiteLens.solar:
        return 'Solar';
      case DawnHouseRiteLens.ancestor:
        return 'Ancestor';
      case DawnHouseRiteLens.household:
        return 'Household';
      case DawnHouseRiteLens.thothic:
        return 'Thothic';
      case DawnHouseRiteLens.protection:
        return 'Protection';
    }
  }

  String detailLine({required bool discreet}) {
    switch (this) {
      case DawnHouseRiteLens.neutral:
        return '';
      case DawnHouseRiteLens.solar:
        return 'Notice how first light restores direction and measure.';
      case DawnHouseRiteLens.ancestor:
        return 'Keep memory ordered; let the day answer what has sustained you.';
      case DawnHouseRiteLens.household:
        return 'Let the practice steady the rooms and relationships around you.';
      case DawnHouseRiteLens.thothic:
        return discreet
            ? 'Record one clear observation; precision is part of order.'
            : 'Keep one exact record; careful measure is part of Ma\'at.';
      case DawnHouseRiteLens.protection:
        return 'Set one clean boundary before the day gathers force.';
    }
  }
}

class DawnHouseRiteDay {
  final int dayNumber;
  final String section;
  final String title;
  final String purpose;
  final String action;
  final String words;
  final String maatAct;

  const DawnHouseRiteDay({
    required this.dayNumber,
    required this.section,
    required this.title,
    required this.purpose,
    required this.action,
    required this.words,
    required this.maatAct,
  });
}

class DawnHouseRiteReferenceLocation {
  final String name;
  final double latitude;
  final double longitude;

  const DawnHouseRiteReferenceLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class DawnHouseRiteOccurrenceSchedule {
  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool usedFallback;
  final TrackSkyTimeZone timezone;
  final DawnHouseRiteReferenceLocation referenceLocation;

  const DawnHouseRiteOccurrenceSchedule({
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
    required this.usedFallback,
    required this.timezone,
    required this.referenceLocation,
  });
}

const Map<TrackSkyTimeZone, DawnHouseRiteReferenceLocation>
kDawnHouseRiteReferenceLocations =
    <TrackSkyTimeZone, DawnHouseRiteReferenceLocation>{
      TrackSkyTimeZone.pacific: DawnHouseRiteReferenceLocation(
        name: 'Los Angeles',
        latitude: 34.0522,
        longitude: -118.2437,
      ),
      TrackSkyTimeZone.mountain: DawnHouseRiteReferenceLocation(
        name: 'Denver',
        latitude: 39.7392,
        longitude: -104.9903,
      ),
      TrackSkyTimeZone.central: DawnHouseRiteReferenceLocation(
        name: 'Chicago',
        latitude: 41.8781,
        longitude: -87.6298,
      ),
      TrackSkyTimeZone.eastern: DawnHouseRiteReferenceLocation(
        name: 'New York',
        latitude: 40.7128,
        longitude: -74.0060,
      ),
    };

const List<DawnHouseRiteDay> kDawnHouseRiteDays = <DawnHouseRiteDay>[
  DawnHouseRiteDay(
    dayNumber: 1,
    section: 'Personal Ma\'at',
    title: 'Opening the Day',
    purpose: 'Enter the day as ordered time.',
    action: 'Wash hands and face. Set water. Face the light.',
    words:
        'The day opens. I enter it in Ma\'at. May my hands be clean, my speech be true, and my actions give life.',
    maatAct: 'Name one thing you will set in order today.',
  ),
  DawnHouseRiteDay(
    dayNumber: 2,
    section: 'Personal Ma\'at',
    title: 'Purifying the Self',
    purpose: 'Remove disorder before action.',
    action: 'Wash hands slowly. Touch water to lips or rinse the mouth.',
    words:
        'I am cleansed for the day. May falsehood fall away. May what is useful remain.',
    maatAct:
        'Avoid one source of disorder today: gossip, haste, resentment, neglect, or waste.',
  ),
  DawnHouseRiteDay(
    dayNumber: 3,
    section: 'Personal Ma\'at',
    title: 'Right Speech',
    purpose: 'Align the mouth before speaking into the world.',
    action:
        'Wash or touch the mouth with water. Pause before messages or conversation.',
    words:
        'May my mouth speak Ma\'at. May I not multiply confusion. May my words steady what they touch.',
    maatAct:
        'Speak one necessary truth kindly, or keep silence where speech would harm.',
  ),
  DawnHouseRiteDay(
    dayNumber: 4,
    section: 'Personal Ma\'at',
    title: 'Clear Sight',
    purpose: 'Move from night-confusion into visible order.',
    action: 'Wash face, especially brow or eyes. Look toward the light.',
    words:
        'The light returns. What was hidden becomes visible. May I see clearly and act in right measure.',
    maatAct: "Name today's true priority before beginning lesser tasks.",
  ),
  DawnHouseRiteDay(
    dayNumber: 5,
    section: 'Personal Ma\'at',
    title: 'Right Measure',
    purpose: 'Resist excess, imbalance, and scattered action.',
    action: 'Set water. Take three measured breaths before speaking.',
    words:
        'May I move in right measure. May I neither rush nor neglect. May my strength be used where it belongs.',
    maatAct:
        'Choose one limit: time, food, spending, speech, work, or emotional reaction.',
  ),
  DawnHouseRiteDay(
    dayNumber: 6,
    section: 'Personal Ma\'at',
    title: 'Steady Hands',
    purpose: 'Make the body an instrument of ordered action.',
    action: 'Wash hands. Hold them open over the water.',
    words:
        'May my hands do what is useful. May they repair, feed, build, clean, and protect.',
    maatAct:
        'Do one physical act of order: clean, prepare, fix, carry, cook, sort, or tend.',
  ),
  DawnHouseRiteDay(
    dayNumber: 7,
    section: 'Personal Ma\'at',
    title: 'Repair',
    purpose: 'Restore what can be restored.',
    action: 'Set water. Think of one neglected matter.',
    words:
        'What is broken should be repaired where repair is possible. May I restore without pride and correct without cruelty.',
    maatAct: 'Apologize, return, pay, answer, mend, reschedule, or resume.',
  ),
  DawnHouseRiteDay(
    dayNumber: 8,
    section: 'Personal Ma\'at',
    title: 'Protection from Isfet',
    purpose: 'Set boundaries against disorder.',
    action: 'Touch water to forehead, chest, or doorframe.',
    words:
        'May this day be guarded from needless harm. May I not invite isfet through fear, anger, haste, or carelessness.',
    maatAct: 'Choose one boundary that protects peace, truth, safety, or duty.',
  ),
  DawnHouseRiteDay(
    dayNumber: 9,
    section: 'Personal Ma\'at',
    title: 'Gratitude',
    purpose: 'Receive the day as a gift and answer it with right action.',
    action: 'Set water. Name three things that sustain you.',
    words:
        'The day is given again. I remember what sustains me. May gratitude become right action.',
    maatAct:
        'Thank someone, preserve something, use resources carefully, or give care.',
  ),
  DawnHouseRiteDay(
    dayNumber: 10,
    section: 'Personal Ma\'at',
    title: 'Personal Recalibration',
    purpose: 'Complete the first ten-day measure.',
    action:
        'Wash hands and face. Set water. Review the past nine days without guilt.',
    words:
        'A measure is complete. What was neglected can be restored. What was rightly done can continue. I return to Ma\'at.',
    maatAct: 'Name one correction for the next ten days.',
  ),
  DawnHouseRiteDay(
    dayNumber: 11,
    section: 'Household Ma\'at',
    title: 'Opening the House',
    purpose: 'Let the household enter the day in order.',
    action:
        'Open a curtain, door, or window if possible. Set water in the kitchen, entryway, desk, or shrine.',
    words:
        'This house enters the day in Ma\'at. May those who dwell here be sustained, truthful, and at peace.',
    maatAct:
        'Clear one household obstruction: dish, trash, clutter, laundry, message, bill, or appointment.',
  ),
  DawnHouseRiteDay(
    dayNumber: 12,
    section: 'Household Ma\'at',
    title: 'Threshold',
    purpose: 'Guard the boundary between inner and outer life.',
    action: 'Touch water to the doorframe or simply pause near the door.',
    words:
        'May what enters this house serve life. May what leaves this house carry truth.',
    maatAct:
        'Make one boundary clear: schedule, privacy, safety, spending, visitors, or conversation.',
  ),
  DawnHouseRiteDay(
    dayNumber: 13,
    section: 'Household Ma\'at',
    title: 'Hearth and Food',
    purpose: 'Honor nourishment as an act of order.',
    action:
        'Set water near where food is prepared. Add bread, fruit, grain, tea, or coffee if available.',
    words:
        'Water and food are set in right order. May this house be nourished, and may I not forget those who hunger.',
    maatAct: 'Prepare, share, donate, save, or avoid wasting food.',
  ),
  DawnHouseRiteDay(
    dayNumber: 14,
    section: 'Household Ma\'at',
    title: 'Clean Place',
    purpose: 'Restore one part of the home as a field of Ma\'at.',
    action: 'Wash hands. Clean one small surface before or after speaking.',
    words:
        'A clean place welcomes clear action. May disorder be seen, named, and gently corrected.',
    maatAct:
        'Clean one area for three minutes only: sink, table, floor, desk, altar, bag, or doorway.',
  ),
  DawnHouseRiteDay(
    dayNumber: 15,
    section: 'Household Ma\'at',
    title: 'Household Speech',
    purpose: 'Keep peace through truthful and measured speech at home.',
    action:
        'Touch water to lips or hold water while thinking of household conversations.',
    words:
        'May speech in this house be truthful, measured, and life-giving. May anger not rule the doorway.',
    maatAct:
        'Speak gently in one difficult interaction, or delay speech until it can be truthful and useful.',
  ),
  DawnHouseRiteDay(
    dayNumber: 16,
    section: 'Household Ma\'at',
    title: 'Ancestor Water',
    purpose: 'Keep the dead within ordered remembrance.',
    action:
        'Set cool water. Speak one ancestor name, family name, lineage, or "the remembered and forgotten dead."',
    words:
        'Cool water for the honored dead. May the names that should live not be lost. May memory be kept in Ma\'at.',
    maatAct:
        'Tell a true story, preserve a photo/name, visit a grave, or correct a family falsehood with care.',
  ),
  DawnHouseRiteDay(
    dayNumber: 17,
    section: 'Household Ma\'at',
    title: 'Hidden Practice',
    purpose:
        'Make the rite possible even without visible shrine or public display.',
    action: 'Perform the whole rite at the sink, silently or quietly.',
    words:
        'Even hidden, Ma\'at is not absent. Even small, right action remains right action.',
    maatAct: 'Do one unseen good thing without announcement.',
  ),
  DawnHouseRiteDay(
    dayNumber: 18,
    section: 'Household Ma\'at',
    title: 'Household Offering',
    purpose: 'Practice reciprocity inside the home.',
    action:
        'Set water and one small offering: bread, fruit, flower, scent, or a clean empty cup if nothing else is available.',
    words:
        'What sustains this house is honored. What is received is answered. May giving and receiving remain in balance.',
    maatAct:
        'Replenish something shared: water, food, soap, care, attention, money, or patience.',
  ),
  DawnHouseRiteDay(
    dayNumber: 19,
    section: 'Household Ma\'at',
    title: 'Peace in the Rooms',
    purpose:
        'Reduce accumulated disorder in the emotional atmosphere of the home.',
    action:
        'Walk through one room with water in hand, or simply stand in the center.',
    words:
        'May this room be free of needless anger, neglect, and confusion. May peace have a place to stand.',
    maatAct:
        'Remove one irritant: clutter, noise, overdue reply, unresolved tension, or avoided task.',
  ),
  DawnHouseRiteDay(
    dayNumber: 20,
    section: 'Household Ma\'at',
    title: 'Household Recalibration',
    purpose: 'Complete the household ten-day measure.',
    action: 'Set water in the center of the home or where the day begins.',
    words:
        'A second measure is complete. May this house remember order. May what is unfinished be met without fear.',
    maatAct: 'Choose one household repair for the next ten days.',
  ),
  DawnHouseRiteDay(
    dayNumber: 21,
    section: 'Communal Ma\'at',
    title: 'Entering the Community',
    purpose: 'Carry Ma\'at beyond the self and house.',
    action:
        'Wash hands. Face the light. Think of the people you will affect today.',
    words:
        'I do not enter the world alone. May my actions strengthen the order around me.',
    maatAct: 'Be useful to one person without making yourself the center.',
  ),
  DawnHouseRiteDay(
    dayNumber: 22,
    section: 'Communal Ma\'at',
    title: 'Fair Dealing',
    purpose: 'Practice justice in ordinary exchange.',
    action: 'Set water. Think of money, work, trade, time, or obligation.',
    words:
        'May I give what is due and not take what is not mine. May my dealings be fair in word and measure.',
    maatAct:
        'Pay, credit, compensate, return, disclose, honor a commitment, or stop an unfair advantage.',
  ),
  DawnHouseRiteDay(
    dayNumber: 23,
    section: 'Communal Ma\'at',
    title: 'Feeding the Living',
    purpose: 'Connect Ma\'at to material care.',
    action: 'Set water and, if possible, food.',
    words:
        'May the hungry be remembered. May life be sustained by more than words.',
    maatAct:
        'Feed someone, donate, share resources, cook, check on someone, or nourish yourself properly so you can serve.',
  ),
  DawnHouseRiteDay(
    dayNumber: 24,
    section: 'Communal Ma\'at',
    title: 'Protecting the Vulnerable',
    purpose: 'Resist the disorder of neglect and exploitation.',
    action: 'Touch water to hands. Hold them open.',
    words:
        'May my strength not harm the weak. May I protect where protection is mine to give.',
    maatAct:
        'Help a child, elder, sick person, worker, animal, neighbor, or anyone with less power in the situation.',
  ),
  DawnHouseRiteDay(
    dayNumber: 25,
    section: 'Communal Ma\'at',
    title: 'True Witness',
    purpose: 'See and name reality without distortion.',
    action: 'Wash face or eyes. Look toward the light.',
    words:
        'May I witness truly. May I not hide what must be seen or invent what is not there.',
    maatAct:
        'Correct one falsehood, refuse exaggeration, document accurately, or listen before judging.',
  ),
  DawnHouseRiteDay(
    dayNumber: 26,
    section: 'Communal Ma\'at',
    title: 'Restraint',
    purpose: 'Prevent disorder before it grows.',
    action:
        'Set water. Take one breath before touching your phone, work, or obligations.',
    words:
        'May restraint guard the day. Not every fire needs my breath. Not every conflict needs my hand.',
    maatAct:
        'Do not escalate one situation. Do not answer immediately if haste would create harm.',
  ),
  DawnHouseRiteDay(
    dayNumber: 27,
    section: 'Communal Ma\'at',
    title: 'Service',
    purpose: 'Make Ma\'at visible through useful action.',
    action: 'Wash hands. Name one person, group, or place that needs care.',
    words:
        'May I be of use. May service be done without pride and without resentment.',
    maatAct:
        'Do one concrete service: carry, clean, call, donate, teach, repair, volunteer, or assist.',
  ),
  DawnHouseRiteDay(
    dayNumber: 28,
    section: 'Communal Ma\'at',
    title: 'Reconciliation',
    purpose: 'Restore right relationship where possible.',
    action:
        'Set water. Think of one strained relationship or community tension.',
    words:
        'May anger not be fed beyond its need. May truth and repair find the path that pride cannot find.',
    maatAct:
        'Make peace where appropriate, apologize, clarify, forgive, set a clean boundary, or stop feeding resentment.',
  ),
  DawnHouseRiteDay(
    dayNumber: 29,
    section: 'Communal Ma\'at',
    title: 'Shared Order',
    purpose: 'Recognize that Ma\'at is collective, not private perfection.',
    action:
        'Face the light. Set water. Name your wider circle: neighborhood, workplace, family, city, land, or online community.',
    words:
        'May the order I keep serve more than myself. May my portion of the world be steadier because I passed through it.',
    maatAct:
        'Improve one shared space: clean, organize, report, plant, help, moderate, protect, or contribute.',
  ),
  DawnHouseRiteDay(
    dayNumber: 30,
    section: 'Communal Ma\'at',
    title: 'Completion and Return',
    purpose: 'Complete the full thirty-day cycle and prepare to begin again.',
    action:
        'Wash hands, face, and mouth if possible. Set fresh water. Review the whole cycle without guilt.',
    words:
        'Thirty dawns have opened. What was done in Ma\'at may endure. What was neglected may be restored. I return to the beginning renewed.',
    maatAct:
        'Name one truth learned, one repair still needed, and one practice to carry into the next cycle.',
  ),
];

bool _dawnHouseRiteTimeZonesInitialized = false;

void _ensureDawnHouseRiteTimeZonesInitialized() {
  if (_dawnHouseRiteTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _dawnHouseRiteTimeZonesInitialized = true;
}

DateTime defaultDawnHouseRiteStartDate(
  TrackSkyTimeZone timezone, {
  DateTime? now,
}) {
  final nowLocal = dawnHouseRiteNowInZone(timezone, now: now);
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final todayDawn = dawnHouseRiteScheduleForDate(today, timezone).startLocal;
  if (!todayDawn.isBefore(nowLocal)) return today;
  return today.add(const Duration(days: 1));
}

DateTime dawnHouseRiteNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureDawnHouseRiteTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromZonedDateTime(zoned);
}

DawnHouseRiteOccurrenceSchedule dawnHouseRiteScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone,
) {
  _ensureDawnHouseRiteTimeZonesInitialized();
  final localDate = DateTime(date.year, date.month, date.day);
  final reference = kDawnHouseRiteReferenceLocations[timezone]!;
  final astronomicalDawnUtc = _solarRisingUtc(
    localDate,
    reference,
    zenithDegrees: 108,
  );
  final sunriseUtc = _solarRisingUtc(
    localDate,
    reference,
    zenithDegrees: 90.833,
  );
  final startUtc =
      astronomicalDawnUtc ??
      sunriseUtc?.subtract(const Duration(minutes: 15)) ??
      tz.TZDateTime(
        tz.getLocation(timezone.ianaName),
        localDate.year,
        localDate.month,
        localDate.day,
        6,
      ).toUtc();
  final endUtc = startUtc.add(
    const Duration(minutes: kDawnHouseRiteDurationMinutes),
  );
  final location = tz.getLocation(timezone.ianaName);

  return DawnHouseRiteOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: astronomicalDawnUtc == null,
    timezone: timezone,
    referenceLocation: reference,
  );
}

String dawnHouseRiteEventTitle(DawnHouseRiteDay day) {
  return 'Day ${day.dayNumber}: ${day.title}';
}

String dawnHouseRiteActionId(DawnHouseRiteDay day) {
  return 'dawn-house-rite-day-${day.dayNumber.toString().padLeft(2, '0')}';
}

DawnHouseRiteDay? dawnHouseRiteDayByNumber(int? dayNumber) {
  if (dayNumber == null) return null;
  for (final day in kDawnHouseRiteDays) {
    if (day.dayNumber == dayNumber) return day;
  }
  return null;
}

DawnHouseRiteLens? dawnHouseRiteLensFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final lens in DawnHouseRiteLens.values) {
    if (lens.key == normalized) return lens;
  }
  return null;
}

bool dawnHouseRiteDiscreetFromNotes(String? notes, {bool fallback = false}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim().toLowerCase();
    if (trimmed == 'dawn_discreet=1' || trimmed == 'dawn_discreet=true') {
      return true;
    }
    if (trimmed == 'dawn_discreet=0' || trimmed == 'dawn_discreet=false') {
      return false;
    }
  }
  return fallback;
}

DawnHouseRiteLens dawnHouseRiteLensFromNotes(
  String? notes, {
  DawnHouseRiteLens fallback = DawnHouseRiteLens.neutral,
}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('dawn_lens=')) continue;
    return dawnHouseRiteLensFromKey(trimmed.substring('dawn_lens='.length)) ??
        fallback;
  }
  return fallback;
}

bool isDawnHouseRiteFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.dawnHouseRite,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

DawnHouseRiteDay? dawnHouseRiteDayForEvent({
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  int? parseDay(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  final payloadDay = dawnHouseRiteDayByNumber(
    parseDay(behaviorPayload?['day']),
  );
  if (payloadDay != null) return payloadDay;

  final actionMatch = RegExp(
    r'dawn-house-rite-day-(\d{1,2})',
    caseSensitive: false,
  ).firstMatch(actionId?.trim() ?? '');
  final actionDay = dawnHouseRiteDayByNumber(parseDay(actionMatch?.group(1)));
  if (actionDay != null) return actionDay;

  final titleMatch = RegExp(
    r'^\s*Day\s+(\d{1,2})\s*:',
    caseSensitive: false,
  ).firstMatch(title?.trim() ?? '');
  return dawnHouseRiteDayByNumber(parseDay(titleMatch?.group(1)));
}

String? canonicalDawnHouseRiteDetailTextForEvent({
  String? flowName,
  String? flowNotes,
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  if (!isDawnHouseRiteFlowReference(
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  )) {
    return null;
  }

  final day = dawnHouseRiteDayForEvent(
    title: title,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
  if (day == null) return null;

  final rawDiscreet = behaviorPayload?['discreet_mode'];
  final discreet = rawDiscreet is bool
      ? rawDiscreet
      : dawnHouseRiteDiscreetFromNotes(flowNotes);
  final lens =
      dawnHouseRiteLensFromKey(behaviorPayload?['lens']?.toString()) ??
      dawnHouseRiteLensFromNotes(flowNotes);

  return dawnHouseRiteDetailText(day, discreet: discreet, lens: lens);
}

Map<String, dynamic> dawnHouseRiteBehaviorPayload({
  required DawnHouseRiteDay day,
  required DawnHouseRiteOccurrenceSchedule schedule,
  required bool discreet,
  required DawnHouseRiteLens lens,
}) {
  return <String, dynamic>{
    'kind': 'maat_dawn_house_rite_day',
    'flow_key': kDawnHouseRiteFlowKey,
    'day': day.dayNumber,
    'duration_minutes': kDawnHouseRiteDurationMinutes,
    'missed_event_rule': 'expire_quietly',
    'schedule': <String, dynamic>{
      'type': 'local_astronomical_dawn',
      'fallback': 'sunrise_minus_15_minutes',
      'used_fallback': schedule.usedFallback,
      'timezone': schedule.timezone.key,
      'iana_timezone': schedule.timezone.ianaName,
      'reference_location': schedule.referenceLocation.name,
    },
    'discreet_mode': discreet,
    'lens': lens.key,
  };
}

String dawnHouseRiteDetailText(
  DawnHouseRiteDay day, {
  required bool discreet,
  required DawnHouseRiteLens lens,
}) {
  final purpose = _dawnHouseRiteVisibleText(day.purpose, discreet: discreet);
  final action = _dawnHouseRiteVisibleText(day.action, discreet: discreet);
  final words = _dawnHouseRiteVisibleText(day.words, discreet: discreet);
  final act = _dawnHouseRiteVisibleText(day.maatAct, discreet: discreet);
  final lensLine = _dawnHouseRiteVisibleText(
    lens.detailLine(discreet: discreet),
    discreet: discreet,
  );
  final actLabel = discreet ? 'Order act' : 'Ma\'at act';

  return <String>[
    'Purpose\n$purpose',
    'Action\n$action',
    'Words\n"$words"',
    '$actLabel\n$act',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
  ].join('\n\n');
}

String _dawnHouseRiteVisibleText(String input, {required bool discreet}) {
  if (!discreet) return input;
  var text = input;
  text = text.replaceAllMapped(
    RegExp(r"\bMa(?:'|’|ʿ)?at\b", caseSensitive: false),
    (match) => match.group(0)!.startsWith('M') ? 'Right order' : 'right order',
  );
  text = text.replaceAll(
    RegExp(r'\bofferings\b', caseSensitive: false),
    'signs of care',
  );
  text = text.replaceAll(
    RegExp(r'\boffering\b', caseSensitive: false),
    'sign of care',
  );
  text = text.replaceAll(
    RegExp(r'\baltar\b', caseSensitive: false),
    'quiet place',
  );
  text = text.replaceAll(
    RegExp(r'\bshrine\b', caseSensitive: false),
    'quiet place',
  );
  text = text.replaceAll(RegExp(r'\bincense\b', caseSensitive: false), 'scent');
  text = text.replaceAll(RegExp(r'\bflame\b', caseSensitive: false), 'light');
  text = text.replaceAll(RegExp(r'\bRa\b'), 'the sun');
  text = text.replaceAll(RegExp(r'\bThoth\b'), 'clear record');
  return text;
}

DateTime? _solarRisingUtc(
  DateTime localDate,
  DawnHouseRiteReferenceLocation location, {
  required double zenithDegrees,
}) {
  final dayOfYear =
      localDate.difference(DateTime(localDate.year, 1, 1)).inDays + 1;
  final lngHour = location.longitude / 15.0;
  final approximateTime = dayOfYear + ((6.0 - lngHour) / 24.0);
  final meanAnomaly = (0.9856 * approximateTime) - 3.289;
  final trueLongitude = _normalizeDegrees(
    meanAnomaly +
        (1.916 * math.sin(_degreesToRadians(meanAnomaly))) +
        (0.020 * math.sin(_degreesToRadians(2 * meanAnomaly))) +
        282.634,
  );

  var rightAscension = _radiansToDegrees(
    math.atan(0.91764 * math.tan(_degreesToRadians(trueLongitude))),
  );
  rightAscension = _normalizeDegrees(rightAscension);
  final longitudeQuadrant = (trueLongitude / 90).floor() * 90;
  final ascensionQuadrant = (rightAscension / 90).floor() * 90;
  rightAscension =
      (rightAscension + longitudeQuadrant - ascensionQuadrant) / 15;

  final sinDeclination = 0.39782 * math.sin(_degreesToRadians(trueLongitude));
  final cosDeclination = math.cos(math.asin(sinDeclination));
  final latitudeRadians = _degreesToRadians(location.latitude);
  final cosHourAngle =
      (math.cos(_degreesToRadians(zenithDegrees)) -
          (sinDeclination * math.sin(latitudeRadians))) /
      (cosDeclination * math.cos(latitudeRadians));

  if (cosHourAngle.isNaN || cosHourAngle < -1 || cosHourAngle > 1) {
    return null;
  }

  final hourAngle = (360 - _radiansToDegrees(math.acos(cosHourAngle))) / 15.0;
  final localMeanTime =
      hourAngle + rightAscension - (0.06571 * approximateTime) - 6.622;
  final utcHour = _normalizeHours(localMeanTime - lngHour);
  final minutes = (utcHour * 60).round();
  return DateTime.utc(
    localDate.year,
    localDate.month,
    localDate.day,
  ).add(Duration(minutes: minutes));
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;

double _radiansToDegrees(double radians) => radians * 180.0 / math.pi;

double _normalizeDegrees(double degrees) {
  final normalized = degrees % 360.0;
  return normalized < 0 ? normalized + 360.0 : normalized;
}

double _normalizeHours(double hours) {
  final normalized = hours % 24.0;
  return normalized < 0 ? normalized + 24.0 : normalized;
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
