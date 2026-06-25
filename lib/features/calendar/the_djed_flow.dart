import 'maat_flow_identity.dart';
import 'the_weighing_flow.dart';
import 'track_sky_flow.dart';

const String kTheDjedFlowKey = 'the-djed';
const String kTheDjedTitle = 'The Djed';
const String kTheDjedGlyph = '𓊽';
const String kTheDjedTagline =
    'What holds you upright when everything around you shakes?';
const int kDjedDefaultMiddayHour = 11;
const int kDjedDefaultMiddayMinute = 0;
const int kDjedRaisingSeconds = 30;

const String kDjedConfidenceLabel =
    'Draws on the Djed pillar, annual raising, stability, contest, and uprightness.';

const String kDjedOverview =
    'The Djed is a thirty-day stability flow with nine sittings. It names what holds life upright, meets what threatens that structure, and closes with one concrete act of raising, repair, or restored support.';

enum DjedTimingSlot { openMorning, checkMidday, sealEvening }

extension DjedTimingSlotX on DjedTimingSlot {
  String get key {
    switch (this) {
      case DjedTimingSlot.openMorning:
        return 'open_morning';
      case DjedTimingSlot.checkMidday:
        return 'check_midday';
      case DjedTimingSlot.sealEvening:
        return 'seal_evening';
    }
  }

  String get label {
    switch (this) {
      case DjedTimingSlot.openMorning:
        return 'Dawn + 30 min';
      case DjedTimingSlot.checkMidday:
        return '11:00 local';
      case DjedTimingSlot.sealEvening:
        return 'Sunset + 30 min';
    }
  }
}

enum DjedLens { neutral, ausar, ptah }

extension DjedLensX on DjedLens {
  String get key {
    switch (this) {
      case DjedLens.neutral:
        return 'neutral';
      case DjedLens.ausar:
        return 'ausar';
      case DjedLens.ptah:
        return 'ptah';
    }
  }

  String get label {
    switch (this) {
      case DjedLens.neutral:
        return 'Neutral';
      case DjedLens.ausar:
        return 'Ausar';
      case DjedLens.ptah:
        return 'Ptah';
    }
  }

  String get detailLine {
    switch (this) {
      case DjedLens.neutral:
        return '';
      case DjedLens.ausar:
        return 'Let Ausar frame the raising: what was scattered is gathered, and the backbone stands again.';
      case DjedLens.ptah:
        return 'Let Ptah frame the work: structure is formed deliberately, then made stable enough to hold.';
    }
  }
}

enum SpineCondition { solid, underPressure, wobbling }

extension SpineConditionX on SpineCondition {
  String get key {
    switch (this) {
      case SpineCondition.solid:
        return 'solid';
      case SpineCondition.underPressure:
        return 'under_pressure';
      case SpineCondition.wobbling:
        return 'wobbling';
    }
  }

  String get label {
    switch (this) {
      case SpineCondition.solid:
        return 'Solid';
      case SpineCondition.underPressure:
        return 'Under pressure';
      case SpineCondition.wobbling:
        return 'Wobbling';
    }
  }
}

enum PostBattleStatus {
  moreSolid,
  unchanged,
  noLongerLoadBearing,
  released,
  needsMoreWork,
}

extension PostBattleStatusX on PostBattleStatus {
  String get key {
    switch (this) {
      case PostBattleStatus.moreSolid:
        return 'more_solid';
      case PostBattleStatus.unchanged:
        return 'unchanged';
      case PostBattleStatus.noLongerLoadBearing:
        return 'no_longer_load_bearing';
      case PostBattleStatus.released:
        return 'released';
      case PostBattleStatus.needsMoreWork:
        return 'needs_more_work';
    }
  }

  String get label {
    switch (this) {
      case PostBattleStatus.moreSolid:
        return 'More solid';
      case PostBattleStatus.unchanged:
        return 'Unchanged';
      case PostBattleStatus.noLongerLoadBearing:
        return 'No longer load-bearing';
      case PostBattleStatus.released:
        return 'Released';
      case PostBattleStatus.needsMoreWork:
        return 'Needs more work';
    }
  }
}

