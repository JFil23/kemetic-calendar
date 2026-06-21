import 'dart:math' as math;

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'track_sky_flow.dart';

const String kEveningThresholdRiteFlowKey = 'evening-threshold-rite';
const String kEveningThresholdRiteTitle = 'The Closing';
const String kEveningThresholdRiteLegacyTitle = 'Evening Threshold Rite';
const int kEveningThresholdRiteDurationMinutes = 3;
const int kEveningThresholdDefaultFallbackMinutes = 20 * 60;

const String kEveningThresholdRiteOverview =
    'The Evening Threshold Rite is a thirty-day sunset flow rooted in the Egyptian pattern of evening as a passage from visible action into hidden renewal. '
    'The report grounds this flow in the Evening Barge and the wider solar journey: as the sun leaves the seen world, the day’s work is closed, cooled, ordered, and released before the hidden hours begin. '
    'Each evening, the user pauses at sunset + 20 minutes, closes one open loop, clears one small disorder, offers gratitude or water, dims or extinguishes one light, and speaks a short line of release. '
    'Across three ten-day movements—closing the visible day, settling the house, and entering hidden renewal—the rite turns evening into a daily act of ma’at: finishing what can be finished, releasing what must wait, and preparing the self and home for restoration.';

enum EveningThresholdRiteLens {
  neutral,
  solar,
  ancestor,
  household,
  protection,
  hiddenRenewal,
}

extension EveningThresholdRiteLensX on EveningThresholdRiteLens {
  String get key {
    switch (this) {
      case EveningThresholdRiteLens.neutral:
        return 'neutral';
      case EveningThresholdRiteLens.solar:
        return 'solar';
      case EveningThresholdRiteLens.ancestor:
        return 'ancestor';
      case EveningThresholdRiteLens.household:
        return 'household';
      case EveningThresholdRiteLens.protection:
        return 'protection';
      case EveningThresholdRiteLens.hiddenRenewal:
        return 'hidden_renewal';
    }
  }

  String get label {
    switch (this) {
      case EveningThresholdRiteLens.neutral:
        return 'Neutral';
      case EveningThresholdRiteLens.solar:
        return 'Solar';
      case EveningThresholdRiteLens.ancestor:
        return 'Ancestor';
      case EveningThresholdRiteLens.household:
        return 'Household';
      case EveningThresholdRiteLens.protection:
        return 'Protection';
      case EveningThresholdRiteLens.hiddenRenewal:
        return 'Hidden Renewal';
    }
  }

  String detailLine({required bool discreet}) {
    switch (this) {
      case EveningThresholdRiteLens.neutral:
        return '';
      case EveningThresholdRiteLens.solar:
        return 'Notice sunset as the beginning of the hidden solar journey toward renewal.';
      case EveningThresholdRiteLens.ancestor:
        return 'Let remembrance enter the quiet hours with steadiness and care.';
      case EveningThresholdRiteLens.household:
        return 'Let the rite settle the rooms, shared resources, and speech at home.';
      case EveningThresholdRiteLens.protection:
        return 'Close one boundary that protects rest, safety, truth, or peace.';
      case EveningThresholdRiteLens.hiddenRenewal:
        return discreet
            ? 'Let quiet restore what the visible day has spent.'
            : 'Enter hidden renewal as a sacred passage, not a failure of productivity.';
    }
  }
}

class EveningThresholdRiteDay {
  final int dayNumber;
  final String section;
  final String title;
  final String purpose;
  final String action;
  final String words;
  final String eveningAct;

  const EveningThresholdRiteDay({
    required this.dayNumber,
    required this.section,
    required this.title,
    required this.purpose,
    required this.action,
    required this.words,
    required this.eveningAct,
  });
}

class EveningThresholdReferenceLocation {
  final String name;
  final double latitude;
  final double longitude;

