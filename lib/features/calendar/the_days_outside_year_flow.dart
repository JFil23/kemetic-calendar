const String kDaysOutsideTheYearFlowKey = 'the-days-outside-the-year';
const String kDaysOutsideTheYearTitle = 'The Days Outside the Year';
const String kDaysOutsideTheYearGlyph = '𓆱';
const String kDaysOutsideTheYearTagline =
    'Five days that do not belong to any year. Receive what is born in them.';
const String kDaysOutsideTheYearConfidenceLabel =
    'Draws on the five epagomenal days and their deity births in the Kemetic sacred calendar.';
const String kDaysOutsideTheYearOverview =
    'Close the old Kemetic year, receive the five births of Ausar, Heru Wer, Set, Aset, and Nebet-Het across the epagomenal days, then open Wep Ronpet carrying one year intention. The Days Outside the Year is annual, fixed to the calendar, and not replayed later.';

enum DaysOutsideEventKind {
  yearClosing,
  birthAusar,
  birthHeruWer,
  birthSet,
  birthAset,
  birthNebetHet,
  wepRonpetOpening,
}

extension DaysOutsideEventKindX on DaysOutsideEventKind {
  String get key {
    switch (this) {
      case DaysOutsideEventKind.yearClosing:
        return 'year_closing';
      case DaysOutsideEventKind.birthAusar:
        return 'birth_ausar';
      case DaysOutsideEventKind.birthHeruWer:
        return 'birth_heru_wer';
      case DaysOutsideEventKind.birthSet:
        return 'birth_set';
      case DaysOutsideEventKind.birthAset:
        return 'birth_aset';
      case DaysOutsideEventKind.birthNebetHet:
        return 'birth_nebet_het';
      case DaysOutsideEventKind.wepRonpetOpening:
        return 'wep_ronpet_opening';
    }
  }
}

enum DaysOutsideScheduleKind { solarDusk, solarDawn }

extension DaysOutsideScheduleKindX on DaysOutsideScheduleKind {
  String get key {
    switch (this) {
      case DaysOutsideScheduleKind.solarDusk:
        return 'solar_dusk';
      case DaysOutsideScheduleKind.solarDawn:
        return 'solar_dawn';
    }
  }

  String get label {
    switch (this) {
      case DaysOutsideScheduleKind.solarDusk:
        return 'Dusk';
      case DaysOutsideScheduleKind.solarDawn:
        return 'Dawn';
    }
  }
}

enum DaysOutsideCopyVariant { standard, setSolarEclipse2026 }

extension DaysOutsideCopyVariantX on DaysOutsideCopyVariant {
  String get key {
    switch (this) {
      case DaysOutsideCopyVariant.standard:
        return 'standard';
      case DaysOutsideCopyVariant.setSolarEclipse2026:
        return 'set_solar_eclipse_2026';
    }
  }
}

enum DaysOutsideLocalPromptKind {
  yearCloseTriple,
  ausarQuality,
  heruWerQuality,
  setQuality,
  asetQuality,
  nebetHetQuality,
  wepRonpetIntention,
}

extension DaysOutsideLocalPromptKindX on DaysOutsideLocalPromptKind {
  String get key {
    switch (this) {
      case DaysOutsideLocalPromptKind.yearCloseTriple:
        return 'year_close_triple';
      case DaysOutsideLocalPromptKind.ausarQuality:
        return 'ausar_quality';
      case DaysOutsideLocalPromptKind.heruWerQuality:
        return 'heru_wer_quality';
      case DaysOutsideLocalPromptKind.setQuality:
        return 'set_quality';
      case DaysOutsideLocalPromptKind.asetQuality:
        return 'aset_quality';
      case DaysOutsideLocalPromptKind.nebetHetQuality:
        return 'nebet_het_quality';
      case DaysOutsideLocalPromptKind.wepRonpetIntention:
        return 'wep_ronpet_intention';
    }
  }

