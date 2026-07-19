const String kMaatFlowProfileCatalogVersion = 'maat_flow_profile_catalog_v1';

enum MaatFlowProfileAxis {
  primaryIntention,
  timeBias,
  mode,
  orientation,
  practiceType,
  effortShape,
}

extension MaatFlowProfileAxisX on MaatFlowProfileAxis {
  String get wireName {
    return switch (this) {
      MaatFlowProfileAxis.primaryIntention => 'primary_intention',
      MaatFlowProfileAxis.timeBias => 'time_bias',
      MaatFlowProfileAxis.mode => 'mode',
      MaatFlowProfileAxis.orientation => 'orientation',
      MaatFlowProfileAxis.practiceType => 'practice_type',
      MaatFlowProfileAxis.effortShape => 'effort_shape',
    };
  }
}

enum MaatFlowTimeBias {
  morning,
  midday,
  evening,
  night,
  lunar,
  seasonal,
  anytime,
  mixed,
}

extension MaatFlowTimeBiasX on MaatFlowTimeBias {
  String get wireName {
    return switch (this) {
      MaatFlowTimeBias.morning => 'morning',
      MaatFlowTimeBias.midday => 'midday',
      MaatFlowTimeBias.evening => 'evening',
      MaatFlowTimeBias.night => 'night',
      MaatFlowTimeBias.lunar => 'lunar',
      MaatFlowTimeBias.seasonal => 'seasonal',
      MaatFlowTimeBias.anytime => 'anytime',
      MaatFlowTimeBias.mixed => 'mixed',
    };
  }
}

enum MaatFlowMode { solitary, relational, household, public, textual, mixed }

extension MaatFlowModeX on MaatFlowMode {
  String get wireName {
    return switch (this) {
      MaatFlowMode.solitary => 'solitary',
      MaatFlowMode.relational => 'relational',
      MaatFlowMode.household => 'household',
      MaatFlowMode.public => 'public',
      MaatFlowMode.textual => 'textual',
      MaatFlowMode.mixed => 'mixed',
    };
  }
}

enum MaatFlowOrientation {
  inward,
  outward,
  relational,
  environmental,
  textual,
  bodily,
  cosmic,
  mixed,
}

extension MaatFlowOrientationX on MaatFlowOrientation {
  String get wireName {
    return switch (this) {
      MaatFlowOrientation.inward => 'inward',
      MaatFlowOrientation.outward => 'outward',
      MaatFlowOrientation.relational => 'relational',
      MaatFlowOrientation.environmental => 'environmental',
      MaatFlowOrientation.textual => 'textual',
      MaatFlowOrientation.bodily => 'bodily',
      MaatFlowOrientation.cosmic => 'cosmic',
      MaatFlowOrientation.mixed => 'mixed',
    };
  }
}

enum MaatFlowPracticeType {
  observation,
  reflection,
  recordKeeping,
  repair,
  planning,
  restraint,
  service,
  provision,
  study,
  recovery,
  speech,
  bodyCare,
  grief,
  dreamWork,
  exchange,
  ritual,
  order,
  stability,
}

extension MaatFlowPracticeTypeX on MaatFlowPracticeType {
  String get wireName {
    return switch (this) {
      MaatFlowPracticeType.observation => 'observation',
      MaatFlowPracticeType.reflection => 'reflection',
      MaatFlowPracticeType.recordKeeping => 'record_keeping',
      MaatFlowPracticeType.repair => 'repair',
      MaatFlowPracticeType.planning => 'planning',
      MaatFlowPracticeType.restraint => 'restraint',
      MaatFlowPracticeType.service => 'service',
      MaatFlowPracticeType.provision => 'provision',
      MaatFlowPracticeType.study => 'study',
      MaatFlowPracticeType.recovery => 'recovery',
      MaatFlowPracticeType.speech => 'speech',
      MaatFlowPracticeType.bodyCare => 'body_care',
      MaatFlowPracticeType.grief => 'grief',
      MaatFlowPracticeType.dreamWork => 'dream_work',
      MaatFlowPracticeType.exchange => 'exchange',
      MaatFlowPracticeType.ritual => 'ritual',
      MaatFlowPracticeType.order => 'order',
      MaatFlowPracticeType.stability => 'stability',
    };
  }
}