  const EveningThresholdReferenceLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class EveningThresholdOccurrenceSchedule {
  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool usedFallback;
  final TrackSkyTimeZone timezone;
  final EveningThresholdReferenceLocation referenceLocation;
  final int fallbackMinutesAfterMidnight;

  const EveningThresholdOccurrenceSchedule({
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
    required this.usedFallback,
    required this.timezone,
    required this.referenceLocation,
    required this.fallbackMinutesAfterMidnight,
  });
}

const Map<TrackSkyTimeZone, EveningThresholdReferenceLocation>
kEveningThresholdReferenceLocations =
    <TrackSkyTimeZone, EveningThresholdReferenceLocation>{
      TrackSkyTimeZone.pacific: EveningThresholdReferenceLocation(
        name: 'Los Angeles',
        latitude: 34.0522,
        longitude: -118.2437,
      ),
      TrackSkyTimeZone.mountain: EveningThresholdReferenceLocation(
        name: 'Denver',
        latitude: 39.7392,
        longitude: -104.9903,
      ),
      TrackSkyTimeZone.central: EveningThresholdReferenceLocation(
        name: 'Chicago',
        latitude: 41.8781,
        longitude: -87.6298,
      ),
      TrackSkyTimeZone.eastern: EveningThresholdReferenceLocation(
        name: 'New York',
        latitude: 40.7128,
        longitude: -74.0060,
      ),
    };

const List<EveningThresholdRiteDay>
kEveningThresholdRiteDays = <EveningThresholdRiteDay>[
  EveningThresholdRiteDay(
    dayNumber: 1,
    section: 'Closing the Visible Day',
    title: 'The Threshold',
    purpose:
        'The evening has no official start time. This rite marks one deliberately.',
    action:
        'Pause near a window, doorway, lamp, or sink. Notice that the visible day has ended.',
    words: 'The visible day closes. I step across the threshold in Ma\'at.',
    eveningAct:
        'Close one open loop: reply, schedule, write down, put away, or release until tomorrow.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 2,
    section: 'Closing the Visible Day',
    title: 'Extinguishing Excess',
    purpose:
        'The day\'s intensity rarely stops on its own. This rite interrupts it.',
    action: 'Dim one light, silence one alert, or step away from one screen.',
    words:
        'What has burned too brightly may now grow quiet. May excess fall away.',
    eveningAct: 'Remove one source of overstimulation.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 3,
    section: 'Closing the Visible Day',
    title: 'Water at Evening',
    purpose:
        'Water is the first Kemetic offering at every threshold. Evening is a threshold. Set water first.',
    action: 'Set a cup or bowl of water, or wash your hands at the sink.',
    words: 'Cool water for the close of day. May the heat of action be calmed.',
    eveningAct:
        'Drink water, wash hands, water a plant, or leave water briefly as an offering.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 4,
    section: 'Closing the Visible Day',
    title: 'The Last Honest Word',
    purpose:
        'Falsehood carried to bed changes the quality of sleep and the state you wake from. One correction here is enough.',
    action: 'Think of one thing left unsaid, misspoken, or exaggerated.',
    words:
        'May my words return to truth before night. May falsehood not follow me into rest.',
    eveningAct: 'Correct, clarify, apologize, or write the truth privately.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 5,
    section: 'Closing the Visible Day',
    title: 'Gratitude Before Hiddenness',
    purpose:
        'What you don\'t name before it disappears disappears entirely. This rite catches it while the day is still present.',
    action:
        'Name three things received today: food, help, shelter, lesson, breath, patience, protection.',
    words:
        'What sustained me is remembered. May gratitude enter the hidden hours.',
    eveningAct:
        'Thank someone, record one blessing, or acknowledge one unseen support.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 6,
    section: 'Closing the Visible Day',
    title: 'Small Disorder',
    purpose:
        'Large disorder began as small disorder ignored. This rite handles it while it\'s still small.',
    action: 'Clean or put away one small thing for two minutes.',
    words: 'A small disorder is met. May this place rest more lightly.',
    eveningAct:
        'Clear a surface, wash a cup, fold a cloth, take out trash, or set tomorrow’s item in place.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 7,
    section: 'Closing the Visible Day',
    title: 'Release of Labor',
    purpose:
        'Work that doesn\'t end spreads into sleep. This rite makes the ending official.',
    action:
        'Close a laptop, put away a tool, remove work items from view, or write tomorrow’s first task.',
    words: 'Work has its measure. The day’s labor ends where night begins.',
    eveningAct:
        'Stop one unfinished task cleanly instead of dragging it into the night.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 8,
    section: 'Closing the Visible Day',
    title: 'Cooling Anger',
    purpose:
        'Anger cools faster when named and set down than when carried. This rite creates the setting-down.',
    action: 'Wash hands or touch cool water. Exhale slowly.',
    words:
        'May anger cool before night. May I not feed what should be released.',
    eveningAct:
        'Do not send the reactive message. Delay, soften, clarify, or step away.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 9,
    section: 'Closing the Visible Day',
    title: 'Safe Passage',
    purpose:
        'The solar barge passed through the night in sequence, each hour with its own character. Your night begins with one deliberate preparation.',
    action: 'Stand still in dim light or near the threshold.',
    words:
        'The day passes into hiddenness. May I pass safely from action into renewal.',
    eveningAct:
        'Prepare one thing that helps tomorrow begin safely: keys, medicine, clothes, alarm, water, door, or route.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 10,
    section: 'Closing the Visible Day',
    title: 'First Recalibration',
    purpose:
        'What pattern appeared across the first ten closings? The recalibration asks before the next ten begin.',
    action: 'Review the past nine evenings without guilt. Set or touch water.',
    words:
        'One measure closes. What is finished may rest. What remains may return in its proper time.',
    eveningAct: 'Name one pattern to release before the next ten days.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 11,
    section: 'Settling the House',
    title: 'House at Dusk',
    purpose:
        'The house holds what the day left in it. This rite begins moving the day\'s residue out before the night settles in.',
    action: 'Walk through one room or stand at the center of the home.',
    words: 'This house crosses into evening. May peace have a place to stand.',
    eveningAct:
        'Restore one shared space: table, sink, entryway, couch, floor, or altar.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 12,
    section: 'Settling the House',
    title: 'Doorway Guard',
    purpose:
        'The doorway is not a wall — things pass through it all day. This rite names what doesn\'t cross into the night.',
    action: 'Touch the door, lock it, check it, or simply pause near it.',
    words:
        'May what belongs outside remain outside. May what belongs within be kept in peace.',
    eveningAct:
        'Close one boundary: door, message thread, work channel, spending impulse, or emotional demand.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 13,
    section: 'Settling the House',
    title: 'Evening Meal',
    purpose:
        'Eating while distracted is not receiving food. This rite makes the meal an act instead of a task.',
    action: 'Before or after food, pause with water or a plate.',
    words:
        'Food and water return strength to the house. May nourishment be received in Ma\'at.',
    eveningAct:
        'Eat with attention, share food, clean after eating, save leftovers, or avoid wasting food.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 14,
    section: 'Settling the House',
    title: 'The Quiet Surface',
    purpose:
        'One clear surface where there wasn\'t one changes the quality of the room. Order is spatial before it is psychological.',
    action:
        'Clear one surface: table, counter, desk, nightstand, sink, or altar.',
    words: 'One clear place is enough to welcome quiet. May order begin here.',
    eveningAct:
        'Clear only one surface. Do not turn it into a full cleaning session.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 15,
    section: 'Settling the House',
    title: 'Peaceful Speech',
    purpose:
        'What is said just before sleep shapes what the night holds. This rite makes the last word intentional.',
    action: 'Touch water to lips or hold silence for one breath.',
    words:
        'May speech in this house soften without losing truth. May night not inherit needless harm.',
    eveningAct:
        'Speak one kind word, end one argument, or choose silence over escalation.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 16,
    section: 'Settling the House',
    title: 'Ancestor Evening',
    purpose:
        'The dead were remembered at dusk as well as dawn. The evening name-speaking closes the day with continuity.',
    action:
        'Set water. Speak one name, family line, or "the remembered and forgotten dead."',
    words:
        'Cool water for those who came before. May the dead be remembered in peace as the day closes.',
    eveningAct:
        'Preserve memory: photo, story, name, prayer, grave care, family note, or quiet remembrance.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 17,
    section: 'Settling the House',
    title: 'Hidden Practice',
    purpose:
        'The rite performed in the dark, alone, with no record — this is the one that belongs entirely to Ma\'at rather than to the display of it.',
    action: 'Perform the rite silently at the sink, bedside, or in the dark.',
    words: 'Even unseen, Ma\'at remains. Even hidden, right action has weight.',
    eveningAct:
        'Do one private good: clean, prepare, forgive, donate, pray, or refrain from harm without announcing it.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 18,
    section: 'Settling the House',
    title: 'Lamp and Shadow',
    purpose:
        'Not every task needs completion today. This rite names what can rest in darkness without becoming abandoned.',
    action: 'Dim one lamp or turn one light off intentionally.',
    words:
        'Light has done its work. Shadow now teaches rest, protection, and renewal.',
    eveningAct:
        'Let one thing be unfinished without anxiety, if it can safely wait.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 19,
    section: 'Settling the House',
    title: 'The Cup Left Standing',
    purpose:
        'Water standing overnight is the simplest offering of continuity: the house holds still while you sleep.',
    action: 'Set a cup of clean water where the evening begins or ends.',
    words:
        'Water stands where the day has passed. May calm remain in this house.',
    eveningAct:
        'Leave water briefly, drink it, pour it out respectfully, or use it to water a plant.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 20,
    section: 'Settling the House',
    title: 'Household Recalibration',
    purpose:
        'Ten evenings of household attention. What did the house give back? What does it still need?',
    action:
        'Stand in the room where the household most gathers. Notice what has improved and what still weighs on the space.',
    words:
        'A second measure closes. May this house release what burdens it and keep what gives life.',
    eveningAct: 'Choose one household correction for the next ten evenings.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 21,
    section: 'Entering Hidden Renewal',
    title: 'Return from the World',
    purpose:
        'You carry the day\'s public self past the doorway unless you deliberately set it down. This rite makes that moment explicit.',
    action:
        'Remove one public marker: shoes, work badge, outer layer, makeup, headphones, or work posture.',
    words:
        'I return from the visible world. May what I carried be set down in order.',
    eveningAct: 'Put away one object connected to the outer day.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 22,
    section: 'Entering Hidden Renewal',
    title: 'Accounting of the Heart',
    purpose:
        'The Kemite asked the heart to give its account before the scale. This evening accounting prepares the heart before sleep applies its own judgment.',
    action:
        'Sit or stand quietly. Ask: What did I do in Ma\'at? Where did I add disorder?',
    words:
        'May I see the day truly. May praise not blind me. May fault not destroy me.',
    eveningAct: 'Name one right action and one correction.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 23,
    section: 'Entering Hidden Renewal',
    title: 'Fair Closure',
    purpose:
        'Debts carried to bed become heavier by morning. One small settlement before sleep changes the texture of what you wake into.',
    action:
        'Think of obligations: money, time, credit, response, labor, attention.',
    words:
        'May what is due be remembered. May I not carry unfairness into the night.',
    eveningAct:
        'Pay, reply, credit someone, write the reminder, or schedule the repayment.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 24,
    section: 'Entering Hidden Renewal',
    title: 'Protection Through Rest',
    purpose:
        'Rest that is not prepared is less restorative than rest that is. One preparation act changes the quality of the night.',
    action:
        'Prepare one thing that supports sleep: water, bedding, medicine, darkness, alarm, clean clothes.',
    words:
        'Rest protects life. May the hidden hours restore what the day has spent.',
    eveningAct: 'Make one practical choice that protects tomorrow’s body.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 25,
    section: 'Entering Hidden Renewal',
    title: 'Releasing Noise',
    purpose:
        'The mind has a channel underneath its daily noise. This rite is the brief interruption that lets it speak.',
    action: 'Turn off or move away from one source of noise.',
    words:
        'May the noise of the day recede. May quiet reveal what haste concealed.',
    eveningAct: 'Take three quiet minutes without media, speech, or input.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 26,
    section: 'Entering Hidden Renewal',
    title: 'Night Boundary',
    purpose:
        'The night belongs to restoration, not extension. This rite names the line between them.',
    action:
        'Set a stopping point: no more work, no more argument, no more scrolling, no more planning.',
    words:
        'The night has a boundary. I do not give it away to what cannot be completed now.',
    eveningAct: 'Choose one thing that will not cross into the night.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 27,
    section: 'Entering Hidden Renewal',
    title: 'Mercy for the Unfinished',
    purpose:
        'Unfinished is not failed. This rite places tomorrow\'s task where it belongs — in tomorrow — and closes the door.',
    action: 'Write or speak one unfinished thing and when it will return.',
    words:
        'What is unfinished is not abandoned. It returns at its proper time.',
    eveningAct: 'Put one task into tomorrow instead of holding it in the body.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 28,
    section: 'Entering Hidden Renewal',
    title: 'Deep Gratitude',
    purpose:
        'There is a level of gratitude that requires no list — just the acknowledgment that something held you through this day that did not have to. This rite names it.',
    action:
        'Set water. Name one person, force, place, ancestor, or unseen support that helped you endure.',
    words:
        'What carried me through the day is honored. May I become a support in return.',
    eveningAct: 'Send thanks, make an offering, or plan one reciprocal act.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 29,
    section: 'Entering Hidden Renewal',
    title: 'Descent into Quiet',
    purpose:
        'The sun went into hiddenness — not to die but to travel. This rite begins your own version of that passage.',
    action:
        'Lower the light. Slow your breathing. Let the room become quieter.',
    words:
        'The sun has gone into hiddenness. I too enter quiet, not as defeat, but as renewal.',
    eveningAct: 'Begin your sleep or night routine with intention.',
  ),
  EveningThresholdRiteDay(
    dayNumber: 30,
    section: 'Entering Hidden Renewal',
    title: 'Completion at the Threshold',
    purpose:
        'Thirty evenings of deliberate closing. The practice is not finished — it is established. This rite marks what changed.',
    action:
        'Wash hands. Set water. Dim or extinguish one light. Review the full flow without guilt.',
    words:
        'Thirty evenings have closed. What was finished may rest. What was learned may remain. What was broken may be repaired. I cross the threshold renewed.',
    eveningAct:
        'Name one thing to release, one thing to keep, and one thing to restore in the next cycle.',
  ),
];

bool _eveningThresholdTimeZonesInitialized = false;

void _ensureEveningThresholdTimeZonesInitialized() {
  if (_eveningThresholdTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _eveningThresholdTimeZonesInitialized = true;
}

DateTime defaultEveningThresholdRiteStartDate(
  TrackSkyTimeZone timezone, {
  DateTime? now,
  int fallbackMinutesAfterMidnight = kEveningThresholdDefaultFallbackMinutes,
}) {
  final nowLocal = eveningThresholdNowInZone(timezone, now: now);
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final tonight = eveningThresholdScheduleForDate(
    today,
    timezone,
    fallbackMinutesAfterMidnight: fallbackMinutesAfterMidnight,
  ).startLocal;
  if (!tonight.isBefore(nowLocal)) return today;
  return today.add(const Duration(days: 1));
}

DateTime eveningThresholdNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureEveningThresholdTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromZonedDateTime(zoned);
}

EveningThresholdOccurrenceSchedule eveningThresholdScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  int fallbackMinutesAfterMidnight = kEveningThresholdDefaultFallbackMinutes,
}) {
  _ensureEveningThresholdTimeZonesInitialized();
  final localDate = DateTime(date.year, date.month, date.day);
  final reference = kEveningThresholdReferenceLocations[timezone]!;
  final sunsetUtc = _solarSettingUtc(
    localDate,
    reference,
    timezone: timezone,
    zenithDegrees: 90.833,
  );
  final location = tz.getLocation(timezone.ianaName);
  final fallbackHour = fallbackMinutesAfterMidnight ~/ 60;
  final fallbackMinute = fallbackMinutesAfterMidnight % 60;
  final fallbackStartUtc = tz.TZDateTime(
    location,
    localDate.year,
    localDate.month,
    localDate.day,
    fallbackHour,
    fallbackMinute,
  ).toUtc();
  final startUtc =
      sunsetUtc?.add(const Duration(minutes: 20)) ?? fallbackStartUtc;
  final endUtc = startUtc.add(
    const Duration(minutes: kEveningThresholdRiteDurationMinutes),
  );

  return EveningThresholdOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: sunsetUtc == null,
    timezone: timezone,
    referenceLocation: reference,
    fallbackMinutesAfterMidnight: fallbackMinutesAfterMidnight,
  );
}

