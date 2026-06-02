import 'maat_flow_identity.dart';

const String kTheWagFlowKey = 'the-wag';
const String kTheWagTitle = 'The Wag';
const String kTheWagGlyph = '𓊝';
const String kTheWagTagline =
    'Speak their names. Set the table. They are not gone.';
const String kTheWagConfidenceLabel =
    'Festival attested; household form reconstructed.';

const String kTheWagOverview =
    'The Wag is an annual Ma\'at flow for the blessed dead: name ancestors, set water and bread, hold the Day 17 vigil, keep the Day 18 feast, then close with what they gave and what you will leave. '
    'It is fixed to Kemetic Month 1, following the year opening rather than a rolling thirty-day enrollment.';

enum WagEventKind {
  beginNaming,
  extendNames,
  tableSet,
  approach,
  vigil,
  feast,
  whatTheyGave,
  whatYouLeave,
  cycleConfirmed,
}

extension WagEventKindX on WagEventKind {
  String get key {
    switch (this) {
      case WagEventKind.beginNaming:
        return 'begin_naming';
      case WagEventKind.extendNames:
        return 'extend_names';
      case WagEventKind.tableSet:
        return 'table_set';
      case WagEventKind.approach:
        return 'approach';
      case WagEventKind.vigil:
        return 'vigil';
      case WagEventKind.feast:
        return 'feast';
      case WagEventKind.whatTheyGave:
        return 'what_they_gave';
      case WagEventKind.whatYouLeave:
        return 'what_you_leave';
      case WagEventKind.cycleConfirmed:
        return 'cycle_confirmed';
    }
  }
}

enum WagScheduleKind { solarDawn, anytime, solarDusk, feastMorning }

extension WagScheduleKindX on WagScheduleKind {
  String get key {
    switch (this) {
      case WagScheduleKind.solarDawn:
        return 'solar_dawn';
      case WagScheduleKind.anytime:
        return 'anytime';
      case WagScheduleKind.solarDusk:
        return 'solar_dusk';
      case WagScheduleKind.feastMorning:
        return 'feast_morning';
    }
  }

  String get label {
    switch (this) {
      case WagScheduleKind.solarDawn:
        return 'Dawn';
      case WagScheduleKind.anytime:
        return '11:00 local';
      case WagScheduleKind.solarDusk:
        return 'Dusk';
      case WagScheduleKind.feastMorning:
        return 'Morning-midday';
    }
  }
}

enum WagCopyVariant { standard, vigilPartialEclipse2026 }

extension WagCopyVariantX on WagCopyVariant {
  String get key {
    switch (this) {
      case WagCopyVariant.standard:
        return 'standard';
      case WagCopyVariant.vigilPartialEclipse2026:
        return 'wag_vigil_eclipse_2026';
    }
  }
}

enum WagLens { neutral, ausar, anpu }

extension WagLensX on WagLens {
  String get key {
    switch (this) {
      case WagLens.neutral:
        return 'neutral';
      case WagLens.ausar:
        return 'ausar';
      case WagLens.anpu:
        return 'anpu';
    }
  }

  String get label {
    switch (this) {
      case WagLens.neutral:
        return 'Neutral';
      case WagLens.ausar:
        return 'Ausar';
      case WagLens.anpu:
        return 'Anpu';
    }
  }

  String get detailLine {
    switch (this) {
      case WagLens.neutral:
        return '';
      case WagLens.ausar:
        return 'Let Ausar frame the feast as restoration for the blessed dead and continuity for the living.';
      case WagLens.anpu:
        return 'Let Anpu frame the work as threshold care: names carried rightly across the boundary.';
    }
  }
}

enum WagLocalPromptKind {
  none,
  ancestorNames,
  extendedNames,
  tableConfirmation,
  wagFocus,
  vigilChecklist,
  feastNames,
  inheritedGift,
  legacyLine,
  closingConfirmation,
}