enum MaatFlowEffortShape {
  smallGate,
  sustainedAttention,
  deepWork,
  embodiedAction,
  socialAccountability,
  recovery,
  threshold,
  physicalReset,
  repeatedMaintenance,
}

extension MaatFlowEffortShapeX on MaatFlowEffortShape {
  String get wireName {
    return switch (this) {
      MaatFlowEffortShape.smallGate => 'small_gate',
      MaatFlowEffortShape.sustainedAttention => 'sustained_attention',
      MaatFlowEffortShape.deepWork => 'deep_work',
      MaatFlowEffortShape.embodiedAction => 'embodied_action',
      MaatFlowEffortShape.socialAccountability => 'social_accountability',
      MaatFlowEffortShape.recovery => 'recovery',
      MaatFlowEffortShape.threshold => 'threshold',
      MaatFlowEffortShape.physicalReset => 'physical_reset',
      MaatFlowEffortShape.repeatedMaintenance => 'repeated_maintenance',
    };
  }
}

class MaatFlowProfileAttribute {
  const MaatFlowProfileAttribute({required this.axis, required this.value});

  final MaatFlowProfileAxis axis;
  final String value;

  String get key => '${axis.wireName}:$value';

  @override
  bool operator ==(Object other) {
    return other is MaatFlowProfileAttribute &&
        other.axis == axis &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(axis, value);
}

class MaatFlowStaticProfile {
  const MaatFlowStaticProfile({
    required this.flowKey,
    required this.title,
    required this.primaryIntentions,
    required this.timeBiases,
    required this.modes,
    required this.orientations,
    required this.practiceTypes,
    required this.effortShapes,
  });

  final String flowKey;
  final String title;
  final List<String> primaryIntentions;
  final List<MaatFlowTimeBias> timeBiases;
  final List<MaatFlowMode> modes;
  final List<MaatFlowOrientation> orientations;
  final List<MaatFlowPracticeType> practiceTypes;
  final List<MaatFlowEffortShape> effortShapes;

