import 'package:mobile/core/composition/composition_models.dart';

const String kDecanReflectionPhraseBankVersion =
    'decan_reflection_phrase_bank_v7';

const CompositionShape kDecanReflectionShape = CompositionShape(
  id: 'observation_interpretation_consequence_next_recommendation_v2',
  positions: <CompositionPosition>[
    CompositionPosition.observation,
    CompositionPosition.interpretation,
    CompositionPosition.consequence,
    CompositionPosition.nextStep,
    CompositionPosition.recommendation,
  ],
  maxLength: 760,
);

const List<CompositionIntent> kDecanReflectionIntents = <CompositionIntent>[
  CompositionIntent(
    id: 'decan_zero_data',
    priority: 100,
    useCase: 'zero_data',
    preferredTone: CompositionTone.still,
    energy: CompositionEnergy.low,
    reflectionShape: ReflectionShape.silentOrInvitation,
    requiredClaims: <CompositionClaimId>{CompositionClaimId.zeroEvidence},
    requiredSignals: <String>{'zero_data'},
  ),
  CompositionIntent(
    id: 'decan_low_data',
    priority: 90,
    useCase: 'low_data',
    preferredTone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    reflectionShape: ReflectionShape.lowEvidenceReturn,
    requiredClaims: <CompositionClaimId>{CompositionClaimId.lowEvidence},
    requiredSignals: <String>{'low_data'},
  ),
  CompositionIntent(
    id: 'decan_many_skips',
    priority: 80,
    useCase: 'many_skips',
    preferredTone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    reflectionShape: ReflectionShape.supportiveRecalibration,
    requiredClaims: <CompositionClaimId>{
      CompositionClaimId.skippedGateTooHeavy,
    },
    requiredSignals: <String>{'many_skips'},
  ),
  CompositionIntent(
    id: 'decan_partial_continuity',
    priority: 70,
    useCase: 'partial_continuity',
    preferredTone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    reflectionShape: ReflectionShape.supportiveRecalibration,
    requiredClaims: <CompositionClaimId>{
      CompositionClaimId.partialContactMaintained,
    },
    requiredSignals: <String>{'mostly_partial'},
  ),
  CompositionIntent(
    id: 'decan_single_flow_depth',
    priority: 60,
    useCase: 'single_flow_depth',
    preferredTone: CompositionTone.still,
    energy: CompositionEnergy.neutral,
    reflectionShape: ReflectionShape.singleThreadContinuation,
    requiredClaims: <CompositionClaimId>{CompositionClaimId.singleFlowDepth},
    requiredSignals: <String>{'single_flow_depth', 'mostly_observed'},
    avoidSignals: <String>{'many_skips', 'mostly_partial'},
  ),
  CompositionIntent(
    id: 'decan_broad_flow_spread',
    priority: 55,
    useCase: 'broad_flow_spread',
    preferredTone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    reflectionShape: ReflectionShape.breadthCentering,
    requiredClaims: <CompositionClaimId>{
      CompositionClaimId.breadthAsRange,
      CompositionClaimId.breadthNeedsCenter,
    },
    requiredSignals: <String>{'broad_flow_spread', 'mostly_observed'},
  ),
  CompositionIntent(
    id: 'decan_steady_presence',
    priority: 50,
    useCase: 'steady_presence',
    preferredTone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    reflectionShape: ReflectionShape.steadyContinuation,
    requiredClaims: <CompositionClaimId>{CompositionClaimId.steadyPresence},
    requiredSignals: <String>{'mostly_observed'},
  ),
  CompositionIntent(
    id: 'decan_simple_completion',
    priority: 10,
    useCase: 'simple_completion',
    preferredTone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    reflectionShape: ReflectionShape.supportiveRecalibration,
    requiredClaims: <CompositionClaimId>{CompositionClaimId.recordedContact},
    avoidClaims: <CompositionClaimId>{
      CompositionClaimId.skippedGateTooHeavy,
      CompositionClaimId.partialContactMaintained,
    },
  ),
];

const Set<String> _lowGroundingPrincipleUseCases = <String>{'low_data'};

const Set<String> _neutralGroundingPrincipleUseCases = <String>{
  'broad_flow_spread',
  'simple_completion',
};

const Set<String> _affirmingPrincipleUseCases = <String>{
  'partial_continuity',
  'steady_presence',
};

const Set<String> _stillPrincipleUseCases = <String>{'single_flow_depth'};

const Set<CompositionClaimId> _firstContactClaims = <CompositionClaimId>{
  CompositionClaimId.firstContact,
};

const Set<CompositionClaimId> _lowEvidenceClaims = <CompositionClaimId>{
  CompositionClaimId.lowEvidence,
};

const Set<CompositionClaimId> _recordedContactClaims = <CompositionClaimId>{
  CompositionClaimId.recordedContact,
};

const Set<CompositionClaimId> _skippedGateClaims = <CompositionClaimId>{
  CompositionClaimId.skippedGateTooHeavy,
};

const Set<CompositionClaimId> _partialContactClaims = <CompositionClaimId>{
  CompositionClaimId.partialContactMaintained,
};

const Set<CompositionClaimId> _supportBeforeExpansionClaims =
    <CompositionClaimId>{CompositionClaimId.supportBeforeExpansion};

const Set<CompositionClaimId> _singleFlowDepthClaims = <CompositionClaimId>{
  CompositionClaimId.singleFlowDepth,
};

const Set<CompositionClaimId> _breadthAsRangeClaims = <CompositionClaimId>{
  CompositionClaimId.breadthAsRange,
};

const Set<CompositionClaimId> _breadthNeedsCenterClaims = <CompositionClaimId>{
  CompositionClaimId.breadthNeedsCenter,
};

const Set<CompositionClaimId> _steadyPresenceClaims = <CompositionClaimId>{
  CompositionClaimId.steadyPresence,
};

const Set<CompositionClaimId> _libraryRecommendationClaims =
    <CompositionClaimId>{CompositionClaimId.librarySupportRecommended};

const Set<CompositionClaimId> _flowRecommendationClaims = <CompositionClaimId>{
  CompositionClaimId.flowReady,
};

const Set<CompositionClaimId> _crossFlowSharedClaims = <CompositionClaimId>{
  CompositionClaimId.crossFlowSharedIntention,
};

const Set<CompositionClaimId> _crossFlowHoldingClaims = <CompositionClaimId>{
  CompositionClaimId.crossFlowSharedIntention,
  CompositionClaimId.crossFlowIntentionHolding,
};

const Set<CompositionClaimId> _crossFlowFrictionClaims = <CompositionClaimId>{
  CompositionClaimId.crossFlowSharedIntention,
  CompositionClaimId.crossFlowIntentionFriction,
};