String eveningThresholdRiteEventTitle(EveningThresholdRiteDay day) {
  return 'Day ${day.dayNumber}: ${day.title}';
}

String eveningThresholdRiteActionId(EveningThresholdRiteDay day) {
  return 'evening-threshold-rite-day-${day.dayNumber.toString().padLeft(2, '0')}';
}

Map<String, dynamic> eveningThresholdRiteBehaviorPayload({
  required EveningThresholdRiteDay day,
  required EveningThresholdOccurrenceSchedule schedule,
  required bool discreet,
  required EveningThresholdRiteLens lens,
}) {
  return <String, dynamic>{
    'kind': 'maat_evening_threshold_rite_day',
    'flow_key': kEveningThresholdRiteFlowKey,
    'day': day.dayNumber,
    'section': day.section,
    'duration_minutes': kEveningThresholdRiteDurationMinutes,
    'burden': 'low',
    'props_profile': <String, dynamic>{
      'required': const <String>[],
      'optional': const <String>[
        'water',
        'cup_or_bowl',
        'candle_or_lamp',
        'incense',
        'journal',
      ],
    },
    'completion_options': const <String>[
      'observed',
      'partly_observed',
      'skipped',
    ],
    'missed_event_rule': 'expire_quietly',
    'schedule': <String, dynamic>{
      'type': 'local_sunset_plus_20_minutes',
      'fallback': 'user_selected_evening_time',
      'used_fallback': schedule.usedFallback,
      'timezone': schedule.timezone.key,
      'iana_timezone': schedule.timezone.ianaName,
      'reference_location': schedule.referenceLocation.name,
      'fallback_minutes_after_midnight': schedule.fallbackMinutesAfterMidnight,
    },
    'discreet_mode': discreet,
    'lens': lens.key,
  };
}