  String get label {
    switch (this) {
      case DaysOutsideLocalPromptKind.yearCloseTriple:
        return 'Year-closing names';
      case DaysOutsideLocalPromptKind.ausarQuality:
        return 'Restoration carried';
      case DaysOutsideLocalPromptKind.heruWerQuality:
        return 'Clear sight carried';
      case DaysOutsideLocalPromptKind.setQuality:
        return 'Directed force carried';
      case DaysOutsideLocalPromptKind.asetQuality:
        return 'Effective speech carried';
      case DaysOutsideLocalPromptKind.nebetHetQuality:
        return 'Threshold witness carried';
      case DaysOutsideLocalPromptKind.wepRonpetIntention:
        return 'Year intention';
    }
  }

  String get helperText {
    switch (this) {
      case DaysOutsideLocalPromptKind.yearCloseTriple:
        return 'Name the unexpected gift, the ungiven ask, and what carries across.';
      case DaysOutsideLocalPromptKind.ausarQuality:
        return 'One line about what needs to be gathered back.';
      case DaysOutsideLocalPromptKind.heruWerQuality:
        return 'One line about what needs elevated sight or rightful position.';
      case DaysOutsideLocalPromptKind.setQuality:
        return 'One line about what force needs direction.';
      case DaysOutsideLocalPromptKind.asetQuality:
        return 'One line about what must be spoken at the right moment.';
      case DaysOutsideLocalPromptKind.nebetHetQuality:
        return 'One line about the threshold that needs witness.';
      case DaysOutsideLocalPromptKind.wepRonpetIntention:
        return 'Five one-word receipts and one year intention. Share only one word if you choose.';
    }
  }
}

class DaysOutsideEvent {
  final int eventNumber;
  final int kMonth;
  final int kDay;
  final DaysOutsideEventKind kind;
  final DaysOutsideScheduleKind schedule;
  final String title;
  final String netjeruLabel;
  final String qualityLabel;
  final String spokenLine;
  final List<String> steps;
  final String? sourceNote;
  final bool optionalShareOnComplete;
  final int durationMinutes;
  final DaysOutsideLocalPromptKind localPrompt;

  const DaysOutsideEvent({
    required this.eventNumber,
    required this.kMonth,
    required this.kDay,
    required this.kind,
    required this.schedule,
    required this.title,
    required this.netjeruLabel,
    required this.qualityLabel,
    required this.spokenLine,
    required this.steps,
    required this.localPrompt,
    this.sourceNote,
    this.optionalShareOnComplete = false,
    this.durationMinutes = 8,
  });
}