const Set<CompositionClaimId> _crossFlowPartialClaims = <CompositionClaimId>{
  CompositionClaimId.crossFlowSharedIntention,
  CompositionClaimId.crossFlowIntentionPartial,
};

const Set<CompositionClaimId> _crossFlowUncenteredClaims = <CompositionClaimId>{
  CompositionClaimId.crossFlowIntentionUncentered,
};

const Set<CompositionClaimId> _singleFlowAvoidClaims = <CompositionClaimId>{
  CompositionClaimId.skippedGateTooHeavy,
  CompositionClaimId.partialContactMaintained,
};

class _FlowLightInterpretation extends CompositionPhrase {
  const _FlowLightInterpretation({
    required super.id,
    required String flowKey,
    required super.text,
  }) : super(
         position: CompositionPosition.interpretation,
         tone: CompositionTone.grounding,
         energy: CompositionEnergy.low,
         useCases: const <String>{'low_data'},
         tags: const <String>{'flow_intention', 'flow_intention_light'},
         minimumEvidence: 1,
         claimStrength: CompositionClaimStrength.low,
         requiresSignals: const <String>{'low_data'},
         requiresClaims: _lowEvidenceClaims,
         cooldownGroup: 'flow_intention_light',
         optionalFlowKey: flowKey,
         weight: 60,
       );
}

class _FlowSteadyInterpretation extends CompositionPhrase {
  const _FlowSteadyInterpretation({
    required super.id,
    required String flowKey,
    required super.text,
  }) : super(
         position: CompositionPosition.interpretation,
         tone: CompositionTone.affirming,
         energy: CompositionEnergy.neutral,
         useCases: const <String>{'steady_presence'},
         tags: const <String>{'flow_intention', 'flow_intention_steady'},
         minimumEvidence: 3,
         claimStrength: CompositionClaimStrength.medium,
         requiresSignals: const <String>{'mostly_observed'},
         avoidSignals: const <String>{
           'broad_flow_spread',
           'has_skipped',
           'single_flow_depth',
         },
         requiresClaims: _steadyPresenceClaims,
         cooldownGroup: 'flow_intention_steady',
         optionalFlowKey: flowKey,
         weight: 60,
       );
}

class _FlowDepthInterpretation extends CompositionPhrase {
  const _FlowDepthInterpretation({
    required super.id,
    required String flowKey,
    required super.text,
  }) : super(
         position: CompositionPosition.interpretation,
         tone: CompositionTone.still,
         energy: CompositionEnergy.neutral,
         useCases: const <String>{'single_flow_depth'},
         tags: const <String>{'flow_intention', 'flow_intention_depth'},
         minimumEvidence: 3,
         claimStrength: CompositionClaimStrength.medium,
         requiresSignals: const <String>{
           'mostly_observed',
           'single_flow_depth',
         },
         avoidSignals: const <String>{'many_skips', 'mostly_partial'},
         requiresClaims: _singleFlowDepthClaims,
         avoidClaims: _singleFlowAvoidClaims,
         cooldownGroup: 'flow_intention_depth',
         optionalFlowKey: flowKey,
         weight: 60,
       );
}