enum DjedLocalPromptKind {
  spineInventory,
  longestWobble,
  inventoryComplete,
  battleCommitment,
  directEngagement,
  postBattleStatus,
  prepareRaising,
  spinePractice,
  raisingRecord,
}

extension DjedLocalPromptKindX on DjedLocalPromptKind {
  String get key {
    switch (this) {
      case DjedLocalPromptKind.spineInventory:
        return 'spine_inventory';
      case DjedLocalPromptKind.longestWobble:
        return 'longest_wobble';
      case DjedLocalPromptKind.inventoryComplete:
        return 'inventory_complete';
      case DjedLocalPromptKind.battleCommitment:
        return 'battle_commitment';
      case DjedLocalPromptKind.directEngagement:
        return 'direct_engagement';
      case DjedLocalPromptKind.postBattleStatus:
        return 'post_battle_status';
      case DjedLocalPromptKind.prepareRaising:
        return 'prepare_raising';
      case DjedLocalPromptKind.spinePractice:
        return 'spine_practice';
      case DjedLocalPromptKind.raisingRecord:
        return 'raising_record';
    }
  }

  String get label {
    switch (this) {
      case DjedLocalPromptKind.spineInventory:
        return 'Spine inventory';
      case DjedLocalPromptKind.longestWobble:
        return 'Longest wobble';
      case DjedLocalPromptKind.inventoryComplete:
        return 'Inventory complete';
      case DjedLocalPromptKind.battleCommitment:
        return 'Mock battle commitment';
      case DjedLocalPromptKind.directEngagement:
        return 'Direct engagement record';
      case DjedLocalPromptKind.postBattleStatus:
        return 'Post-battle status';
      case DjedLocalPromptKind.prepareRaising:
        return 'Prepare the raising';
      case DjedLocalPromptKind.spinePractice:
        return 'The spine in practice';
      case DjedLocalPromptKind.raisingRecord:
        return 'What holds';
    }
  }

  String get placeholder {
    switch (this) {
      case DjedLocalPromptKind.spineInventory:
        return '4-5 load-bearing elements, each marked solid / under pressure / wobbling...';
      case DjedLocalPromptKind.longestWobble:
        return 'The longest wobble began when... One thing that would return it to solid is...';
      case DjedLocalPromptKind.inventoryComplete:
        return 'Solid items retested...\nWobbling items to restore...\nItems to release...';
      case DjedLocalPromptKind.battleCommitment:
        return 'Challenge: ...\nBy Day 19 I will directly engage by...';
      case DjedLocalPromptKind.directEngagement:
        return 'What happened / what obstacle remains / what will move before Day 19...';
      case DjedLocalPromptKind.postBattleStatus:
        return 'More solid / unchanged / no longer load-bearing / released / needs more work...';
      case DjedLocalPromptKind.prepareRaising:
        return 'Surviving spine elements and one strengthening act for each...';
      case DjedLocalPromptKind.spinePractice:
        return 'One moment the spine was tested in the last 10 days...';
      case DjedLocalPromptKind.raisingRecord:
        return 'What holds after 30 days is...';
    }
  }
}

class DjedEvent {
  final int eventNumber;
  final int flowDay;
  final String decanSection;
  final String title;
  final DjedTimingSlot slot;
  final int durationMinutesMin;
  final int durationMinutesMax;
  final String spokenLine;
  final List<String> steps;
  final String? sourceNote;
  final bool requiresDirectEngagement;
  final bool physicalRaising;
  final bool sharePromptOnComplete;
  final DjedLocalPromptKind localPrompt;

  const DjedEvent({
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
    this.requiresDirectEngagement = false,
    this.physicalRaising = false,
    this.sharePromptOnComplete = false,
  });
}