const List<DaysOutsideEvent> kDaysOutsideEvents = <DaysOutsideEvent>[
  DaysOutsideEvent(
    eventNumber: 0,
    kMonth: 12,
    kDay: 30,
    kind: DaysOutsideEventKind.yearClosing,
    schedule: DaysOutsideScheduleKind.solarDusk,
    title: 'Set Down What the Year Carried',
    netjeruLabel: '',
    qualityLabel: 'year closing',
    spokenLine:
        'The year has completed its course. What it carried is named. What is finished is finished. What continues, continues.',
    steps: <String>[
      'Name one thing the year gave you that you did not expect.',
      'Name one thing the year asked of you that you did not fully give.',
      'Name one thing that carries across the threshold into the five days.',
      'Place water while you name these three things. Drink it when done.',
    ],
    sourceNote:
        'The Stela of Amenemhet at Beni Hasan lists the end-of-year festival among annual observances. The year is completed before the threshold is crossed.',
    localPrompt: DaysOutsideLocalPromptKind.yearCloseTriple,
  ),
  DaysOutsideEvent(
    eventNumber: 1,
    kMonth: 13,
    kDay: 1,
    kind: DaysOutsideEventKind.birthAusar,
    schedule: DaysOutsideScheduleKind.solarDawn,
    title: 'Ausar - Restoration',
    netjeruLabel: 'ausar',
    qualityLabel: 'restoration',
    spokenLine:
        'Ausar (Osiris) shall live. The akh in Nedit shall live. What was scattered is gathered. What was diminished will endure.',
    steps: <String>[
      'Pause at dawn before ordinary work begins.',
      'Name one thing in the new year that needs to be gathered back.',
      'Say: This needs to be gathered back. Restoration is what I carry.',
      'Place water while you speak.',
    ],
    sourceNote:
        'Ausar enters the epagomenal days carrying the pattern of dispersal, gathering, and restoration.',
    localPrompt: DaysOutsideLocalPromptKind.ausarQuality,
    durationMinutes: 6,
  ),
  DaysOutsideEvent(
    eventNumber: 2,
    kMonth: 13,
    kDay: 2,
    kind: DaysOutsideEventKind.birthHeruWer,
    schedule: DaysOutsideScheduleKind.solarDawn,
    title: 'Heru Wer - Clear Sight',
    netjeruLabel: 'heru_wer',
    qualityLabel: 'clear sight',
    spokenLine:
        'Heru Wer (Horus the Elder), great god, lord of the sky. The eye that sees the field from above. I receive the quality of clear sight.',
    steps: <String>[
      'Go outside briefly at dawn and face east.',
      'Name what you need to see from a higher position.',
      'Name any rightful position that needs to be claimed by sound action.',
      'Say: Clear sight. Rightful position. I carry these from this day.',
    ],
    sourceNote:
        'Heru Wer is the sky-hawk whose elevated position makes accurate sight possible.',
    localPrompt: DaysOutsideLocalPromptKind.heruWerQuality,
    durationMinutes: 6,
  ),
  DaysOutsideEvent(
    eventNumber: 3,
    kMonth: 13,
    kDay: 3,
    kind: DaysOutsideEventKind.birthSet,
    schedule: DaysOutsideScheduleKind.solarDawn,
    title: 'Set - Directed Force',
    netjeruLabel: 'set',
    qualityLabel: 'directed force',
    spokenLine:
        'Set is born. Force and contest enter the world. What contests me sharpens me. I do not run from what is difficult. I place Set\'s quality in its proper position.',
    steps: <String>[
      'Name one difficult thing you have been avoiding.',
      'Ask where force in you or around you has been misdirected.',
      'Name where that force must be pointed to defend Ma\'at.',
      'Say: Directed, it defends. Unplaced, it destroys. I choose the direction.',
    ],
    sourceNote:
        'Set is the necessary force of contest and resistance; correctly placed, his strength protects the solar passage.',
    localPrompt: DaysOutsideLocalPromptKind.setQuality,
    durationMinutes: 6,
  ),
  DaysOutsideEvent(
    eventNumber: 4,
    kMonth: 13,
    kDay: 4,
    kind: DaysOutsideEventKind.birthAset,
    schedule: DaysOutsideScheduleKind.solarDawn,
    title: 'Aset - Effective Speech',
    netjeruLabel: 'aset',
    qualityLabel: 'effective speech',
    spokenLine:
        'Aset (Isis) has come. She speaks to you. Knowledge alone does nothing. Speech alone does nothing. Timed and directed speech produces effect. I carry this into the new year.',
    steps: <String>[
      'Name one true thing you know and have not yet said.',
      'Name what stops the speech: timing, fear, habit, or preparation.',
      'Name the arrangement that must be made before the word is spoken.',
      'Say: I carry Aset\'s quality: to know, wait, and speak with effect.',
    ],
    sourceNote:
        'Aset restores through knowledge, timing, and precise speech: the word spoken when the moment can receive it.',
    localPrompt: DaysOutsideLocalPromptKind.asetQuality,
    durationMinutes: 6,
  ),
  DaysOutsideEvent(
    eventNumber: 5,
    kMonth: 13,
    kDay: 5,
    kind: DaysOutsideEventKind.birthNebetHet,
    schedule: DaysOutsideScheduleKind.solarDawn,
    title: 'Nebet-Het - Threshold Witness',
    netjeruLabel: 'nebet_het',
    qualityLabel: 'threshold witness',
    spokenLine:
        'Nebet-Het (Nephthys) stands at the boundary. She guards what passes. She witnesses what cannot be fixed, only attended. I carry her quality into the new year: to stand at the threshold and remain.',
    steps: <String>[
      'Name one transition that needs presence more than a solution.',
      'Name who or what needs a threshold witness.',
      'Name the threshold you have avoided looking at directly.',
      'Say: I carry Nebet-Het\'s quality: to stand at the boundary and remain.',
    ],
    sourceNote:
        'Nebet-Het stands at boundaries, present in lament, preparation, transition, and protection.',
    localPrompt: DaysOutsideLocalPromptKind.nebetHetQuality,
    durationMinutes: 6,
  ),
  DaysOutsideEvent(
    eventNumber: 6,
    kMonth: 1,
    kDay: 1,
    kind: DaysOutsideEventKind.wepRonpetOpening,
    schedule: DaysOutsideScheduleKind.solarDawn,
    title: 'Wep Ronpet - The Year Opens',
    netjeruLabel: '',
    qualityLabel: 'year opening',
    spokenLine:
        'Wep Ronpet. The year opens. I carry the five births across the first threshold. Ausar, Heru Wer, Set, Aset, Nebet-Het - restoration, sight, directed force, effective speech, threshold witness. These are what I enter this year carrying.',
    steps: <String>[
      'Wash your hands and face at dawn.',
      'Set fresh water on the surface and say: This water is for the year that opens.',
      'Speak the five names and one word for each quality received.',
      'Name one orienting intention for the new year. Drink the water.',
    ],
    sourceNote:
        'Wep Ronpet, the Opening of the Year, begins ordinary time again after the five days outside the year.',
    optionalShareOnComplete: true,
    localPrompt: DaysOutsideLocalPromptKind.wepRonpetIntention,
  ),
];