const List<CompositionPhrase> _flowIntentionPhrases = <CompositionPhrase>[
  _FlowLightInterpretation(
    id: 'flow_track_sky_light',
    flowKey: 'track-the-sky',
    text:
        'Track the Sky points toward steady attention: noticing what is present before reacting.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_track_sky_steady',
    flowKey: 'track-the-sky',
    text:
        'Through Track the Sky, you practiced steady attention: noticing what was actually visible before adding a story.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_track_sky_depth',
    flowKey: 'track-the-sky',
    text:
        'Through Track the Sky, you practiced steady attention: returning to what was visible even when conditions were not perfect.',
  ),
  _FlowLightInterpretation(
    id: 'flow_dawn_house_light',
    flowKey: 'dawn-house-rite',
    text:
        'Dawn House Rite points toward a clean beginning: using water, light, and one right act to shape the day early.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_dawn_house_steady',
    flowKey: 'dawn-house-rite',
    text:
        'Through Dawn House Rite, you practiced a clean beginning: giving the day one small act before it gathered force.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_dawn_house_depth',
    flowKey: 'dawn-house-rite',
    text:
        'Through Dawn House Rite, you practiced a clean beginning: meeting the day early enough to keep it from scattering.',
  ),
  _FlowLightInterpretation(
    id: 'flow_evening_threshold_light',
    flowKey: 'evening_threshold',
    text:
        'Evening Threshold points toward evening review: naming what happened before deciding what carries forward.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_evening_threshold_steady',
    flowKey: 'evening_threshold',
    text:
        'Through Evening Threshold, you practiced evening review: returning to the day as it was before carrying anything into tomorrow.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_evening_threshold_depth',
    flowKey: 'evening_threshold',
    text:
        'Through Evening Threshold, you practiced evening review: letting the record decide what should cross into tomorrow.',
  ),
  _FlowLightInterpretation(
    id: 'flow_evening_threshold_rite_light',
    flowKey: 'evening-threshold-rite',
    text:
        'Evening Threshold Rite points toward closure: settling one open loop so the day does not keep spilling forward.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_evening_threshold_rite_steady',
    flowKey: 'evening-threshold-rite',
    text:
        'Through Evening Threshold Rite, you practiced closure: giving the house and the day a clearer edge.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_evening_threshold_rite_depth',
    flowKey: 'evening-threshold-rite',
    text:
        'Through Evening Threshold Rite, you practiced closure: naming what was finished so it could stop asking for attention.',
  ),
  _FlowLightInterpretation(
    id: 'flow_weighing_light',
    flowKey: 'the-weighing',
    text:
        'The Weighing points toward honest review: placing one real record on the scale without shame.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_weighing_steady',
    flowKey: 'the-weighing',
    text:
        'Through The Weighing, you practiced honest review: making the record clear enough for correction.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_weighing_depth',
    flowKey: 'the-weighing',
    text:
        'Through The Weighing, you practiced honest review: letting correction begin from truth instead of blame.',
  ),
  _FlowLightInterpretation(
    id: 'flow_offering_table_light',
    flowKey: 'the-offering-table',
    text:
        'The Offering Table points toward provision: answering a need with water, food, rest, or care.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_offering_table_steady',
    flowKey: 'the-offering-table',
    text:
        'Through The Offering Table, you practiced provision: making care concrete enough to be received.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_offering_table_depth',
    flowKey: 'the-offering-table',
    text:
        'Through The Offering Table, you practiced provision: answering need through something actual rather than only concern.',
  ),
  _FlowLightInterpretation(
    id: 'flow_tending_light',
    flowKey: 'the-tending',
    text:
        'The Tending points toward specific care: naming who or what needs tending before acting.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_tending_steady',
    flowKey: 'the-tending',
    text:
        'Through The Tending, you practiced specific care: moving attention toward a person, place, or need that could receive it.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_tending_depth',
    flowKey: 'the-tending',
    text:
        'Through The Tending, you practiced specific care: turning concern into labor that could land.',
  ),
  _FlowLightInterpretation(
    id: 'flow_kept_word_light',
    flowKey: 'the-kept-word',
    text:
        'The Kept Word points toward kept agreement: checking what was said against what was done.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_kept_word_steady',
    flowKey: 'the-kept-word',
    text:
        'Through The Kept Word, you practiced kept agreement: holding what was said and what was done in the same view.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_kept_word_depth',
    flowKey: 'the-kept-word',
    text:
        'Through The Kept Word, you practiced kept agreement: making repair part of the spoken record.',
  ),
  _FlowLightInterpretation(
    id: 'flow_course_light',
    flowKey: 'the-course',
    text:
        'The Course points toward time orientation: choosing action by the day, decan, and season.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_course_steady',
    flowKey: 'the-course',
    text:
        'Through The Course, you practiced time orientation: measuring action against time instead of impulse.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_course_depth',
    flowKey: 'the-course',
    text:
        'Through The Course, you practiced time orientation: choosing the next act by what the moment could actually hold.',
  ),
  _FlowLightInterpretation(
    id: 'flow_moon_return_light',
    flowKey: 'the-moon-return',
    text:
        'The Moon Return points toward lunar reflection: noticing what is released and what becomes full.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_moon_return_steady',
    flowKey: 'the-moon-return',
    text:
        'Through The Moon Return, you practiced lunar reflection: treating absence and fullness as usable evidence.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_moon_return_depth',
    flowKey: 'the-moon-return',
    text:
        'Through The Moon Return, you practiced lunar reflection: reading what emptied and what filled together.',
  ),
  _FlowLightInterpretation(
    id: 'flow_wag_light',
    flowKey: 'the-wag',
    text:
        'The Wag points toward remembrance: tending memory through provision, not only feeling.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_wag_steady',
    flowKey: 'the-wag',
    text:
        'Through The Wag, you practiced remembrance: meeting the honored dead through table, memory, and return.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_wag_depth',
    flowKey: 'the-wag',
    text:
        'Through The Wag, you practiced remembrance: letting grief and provision sit at the same table.',
  ),
  _FlowLightInterpretation(
    id: 'flow_decan_watch_light',
    flowKey: 'the-decan-watch',
    text:
        'The Decan Watch points toward decan orientation: beginning the next ten days from what the night actually allowed.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_decan_watch_steady',
    flowKey: 'the-decan-watch',
    text:
        'Through The Decan Watch, you practiced decan orientation: opening the ten-day period from honest sky contact.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_decan_watch_depth',
    flowKey: 'the-decan-watch',
    text:
        'Through The Decan Watch, you practiced decan orientation: carrying a bearing without forcing the sky to answer.',
  ),
  _FlowLightInterpretation(
    id: 'flow_days_outside_light',
    flowKey: 'the-days-outside-the-year',
    text:
        'The Days Outside the Year points toward year transition: closing the old cycle before the new one opens.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_days_outside_steady',
    flowKey: 'the-days-outside-the-year',
    text:
        'Through The Days Outside the Year, you practiced year transition: keeping closing and opening in their proper places.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_days_outside_depth',
    flowKey: 'the-days-outside-the-year',
    text:
        'Through The Days Outside the Year, you practiced year transition: letting the outside days remain distinct instead of blurred.',
  ),
  _FlowLightInterpretation(
    id: 'flow_open_hand_light',
    flowKey: 'the-open-hand',
    text:
        'The Open Hand points toward outward help: meeting a visible need with a real resource.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_open_hand_steady',
    flowKey: 'the-open-hand',
    text:
        'Through The Open Hand, you practiced outward help: seeing a need and answering it with something usable.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_open_hand_depth',
    flowKey: 'the-open-hand',
    text:
        'Through The Open Hand, you practiced outward help: turning generosity into accountable action.',
  ),
  _FlowLightInterpretation(
    id: 'flow_djed_light',
    flowKey: 'the-djed',
    text:
        'The Djed points toward stability: naming the load-bearing part before restoring it.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_djed_steady',
    flowKey: 'the-djed',
    text:
        'Through The Djed, you practiced stability: keeping the spine of the matter visible.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_djed_depth',
    flowKey: 'the-djed',
    text:
        'Through The Djed, you practiced stability: meeting what wobbled before trying to raise it.',
  ),
  _FlowLightInterpretation(
    id: 'flow_reading_house_light',
    flowKey: 'reading-house',
    text:
        'Reading House points toward measured study: reading slowly enough to keep one useful mark.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_reading_house_steady',
    flowKey: 'reading-house',
    text:
        'Through Reading House, you practiced measured study: approaching the text slowly enough to leave a mark.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_reading_house_depth',
    flowKey: 'reading-house',
    text:
        'Through Reading House, you practiced measured study: turning reading into a record, not just passage through pages.',
  ),
  _FlowLightInterpretation(
    id: 'flow_the_reading_house_light',
    flowKey: 'the-reading-house',
    text:
        'The Reading House points toward measured study: reading slowly enough to keep one useful mark.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_the_reading_house_steady',
    flowKey: 'the-reading-house',
    text:
        'Through The Reading House, you practiced measured study: approaching the text slowly enough to leave a mark.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_the_reading_house_depth',
    flowKey: 'the-reading-house',
    text:
        'Through The Reading House, you practiced measured study: turning reading into a record, not just passage through pages.',
  ),
  _FlowLightInterpretation(
    id: 'flow_fair_hearing_light',
    flowKey: 'the-fair-hearing',
    text:
        'The Fair Hearing points toward fair judgment: hearing comes before decision and the measure stays even.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_fair_hearing_steady',
    flowKey: 'the-fair-hearing',
    text:
        'Through The Fair Hearing, you practiced fair judgment: keeping the hearing wider than the first conclusion.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_fair_hearing_depth',
    flowKey: 'the-fair-hearing',
    text:
        'Through The Fair Hearing, you practiced fair judgment: holding the measure even when preference was present.',
  ),
  _FlowLightInterpretation(
    id: 'flow_house_life_light',
    flowKey: 'the-house-of-life',
    text:
        'The House of Life points toward transmission: knowledge is learned accurately before it is handed on.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_house_life_steady',
    flowKey: 'the-house-of-life',
    text:
        'Through The House of Life, you practiced careful transmission: placing accuracy before display.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_house_life_depth',
    flowKey: 'the-house-of-life',
    text:
        'Through The House of Life, you practiced careful transmission: making what was learned fit to preserve.',
  ),
  _FlowLightInterpretation(
    id: 'flow_boundary_stone_light',
    flowKey: 'the-boundary-stone',
    text:
        'The Boundary Stone points toward boundary work: resources, force, and credit return to right measure.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_boundary_stone_steady',
    flowKey: 'the-boundary-stone',
    text:
        'Through The Boundary Stone, you practiced boundary repair: naming what had moved so it could be marked.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_boundary_stone_depth',
    flowKey: 'the-boundary-stone',
    text:
        'Through The Boundary Stone, you practiced boundary repair: restoring the marker to where it belonged.',
  ),
  _FlowLightInterpretation(
    id: 'flow_hotep_light',
    flowKey: 'hotep',
    text:
        'Hotep points toward peace: real obligation is separated from fear so the heart can cool.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_hotep_steady',
    flowKey: 'hotep',
    text:
        'Through Hotep, you practiced peace after effort: naming enough before fear could add more weight.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_hotep_depth',
    flowKey: 'hotep',
    text:
        'Through Hotep, you practiced peace after effort: cooling the heart without denying what was owed.',
  ),
  _FlowLightInterpretation(
    id: 'flow_open_mouth_light',
    flowKey: 'the-open-mouth',
    text:
        'The Open Mouth points toward speech: words are treated as things that create conditions.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_open_mouth_steady',
    flowKey: 'the-open-mouth',
    text:
        'Through The Open Mouth, you practiced careful speech: treating the mouth as an instrument with consequences.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_open_mouth_depth',
    flowKey: 'the-open-mouth',
    text:
        'Through The Open Mouth, you practiced careful speech: making both saying and withholding deliberate.',
  ),
  _FlowLightInterpretation(
    id: 'flow_living_record_light',
    flowKey: 'the-living-record',
    text:
        'The Living Record points toward record-keeping: the decan becomes an account that can be trusted.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_living_record_steady',
    flowKey: 'the-living-record',
    text:
        'Through The Living Record, you practiced reliable record-keeping: making what happened durable enough to revisit.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_living_record_depth',
    flowKey: 'the-living-record',
    text:
        'Through The Living Record, you practiced reliable record-keeping: making the account part of the work itself.',
  ),
  _FlowLightInterpretation(
    id: 'flow_het_heru_light',
    flowKey: 'het-heru',
    text:
        'Het-Heru points toward cooling strong feeling: returning heat toward beauty, joy, rest, or feast.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_het_heru_steady',
    flowKey: 'het-heru',
    text:
        'Through Het-Heru, you practiced cooling strong feeling: meeting heat before it became destructive.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_het_heru_depth',
    flowKey: 'het-heru',
    text:
        'Through Het-Heru, you practiced cooling strong feeling: returning intensity toward joy without denying it.',
  ),
  _FlowLightInterpretation(
    id: 'flow_shore_light',
    flowKey: 'the-shore',
    text:
        'The Shore points toward exchange: what is offered and what returns move closer to honest measure.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_shore_steady',
    flowKey: 'the-shore',
    text:
        'Through The Shore, you practiced honest exchange: keeping giving and return in the same account.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_shore_depth',
    flowKey: 'the-shore',
    text:
        'Through The Shore, you practiced honest exchange: weighing value without pretending all returns are equal.',
  ),
  _FlowLightInterpretation(
    id: 'flow_autobiography_light',
    flowKey: 'the-autobiography',
    text:
        'The Autobiography points toward life-record: claims are tied to evidence instead of performance.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_autobiography_steady',
    flowKey: 'the-autobiography',
    text:
        'Through The Autobiography, you practiced evidence-based self-record: naming capacity and conduct with support.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_autobiography_depth',
    flowKey: 'the-autobiography',
    text:
        'Through The Autobiography, you practiced evidence-based self-record: making the account truer than display.',
  ),
  _FlowLightInterpretation(
    id: 'flow_first_arrangement_light',
    flowKey: 'the-first-arrangement',
    text:
        'The First Arrangement points toward space-order: a place is seen accurately before it is rearranged.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_first_arrangement_steady',
    flowKey: 'the-first-arrangement',
    text:
        'Through The First Arrangement, you practiced ordering a place: reading the room before correcting it.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_first_arrangement_depth',
    flowKey: 'the-first-arrangement',
    text:
        'Through The First Arrangement, you practiced ordering a place: helping what belonged find its place again.',
  ),
  _FlowLightInterpretation(
    id: 'flow_living_pattern_light',
    flowKey: 'the-living-pattern',
    text:
        'The Living Pattern points toward patient observation: watching the natural world before drawing conclusions.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_living_pattern_steady',
    flowKey: 'the-living-pattern',
    text:
        'Through The Living Pattern, you practiced patient observation: waiting long enough for nature to show the lesson.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_living_pattern_depth',
    flowKey: 'the-living-pattern',
    text:
        'Through The Living Pattern, you practiced patient observation: letting interpretation follow observation instead of replacing it.',
  ),
  _FlowLightInterpretation(
    id: 'flow_true_name_light',
    flowKey: 'the-true-name',
    text:
        'The True Name points toward accurate naming: a false account is measured against the record.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_true_name_steady',
    flowKey: 'the-true-name',
    text:
        'Through The True Name, you practiced accurate naming: testing a given account against what the record showed.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_true_name_depth',
    flowKey: 'the-true-name',
    text:
        'Through The True Name, you practiced accurate naming: moving the name closer to evidence.',
  ),
  _FlowLightInterpretation(
    id: 'flow_living_text_light',
    flowKey: 'the-living-text',
    text:
        'The Living Text points toward living study: a line becomes question, application, or mark.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_living_text_steady',
    flowKey: 'the-living-text',
    text:
        'Through The Living Text, you practiced living study: letting the text change what came next.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_living_text_depth',
    flowKey: 'the-living-text',
    text:
        'Through The Living Text, you practiced living study: making reading a mark in the Library, not only intake.',
  ),
  _FlowLightInterpretation(
    id: 'flow_clearing_light',
    flowKey: 'the-clearing',
    text:
        'The Clearing points toward temperance: space is made before reply so action can come from the cleared place.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_clearing_steady',
    flowKey: 'the-clearing',
    text:
        'Through The Clearing, you practiced temperance: giving heat room before it became action.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_clearing_depth',
    flowKey: 'the-clearing',
    text:
        'Through The Clearing, you practiced temperance: making the cleared place easier to find again.',
  ),
  _FlowLightInterpretation(
    id: 'flow_wandering_light',
    flowKey: 'the-wandering',
    text:
        'The Wandering points toward grief accompaniment: loss is honored while one remaining capacity is noticed.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_wandering_steady',
    flowKey: 'the-wandering',
    text:
        'Through The Wandering, you practiced grief accompaniment: letting searching and what remains sit together.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_wandering_depth',
    flowKey: 'the-wandering',
    text:
        'Through The Wandering, you practiced grief accompaniment: noticing what remains without dismissing the loss.',
  ),
  _FlowLightInterpretation(
    id: 'flow_khat_light',
    flowKey: 'the-khat',
    text:
        'The Khat points toward body care: answering the body with one concrete act.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_khat_steady',
    flowKey: 'the-khat',
    text:
        'Through The Khat, you practiced body care: treating the body as evidence, not interruption.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_khat_depth',
    flowKey: 'the-khat',
    text:
        'Through The Khat, you practiced body care: making response more concrete than intention.',
  ),
  _FlowLightInterpretation(
    id: 'flow_oracle_light',
    flowKey: 'the-oracle',
    text:
        'The Oracle points toward dream-question work: meaning is received without force and tested through grounded action.',
  ),
  _FlowSteadyInterpretation(
    id: 'flow_oracle_steady',
    flowKey: 'the-oracle',
    text:
        'Through The Oracle, you practiced dream-question work: receiving before interpreting.',
  ),
  _FlowDepthInterpretation(
    id: 'flow_oracle_depth',
    flowKey: 'the-oracle',
    text:
        'Through The Oracle, you practiced dream-question work: testing signs through action instead of certainty.',
  ),
];