extension WagLocalPromptKindX on WagLocalPromptKind {
  String get key {
    switch (this) {
      case WagLocalPromptKind.none:
        return 'none';
      case WagLocalPromptKind.ancestorNames:
        return 'ancestor_names';
      case WagLocalPromptKind.extendedNames:
        return 'extended_names';
      case WagLocalPromptKind.tableConfirmation:
        return 'table_confirmation';
      case WagLocalPromptKind.wagFocus:
        return 'wag_focus';
      case WagLocalPromptKind.vigilChecklist:
        return 'vigil_checklist';
      case WagLocalPromptKind.feastNames:
        return 'feast_names';
      case WagLocalPromptKind.inheritedGift:
        return 'inherited_gift';
      case WagLocalPromptKind.legacyLine:
        return 'legacy_line';
      case WagLocalPromptKind.closingConfirmation:
        return 'closing_confirmation';
    }
  }

  String get label {
    switch (this) {
      case WagLocalPromptKind.none:
        return '';
      case WagLocalPromptKind.ancestorNames:
        return 'Ancestor names';
      case WagLocalPromptKind.extendedNames:
        return 'Extended names';
      case WagLocalPromptKind.tableConfirmation:
        return 'Table confirmation';
      case WagLocalPromptKind.wagFocus:
        return 'Wag focus';
      case WagLocalPromptKind.vigilChecklist:
        return 'Vigil notes';
      case WagLocalPromptKind.feastNames:
        return 'Feast names';
      case WagLocalPromptKind.inheritedGift:
        return 'What they gave';
      case WagLocalPromptKind.legacyLine:
        return 'What you leave';
      case WagLocalPromptKind.closingConfirmation:
        return 'Closing line';
    }
  }

  String get helperText {
    switch (this) {
      case WagLocalPromptKind.none:
        return '';
      case WagLocalPromptKind.ancestorNames:
        return 'Write names on paper first. This optional local list is for your device only.';
      case WagLocalPromptKind.extendedNames:
        return 'Add missed names, unknown-ancestor placeholders, mentors, elders, or practice ancestors.';
      case WagLocalPromptKind.tableConfirmation:
        return 'Confirm the list and table without syncing names to the server.';
      case WagLocalPromptKind.wagFocus:
        return 'Name the person or group you most want to acknowledge at the Wag.';
      case WagLocalPromptKind.vigilChecklist:
        return 'Track water, bread or food, scent, and the names spoken at dusk.';
      case WagLocalPromptKind.feastNames:
        return 'Record whether the names were spoken. Full feast details stay local.';
      case WagLocalPromptKind.inheritedGift:
        return 'Name one specific gift, skill, story, or way of being you carry.';
      case WagLocalPromptKind.legacyLine:
        return 'Write the one sentence you would want spoken after your name.';
      case WagLocalPromptKind.closingConfirmation:
        return 'Keep the closing line private unless you choose to share a generic reflection.';
    }
  }
}

class WagEvent {
  final int eventNumber;
  final int kemeticMonth;
  final int kemeticDay;
  final String decanSection;
  final String title;
  final WagEventKind kind;
  final WagScheduleKind schedule;
  final int durationMinutesMin;
  final int durationMinutesMax;
  final String spokenLine;
  final List<String> steps;
  final List<String> optionalSteps;
  final String? sourceNote;
  final bool requiresOfferings;
  final bool sharePromptOnComplete;
  final WagLocalPromptKind localPrompt;

  const WagEvent({
    required this.eventNumber,
    this.kemeticMonth = 1,
    required this.kemeticDay,
    required this.decanSection,
    required this.title,
    required this.kind,
    required this.schedule,
    required this.durationMinutesMin,
    required this.durationMinutesMax,
    required this.spokenLine,
    required this.steps,
    this.optionalSteps = const <String>[],
    this.sourceNote,
    this.requiresOfferings = false,
    this.sharePromptOnComplete = false,
    this.localPrompt = WagLocalPromptKind.none,
  });
}