int daysOutsideEventKYear({
  required int closingKYear,
  required DaysOutsideEvent event,
}) {
  return event.kMonth == 1 && event.kDay == 1 ? closingKYear + 1 : closingKYear;
}

DaysOutsideEvent? daysOutsideEventForNumber(int eventNumber) {
  for (final event in kDaysOutsideEvents) {
    if (event.eventNumber == eventNumber) return event;
  }
  return null;
}

DaysOutsideEvent? daysOutsideEventForEvent({String? title, String? actionId}) {
  final normalizedTitle = title?.trim().toLowerCase() ?? '';
  final normalizedAction = actionId?.trim().toLowerCase() ?? '';
  final actionMatch = RegExp(
    r'the-days-outside-year-event-(\d{2})',
  ).firstMatch(normalizedAction);
  if (actionMatch != null) {
    final number = int.tryParse(actionMatch.group(1) ?? '');
    if (number != null) return daysOutsideEventForNumber(number);
  }
  for (final event in kDaysOutsideEvents) {
    if (normalizedTitle == daysOutsideEventTitle(event).toLowerCase() ||
        normalizedTitle.contains(event.title.toLowerCase())) {
      return event;
    }
  }
  return null;
}

String daysOutsideEventTitle(DaysOutsideEvent event) {
  return 'Event ${event.eventNumber}: ${event.title}';
}

String daysOutsideActionId(DaysOutsideEvent event) {
  return 'the-days-outside-year-event-${event.eventNumber.toString().padLeft(2, '0')}';
}

String daysOutsideClientEventId({
  required int flowId,
  required int closingKYear,
  required DaysOutsideEvent event,
}) {
  return 'days-outside:$flowId:$closingKYear:${event.eventNumber}';
}

DaysOutsideCopyVariant daysOutsideCopyVariantForEvent({
  required DaysOutsideEvent event,
  required DateTime gregorianDate,
}) {
  final iso = _isoDate(gregorianDate);
  if (event.kind == DaysOutsideEventKind.birthSet && iso == '2026-08-12') {
    return DaysOutsideCopyVariant.setSolarEclipse2026;
  }
  return DaysOutsideCopyVariant.standard;
}