class DjedOccurrenceSchedule {
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

  const DjedOccurrenceSchedule({
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

const List<DjedEvent> kDjedEvents = <DjedEvent>[
  DjedEvent(
    eventNumber: 1,
    flowDay: 1,
    decanSection: 'name_the_spine',
    title: 'What Is Your Spine?',
    slot: DjedTimingSlot.openMorning,
    durationMinutesMin: 8,
    durationMinutesMax: 10,
    spokenLine:
        'Become established, become established, established one. Your identity will endure with people even as your identity comes to be with the gods.',
    steps: <String>[
      'Name four or five load-bearing elements of your life right now: practices, relationships, commitments, structures, or truths.',
      'For each, mark the current condition: solid, under pressure, or wobbling.',
      'Circle the wobbling elements. These become the material for the mock battle.',
    ],
    localPrompt: DjedLocalPromptKind.spineInventory,
    sourceNote:
        'The Djed pillar was Ausar\'s backbone — what remained when everything else was scattered. Your spine is the same: what persists when the rest is under pressure. Name it before the mock battle begins.',
  ),
  DjedEvent(
    eventNumber: 2,
    flowDay: 5,
    decanSection: 'name_the_spine',
    title: 'Name What Has Been Drifting',
    slot: DjedTimingSlot.checkMidday,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'Stable in the city of the Djed. What is load-bearing must be named to hold.',
    steps: <String>[
      'Choose the wobbling or pressured element that has been drifting longest.',
      'Name when the wobble began: what changed, stopped, or accumulated?',
      'Name one real thing that would return this element toward solid.',
    ],
    localPrompt: DjedLocalPromptKind.longestWobble,
    sourceNote:
        'Being stable in Djedut — the City of the Djed — was a specific Pyramid Texts aspiration: where the backbone held even amid what pressed against it. The longest wobble is the one most in need of that stability.',
  ),
  DjedEvent(
    eventNumber: 3,
    flowDay: 9,
    decanSection: 'name_the_spine',
    title: 'The Spine Inventory Complete',
    slot: DjedTimingSlot.openMorning,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'Your identity will endure with people even as your identity comes to be with the gods. What endures is what holds. What is named must be real.',
    steps: <String>[
      'Retest every element marked solid: is it actually solid, or simply untested?',
      'For every wobbling element, decide whether it should be restored, rebuilt, or released.',
      'Enter Decan 2 knowing exactly what goes into the mock battle.',
    ],
    localPrompt: DjedLocalPromptKind.inventoryComplete,
    sourceNote: 'Event 3 closes Decan 1 at dawn by specification, not evening.',
  ),
  DjedEvent(
    eventNumber: 4,
    flowDay: 11,
    decanSection: 'mock_battle',
    title: 'The Mock Battle Begins',
    slot: DjedTimingSlot.openMorning,
    durationMinutesMin: 8,
    durationMinutesMax: 8,
    spokenLine:
        'The Djed holds after the battle, not before it. What threatens the spine is engaged directly. I do not manage around what challenges my foundation.',
    steps: <String>[
      'For each wobbling element, name the specific challenge. Battle means direct engagement with the threat, not harmful confrontation.',
      'Choose the most significant challenge and define one concrete direct engagement act.',
      'Commit: By Day 19, I will directly engage ___ by doing ___.',
    ],
    localPrompt: DjedLocalPromptKind.battleCommitment,
    sourceNote:
        'The Djed Pillar Festival included a mock battle because raising the pillar without engaging what had knocked it over was decoration, not restoration. The battle is the prerequisite.',
  ),
  DjedEvent(
    eventNumber: 5,
    flowDay: 15,
    decanSection: 'mock_battle',
    title: 'Engage the Challenge Directly',
    slot: DjedTimingSlot.checkMidday,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'Before checking the commitment, speak: Unis, raise yourself from your side! Do my command, you who hate sleep but were made slack. Then check: has the engagement happened?',
    steps: <String>[
      'Check whether the direct engagement committed on Day 11 has happened.',
      'If yes, record what occurred in one honest sentence.',
      'If no, name the obstacle and what must move for the engagement to happen before Day 19.',
      'Do it today if possible. The battle must occur before the Djed is raised.',
    ],
    localPrompt: DjedLocalPromptKind.directEngagement,
    requiresDirectEngagement: true,
    sourceNote:
        'Drawn from Pyramid Texts, Utterance 158: Stand up from slackness and act.',
  ),
  DjedEvent(
    eventNumber: 6,
    flowDay: 19,
    decanSection: 'mock_battle',
    title: 'What Survived the Battle',
    slot: DjedTimingSlot.sealEvening,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine: 'Stand up! Raise yourself like Ausar (Osiris)!',
    steps: <String>[
      'Return to the wobbling elements from Decan 1.',
      'After direct engagement, mark each one: more solid, unchanged, no longer load-bearing, released, or needs more work.',
      'If Event 5 was missed, record what actually happened. Ma’at does not require a false victory.',
      'Name what remains to be raised in Decan 3.',
    ],
    localPrompt: DjedLocalPromptKind.postBattleStatus,
    sourceNote:
        'Drawn from Pyramid Texts, Utterance 145: the command to stand and raise.',
  ),
  DjedEvent(
    eventNumber: 7,
    flowDay: 21,
    decanSection: 'raise_the_djed',
    title: 'Prepare the Raising',
    slot: DjedTimingSlot.openMorning,
    durationMinutesMin: 8,
    durationMinutesMax: 8,
    spokenLine:
        'Become established, become established. The spine that has passed through the battle now stands. I prepare what will be raised.',
    steps: <String>[
      'Name the spine elements that survived the second decan engagement.',
      'For each surviving element, name one act in this decan that strengthens it.',
      'Compare the spine now to Day 1: what is actually load-bearing?',
    ],
    localPrompt: DjedLocalPromptKind.prepareRaising,
    sourceNote:
        'The Djed raising was celebratory: the spine that survived contest is prepared to stand.',
  ),
  DjedEvent(
    eventNumber: 8,
    flowDay: 25,
    decanSection: 'raise_the_djed',
    title: 'The Spine in Practice',
    slot: DjedTimingSlot.checkMidday,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'What stands is what holds. What holds is what endures. What endures is what can be raised.',
    steps: <String>[
      'Name one moment in the last 10 days when a load-bearing element was tested.',
      'Name one way your relationship to what holds you upright has changed.',
      'Optional: place a hand on the physical spine and notice what holds without announcement.',
      'Prepare standing room: the next event requires standing and raising the arms for about 30 seconds.',
    ],
    localPrompt: DjedLocalPromptKind.spinePractice,
    sourceNote: 'This event previews the physical raising required at Event 9.',
  ),
  DjedEvent(
    eventNumber: 9,
    flowDay: 29,
    decanSection: 'raise_the_djed',
    title: 'The Raising',
    slot: DjedTimingSlot.openMorning,
    durationMinutesMin: 10,
    durationMinutesMax: 15,
    spokenLine:
        'Stand up! Raise yourself like Ausar (Osiris)! Become established, become established. The Djed is raised. The spine holds. The identity endures.',
    steps: <String>[
      'Name the spine elements that held across the full cycle.',
      'Stand upright with your spine straight. Raise your arms and hold for approximately thirty seconds. The body declares what the record produced.',
      'Speak the closing line while standing.',
      'Choose the maintenance practice that keeps the Djed upright.',
    ],
    localPrompt: DjedLocalPromptKind.raisingRecord,
    physicalRaising: true,
    sharePromptOnComplete: true,
    sourceNote:
        'The Djed was physically hauled upright by ropes while priests held the opposing lines. The raising was labor before it was ceremony. This final event requires the body to do the same: the claim is spoken while standing, not seated.',
  ),
];

DateTime djedEventDate(DateTime startDate, DjedEvent event) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  return DateTime(start.year, start.month, start.day + event.flowDay - 1);
}

DateTime djedNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  return theWeighingNowInZone(timezone, now: now);
}

DjedOccurrenceSchedule djedScheduleForEvent(
  DjedEvent event,
  DateTime flowStart,
  TrackSkyTimeZone timezone, {
  int middayHour = kDjedDefaultMiddayHour,
  int middayMinute = kDjedDefaultMiddayMinute,
}) {
  final date = djedEventDate(flowStart, event);
  switch (event.slot) {
    case DjedTimingSlot.openMorning:
      return _fromWeighingSchedule(
        weighingMorningScheduleForDate(
          date,
          timezone,
          durationMinutes: event.durationMinutesMax,
        ),
      );
    case DjedTimingSlot.checkMidday:
      return _fromWeighingSchedule(
        weighingMiddayScheduleForDate(
          date,
          timezone,
          durationMinutes: event.durationMinutesMax,
          hour: middayHour,
          minute: middayMinute,
        ),
      );
    case DjedTimingSlot.sealEvening:
      return _fromWeighingSchedule(
        weighingEveningScheduleForDate(
          date,
          timezone,
          durationMinutes: event.durationMinutesMax,
        ),
      );
  }
}

DjedOccurrenceSchedule _fromWeighingSchedule(
  TheWeighingOccurrenceSchedule schedule,
) {
  return DjedOccurrenceSchedule(
    startLocal: schedule.startLocal,
    endLocal: schedule.endLocal,
    startUtc: schedule.startUtc,
    endUtc: schedule.endUtc,
    usedFallback: schedule.usedFallback,
    timezone: schedule.timezone,
    referenceLocationName: schedule.referenceLocationName,
    scheduleType: schedule.scheduleType,
    fallback: schedule.fallback,
    middayHour: schedule.middayHour,
    middayMinute: schedule.middayMinute,
  );
}

String djedEventTitle(DjedEvent event) {
  return 'Djed ${event.eventNumber}: ${event.title}';
}

String djedActionId(DjedEvent event) {
  return 'the-djed-event-${event.eventNumber.toString().padLeft(2, '0')}';
}

String djedClientEventId({required int flowId, required DjedEvent event}) {
  return 'djed:$flowId:event-${event.eventNumber}';
}

DjedEvent? djedEventByNumber(int? eventNumber) {
  if (eventNumber == null) return null;
  for (final event in kDjedEvents) {
    if (event.eventNumber == eventNumber) return event;
  }
  return null;
}

DjedLens? djedLensFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final lens in DjedLens.values) {
    if (lens.key == normalized) return lens;
  }
  return null;
}