const List<WagEvent> kWagEvents = <WagEvent>[
  WagEvent(
    eventNumber: 1,
    kemeticDay: 1,
    decanSection: 'The Naming',
    title: 'Begin the Naming',
    kind: WagEventKind.beginNaming,
    schedule: WagScheduleKind.solarDawn,
    durationMinutesMin: 8,
    durationMinutesMax: 10,
    spokenLine:
        'Your name shall live at the fore of the living. May your name not perish on earth.',
    steps: <String>[
      'Write the known names on paper: parents, grandparents, great-grandparents, and the dead you personally knew.',
      'For unknown names, write: [Name unknown] - [their relationship to you].',
      'Add one ancestor of practice, craft, community, or way of being.',
      'Read each name aloud once.',
    ],
    optionalSteps: <String>[
      'Use the local list only as a private backup; the handwritten page is the primary act.',
    ],
    sourceNote:
        'The ren, or name, was treated as a living part of the person. Speaking the name maintained continuation.',
    localPrompt: WagLocalPromptKind.ancestorNames,
  ),
  WagEvent(
    eventNumber: 2,
    kemeticDay: 5,
    decanSection: 'The Naming',
    title: 'Extend the Names',
    kind: WagEventKind.extendNames,
    schedule: WagScheduleKind.anytime,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine: 'Your name shall live at the fore of the living.',
    steps: <String>[
      'Look at the Day 1 list and add anyone missing.',
      'Name one ancestor known only by story, or one ancestor of your practice or tradition.',
      'Place water on the surface while you add to the list.',
    ],
    sourceNote:
        'The offering is not canceled by missing records; unknown ancestors can still be addressed by relationship.',
    localPrompt: WagLocalPromptKind.extendedNames,
  ),
  WagEvent(
    eventNumber: 3,
    kemeticDay: 9,
    decanSection: 'The Naming',
    title: 'The Table Is Set',
    kind: WagEventKind.tableSet,
    schedule: WagScheduleKind.solarDawn,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'I have not neglected the days concerning their meat offerings.',
    steps: <String>[
      'Read the complete list of names aloud.',
      'After each name, say: I speak your name. You live.',
      'Set water before you begin. When you are done, drink it.',
    ],
    sourceNote:
        'Spell 125 names neglecting the appointed offering days for the blessed dead as disorder.',
    localPrompt: WagLocalPromptKind.tableConfirmation,
  ),
  WagEvent(
    eventNumber: 4,
    kemeticDay: 11,
    decanSection: 'The Offering and the Wag',
    title: 'The Approach',
    kind: WagEventKind.approach,
    schedule: WagScheduleKind.solarDawn,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'I have given bread to the hungry, water to the thirsty. I have made invocation-offerings for the blessed dead.',
    steps: <String>[
      'Identify the physical surface where the Wag will be held.',
      'Identify the offerings: water first, then bread or food, and if possible something fragrant.',
      'Write one sentence about who you most want to acknowledge at the Wag.',
    ],
    optionalSteps: <String>[
      'Clear the surface now and leave it empty until the vigil.',
    ],
    sourceNote:
        'The invocation-offering, prt-ḫrw, came forth through the living voice speaking the formula.',
    requiresOfferings: true,
    localPrompt: WagLocalPromptKind.wagFocus,
  ),
  WagEvent(
    eventNumber: 5,
    kemeticDay: 17,
    decanSection: 'The Offering and the Wag',
    title: 'The Vigil',
    kind: WagEventKind.vigil,
    schedule: WagScheduleKind.solarDusk,
    durationMinutesMin: 10,
    durationMinutesMax: 10,
    spokenLine:
        'His heart joyful with the calendrical offerings of the processions of every god on the Wag-festival. His heart joyful on the Wag-festival and an eternity of years therein.',
    steps: <String>[
      'Go to the surface prepared on Day 11.',
      'Place water, bread or food, and anything fragrant there now.',
      'Read the complete list of names aloud at dusk.',
      'Leave the offerings on the surface through the night.',
    ],
    sourceNote:
        'The Neferhotep Stela describes joy for the dead at the calendrical offerings of the Wag festival.',
    requiresOfferings: true,
    localPrompt: WagLocalPromptKind.vigilChecklist,
  ),
  WagEvent(
    eventNumber: 6,
    kemeticDay: 18,
    decanSection: 'The Offering and the Wag',
    title: 'The Feast',
    kind: WagEventKind.feast,
    schedule: WagScheduleKind.feastMorning,
    durationMinutesMin: 15,
    durationMinutesMax: 20,
    spokenLine:
        'A thousand of bread, a thousand of beer, a thousand of cattle, a thousand of fowl, a thousand of everything sweet, a thousand of every kind of clothing - for [name], and for all those who came before.',
    steps: <String>[
      'Return to the prepared surface and add fresh water.',
      'Read the complete list of names slowly.',
      'After each name, speak: [Name] - this bread is yours. This water is yours. You live.',
      'Speak the offering formula with the Wag focus name from Day 11.',
      'Sit with memory, then eat the bread and drink the water as reversion.',
    ],
    sourceNote:
        'The Wag is attested across Kemetic festival calendars and tomb texts; the thousand-offering formula activates provision through speech.',
    requiresOfferings: true,
    localPrompt: WagLocalPromptKind.feastNames,
  ),
  WagEvent(
    eventNumber: 7,
    kemeticDay: 21,
    decanSection: 'The Living Memory',
    title: 'What They Gave',
    kind: WagEventKind.whatTheyGave,
    schedule: WagScheduleKind.solarDawn,
    durationMinutesMin: 8,
    durationMinutesMax: 8,
    spokenLine:
        'I have not stolen the cakes of the blessed dead. I carry what they gave. I offer what they carried.',
    steps: <String>[
      'Choose one person among the dead and name one specific thing they gave you.',
      'Ask whether the living have heard that person named with this gift.',
      'Name one way to carry the gift forward more intentionally.',
      'Drink water as acknowledgment that you are still living.',
    ],
    sourceNote:
        'Spell 125 names the cakes of the blessed dead; this event turns from offering to what is carried forward.',
    localPrompt: WagLocalPromptKind.inheritedGift,
  ),
  WagEvent(
    eventNumber: 8,
    kemeticDay: 25,
    decanSection: 'The Living Memory',
    title: 'What You Will Leave',
    kind: WagEventKind.whatYouLeave,
    schedule: WagScheduleKind.anytime,
    durationMinutesMin: 5,
    durationMinutesMax: 5,
    spokenLine:
        'A man lives when his name is spoken. Speak the names. They live.',
    steps: <String>[
      'Write one sentence you would want spoken after your name at a future Wag.',
      'Ask whether that thing is true of you now, partly true, or not yet true.',
      'Optional: add your own name to the continuity, not as dead, but as one who will eventually be spoken for.',
    ],
    sourceNote:
        'The ren principle places the living inside continuity: names received, names spoken, names eventually carried.',
    localPrompt: WagLocalPromptKind.legacyLine,
  ),
  WagEvent(
    eventNumber: 9,
    kemeticDay: 29,
    decanSection: 'The Living Memory',
    title: 'The Cycle Confirmed',
    kind: WagEventKind.cycleConfirmed,
    schedule: WagScheduleKind.solarDusk,
    durationMinutesMin: 10,
    durationMinutesMax: 10,
    spokenLine:
        'I have made invocation-offerings for the blessed dead. Their names have been spoken. They live. I am their continuation. They are my foundation.',
    steps: <String>[
      'Read the complete list of names one final time.',
      'Speak only the closing lines that are true: I spoke the names; I set water; I set bread; I did not neglect the appointed days; I received what they gave.',
      'Write next year\'s Wag date somewhere you will see it.',
      'Place water one more time. Drink it. The cycle closes.',
    ],
    sourceNote:
        'Harkhuf asks the living to speak offerings and promises reciprocal intercession; the living and dead remain in maintained relationship.',
    requiresOfferings: true,
    sharePromptOnComplete: true,
    localPrompt: WagLocalPromptKind.closingConfirmation,
  ),
];