Map<String, dynamic> daysOutsideBehaviorPayload({
  required DaysOutsideEvent event,
  required int closingKYear,
  required String timezoneKey,
  required String ianaTimezone,
  required String scheduleType,
  required String referenceLocationName,
  required bool usedFallback,
  required DaysOutsideCopyVariant variant,
}) {
  return <String, dynamic>{
    'kind': 'maat_days_outside_year',
    'flow_key': kDaysOutsideTheYearFlowKey,
    'event_number': event.eventNumber,
    'closing_k_year': closingKYear,
    'event_k_year': daysOutsideEventKYear(
      closingKYear: closingKYear,
      event: event,
    ),
    'k_month': event.kMonth,
    'k_day': event.kDay,
    'event_kind': event.kind.key,
    'schedule_kind': event.schedule.key,
    'netjeru': event.netjeruLabel.isEmpty ? null : event.netjeruLabel,
    'quality': event.qualityLabel,
    'variant': variant.key,
    'missed_event_rule': 'expire_no_replay',
    'sequential': true,
    'completion_options': const <String>[
      'observed',
      'observed_partly',
      'skipped',
    ],
    'optional_share_on_complete': event.optionalShareOnComplete,
    'duration_minutes': event.durationMinutes,
    'local_prompt': event.localPrompt.key,
    'timezone': timezoneKey,
    'iana_timezone': ianaTimezone,
    'schedule_type': scheduleType,
    'reference_location_name': referenceLocationName,
    'used_fallback': usedFallback,
  };
}

String daysOutsideDetailText(
  DaysOutsideEvent event, {
  required int closingKYear,
  required DaysOutsideCopyVariant variant,
}) {
  final eventYear = daysOutsideEventKYear(
    closingKYear: closingKYear,
    event: event,
  );
  final lines = <String>[
    'Kemetic Date\nYear $eventYear · Month ${event.kMonth} · Day ${event.kDay}',
    'Timing\n${event.schedule.label}. This event belongs to this Kemetic calendar day only; missed days are not replayed later in the year.',
    if (event.netjeruLabel.isNotEmpty)
      'Birth\n${_netjeruDisplay(event.netjeruLabel)} — ${event.qualityLabel}.',
    'Words\n"${event.spokenLine}"',
    'What to do\n${_numbered(event.steps)}',
    if (event.kind == DaysOutsideEventKind.yearClosing)
      'Optional\nLight a candle or oil lamp if that is safe. Water is enough.',
    if (event.kind == DaysOutsideEventKind.wepRonpetOpening)
      'Share\nIf you share, share one word only: the quality or intention you carry into the year. Do not share the full private reflection.',
    if (variant == DaysOutsideCopyVariant.setSolarEclipse2026)
      'Eclipse\nToday is Set\'s day. The Sun goes dark at midday. This is Set\'s work - not Isfet, but the necessary contest between light and darkness that makes Ra\'s passage real.',
  ];
  return lines.join('\n\n');
}

String daysOutsideMissedCopy(DaysOutsideEvent event) {
  final name = event.netjeruLabel.isEmpty
      ? 'This threshold'
      : _netjeruDisplay(event.netjeruLabel);
  return '$name\'s day has passed for this year. ${event.qualityLabel} can still be received - it carries across all thresholds, not only the appointed one.';
}

String _netjeruDisplay(String key) {
  switch (key) {
    case 'ausar':
      return 'Ausar';
    case 'heru_wer':
      return 'Heru Wer';
    case 'set':
      return 'Set';
    case 'aset':
      return 'Aset';
    case 'nebet_het':
      return 'Nebet-Het';
  }
  return key;
}

String _numbered(List<String> values) {
  return values
      .asMap()
      .entries
      .map((entry) => '${entry.key + 1}. ${entry.value}')
      .join('\n');
}

String _isoDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