  Iterable<MaatFlowProfileAttribute> get attributes sync* {
    for (final intention in primaryIntentions) {
      yield MaatFlowProfileAttribute(
        axis: MaatFlowProfileAxis.primaryIntention,
        value: intention,
      );
    }
    for (final bias in timeBiases) {
      yield MaatFlowProfileAttribute(
        axis: MaatFlowProfileAxis.timeBias,
        value: bias.wireName,
      );
    }
    for (final mode in modes) {
      yield MaatFlowProfileAttribute(
        axis: MaatFlowProfileAxis.mode,
        value: mode.wireName,
      );
    }
    for (final orientation in orientations) {
      yield MaatFlowProfileAttribute(
        axis: MaatFlowProfileAxis.orientation,
        value: orientation.wireName,
      );
    }
    for (final type in practiceTypes) {
      yield MaatFlowProfileAttribute(
        axis: MaatFlowProfileAxis.practiceType,
        value: type.wireName,
      );
    }
    for (final shape in effortShapes) {
      yield MaatFlowProfileAttribute(
        axis: MaatFlowProfileAxis.effortShape,
        value: shape.wireName,
      );
    }
  }
}

MaatFlowStaticProfile? maatFlowStaticProfileForKey(String flowKey) {
  return kMaatFlowStaticProfiles[flowKey.trim()];
}

const Map<String, MaatFlowStaticProfile>
kMaatFlowStaticProfiles = <String, MaatFlowStaticProfile>{
  'track-the-sky': MaatFlowStaticProfile(
    flowKey: 'track-the-sky',
    title: 'Track the Sky',
    primaryIntentions: <String>['steady_attention'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.seasonal],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.cosmic],
    practiceTypes: <MaatFlowPracticeType>[MaatFlowPracticeType.observation],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.sustainedAttention],
  ),
  'dawn-house-rite': MaatFlowStaticProfile(
    flowKey: 'dawn-house-rite',
    title: 'Dawn House Rite',
    primaryIntentions: <String>['clean_beginning'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.morning],
    modes: <MaatFlowMode>[MaatFlowMode.household],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.environmental],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.ritual,
      MaatFlowPracticeType.order,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.smallGate],
  ),
  'evening_threshold': MaatFlowStaticProfile(
    flowKey: 'evening_threshold',
    title: 'Evening Threshold',
    primaryIntentions: <String>['evening_review'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.evening],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.inward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.reflection,
      MaatFlowPracticeType.recordKeeping,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.threshold],
  ),
  'evening-threshold-rite': MaatFlowStaticProfile(
    flowKey: 'evening-threshold-rite',
    title: 'Evening Threshold Rite',
    primaryIntentions: <String>['closure'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.evening],
    modes: <MaatFlowMode>[MaatFlowMode.household],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.environmental],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.ritual,
      MaatFlowPracticeType.repair,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.threshold],
  ),
  'the-weighing': MaatFlowStaticProfile(
    flowKey: 'the-weighing',
    title: 'The Weighing',
    primaryIntentions: <String>['honest_review'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.inward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.reflection,
      MaatFlowPracticeType.recordKeeping,
      MaatFlowPracticeType.repair,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.deepWork],
  ),
  'the-offering-table': MaatFlowStaticProfile(
    flowKey: 'the-offering-table',
    title: 'The Offering Table',
    primaryIntentions: <String>['provision'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.household],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.outward],
    practiceTypes: <MaatFlowPracticeType>[MaatFlowPracticeType.provision],
    effortShapes: <MaatFlowEffortShape>[
      MaatFlowEffortShape.repeatedMaintenance,
    ],
  ),
  'the-tending': MaatFlowStaticProfile(
    flowKey: 'the-tending',
    title: 'The Tending',
    primaryIntentions: <String>['specific_care'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.relational],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.outward],
    practiceTypes: <MaatFlowPracticeType>[MaatFlowPracticeType.service],
    effortShapes: <MaatFlowEffortShape>[
      MaatFlowEffortShape.embodiedAction,
      MaatFlowEffortShape.socialAccountability,
    ],
  ),
  'the-kept-word': MaatFlowStaticProfile(
    flowKey: 'the-kept-word',
    title: 'The Kept Word',
    primaryIntentions: <String>['kept_agreement'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.relational],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.relational],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.speech,
      MaatFlowPracticeType.repair,
    ],
    effortShapes: <MaatFlowEffortShape>[
      MaatFlowEffortShape.socialAccountability,
    ],
  ),
  'the-course': MaatFlowStaticProfile(
    flowKey: 'the-course',
    title: 'The Course',
    primaryIntentions: <String>['time_orientation'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.mixed],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.cosmic],
    practiceTypes: <MaatFlowPracticeType>[MaatFlowPracticeType.planning],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.sustainedAttention],
  ),
  'the-moon-return': MaatFlowStaticProfile(
    flowKey: 'the-moon-return',
    title: 'The Moon Return',
    primaryIntentions: <String>['lunar_reflection'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.lunar],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[
      MaatFlowOrientation.cosmic,
      MaatFlowOrientation.inward,
    ],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.reflection,
      MaatFlowPracticeType.observation,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.threshold],
  ),
  'the-wag': MaatFlowStaticProfile(
    flowKey: 'the-wag',
    title: 'The Wag',
    primaryIntentions: <String>['remembrance'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.seasonal],
    modes: <MaatFlowMode>[MaatFlowMode.household],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.relational],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.provision,
      MaatFlowPracticeType.grief,
    ],
    effortShapes: <MaatFlowEffortShape>[
      MaatFlowEffortShape.repeatedMaintenance,
    ],
  ),
  'the-decan-watch': MaatFlowStaticProfile(
    flowKey: 'the-decan-watch',
    title: 'The Decan Watch',
    primaryIntentions: <String>['decan_orientation'],
    timeBiases: <MaatFlowTimeBias>[
      MaatFlowTimeBias.night,
      MaatFlowTimeBias.seasonal,
    ],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.cosmic],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.observation,
      MaatFlowPracticeType.reflection,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.threshold],
  ),
  'the-days-outside-the-year': MaatFlowStaticProfile(
    flowKey: 'the-days-outside-the-year',
    title: 'The Days Outside the Year',
    primaryIntentions: <String>['year_transition'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.seasonal],
    modes: <MaatFlowMode>[MaatFlowMode.household],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.inward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.reflection,
      MaatFlowPracticeType.ritual,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.recovery],
  ),
  'the-open-hand': MaatFlowStaticProfile(
    flowKey: 'the-open-hand',
    title: 'The Open Hand',
    primaryIntentions: <String>['outward_help'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.public],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.outward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.service,
      MaatFlowPracticeType.provision,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.embodiedAction],
  ),
  'the-djed': MaatFlowStaticProfile(
    flowKey: 'the-djed',
    title: 'The Djed',
    primaryIntentions: <String>['stability'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.household],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.inward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.repair,
      MaatFlowPracticeType.stability,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.recovery],
  ),
  'reading-house': MaatFlowStaticProfile(
    flowKey: 'reading-house',
    title: 'Reading House',
    primaryIntentions: <String>['measured_study'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.textual],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.textual],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.study,
      MaatFlowPracticeType.reflection,
      MaatFlowPracticeType.recordKeeping,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.sustainedAttention],
  ),
  'the-reading-house': MaatFlowStaticProfile(
    flowKey: 'the-reading-house',
    title: 'The Reading House',
    primaryIntentions: <String>['measured_study'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.textual],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.textual],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.study,
      MaatFlowPracticeType.reflection,
      MaatFlowPracticeType.recordKeeping,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.sustainedAttention],
  ),
  'the-fair-hearing': MaatFlowStaticProfile(
    flowKey: 'the-fair-hearing',
    title: 'The Fair Hearing',
    primaryIntentions: <String>['fair_judgment'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.relational],
    orientations: <MaatFlowOrientation>[
      MaatFlowOrientation.relational,
      MaatFlowOrientation.outward,
    ],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.reflection,
      MaatFlowPracticeType.restraint,
      MaatFlowPracticeType.repair,
    ],
    effortShapes: <MaatFlowEffortShape>[
      MaatFlowEffortShape.socialAccountability,
    ],
  ),
  'the-house-of-life': MaatFlowStaticProfile(
    flowKey: 'the-house-of-life',
    title: 'The House of Life',
    primaryIntentions: <String>['transmission'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.textual],
    orientations: <MaatFlowOrientation>[
      MaatFlowOrientation.textual,
      MaatFlowOrientation.outward,
    ],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.study,
      MaatFlowPracticeType.recordKeeping,
      MaatFlowPracticeType.service,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.deepWork],
  ),
  'the-boundary-stone': MaatFlowStaticProfile(
    flowKey: 'the-boundary-stone',
    title: 'The Boundary Stone',
    primaryIntentions: <String>['boundary_work'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.relational],
    orientations: <MaatFlowOrientation>[
      MaatFlowOrientation.relational,
      MaatFlowOrientation.outward,
    ],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.restraint,
      MaatFlowPracticeType.repair,
    ],
    effortShapes: <MaatFlowEffortShape>[
      MaatFlowEffortShape.socialAccountability,
    ],
  ),
  'hotep': MaatFlowStaticProfile(
    flowKey: 'hotep',
    title: 'Hotep',
    primaryIntentions: <String>['peace'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.evening],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.inward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.recovery,
      MaatFlowPracticeType.reflection,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.smallGate],
  ),
  'the-open-mouth': MaatFlowStaticProfile(
    flowKey: 'the-open-mouth',
    title: 'The Open Mouth',
    primaryIntentions: <String>['careful_speech'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.relational],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.outward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.speech,
      MaatFlowPracticeType.restraint,
    ],
    effortShapes: <MaatFlowEffortShape>[
      MaatFlowEffortShape.socialAccountability,
    ],
  ),
  'the-living-record': MaatFlowStaticProfile(
    flowKey: 'the-living-record',
    title: 'The Living Record',
    primaryIntentions: <String>['record_keeping'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.textual],
    orientations: <MaatFlowOrientation>[
      MaatFlowOrientation.textual,
      MaatFlowOrientation.inward,
    ],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.recordKeeping,
      MaatFlowPracticeType.reflection,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.sustainedAttention],
  ),
  'het-heru': MaatFlowStaticProfile(
    flowKey: 'het-heru',
    title: 'Het-Heru',
    primaryIntentions: <String>['cooling_strong_feeling'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.inward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.recovery,
      MaatFlowPracticeType.restraint,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.recovery],
  ),
  'the-shore': MaatFlowStaticProfile(
    flowKey: 'the-shore',
    title: 'The Shore',
    primaryIntentions: <String>['honest_exchange'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.relational],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.outward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.exchange,
      MaatFlowPracticeType.recordKeeping,
    ],
    effortShapes: <MaatFlowEffortShape>[
      MaatFlowEffortShape.socialAccountability,
    ],
  ),
  'the-autobiography': MaatFlowStaticProfile(
    flowKey: 'the-autobiography',
    title: 'The Autobiography',
    primaryIntentions: <String>['life_record'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.textual],
    orientations: <MaatFlowOrientation>[
      MaatFlowOrientation.textual,
      MaatFlowOrientation.inward,
    ],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.recordKeeping,
      MaatFlowPracticeType.reflection,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.deepWork],
  ),
  'the-first-arrangement': MaatFlowStaticProfile(
    flowKey: 'the-first-arrangement',
    title: 'The First Arrangement',
    primaryIntentions: <String>['space_order'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.household],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.environmental],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.order,
      MaatFlowPracticeType.planning,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.physicalReset],
  ),
  'the-living-pattern': MaatFlowStaticProfile(
    flowKey: 'the-living-pattern',
    title: 'The Living Pattern',
    primaryIntentions: <String>['patient_observation'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.environmental],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.observation,
      MaatFlowPracticeType.reflection,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.sustainedAttention],
  ),
  'the-true-name': MaatFlowStaticProfile(
    flowKey: 'the-true-name',
    title: 'The True Name',
    primaryIntentions: <String>['accurate_naming'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.inward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.reflection,
      MaatFlowPracticeType.speech,
      MaatFlowPracticeType.recordKeeping,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.deepWork],
  ),
  'the-living-text': MaatFlowStaticProfile(
    flowKey: 'the-living-text',
    title: 'The Living Text',
    primaryIntentions: <String>['living_study'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.textual],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.textual],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.study,
      MaatFlowPracticeType.recordKeeping,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.sustainedAttention],
  ),
  'the-clearing': MaatFlowStaticProfile(
    flowKey: 'the-clearing',
    title: 'The Clearing',
    primaryIntentions: <String>['temperance'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.inward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.restraint,
      MaatFlowPracticeType.recovery,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.recovery],
  ),
  'the-wandering': MaatFlowStaticProfile(
    flowKey: 'the-wandering',
    title: 'The Wandering',
    primaryIntentions: <String>['grief_accompaniment'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.evening],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.inward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.grief,
      MaatFlowPracticeType.reflection,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.recovery],
  ),
  'the-khat': MaatFlowStaticProfile(
    flowKey: 'the-khat',
    title: 'The Khat',
    primaryIntentions: <String>['body_care'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.anytime],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.bodily],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.bodyCare,
      MaatFlowPracticeType.recovery,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.embodiedAction],
  ),
  'the-oracle': MaatFlowStaticProfile(
    flowKey: 'the-oracle',
    title: 'The Oracle',
    primaryIntentions: <String>['dream_question_work'],
    timeBiases: <MaatFlowTimeBias>[MaatFlowTimeBias.night],
    modes: <MaatFlowMode>[MaatFlowMode.solitary],
    orientations: <MaatFlowOrientation>[MaatFlowOrientation.inward],
    practiceTypes: <MaatFlowPracticeType>[
      MaatFlowPracticeType.dreamWork,
      MaatFlowPracticeType.reflection,
    ],
    effortShapes: <MaatFlowEffortShape>[MaatFlowEffortShape.threshold],
  ),
};