String eveningThresholdRiteDetailText(
  EveningThresholdRiteDay day, {
  required bool discreet,
  required EveningThresholdRiteLens lens,
}) {
  final purpose = _eveningThresholdVisibleText(day.purpose, discreet: discreet);
  final action = _eveningThresholdVisibleText(day.action, discreet: discreet);
  final words = _eveningThresholdVisibleText(day.words, discreet: discreet);
  final act = _eveningThresholdVisibleText(day.eveningAct, discreet: discreet);
  final lensLine = _eveningThresholdVisibleText(
    lens.detailLine(discreet: discreet),
    discreet: discreet,
  );
  final wordsLabel = discreet ? 'Quiet line' : 'Words';

  return <String>[
    'Purpose\n$purpose',
    'Action\n$action',
    '$wordsLabel\n"$words"',
    'Evening act\n$act',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
  ].join('\n\n');
}

String _eveningThresholdVisibleText(String input, {required bool discreet}) {
  if (!discreet) return input;
  var text = input;
  text = text.replaceAllMapped(
    RegExp(r"\bMa(?:'|’|ʿ)?at\b", caseSensitive: false),
    (match) => match.group(0)!.startsWith('M') ? 'Right order' : 'right order',
  );
  text = text.replaceAll(
    RegExp(r'\bofferings\b', caseSensitive: false),
    'signs of gratitude',
  );
  text = text.replaceAll(
    RegExp(r'\bas an offering\b', caseSensitive: false),
    'as a sign of gratitude',
  );
  text = text.replaceAll(
    RegExp(r'\bmake an offering\b', caseSensitive: false),
    'make a sign of gratitude',
  );
  text = text.replaceAll(
    RegExp(r'\boffering\b', caseSensitive: false),
    'sign of gratitude',
  );
  text = text.replaceAll(
    RegExp(r'\boffer\b', caseSensitive: false),
    'show gratitude',
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
  text = text.replaceAll(RegExp(r'\bcandle\b', caseSensitive: false), 'light');
  text = text.replaceAll(
    RegExp(r'\bspoken recitation\b', caseSensitive: false),
    'quiet practice',
  );
  text = text.replaceAll(
    RegExp(r'\brecitation\b', caseSensitive: false),
    'quiet practice',
  );
  text = text.replaceAll(RegExp(r'\bspoken\b', caseSensitive: false), 'quiet');
  text = text.replaceAll(RegExp(r'\bspeaks\b', caseSensitive: false), 'holds');
  text = text.replaceAll(RegExp(r'\bspeak\b', caseSensitive: false), 'hold');
  return text;
}

DateTime? _solarSettingUtc(
  DateTime localDate,
  EveningThresholdReferenceLocation location, {
  required TrackSkyTimeZone timezone,
  required double zenithDegrees,
}) {
  final dayOfYear =
      localDate.difference(DateTime(localDate.year, 1, 1)).inDays + 1;
  final lngHour = location.longitude / 15.0;
  final approximateTime = dayOfYear + ((18.0 - lngHour) / 24.0);
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

  final hourAngle = _radiansToDegrees(math.acos(cosHourAngle)) / 15.0;
  final localMeanTime =
      hourAngle + rightAscension - (0.06571 * approximateTime) - 6.622;
  final utcHour = _normalizeHours(localMeanTime - lngHour);
  final minutes = (utcHour * 60).round();
  final candidate = DateTime.utc(
    localDate.year,
    localDate.month,
    localDate.day,
  ).add(Duration(minutes: minutes));
  return _alignUtcCandidateToLocalDate(candidate, localDate, timezone);
}

DateTime _alignUtcCandidateToLocalDate(
  DateTime candidateUtc,
  DateTime localDate,
  TrackSkyTimeZone timezone,
) {
  final location = tz.getLocation(timezone.ianaName);
  final targetDate = DateTime(localDate.year, localDate.month, localDate.day);
  var aligned = candidateUtc;
  for (var i = 0; i < 3; i++) {
    final local = tz.TZDateTime.from(aligned, location);
    final candidateLocalDate = DateTime(local.year, local.month, local.day);
    final comparison = candidateLocalDate.compareTo(targetDate);
    if (comparison == 0) return aligned;
    aligned = comparison < 0
        ? aligned.add(const Duration(days: 1))
        : aligned.subtract(const Duration(days: 1));
  }
  return aligned;
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
