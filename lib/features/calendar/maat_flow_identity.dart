enum MaatFlowKind {
  trackSky,
  dawnHouseRite,
  eveningThresholdRite,
  theWeighing,
  offeringTable,
  theTending,
  keptWord,
  theCourse,
  moonReturn,
  theWag,
  decanWatch,
  daysOutsideTheYear,
  theOpenHand,
  theDjed,
}

extension MaatFlowKindIdentity on MaatFlowKind {
  String get flowKey {
    switch (this) {
      case MaatFlowKind.trackSky:
        return 'track-the-sky';
      case MaatFlowKind.dawnHouseRite:
        return 'dawn-house-rite';
      case MaatFlowKind.eveningThresholdRite:
        return 'evening-threshold-rite';
      case MaatFlowKind.theWeighing:
        return 'the-weighing';
      case MaatFlowKind.offeringTable:
        return 'the-offering-table';
      case MaatFlowKind.theTending:
        return 'the-tending';
      case MaatFlowKind.keptWord:
        return 'the-kept-word';
      case MaatFlowKind.theCourse:
        return 'the-course';
      case MaatFlowKind.moonReturn:
        return 'the-moon-return';
      case MaatFlowKind.theWag:
        return 'the-wag';
      case MaatFlowKind.decanWatch:
        return 'the-decan-watch';
      case MaatFlowKind.daysOutsideTheYear:
        return 'the-days-outside-the-year';
      case MaatFlowKind.theOpenHand:
        return 'the-open-hand';
      case MaatFlowKind.theDjed:
        return 'the-djed';
    }
  }
}

MaatFlowKind? resolveMaatFlowKind({
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  final flowKey =
      _normalize(behaviorPayload?['flow_key']?.toString()) ??
      _maatKeyFromNotes(flowNotes);
  final keyMatch = _flowKeyKinds[flowKey];
  if (keyMatch != null) return keyMatch;

  final behaviorKind = _normalize(behaviorPayload?['kind']?.toString());
  final behaviorKindMatch = _behaviorKindKinds[behaviorKind];
  if (behaviorKindMatch != null) return behaviorKindMatch;

  if (behaviorKind != null) {
    for (final entry in _behaviorKindPrefixKinds.entries) {
      if (behaviorKind.startsWith(entry.key)) return entry.value;
    }
  }

  final normalizedActionId = _normalize(actionId);
  if (normalizedActionId != null) {
    for (final entry in _actionIdPrefixKinds.entries) {
      if (normalizedActionId.startsWith(entry.key)) return entry.value;
    }
  }

  final normalizedName = _normalizeName(flowName);
  return _flowNameKinds[normalizedName];
}

bool isMaatFlowReference(
  MaatFlowKind kind, {
  String? flowName,
  String? flowNotes,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  return resolveMaatFlowKind(
        flowName: flowName,
        flowNotes: flowNotes,
        actionId: actionId,
        behaviorPayload: behaviorPayload,
      ) ==
      kind;
}

const Map<String, MaatFlowKind> _flowKeyKinds = <String, MaatFlowKind>{
  'track-the-sky': MaatFlowKind.trackSky,
  'dawn-house-rite': MaatFlowKind.dawnHouseRite,
  'evening-threshold-rite': MaatFlowKind.eveningThresholdRite,
  'the-weighing': MaatFlowKind.theWeighing,
  'the-offering-table': MaatFlowKind.offeringTable,
  'the-tending': MaatFlowKind.theTending,
  'the-kept-word': MaatFlowKind.keptWord,
  'the-course': MaatFlowKind.theCourse,
  'the-moon-return': MaatFlowKind.moonReturn,
  'the-wag': MaatFlowKind.theWag,
  'the-decan-watch': MaatFlowKind.decanWatch,
  'the-days-outside-the-year': MaatFlowKind.daysOutsideTheYear,
  'the-open-hand': MaatFlowKind.theOpenHand,
  'the-djed': MaatFlowKind.theDjed,
};

const Map<String, MaatFlowKind> _behaviorKindKinds = <String, MaatFlowKind>{
  'maat_dawn_house_rite_day': MaatFlowKind.dawnHouseRite,
  'maat_evening_threshold_rite_day': MaatFlowKind.eveningThresholdRite,
  'maat_the_weighing_event': MaatFlowKind.theWeighing,
  'maat_offering_table_day': MaatFlowKind.offeringTable,
  'maat_the_tending_event': MaatFlowKind.theTending,
  'maat_kept_word_event': MaatFlowKind.keptWord,
  'maat_course_event': MaatFlowKind.theCourse,
  'maat_wag_event': MaatFlowKind.theWag,
  'maat_decan_watch': MaatFlowKind.decanWatch,
  'maat_days_outside_year': MaatFlowKind.daysOutsideTheYear,
  'maat_open_hand_event': MaatFlowKind.theOpenHand,
  'maat_djed_event': MaatFlowKind.theDjed,
};

const Map<String, MaatFlowKind> _behaviorKindPrefixKinds =
    <String, MaatFlowKind>{'maat_moon_return_': MaatFlowKind.moonReturn};

const Map<String, MaatFlowKind> _actionIdPrefixKinds = <String, MaatFlowKind>{
  'dawn-house-rite-day-': MaatFlowKind.dawnHouseRite,
  'evening-threshold-rite-day-': MaatFlowKind.eveningThresholdRite,
  'the-weighing-event-': MaatFlowKind.theWeighing,
  'the-offering-table-day-': MaatFlowKind.offeringTable,
  'the-tending-event-': MaatFlowKind.theTending,
  'the-kept-word-event-': MaatFlowKind.keptWord,
  'the-course-event-': MaatFlowKind.theCourse,
  'the-moon-return-': MaatFlowKind.moonReturn,
  'the-wag-event-': MaatFlowKind.theWag,
  'the-decan-watch-': MaatFlowKind.decanWatch,
  'the-days-outside-year-event-': MaatFlowKind.daysOutsideTheYear,
  'the-open-hand-event-': MaatFlowKind.theOpenHand,
  'the-djed-event-': MaatFlowKind.theDjed,
};

const Map<String, MaatFlowKind> _flowNameKinds = <String, MaatFlowKind>{
  'follow the sky': MaatFlowKind.trackSky,
  'track the sky': MaatFlowKind.trackSky,
  'dawn house rite': MaatFlowKind.dawnHouseRite,
  'evening threshold rite': MaatFlowKind.eveningThresholdRite,
  'the weighing': MaatFlowKind.theWeighing,
  'the offering table': MaatFlowKind.offeringTable,
  'the tending': MaatFlowKind.theTending,
  'the kept word': MaatFlowKind.keptWord,
  'the course': MaatFlowKind.theCourse,
  'the moon return': MaatFlowKind.moonReturn,
  'the wag': MaatFlowKind.theWag,
  'the decan watch': MaatFlowKind.decanWatch,
  'the days outside the year': MaatFlowKind.daysOutsideTheYear,
  'the open hand': MaatFlowKind.theOpenHand,
  'the djed': MaatFlowKind.theDjed,
};

String? _maatKeyFromNotes(String? flowNotes) {
  if (flowNotes == null || flowNotes.isEmpty) return null;
  for (final token in flowNotes.split(';')) {
    final trimmed = token.trim();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('maat=')) {
      return _normalize(trimmed.substring(5));
    }
  }
  return null;
}

String? _normalize(String? raw) {
  final normalized = raw?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}

String? _normalizeName(String? raw) {
  final normalized = _normalize(raw)?.replaceAll(RegExp(r'\s+'), ' ');
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}