String wagEventTitle(WagEvent event) {
  return 'Wag ${event.eventNumber}: ${event.title}';
}

String wagActionId(WagEvent event) {
  return 'the-wag-event-${event.eventNumber.toString().padLeft(2, '0')}';
}

WagEvent? wagEventByNumber(int? eventNumber) {
  if (eventNumber == null) return null;
  for (final event in kWagEvents) {
    if (event.eventNumber == eventNumber) return event;
  }
  return null;
}

WagLens? wagLensFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final lens in WagLens.values) {
    if (lens.key == normalized) return lens;
  }
  return null;
}

WagLens wagLensFromNotes(String? notes, {WagLens fallback = WagLens.neutral}) {
  if (notes == null || notes.isEmpty) return fallback;
  for (final token in notes.split(';')) {
    final trimmed = token.trim();
    if (!trimmed.startsWith('wag_lens=')) continue;
    return wagLensFromKey(trimmed.substring('wag_lens='.length)) ?? fallback;
  }
  return fallback;
}

bool isWagFlowReference({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return isMaatFlowReference(
    MaatFlowKind.theWag,
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
}

WagEvent? wagEventForEvent({
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  int? parseNumber(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  final payloadEvent = wagEventByNumber(
    parseNumber(behaviorPayload?['event_number']),
  );
  if (payloadEvent != null) return payloadEvent;

  final actionMatch = RegExp(
    r'the-wag-event-(\d{1,2})',
    caseSensitive: false,
  ).firstMatch(actionId?.trim() ?? '');
  final actionEvent = wagEventByNumber(parseNumber(actionMatch?.group(1)));
  if (actionEvent != null) return actionEvent;

  final titleMatch = RegExp(
    r'^\s*Wag\s+(\d{1,2})\s*:',
    caseSensitive: false,
  ).firstMatch(title?.trim() ?? '');
  return wagEventByNumber(parseNumber(titleMatch?.group(1)));
}

String? canonicalWagDetailTextForEvent({
  String? flowName,
  String? flowNotes,
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
  DateTime? nextWagDate,
}) {
  if (!isWagFlowReference(
    flowName: flowName,
    flowNotes: flowNotes,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  )) {
    return null;
  }
  final event = wagEventForEvent(
    title: title,
    actionId: actionId,
    behaviorPayload: behaviorPayload,
  );
  if (event == null) return null;
  final lens =
      wagLensFromKey(behaviorPayload?['lens']?.toString()) ??
      wagLensFromNotes(flowNotes);
  final variant = wagCopyVariantFromKey(
    behaviorPayload?['variant']?.toString(),
  );
  return wagDetailText(
    event,
    lens: lens,
    variant: variant,
    nextWagDate: nextWagDate,
  );
}

WagCopyVariant wagCopyVariantFromKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  for (final variant in WagCopyVariant.values) {
    if (variant.key == normalized) return variant;
  }
  return WagCopyVariant.standard;
}

WagCopyVariant wagCopyVariantForEvent({
  required WagEvent event,
  required int kYear,
}) {
  if (event.kind == WagEventKind.vigil && kYear == 2) {
    return WagCopyVariant.vigilPartialEclipse2026;
  }
  return WagCopyVariant.standard;
}

Map<String, dynamic> wagBehaviorPayload({
  required WagEvent event,
  required int kYear,
  required String timezoneKey,
  required String ianaTimezone,
  required String scheduleType,
  required String referenceLocationName,
  required bool usedFallback,
  required WagLens lens,
  required WagCopyVariant variant,
}) {
  return <String, dynamic>{
    'kind': 'maat_wag_event',
    'flow_key': kTheWagFlowKey,
    'event_number': event.eventNumber,
    'k_year': kYear,
    'k_month': event.kemeticMonth,
    'k_day': event.kemeticDay,
    'wag_kind': event.kind.key,
    'schedule_kind': event.schedule.key,
    'variant': variant.key,
    'missed_event_rule':
        event.kind == WagEventKind.vigil || event.kind == WagEventKind.feast
        ? 'wag_grace'
        : 'expire_quietly',
    if (event.kind == WagEventKind.vigil)
      'grace_policy': const <String, dynamic>{
        'remind_on_k_day': 18,
        'message': 'If the vigil was missed, Wag proper is today.',
      },
    if (event.kind == WagEventKind.feast)
      'grace_policy': const <String, dynamic>{
        'grace_window_hours': 48,
        'minimum_status': 'names_spoken',
      },
    'duration_minutes': event.durationMinutesMax,
    'duration_minutes_min': event.durationMinutesMin,
    'duration_minutes_max': event.durationMinutesMax,
    'requires_offerings': event.requiresOfferings,
    'props_profile': <String, dynamic>{
      'required': const <String>[],
      'encouraged': event.requiresOfferings
          ? const <String>['water', 'bread_or_food']
          : const <String>['water'],
      'optional': const <String>['paper', 'scent'],
    },
    'completion_options': event.kind == WagEventKind.feast
        ? const <String>[
            'observed',
            'observed_partly',
            'names_spoken',
            'skipped',
          ]
        : const <String>['observed', 'observed_partly', 'skipped'],
    'privacy': 'ancestor_names_device_only',
    'share_prompt_on_complete': event.sharePromptOnComplete,
    'local_prompt': event.localPrompt.key,
    'lens': lens.key,
    'schedule': <String, dynamic>{
      'type': scheduleType,
      'timezone': timezoneKey,
      'iana_timezone': ianaTimezone,
      'reference_location': referenceLocationName,
      'used_fallback': usedFallback,
    },
  };
}

String wagDetailText(
  WagEvent event, {
  required WagLens lens,
  WagCopyVariant variant = WagCopyVariant.standard,
  DateTime? nextWagDate,
}) {
  final optional = event.optionalSteps
      .map((step) => '- $step')
      .join('\n')
      .trim();
  final lensLine = lens.detailLine.trim();
  final variantLine = _wagVariantLine(variant);
  final nextWagLine = nextWagDate == null
      ? ''
      : 'Next year\'s Wag feast returns on ${_isoDate(nextWagDate)}.';
  return <String>[
    'Purpose\n${_wagPurpose(event)}',
    if (variantLine.isNotEmpty) 'Variant\n$variantLine',
    'Words\n"${event.spokenLine}"',
    'Steps\n${_numberedLines(event.steps)}',
    if (optional.isNotEmpty) 'Optional\n$optional',
    if (event.requiresOfferings)
      'Offerings\nWater first. Bread or food is strongly encouraged from the approach onward; a clean surface is enough.',
    if (event.kind == WagEventKind.feast)
      'Minimum\nIf you cannot keep the full feast, speak the names. Use Names spoken for the completion state.',
    if (event.kind == WagEventKind.feast)
      'Grace\nIf the vigil was missed, Wag proper is today. Keep the feast now, or speak the names as the minimum. The feast carries a 48-hour grace window.',
    if (event.kind == WagEventKind.cycleConfirmed && nextWagLine.isNotEmpty)
      'Next Wag\n$nextWagLine',
    if (lensLine.isNotEmpty) 'Lens\n$lensLine',
  ].join('\n\n');
}

String wagTimingLabel(WagEvent event) {
  return 'M${event.kemeticMonth} D${event.kemeticDay} · ${event.schedule.label}';
}

String _wagVariantLine(WagCopyVariant variant) {
  switch (variant) {
    case WagCopyVariant.standard:
      return '';
    case WagCopyVariant.vigilPartialEclipse2026:
      return 'Tonight the Moon is partially in shadow as the dead are called to the table. The eye sees them, though not fully; the restoration is partial, and real.';
  }
}

String _wagPurpose(WagEvent event) {
  switch (event.kind) {
    case WagEventKind.beginNaming:
      return 'Open the year by writing and speaking the names of the dead.';
    case WagEventKind.extendNames:
      return 'Reach beyond the first list and include unknown, story-held, and practice ancestors.';
    case WagEventKind.tableSet:
      return 'Close the naming decan by confirming the list and first shared water.';
    case WagEventKind.approach:
      return 'Prepare the surface and the offerings before the Wag arrives.';
    case WagEventKind.vigil:
      return 'Call the dead to the table at dusk and leave the offerings overnight.';
    case WagEventKind.feast:
      return 'Keep the annual feast: names, water, bread or food, formula, presence, reversion.';
    case WagEventKind.whatTheyGave:
      return 'Name the living gift carried from the dead into your conduct.';
    case WagEventKind.whatYouLeave:
      return 'Look forward and name what you are becoming for those who will speak after you.';
    case WagEventKind.cycleConfirmed:
      return 'Close the annual cycle and set the next Wag in view.';
  }
}

String _numberedLines(List<String> lines) {
  return lines
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