DjedLens djedLensFromNotes(
  String? notes, {
  DjedLens fallback = DjedLens.neutral,
}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('djed_lens=')) continue;
    return djedLensFromKey(trimmed.substring('djed_lens='.length)) ?? fallback;
  }
  return fallback;
}

bool isDjedFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.theDjed,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

DjedEvent? djedEventForEvent({
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  int? parseNumber(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  final payloadEvent = djedEventByNumber(
    parseNumber(behaviorPayload?['event_number']),
  );
  if (payloadEvent != null) return payloadEvent;

  final actionMatch = RegExp(
    r'the-djed-event-(\d{1,2})',
    caseSensitive: false,
  ).firstMatch(actionId?.trim() ?? '');
  final actionEvent = djedEventByNumber(parseNumber(actionMatch?.group(1)));
  if (actionEvent != null) return actionEvent;

  final titleMatch = RegExp(
    r'^\s*Djed\s+(\d{1,2})\s*:',
    caseSensitive: false,
  ).firstMatch(title?.trim() ?? '');
  return djedEventByNumber(parseNumber(titleMatch?.group(1)));
}

String? canonicalDjedDetailTextForEvent({
  String? flowName,
  String? flowNotes,
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  if (!isDjedFlowReference(
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  )) {
    return null;
  }
  final event = djedEventForEvent(
    title: title,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
  if (event == null) return null;
  final lens =
      djedLensFromKey(behaviorPayload?['lens']?.toString()) ??
      djedLensFromNotes(flowNotes);
  return djedDetailText(event, lens: lens);
}

Map<String, dynamic> djedBehaviorPayload({
  required DjedEvent event,
  required DjedOccurrenceSchedule schedule,
  required DjedLens lens,
}) {
  return <String, dynamic>{
    'kind': 'maat_djed_event',
    'flow_key': kTheDjedFlowKey,
    'event_number': event.eventNumber,
    'flow_day': event.flowDay,
    'decan_section': event.decanSection,
    'timing_slot': event.slot.key,
    'requires_direct_engagement': event.requiresDirectEngagement,
    'physical_raising': event.physicalRaising,
    'raising_seconds': event.physicalRaising ? kDjedRaisingSeconds : null,
    'missed_event_rule': 'expire_quietly',
    'completion_options': event.physicalRaising
        ? const <String>['raised', 'observed', 'observed_partly', 'skipped']
        : const <String>['observed', 'observed_partly', 'skipped'],
    'share_prompt_on_complete': event.sharePromptOnComplete,
    'duration_minutes': event.durationMinutesMax,
    'duration_minutes_min': event.durationMinutesMin,
    'duration_minutes_max': event.durationMinutesMax,
    'burden': event.physicalRaising ? 'low_medium' : 'low',
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

String djedDetailText(DjedEvent event, {required DjedLens lens}) {
  final lensLine = lens.detailLine.trim();
  return <String>[
    'Purpose\n${_djedPurpose(event)}',
    if (event.eventNumber == 8)
      'Next Event\nThe next event requires standing room for about 30 seconds.',
    if (event.physicalRaising)
      'Raise First\nStand upright, raise your arms for about 30 seconds, then speak the required line before marking Raised.',
    if (event.requiresDirectEngagement)
      'Direct engagement\nChoose a concrete stabilizing act: a conversation, stopping a pattern, restarting a practice, or making a decision that addresses the structural threat.',
    'Words\n"${event.spokenLine}"',
    'Steps\n${_numberedLines(event.steps)}',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
  ].join('\n\n');
}

String djedTimingLabel(DjedEvent event) {
  switch (event.slot) {
    case DjedTimingSlot.openMorning:
      return 'Day ${event.flowDay} · dawn + 30 min';
    case DjedTimingSlot.checkMidday:
      return 'Day ${event.flowDay} · 11:00 local';
    case DjedTimingSlot.sealEvening:
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

String _djedPurpose(DjedEvent event) {
  switch (event.eventNumber) {
    case 1:
      return 'The spine is what holds when everything around it is pressing. Not the aspirational structure — the actual load-bearing elements. Name what is currently holding you upright, not what should be.';
    case 2:
      return 'The wobble that has been going longest is usually the one that has been quietly justified, tolerated, or renamed as acceptable. This sitting finds it.';
    case 3:
      return 'Complete the spine inventory at dawn before the mock battle begins.';
    case 4:
      return 'The Djed was raised after a ceremonial battle, not before one. What threatens the spine is engaged directly — not in anger, not in confrontation, but in the specific act that meets the challenge instead of managing around it.';
    case 5:
      return 'The midpoint check asks whether the battle happened — not whether it was won. The engagement is the event.';
    case 6:
      return 'Record what survived the battle without forcing a false victory.';
    case 7:
      return 'Prepare the spine elements that remain to be strengthened and raised.';
    case 8:
      return 'Test whether the spine has functioned in daily pressure and prepare physical space for the raising.';
    case 9:
      return 'The raising requires the body. This is not metaphorical — the Djed was physically raised. This event requires you to stand, lift your arms, and declare what holds while the body enacts the claim.';
  }
  return 'Become established.';
}
