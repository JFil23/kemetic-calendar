enum MaatFlowKind {
  trackSky,
  dawnHouseRite,
  eveningThreshold,
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
  readingHouse,
  fairHearing,
  houseOfLife,
  boundaryStone,
  hotep,
  openMouth,
  livingRecord,
  hetHeru,
  theShore,
  theAutobiography,
  firstArrangement,
  livingPattern,
  trueName,
  livingText,
  clearing,
  wandering,
  khat,
  oracle,
}

extension MaatFlowKindIdentity on MaatFlowKind {
  String get flowKey {
    switch (this) {
      case MaatFlowKind.trackSky:
        return 'track-the-sky';
      case MaatFlowKind.dawnHouseRite:
        return 'dawn-house-rite';
      case MaatFlowKind.eveningThreshold:
        return 'evening_threshold';
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
      case MaatFlowKind.readingHouse:
        return 'the-reading-house';
      case MaatFlowKind.fairHearing:
        return 'the-fair-hearing';
      case MaatFlowKind.houseOfLife:
        return 'the-house-of-life';
      case MaatFlowKind.boundaryStone:
        return 'the-boundary-stone';
      case MaatFlowKind.hotep:
        return 'hotep';
      case MaatFlowKind.openMouth:
        return 'the-open-mouth';
      case MaatFlowKind.livingRecord:
        return 'the-living-record';
      case MaatFlowKind.hetHeru:
        return 'het-heru';
      case MaatFlowKind.theShore:
        return 'the-shore';
      case MaatFlowKind.theAutobiography:
        return 'the-autobiography';
      case MaatFlowKind.firstArrangement:
        return 'the-first-arrangement';
      case MaatFlowKind.livingPattern:
        return 'the-living-pattern';
      case MaatFlowKind.trueName:
        return 'the-true-name';
      case MaatFlowKind.livingText:
        return 'the-living-text';
      case MaatFlowKind.clearing:
        return 'the-clearing';
      case MaatFlowKind.wandering:
        return 'the-wandering';
      case MaatFlowKind.khat:
        return 'the-khat';
      case MaatFlowKind.oracle:
        return 'the-oracle';
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
  'evening_threshold': MaatFlowKind.eveningThreshold,
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
  'the-reading-house': MaatFlowKind.readingHouse,
  'the-fair-hearing': MaatFlowKind.fairHearing,
  'the-house-of-life': MaatFlowKind.houseOfLife,
  'the-boundary-stone': MaatFlowKind.boundaryStone,
  'hotep': MaatFlowKind.hotep,
  'the-open-mouth': MaatFlowKind.openMouth,
  'the-living-record': MaatFlowKind.livingRecord,
  'het-heru': MaatFlowKind.hetHeru,
  'the-shore': MaatFlowKind.theShore,
  'the-autobiography': MaatFlowKind.theAutobiography,
  'the-first-arrangement': MaatFlowKind.firstArrangement,
  'the-living-pattern': MaatFlowKind.livingPattern,
  'the-true-name': MaatFlowKind.trueName,
  'the-living-text': MaatFlowKind.livingText,
  'the-clearing': MaatFlowKind.clearing,
  'the-wandering': MaatFlowKind.wandering,
  'the-khat': MaatFlowKind.khat,
  'the-oracle': MaatFlowKind.oracle,
};

const Map<String, MaatFlowKind> _behaviorKindKinds = <String, MaatFlowKind>{
  'maat_dawn_house_rite_day': MaatFlowKind.dawnHouseRite,
  'maat_evening_threshold_event': MaatFlowKind.eveningThreshold,
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
  'maat_reading_house_sitting': MaatFlowKind.readingHouse,
  'maat_fair_hearing_event': MaatFlowKind.fairHearing,
  'maat_house_of_life_event': MaatFlowKind.houseOfLife,
  'maat_boundary_stone_event': MaatFlowKind.boundaryStone,
  'maat_hotep_event': MaatFlowKind.hotep,
  'maat_open_mouth_event': MaatFlowKind.openMouth,
  'maat_living_record_event': MaatFlowKind.livingRecord,
  'maat_het_heru_event': MaatFlowKind.hetHeru,
  'maat_shore_event': MaatFlowKind.theShore,
  'maat_autobiography_event': MaatFlowKind.theAutobiography,
  'maat_first_arrangement_event': MaatFlowKind.firstArrangement,
  'maat_living_pattern_event': MaatFlowKind.livingPattern,
  'maat_true_name_event': MaatFlowKind.trueName,
  'maat_living_text_event': MaatFlowKind.livingText,
  'maat_clearing_event': MaatFlowKind.clearing,
  'maat_wandering_event': MaatFlowKind.wandering,
  'maat_khat_event': MaatFlowKind.khat,
  'maat_oracle_event': MaatFlowKind.oracle,
};

const Map<String, MaatFlowKind> _behaviorKindPrefixKinds =
    <String, MaatFlowKind>{'maat_moon_return_': MaatFlowKind.moonReturn};

const Map<String, MaatFlowKind> _actionIdPrefixKinds = <String, MaatFlowKind>{
  'dawn-house-rite-day-': MaatFlowKind.dawnHouseRite,
  'evening-threshold-event-': MaatFlowKind.eveningThreshold,
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
  'the-reading-house-sitting-': MaatFlowKind.readingHouse,
  'the-fair-hearing-event-': MaatFlowKind.fairHearing,
  'the-house-of-life-event-': MaatFlowKind.houseOfLife,
  'the-boundary-stone-event-': MaatFlowKind.boundaryStone,
  'hotep-event-': MaatFlowKind.hotep,
  'the-open-mouth-event-': MaatFlowKind.openMouth,
  'the-living-record-event-': MaatFlowKind.livingRecord,
  'het-heru-event-': MaatFlowKind.hetHeru,
  'the-shore-event-': MaatFlowKind.theShore,
  'the-autobiography-event-': MaatFlowKind.theAutobiography,
  'the-first-arrangement-event-': MaatFlowKind.firstArrangement,
  'the-living-pattern-event-': MaatFlowKind.livingPattern,
  'the-true-name-event-': MaatFlowKind.trueName,
  'the-living-text-event-': MaatFlowKind.livingText,
  'the-clearing-event-': MaatFlowKind.clearing,
  'the-wandering-event-': MaatFlowKind.wandering,
  'the-khat-event-': MaatFlowKind.khat,
  'the-oracle-event-': MaatFlowKind.oracle,
};

const Map<String, MaatFlowKind> _flowNameKinds = <String, MaatFlowKind>{
  'follow the sky': MaatFlowKind.trackSky,
  'track the sky': MaatFlowKind.trackSky,
  'dawn house rite': MaatFlowKind.dawnHouseRite,
  'the evening threshold': MaatFlowKind.eveningThreshold,
  'evening threshold': MaatFlowKind.eveningThreshold,
  'the closing': MaatFlowKind.eveningThresholdRite,
  'closing': MaatFlowKind.eveningThresholdRite,
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
  'the reading house': MaatFlowKind.readingHouse,
  'book club flow': MaatFlowKind.readingHouse,
  'hosted book flow': MaatFlowKind.readingHouse,
  'the fair hearing': MaatFlowKind.fairHearing,
  'the house of life': MaatFlowKind.houseOfLife,
  'the boundary stone': MaatFlowKind.boundaryStone,
  'hotep': MaatFlowKind.hotep,
  'the open mouth': MaatFlowKind.openMouth,
  'the living record': MaatFlowKind.livingRecord,
  'het-heru': MaatFlowKind.hetHeru,
  'het heru': MaatFlowKind.hetHeru,
  'the shore': MaatFlowKind.theShore,
  'the autobiography': MaatFlowKind.theAutobiography,
  'the first arrangement': MaatFlowKind.firstArrangement,
  'the living pattern': MaatFlowKind.livingPattern,
  'the true name': MaatFlowKind.trueName,
  'the living text': MaatFlowKind.livingText,
  'the clearing': MaatFlowKind.clearing,
  'the wandering': MaatFlowKind.wandering,
  'the khat': MaatFlowKind.khat,
  'the oracle': MaatFlowKind.oracle,
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