const List<CompositionPhrase> kDecanReflectionPhrases = <CompositionPhrase>[
  ..._flowIntentionPhrases,
  // Cross-flow inference.
  CompositionPhrase(
    id: 'cross_flow_shared_interpretation',
    text:
        'Much of this decan asked for {cross_flow_intention_label}: {cross_flow_intention_description}.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'broad_flow_spread', 'simple_completion'},
    minimumEvidence: 4,
    claimStrength: CompositionClaimStrength.medium,
    requiresClaims: _crossFlowSharedClaims,
    avoidClaims: _crossFlowUncenteredClaims,
    cooldownGroup: 'cross_flow_interpretation',
    weight: 80,
  ),
  CompositionPhrase(
    id: 'cross_flow_holding_consequence',
    text:
        'The common thread was practical, not abstract: {observed_count_label} returned to {cross_flow_intention_label}.',
    position: CompositionPosition.consequence,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'steady_presence', 'broad_flow_spread'},
    minimumEvidence: 4,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'mostly_observed'},
    avoidSignals: <String>{'has_skipped'},
    requiresClaims: _crossFlowHoldingClaims,
    cooldownGroup: 'cross_flow_consequence',
    weight: 80,
  ),
  CompositionPhrase(
    id: 'cross_flow_holding_next',
    text: 'Repeat that same thread once before widening the field.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'steady_presence'},
    minimumEvidence: 4,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'mostly_observed'},
    avoidSignals: <String>{'has_skipped'},
    requiresClaims: _crossFlowHoldingClaims,
    cooldownGroup: 'cross_flow_next_step',
    weight: 70,
  ),
  CompositionPhrase(
    id: 'cross_flow_partial_interpretation',
    text:
        'The pull toward {cross_flow_intention_label} is present, but the form needs easier completion.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'partial_continuity'},
    minimumEvidence: 4,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'mostly_partial'},
    requiresClaims: _crossFlowPartialClaims,
    cooldownGroup: 'cross_flow_interpretation',
    weight: 80,
  ),
  CompositionPhrase(
    id: 'cross_flow_partial_next',
    text:
        'Keep {cross_flow_intention_label} small enough to finish once before asking for more.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'partial_continuity'},
    minimumEvidence: 4,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'mostly_partial'},
    requiresClaims: _crossFlowPartialClaims,
    cooldownGroup: 'cross_flow_next_step',
    weight: 80,
  ),
  CompositionPhrase(
    id: 'cross_flow_friction_interpretation',
    text:
        'The record reaches toward {cross_flow_intention_label}, but the gate is breaking before completion.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'many_skips'},
    minimumEvidence: 4,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'many_skips'},
    requiresClaims: _crossFlowFrictionClaims,
    cooldownGroup: 'cross_flow_interpretation',
    weight: 80,
  ),
  CompositionPhrase(
    id: 'cross_flow_friction_next',
    text:
        'Keep the same intention, but lower the gate until one completion can land.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'many_skips'},
    minimumEvidence: 4,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'many_skips'},
    requiresClaims: _crossFlowFrictionClaims,
    cooldownGroup: 'cross_flow_next_step',
    weight: 80,
  ),
  CompositionPhrase(
    id: 'cross_flow_uncentered_interpretation',
    text:
        'The decan reached in several directions, and no single practice held the center.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'broad_flow_spread'},
    minimumEvidence: 4,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'broad_flow_spread'},
    requiresClaims: _crossFlowUncenteredClaims,
    cooldownGroup: 'cross_flow_interpretation',
    weight: 90,
  ),
  CompositionPhrase(
    id: 'cross_flow_uncentered_next',
    text:
        'Choose one practice to hold the center, then let the other directions support it.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'broad_flow_spread'},
    minimumEvidence: 4,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'broad_flow_spread'},
    requiresClaims: _crossFlowUncenteredClaims,
    cooldownGroup: 'cross_flow_next_step',
    weight: 80,
  ),

  // Low data.
  CompositionPhrase(
    id: 'low_obs_one_mark',
    text: 'One observed interaction anchors this decan.',
    position: CompositionPosition.observation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'low_data'},
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'low_data'},
    requiresClaims: _firstContactClaims,
    cooldownGroup: 'low_data_observation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'low_obs_one_record',
    text: 'One recorded interaction marks the decan.',
    position: CompositionPosition.observation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'low_data'},
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'low_data'},
    requiresClaims: _lowEvidenceClaims,
    avoidClaims: _firstContactClaims,
    cooldownGroup: 'low_data_observation',
  ),
  CompositionPhrase(
    id: 'low_interp_small_contact',
    text:
        'That single contact shows the way back without forcing a larger story.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'low_data'},
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'low_data'},
    requiresClaims: _firstContactClaims,
    cooldownGroup: 'low_data_interpretation',
  ),
  CompositionPhrase(
    id: 'low_interp_one_point',
    text:
        'A single point can orient the record without pretending to be a pattern.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'low_data'},
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'low_data'},
    requiresClaims: _lowEvidenceClaims,
    cooldownGroup: 'low_data_interpretation',
  ),
  CompositionPhrase(
    id: 'low_next_one_action',
    text:
        'For the next decan, choose one small action and make completion easier than ambition.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'low_data'},
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'low_data'},
    requiresClaims: _firstContactClaims,
    cooldownGroup: 'low_data_next_step',
  ),
  CompositionPhrase(
    id: 'low_next_repeatable_gate',
    text:
        'Let the next interval begin with a gate small enough to repeat without strain.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'low_data'},
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'low_data'},
    requiresClaims: _supportBeforeExpansionClaims,
    cooldownGroup: 'low_data_next_step',
  ),

  // Dominant principle interpretation.
  CompositionPhrase(
    id: 'principle_truth_grounding_low',
    text:
        'Truth turns a small record into usable evidence: what happened was named without decoration.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: _lowGroundingPrincipleUseCases,
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'dominant_principle_truth'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_order_grounding_low',
    text:
        'Order begins in scale: the next gate can be clearer without becoming heavier.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: _lowGroundingPrincipleUseCases,
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'dominant_principle_order'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_balance_grounding_low',
    text:
        'Balance keeps contact and limits in the same view, so the next step can stay proportionate.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: _lowGroundingPrincipleUseCases,
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'dominant_principle_balance'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_truth_many_skips',
    text:
        'Truth makes the missed gate useful: the record can point to support without blame.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'many_skips'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'dominant_principle_truth'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_order_many_skips',
    text:
        'Order starts by lowering the gate: shape matters more than force here.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'many_skips'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'dominant_principle_order'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_balance_many_skips',
    text:
        'Balance keeps the missed gate and the remaining contact in one view.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'many_skips'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'dominant_principle_balance'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_truth_grounding_neutral',
    text:
        'Truth sharpens the record: mixed marks can be sorted without guessing.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: _neutralGroundingPrincipleUseCases,
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'dominant_principle_truth'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_order_grounding_neutral',
    text: 'Order gives range a shape: that is range, not scatter.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: _neutralGroundingPrincipleUseCases,
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'dominant_principle_order'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_balance_grounding_neutral',
    text:
        'Balance turns the mixed record into proportion: each part shows what needs support next.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: _neutralGroundingPrincipleUseCases,
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'dominant_principle_balance'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_truth_affirming_neutral',
    text:
        'Truth is already visible in the pattern: the record can be trusted without embellishment.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: _affirmingPrincipleUseCases,
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'dominant_principle_truth'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_order_affirming_neutral',
    text:
        'Order interprets that steadiness as a pattern to protect, not a streak to chase.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: _affirmingPrincipleUseCases,
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'dominant_principle_order'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_balance_affirming_neutral',
    text:
        'Balance turns the mix into calibration: the measure can change without treating the record as failure.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: _affirmingPrincipleUseCases,
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'dominant_principle_balance'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_recovery_after_interruption',
    text: 'The return matters because it came after interruption.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'steady_presence'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{
      'dominant_principle_balance',
      'has_skipped',
      'mostly_observed',
    },
    requiresClaims: _steadyPresenceClaims,
    cooldownGroup: 'principle_interpretation',
    weight: 40,
  ),
  CompositionPhrase(
    id: 'principle_truth_still_neutral',
    text:
        'Truth deepens through repetition when the same thread is chosen again.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.still,
    energy: CompositionEnergy.neutral,
    useCases: _stillPrincipleUseCases,
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'dominant_principle_truth'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_order_still_neutral',
    text:
        'Order deepens when repetition becomes chosen attention rather than habit.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.still,
    energy: CompositionEnergy.neutral,
    useCases: _stillPrincipleUseCases,
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'dominant_principle_order'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'principle_balance_still_neutral',
    text:
        'Balance keeps depth proportional: staying with one thread can be stronger than widening too soon.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.still,
    energy: CompositionEnergy.neutral,
    useCases: _stillPrincipleUseCases,
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'dominant_principle_balance'},
    cooldownGroup: 'principle_interpretation',
    weight: 20,
  ),

  // Many skips.
  CompositionPhrase(
    id: 'skip_obs_larger_part',
    text:
        'A visible record held {interaction_count_label}, including {skipped_count_label} where the gate did not hold.',
    position: CompositionPosition.observation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'many_skips'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'many_skips'},
    requiresClaims: _skippedGateClaims,
    cooldownGroup: 'skips_observation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'skip_obs_more_skipped',
    text:
        'The record stayed visible across {active_days_label}, even where completion did not fully hold.',
    position: CompositionPosition.observation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'many_skips'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'many_skips'},
    requiresClaims: _skippedGateClaims,
    cooldownGroup: 'skips_observation',
  ),
  CompositionPhrase(
    id: 'skip_interp_gate_heavy',
    text:
        'The marks that did not hold still show where the current gate may have been too heavy.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'many_skips'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'many_skips'},
    requiresClaims: _skippedGateClaims,
    cooldownGroup: 'skips_interpretation',
  ),
  CompositionPhrase(
    id: 'skip_interp_record_usable',
    text:
        'The honest record still belongs to the work; it points directly to where support is needed.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'many_skips'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'many_skips'},
    requiresClaims: _supportBeforeExpansionClaims,
    cooldownGroup: 'skips_interpretation',
  ),
  CompositionPhrase(
    id: 'skip_next_lower_gate',
    text:
        'Begin again with one lower gate, and let consistency matter more than intensity.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'many_skips'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'many_skips'},
    requiresClaims: _supportBeforeExpansionClaims,
    cooldownGroup: 'skips_next_step',
  ),
  CompositionPhrase(
    id: 'skip_next_restore_entry',
    text:
        'For the next decan, make the first step smaller before asking for deeper completion.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'many_skips'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'many_skips'},
    requiresClaims: _supportBeforeExpansionClaims,
    cooldownGroup: 'skips_next_step',
  ),

  // Mostly partial.
  CompositionPhrase(
    id: 'partial_obs_most_partly',
    text:
        'Across {active_days_label}, contact continued through {partial_count_label} and {observed_count_label}.',
    position: CompositionPosition.observation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'partial_continuity'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'mostly_partial'},
    requiresClaims: _partialContactClaims,
    cooldownGroup: 'partial_observation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'partial_obs_continued',
    text:
        'Contact stayed visible across {active_days_label}, even where completion stayed partial.',
    position: CompositionPosition.observation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'partial_continuity'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'mostly_partial'},
    requiresClaims: _partialContactClaims,
    cooldownGroup: 'partial_observation',
  ),
  CompositionPhrase(
    id: 'partial_interp_contact_remained',
    text: 'Contact remained, and the form can now be made easier to finish.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'partial_continuity'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'mostly_partial'},
    requiresClaims: _partialContactClaims,
    cooldownGroup: 'partial_interpretation',
  ),
  CompositionPhrase(
    id: 'partial_interp_rhythm_thinned',
    text: 'The rhythm thinned, but it did not disappear.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'partial_continuity'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'mostly_partial'},
    requiresClaims: _partialContactClaims,
    cooldownGroup: 'partial_interpretation',
  ),
  CompositionPhrase(
    id: 'partial_consequence_finishable',
    text:
        'A finishable measure will teach more than a beautiful measure that keeps slipping.',
    position: CompositionPosition.consequence,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'partial_continuity'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'mostly_partial'},
    requiresClaims: _supportBeforeExpansionClaims,
    cooldownGroup: 'partial_consequence',
  ),
  CompositionPhrase(
    id: 'partial_next_less_friction',
    text: 'Remove one point of friction before you repeat the practice.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'partial_continuity'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'mostly_partial'},
    requiresClaims: _supportBeforeExpansionClaims,
    cooldownGroup: 'partial_next_step',
  ),
  CompositionPhrase(
    id: 'partial_next_keep_reachable',
    text: 'Set the next measure small enough to finish in one sitting.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'partial_continuity'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'mostly_partial'},
    requiresClaims: _supportBeforeExpansionClaims,
    cooldownGroup: 'partial_next_step',
  ),

  // Single-flow depth.
  CompositionPhrase(
    id: 'single_obs_returned_same',
    text:
        'One flow carried {interaction_count_label} across {active_days_label}.',
    position: CompositionPosition.observation,
    tone: CompositionTone.still,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'single_flow_depth'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'single_flow_depth'},
    avoidSignals: <String>{'many_skips', 'mostly_partial'},
    requiresClaims: _singleFlowDepthClaims,
    avoidClaims: _singleFlowAvoidClaims,
    cooldownGroup: 'single_flow_observation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'single_obs_same_thread',
    text: 'One flow held the decan’s thread across {active_days_label}.',
    position: CompositionPosition.observation,
    tone: CompositionTone.still,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'single_flow_depth'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'single_flow_depth'},
    avoidSignals: <String>{'many_skips', 'mostly_partial'},
    requiresClaims: _singleFlowDepthClaims,
    avoidClaims: _singleFlowAvoidClaims,
    cooldownGroup: 'single_flow_observation',
  ),
  CompositionPhrase(
    id: 'single_interp_depth',
    text: 'Repetition can be depth when it is chosen with attention.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.still,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'single_flow_depth'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'single_flow_depth'},
    avoidSignals: <String>{'many_skips', 'mostly_partial'},
    requiresClaims: _singleFlowDepthClaims,
    avoidClaims: _singleFlowAvoidClaims,
    cooldownGroup: 'single_flow_interpretation',
  ),
  CompositionPhrase(
    id: 'single_interp_thread_attention',
    text: 'A repeated thread can become a place of attention instead of habit.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.still,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'single_flow_depth'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'single_flow_depth'},
    avoidSignals: <String>{'many_skips', 'mostly_partial'},
    requiresClaims: _singleFlowDepthClaims,
    avoidClaims: _singleFlowAvoidClaims,
    cooldownGroup: 'single_flow_interpretation',
  ),
  CompositionPhrase(
    id: 'single_consequence_thread_teaches',
    text: 'Repeating one flow made small changes easier to notice.',
    position: CompositionPosition.consequence,
    tone: CompositionTone.still,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'single_flow_depth'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'single_flow_depth'},
    avoidSignals: <String>{'many_skips', 'mostly_partial'},
    requiresClaims: _singleFlowDepthClaims,
    avoidClaims: _singleFlowAvoidClaims,
    cooldownGroup: 'single_flow_consequence',
  ),

  // Broad flow spread.
  CompositionPhrase(
    id: 'broad_obs_many_currents',
    text:
        'The record touched {distinct_flow_count_label} across {active_days_label}.',
    position: CompositionPosition.observation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'broad_flow_spread'},
    minimumEvidence: 3,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'broad_flow_spread'},
    requiresClaims: _breadthAsRangeClaims,
    cooldownGroup: 'broad_observation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'broad_obs_multiple_flows',
    text:
        'Attention spread across {distinct_flow_count_label}, with {observed_count_label} completed.',
    position: CompositionPosition.observation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'broad_flow_spread'},
    minimumEvidence: 3,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'broad_flow_spread'},
    requiresClaims: _breadthAsRangeClaims,
    cooldownGroup: 'broad_observation',
  ),
  CompositionPhrase(
    id: 'broad_interp_center',
    text:
        'You reached in several directions, and no single practice held the center.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'broad_flow_spread'},
    minimumEvidence: 3,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'broad_flow_spread'},
    requiresClaims: _breadthNeedsCenterClaims,
    cooldownGroup: 'broad_interpretation',
    weight: 30,
  ),
  CompositionPhrase(
    id: 'broad_interp_wide_record',
    text: 'A wide record becomes useful when it has a center.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'broad_flow_spread'},
    minimumEvidence: 3,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'broad_flow_spread'},
    requiresClaims: _breadthNeedsCenterClaims,
    cooldownGroup: 'broad_interpretation',
  ),
  CompositionPhrase(
    id: 'broad_next_name_center',
    text: 'Name the center first, then let the surrounding flows support it.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'broad_flow_spread'},
    minimumEvidence: 3,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'broad_flow_spread'},
    requiresClaims: _breadthNeedsCenterClaims,
    cooldownGroup: 'broad_next_step',
  ),
  CompositionPhrase(
    id: 'broad_next_choose_one',
    text:
        'Choose one flow to lead the next interval, then let the rest arrange around it.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'broad_flow_spread'},
    minimumEvidence: 3,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'broad_flow_spread'},
    requiresClaims: _breadthNeedsCenterClaims,
    cooldownGroup: 'broad_next_step',
  ),

  // Steady presence.
  CompositionPhrase(
    id: 'steady_obs_most_marks',
    text:
        'Across {active_days_label}, {observed_count_label} carried most of the decan.',
    position: CompositionPosition.observation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'steady_presence'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'mostly_observed'},
    requiresClaims: _steadyPresenceClaims,
    cooldownGroup: 'steady_observation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'steady_obs_observed',
    text: '{observed_count_title_label} held the center of this decan.',
    position: CompositionPosition.observation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'steady_presence'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'mostly_observed'},
    requiresClaims: _steadyPresenceClaims,
    cooldownGroup: 'steady_observation',
  ),
  CompositionPhrase(
    id: 'steady_obs_return_after_interruption',
    text:
        'Balance framed the finish: {observed_count_label} followed {skipped_count_label}.',
    position: CompositionPosition.observation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'steady_presence'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{
      'mostly_observed',
      'has_skipped',
      'dominant_principle_balance',
    },
    requiresClaims: _steadyPresenceClaims,
    cooldownGroup: 'steady_observation',
    weight: 30,
  ),
  CompositionPhrase(
    id: 'steady_interp_pattern',
    text: 'A pattern becomes trustworthy when it survives ordinary days.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'steady_presence'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'mostly_observed'},
    requiresClaims: _steadyPresenceClaims,
    cooldownGroup: 'steady_interpretation',
  ),
  CompositionPhrase(
    id: 'steady_interp_continuity',
    text: 'Continuity is easier to trust when it appears across ordinary days.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'steady_presence'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'mostly_observed'},
    requiresClaims: _steadyPresenceClaims,
    cooldownGroup: 'steady_interpretation',
  ),
  CompositionPhrase(
    id: 'steady_consequence_rhythm_support',
    text: 'What worked was repeatability across ordinary days.',
    position: CompositionPosition.consequence,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'steady_presence'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.medium,
    requiresSignals: <String>{'mostly_observed'},
    avoidSignals: <String>{'has_skipped'},
    requiresClaims: _steadyPresenceClaims,
    cooldownGroup: 'steady_consequence',
  ),

  // Mixed or low follow-through.
  CompositionPhrase(
    id: 'generic_obs_mixed',
    text:
        'A mixed but usable record covered {interaction_count_label} across {distinct_flow_count_label}.',
    position: CompositionPosition.observation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'simple_completion', 'generic'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresClaims: _recordedContactClaims,
    cooldownGroup: 'generic_observation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'generic_obs_visible',
    text: 'The decan left a visible record across {active_days_label}.',
    position: CompositionPosition.observation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'simple_completion', 'generic'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresClaims: _recordedContactClaims,
    cooldownGroup: 'generic_observation',
  ),
  CompositionPhrase(
    id: 'generic_interp_plain_record',
    text: 'A plain record gives the next choice firmer ground.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'simple_completion', 'generic'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresClaims: _recordedContactClaims,
    cooldownGroup: 'generic_interpretation',
  ),
  CompositionPhrase(
    id: 'generic_interp_honest_record',
    text:
        'What is recorded can be worked with more honestly than what is guessed.',
    position: CompositionPosition.interpretation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'simple_completion', 'generic'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresClaims: _recordedContactClaims,
    cooldownGroup: 'generic_interpretation',
  ),
  CompositionPhrase(
    id: 'generic_next_proportionate',
    text: 'Begin from the clearest mark and keep the demand proportionate.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'simple_completion', 'generic'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresClaims: _supportBeforeExpansionClaims,
    cooldownGroup: 'generic_next_step',
  ),
  CompositionPhrase(
    id: 'generic_next_smallest_repeat',
    text:
        'Choose the smallest repeatable action, then let the record grow from there.',
    position: CompositionPosition.nextStep,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'simple_completion', 'generic'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresClaims: _supportBeforeExpansionClaims,
    cooldownGroup: 'generic_next_step',
  ),

  // Recommendations.
  CompositionPhrase(
    id: 'rec_library_open_support',
    text: 'Read “{recommendation_title}” before raising the measure again.',
    position: CompositionPosition.recommendation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'partial_continuity'},
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'recommend_library'},
    requiresClaims: _libraryRecommendationClaims,
    cooldownGroup: 'library_recommendation',
  ),
  CompositionPhrase(
    id: 'rec_library_first_contact',
    text:
        'Read “{recommendation_title}” next as a way to hold the first return.',
    position: CompositionPosition.recommendation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'low_data'},
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'recommend_library'},
    requiresClaims: <CompositionClaimId>{
      CompositionClaimId.librarySupportRecommended,
      CompositionClaimId.firstContact,
    },
    cooldownGroup: 'library_recommendation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'rec_library_low_gate',
    text:
        'Let “{recommendation_title}” set a smaller entry point for the next return.',
    position: CompositionPosition.recommendation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'low_data'},
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'recommend_library'},
    requiresClaims: <CompositionClaimId>{
      CompositionClaimId.librarySupportRecommended,
      CompositionClaimId.supportBeforeExpansion,
    },
    cooldownGroup: 'library_recommendation',
    weight: 20,
  ),
  CompositionPhrase(
    id: 'rec_library_study_before_more',
    text: 'Read “{recommendation_title}” before adding another flow.',
    position: CompositionPosition.recommendation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.low,
    useCases: <String>{'many_skips', 'simple_completion'},
    minimumEvidence: 1,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'recommend_library'},
    requiresClaims: _libraryRecommendationClaims,
    cooldownGroup: 'library_recommendation',
  ),
  CompositionPhrase(
    id: 'rec_flow_continue',
    text: 'Repeat “{recommendation_title}” for one more decan.',
    position: CompositionPosition.recommendation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'single_flow_depth'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'recommend_flow'},
    requiresClaims: _flowRecommendationClaims,
    cooldownGroup: 'flow_recommendation',
  ),
  CompositionPhrase(
    id: 'rec_flow_next',
    text:
        'Let “{recommendation_title}” lead the next interval with one clear repeat.',
    position: CompositionPosition.recommendation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'steady_presence'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'recommend_flow'},
    requiresClaims: _flowRecommendationClaims,
    cooldownGroup: 'flow_recommendation',
  ),
  CompositionPhrase(
    id: 'rec_flow_recovery',
    text:
        'Use “{recommendation_title}” to repeat the return that reappeared near the end.',
    position: CompositionPosition.recommendation,
    tone: CompositionTone.affirming,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'steady_presence'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'recommend_flow', 'has_skipped'},
    requiresClaims: _flowRecommendationClaims,
    cooldownGroup: 'flow_recommendation',
    weight: 30,
  ),
  CompositionPhrase(
    id: 'rec_flow_center',
    text:
        'Use “{recommendation_title}” as the center that organizes the next interval.',
    position: CompositionPosition.recommendation,
    tone: CompositionTone.grounding,
    energy: CompositionEnergy.neutral,
    useCases: <String>{'broad_flow_spread'},
    minimumEvidence: 2,
    claimStrength: CompositionClaimStrength.low,
    requiresSignals: <String>{'recommend_flow'},
    requiresClaims: _flowRecommendationClaims,
    cooldownGroup: 'flow_recommendation',
  ),
];
