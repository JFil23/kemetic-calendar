import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dawn_house_rite_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'maat_flow_identity.dart';
import 'track_sky_flow.dart';

const String kFairHearingFlowKey = 'the-fair-hearing';
const String kFairHearingTitle = 'The Fair Hearing';
const String kFairHearingGlyph = '𓄔';
const String kFairHearingTagline =
    'You are a balance. If it wavers, then you will waver.';

const String kHouseOfLifeFlowKey = 'the-house-of-life';
const String kHouseOfLifeTitle = 'The House of Life';
const String kHouseOfLifeGlyph = '𓉐𓋹';
const String kHouseOfLifeTagline =
    'What you learn accurately, you give to those who come after.';

const String kBoundaryStoneFlowKey = 'the-boundary-stone';
const String kBoundaryStoneTitle = 'The Boundary Stone';
const String kBoundaryStoneGlyph = '𓊌';
const String kBoundaryStoneTagline =
    'What is yours ends somewhere. Know where.';

const String kHotepFlowKey = 'hotep';
const String kHotepTitle = 'Hotep';
const String kHotepGlyph = '𓊵';
const String kHotepTagline = 'What you have given is enough. Cool your heart.';

const String kOpenMouthFlowKey = 'the-open-mouth';
const String kOpenMouthTitle = 'The Open Mouth';
const String kOpenMouthGlyph = '𓂋';
const String kOpenMouthTagline =
    'What comes out of your mouth is what you are creating.';

const String kLivingRecordFlowKey = 'the-living-record';
const String kLivingRecordTitle = 'The Living Record';
const String kLivingRecordGlyph = '𓏞';
const String kLivingRecordTagline =
    'What is recorded persists. Build the record of this decan.';

const String kHetHeruFlowKey = 'het-heru';
const String kHetHeruTitle = 'Het-Heru';
const String kHetHeruGlyph = '𓉡';
const String kHetHeruTagline =
    'The destroying eye and the goddess of joy are the same force.';

const String kTheShoreFlowKey = 'the-shore';
const String kTheShoreTitle = 'The Shore';
const String kTheShoreGlyph = '𓈘';
const String kTheShoreTagline =
    'What is in your boat? Bring what you actually have.';

const String kTheAutobiographyFlowKey = 'the-autobiography';
const String kTheAutobiographyTitle = 'The Autobiography';
const String kTheAutobiographyGlyph = '𓏞𓀀';
const String kTheAutobiographyTagline =
    'I will put my annals among people and love of me among the gods.';

const String kFirstArrangementFlowKey = 'the-first-arrangement';
const String kFirstArrangementTitle = 'The First Arrangement';
const String kFirstArrangementGlyph = '𓇾';
const String kFirstArrangementTagline =
    'For I ordered everything in its proper place.';

const String kLivingPatternFlowKey = 'the-living-pattern';
const String kLivingPatternTitle = 'The Living Pattern';
const String kLivingPatternGlyph = '𓆭';
const String kLivingPatternTagline =
    'The natural world is a text. Patient observation reveals one lesson at a time.';

const String kTrueNameFlowKey = 'the-true-name';
const String kTrueNameTitle = 'The True Name';
const String kTrueNameGlyph = '𓂋𓈖';
const String kTrueNameTagline =
    'The account others gave you and the account the scale shows are not always the same.';

const String kLivingTextFlowKey = 'the-living-text';
const String kLivingTextTitle = 'The Living Text';
const String kLivingTextGlyph = '𓏛𓋹';
const String kLivingTextTagline =
    'The Library was written by those who came before. What do you add?';

const String kClearingFlowKey = 'the-clearing';
const String kClearingTitle = 'The Clearing';
const String kClearingGlyph = '𓈖';
const String kClearingTagline =
    'Its fruit is something sweet, its shade is pleasant, and it reaches its end in a grove.';

const String kWanderingFlowKey = 'the-wandering';
const String kWanderingTitle = 'The Wandering';
const String kWanderingGlyph = '𓂻';
const String kWanderingTagline = 'I found, I found.';

const String kKhatFlowKey = 'the-khat';
const String kKhatTitle = 'The Khat';
const String kKhatGlyph = '𓀾';
const String kKhatTagline = 'Teti is sound because of his body.';

const String kOracleFlowKey = 'the-oracle';
const String kOracleTitle = 'The Oracle';
const String kOracleGlyph = '𓄔';
const String kOracleTagline =
    'Thutmose placed himself in the shadow of the Great God and rested. The god came to him in the night. He awoke and acted.';

const int kMaatDecanFlowDefaultMiddayHour = 11;
const int kMaatDecanFlowDefaultMiddayMinute = 0;
const int kMaatDecanFlowEveningFallbackMinutes =
    kEveningThresholdDefaultFallbackMinutes + 20;

enum MaatDecanFlowTiming { morning, anyTime, midday, evening }

extension MaatDecanFlowTimingX on MaatDecanFlowTiming {
  String get key {
    switch (this) {
      case MaatDecanFlowTiming.morning:
        return 'morning';
      case MaatDecanFlowTiming.anyTime:
        return 'any_time';
      case MaatDecanFlowTiming.midday:
        return 'midday';
      case MaatDecanFlowTiming.evening:
        return 'evening';
    }
  }

  String get label {
    switch (this) {
      case MaatDecanFlowTiming.morning:
        return 'Morning';
      case MaatDecanFlowTiming.anyTime:
        return 'Any time';
      case MaatDecanFlowTiming.midday:
        return '11:00 local';
      case MaatDecanFlowTiming.evening:
        return 'Evening';
    }
  }
}

class MaatDecanFlowDefinition {
  final String key;
  final String title;
  final String eventTitlePrefix;
  final String glyph;
  final String tagline;
  final String overview;
  final String confidenceLabel;
  final String routingSummary;
  final String notesPrefix;
  final String behaviorKind;
  final List<String> graphNodeSlugs;
  final String burdenLabel;
  final String rhythmLabel;
  final String? specialRequirementLabel;
  final String? safetyNote;
  final List<MaatDecanFlowEvent> events;

  const MaatDecanFlowDefinition({
    required this.key,
    required this.title,
    required this.eventTitlePrefix,
    required this.glyph,
    required this.tagline,
    required this.overview,
    required this.confidenceLabel,
    required this.routingSummary,
    required this.notesPrefix,
    required this.behaviorKind,
    required this.graphNodeSlugs,
    this.burdenLabel = 'Low',
    this.rhythmLabel = 'Decan',
    this.specialRequirementLabel,
    this.safetyNote,
    required this.events,
  });
}

class MaatDecanFlowEvent {
  final int eventNumber;
  final int flowDay;
  final String decanSection;
  final String title;
  final MaatDecanFlowTiming timing;
  final int durationMinutesMin;
  final int durationMinutesMax;
  final String purpose;
  final String spokenLine;
  final List<String> steps;
  final List<String> optionalSteps;
  final String? sourceNote;
  final bool requiresRealWorldAction;
  final bool sharePromptOnComplete;
  final Map<String, String> extraCompletionStatusLabels;

  const MaatDecanFlowEvent({
    required this.eventNumber,
    required this.flowDay,
    required this.decanSection,
    required this.title,
    required this.timing,
    required this.durationMinutesMin,
    required this.durationMinutesMax,
    required this.purpose,
    required this.spokenLine,
    required this.steps,
    this.optionalSteps = const <String>[],
    this.sourceNote,
    this.requiresRealWorldAction = false,
    this.sharePromptOnComplete = false,
    this.extraCompletionStatusLabels = const <String, String>{},
  });
}

class MaatDecanFlowOccurrenceSchedule {
  final DateTime startLocal;
  final DateTime endLocal;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool usedFallback;
  final TrackSkyTimeZone timezone;
  final String referenceLocationName;
  final String scheduleType;
  final String fallback;
  final int? anchorHour;
  final int? anchorMinute;

  const MaatDecanFlowOccurrenceSchedule({
    required this.startLocal,
    required this.endLocal,
    required this.startUtc,
    required this.endUtc,
    required this.usedFallback,
    required this.timezone,
    required this.referenceLocationName,
    required this.scheduleType,
    required this.fallback,
    this.anchorHour,
    this.anchorMinute,
  });
}

const String kFairHearingOverview =
    'A 30-day practice of fair judgment: hear fully before deciding, apply the same measure to those you favor and those you do not, and pronounce the decision clearly. Drawn from the nine appeals of the Eloquent Peasant.';

const String kHouseOfLifeOverview =
    'A 30-day scribal practice for learning accurately: write with the hand, recite with the mouth, seek those who know more, then transmit one useful piece of knowledge.';

const String kBoundaryStoneOverview =
    'A 30-day survey of what is yours and what is not: map resources, labor, credit, and force; name where the markers moved; then restore at least one stone to its right place.';

const String kHotepOverview =
    'A 30-day evening practice for the peace of completed offering: name what was given, distinguish real obligation from fear of tomorrow, and let the heart cool before sleep.';

const String kOpenMouthOverview =
    'A 30-day speech practice: record what your mouth has been creating, govern the tongue through one discipline, and say one important thing that has been withheld.';

const String kLivingRecordOverview =
    'A 30-day practice of building a genuine decan account across ḥꜣw: day card, node library, planner, journal, feed, alignment, Flow Studio, guidance, and a physical record.';

const String kHetHeruOverview =
    'A 30-day practice of transforming the hot Sekhmet force into Het-Heru: name what has gone too far, find the red beer that fills the need, then practice music, feast, beauty, and joy.';

const String kTheShoreOverview =
    'A 30-day practice of honest exchange: inventory what you can offer, prepare one real exchange, make it at honest measure, and account for what returns.';

const String kTheAutobiographyOverview =
    'A 30-day life review that surveys capacities, works, and gifts, then produces a four-section autobiography: Capacities, Works, Gifts, and Claim.';

const String kFirstArrangementOverview =
    'A 30-day practice of choosing one physical space, seeing what is actually there, removing what does not belong, arranging what remains, purifying it, and establishing maintenance.';

const String kLivingPatternOverview =
    'A 30-day practice of observing one natural subject until a real pattern appears, then extracting one principle and acting from it.';

const String kTrueNameOverview =
    'A 30-day private self-accounting flow: identify a false account, measure it against the real record, speak the accurate account aloud, and act from it.';

const String kLivingTextOverview =
    'A 30-day Library practice: read carefully, add reflections, questions, connections, and close with a colophon naming what your life added to the living text.';

const String kClearingOverview =
    'A 30-day practice of temperance before response: identify where heat drives action, create space before reply, and act once from the cleared state.';

const String kWanderingOverview =
    'A 30-day evening grief accompaniment: name the loss, search for what remains, and gently notice which capacities begin to open again.';

const String kKhatOverview =
    'A 30-day body-care practice: listen to the body, provide food, water, washing, rest, and movement, then close with a grounded body record.';

const String kOracleOverview =
    'A 30-day dream-question practice: prepare one specific oracle question, receive and record the night without early interpretation, then act on one grounded indication.';

const String kFairHearingConfidence =
    'Draws on Kemetic wisdom and administrative scenes of hearing, weighing, and pronounced judgment.';

const String kHouseOfLifeConfidence =
    'Draws on Per Ankh learning, scribal copying, temple practice, and careful transmission.';

const String kBoundaryStoneConfidence =
    'Draws on boundary-stone language in administrative and wisdom settings.';

const String kHotepConfidence =
    'Draws on htp offering language, cooling passages, and the peace of completed presentation.';

const String kOpenMouthConfidence =
    'Draws on the formative power of speech in the Memphite Theology and Opening of the Mouth ritual.';

const String kLivingRecordConfidence =
    'Draws on Kemetic logbooks, royal annals, autobiographies, and scribal record practice.';

const String kHetHeruConfidence =
    'Draws on Sekhmet-Hathor transformation, the Feast of Drunkenness, and Hathor as Mistress of Joy.';

const String kTheShoreConfidence =
    'The Shore draws on attested exchange practice, deben-weighted value, Amenemope balance language, and The Shipwrecked Sailor. This household flow reconstructs honest exchange at modern scale.';

const String kTheAutobiographyConfidence =
    'Draws on Kemetic tomb and stela autobiography as a dated account of lived conduct.';

const String kFirstArrangementConfidence =
    'The First Arrangement draws on Zep Tepi, temple order, offering-table placement, and purification practice.';

const String kLivingPatternConfidence =
    'The Living Pattern reads natural phenomena as demonstrations of durable principles, beginning with observation before interpretation.';

const String kTrueNameConfidence =
    'The True Name draws on Ren theology, Aset’s name-work, and declaration before the scale. This household flow frames identity as accurate account, not diagnosis.';

const String kLivingTextConfidence =
    'The Living Text draws on scribal copying, colophon, variant, and commentary practices.';

const String kClearingConfidence =
    'The Clearing draws on Instruction of Amenemope’s teaching of the temperate person as a tree in a sunlit field.';

const String kWanderingConfidence =
    'The Wandering draws on Aset and Nebet-Het’s search, lament, and finding in the Pyramid Texts. This household flow accompanies grief without treating it as something to win.';

const String kKhatConfidence =
    'The Khat draws on the physical restoration language of the Pyramid Texts: the body assembled, washed, fed, anointed, watered, and raised.';

const String kOracleConfidence =
    'The Oracle draws on Kemetic dream incubation, dream books, and the Dream Stela of Thutmose IV.';

const String kWanderingSafetyNote =
    'If grief feels acute or unsafe, reach out to someone you trust, 988 in the US, or findahelpline.com internationally before returning here.';

const String kKhatSafetyNote =
    'If your body is signaling something that may require medical attention, let this step support seeking care.';

const String kOracleSafetyNote =
    'If disturbing dream content appears, bring it to a qualified professional or trusted support before continuing.';

const List<MaatDecanFlowDefinition>
kMaatDecanFlowDefinitions = <MaatDecanFlowDefinition>[
  MaatDecanFlowDefinition(
    key: kFairHearingFlowKey,
    title: kFairHearingTitle,
    eventTitlePrefix: 'Fair Hearing',
    glyph: kFairHearingGlyph,
    tagline: kFairHearingTagline,
    overview: kFairHearingOverview,
    confidenceLabel: kFairHearingConfidence,
    routingSummary:
        'Best for judgment, partiality, premature decisions, deferred decisions, and uneven hearing.',
    notesPrefix: 'fair_hearing',
    behaviorKind: 'maat_fair_hearing_event',
    graphNodeSlugs: <String>['maat', 'djehuty', 'anpu', 'heru'],
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'Where Are You Called to Judge?',
        title: 'Who Is Before You?',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Begin by naming the real situations where your judgment affects another person.',
        spokenLine:
            'Be patient, so that you may learn Ma\'at. Control your own preference, so that the humble petitioner may gain.',
        steps: <String>[
          'List the work, family, friendship, community, or self-judgment situations where your view affects an outcome.',
          'For each, mark whether you have already formed a view before fully hearing all sides.',
          'Circle the situation where your preference is strongest. This is where the fair hearing is most needed.',
        ],
        sourceNote:
            'Khunanup, the Eloquent Peasant, appealed to Rensi nine times after his goods were stolen. The hearing itself was part of the justice: who is before you, and what are they actually asking?',
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'Where Are You Called to Judge?',
        title: 'Your Known Preferences',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Name the preference that will tilt the balance if you pretend you do not have one.',
        spokenLine:
            'Control your own preference, so that the humble petitioner may gain.',
        steps: <String>[
          'Return to the most charged situation from Day 1 and name what you prefer to be true.',
          'Ask who has more power and who has less. Does your preference align with the more powerful party?',
          'Write: My preference in [situation] is [specific view]. I will hold this preference lightly until I have heard fully.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'Where Are You Called to Judge?',
        title: 'The Inventory Complete',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Choose the one live judgment that will receive the Decan 2 fair-hearing practice.',
        spokenLine:
            'Do not be partial, and do not give in to a whim. Let your decision be pronounced.',
        steps: <String>[
          'Choose one situation for Decan 2 - the one where fairness will require the most from you.',
          'Name who has not yet been fully heard.',
          'Write: In Decan 2, I will give the full fair hearing to [situation]. I will hear [person or side] before I decide.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'The Practice of Fair Hearing',
        title: 'Hear Fully',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Practice the first discipline: hear the full account before interrupting, redirecting, or deciding.',
        spokenLine:
            'Be patient when listening to the words of a petitioner. Do not dismiss him until he has completely unburdened himself.',
        steps: <String>[
          'Before the hearing, write one sentence about what you expect to hear.',
          'Give the actual hearing: conversation, document, or full account. Do not interrupt or signal your conclusion.',
          'Afterward, write one thing you heard that complicated or expanded your view.',
        ],
        requiresRealWorldAction: true,
        sourceNote:
            'Ptahhotep says the wronged person needs to unburden the heart even when not every request can be granted. The full hearing is the first condition of fair judgment.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'The Practice of Fair Hearing',
        title: 'Apply the Same Measure',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Test whether the balance changes when a different person is standing on it.',
        spokenLine:
            'Do not cover your face against one whom you know; do not blind your sight against one whom you have seen.',
        steps: <String>[
          'If the parties were reversed, would you hear the claim the same way?',
          'Name one piece of evidence you have minimized because of who offered it.',
          'Write: I have been minimizing [account] because [reason]. I will hear it again with the same attention.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'The Practice of Fair Hearing',
        title: 'Pronounce the Decision',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'A fair hearing is incomplete until the decision is named clearly to those it affects.',
        spokenLine:
            'Turn away from this slothfulness, and let your decision be pronounced.',
        steps: <String>[
          'State the decision you can give now based on what has been heard.',
          'Write: Based on what I have heard, [decision]. This is based on [basis].',
          'If it has not been communicated, name exactly when it will be spoken.',
        ],
        requiresRealWorldAction: true,
        extraCompletionStatusLabels: <String, String>{
          'decision_pronounced': 'Decision pronounced',
        },
        sourceNote:
            'Rensi waited to hear the full case; that was patience. The failure named by the peasant is different: indefinite postponement wearing the mask of patience.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'The Decision Pronounced',
        title: 'Was It Fair?',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Review the process: not whether the outcome favored everyone, but whether the hearing was fair.',
        spokenLine:
            'Do not utter falsehood, for you are a balance. If it wavers, then you will waver.',
        steps: <String>[
          'Ask whether the hearing was full, the measure was consistent, and the decision was based on what was heard.',
          'For any no or partial answer, name exactly what was missing.',
          'If something was not fully heard, name whether an acknowledgment is owed.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'The Decision Pronounced',
        title: 'The Petitioner Not Heard',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Look beyond the main case and name the person whose appeal has simply not been heard.',
        spokenLine:
            'Do not be a hawk to the commoners. One who is deaf to Ma\'at has no friend.',
        steps: <String>[
          'Name someone who has appealed to you and genuinely has not been heard.',
          'Name what they are asking and why they have not been heard.',
          'Name what a fair hearing would require before this flow closes.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'The Decision Pronounced',
        title: 'The Balance Holds',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Close by naming where the balance held, where it wavered, and what practice continues.',
        spokenLine:
            'Do not utter falsehood, for you are a balance. Great is Ma\'at, lasting in effect.',
        steps: <String>[
          'Name the situation where the fair hearing was most complete.',
          'Name the situation where partiality or incompleteness still entered.',
          'Speak only the truth-check lines that apply: I heard fully; I applied the same measure; I pronounced a decision clearly.',
          'Write one continuing practice: When I am called to judge, I will [practice] before I decide.',
        ],
        sourceNote:
            'The Eloquent Peasant ends with judgment finally pronounced and the stolen goods restored. The balance protects the judged and the judge alike.',
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kFirstArrangementFlowKey,
    title: kFirstArrangementTitle,
    eventTitlePrefix: 'Arrangement',
    glyph: kFirstArrangementGlyph,
    tagline: kFirstArrangementTagline,
    overview: kFirstArrangementOverview,
    confidenceLabel: kFirstArrangementConfidence,
    routingSummary:
        'Best for clutter, physical space, room, desk, office, studio, home, mess, organization, focus, environment, and physical reset.',
    notesPrefix: 'first_arrangement',
    behaviorKind: 'maat_first_arrangement_event',
    graphNodeSlugs: <String>['maat', 'ptah', 'anpu', 'hapy'],
    burdenLabel: 'Low-Medium',
    specialRequirementLabel: 'Requires one physical space',
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'See the Space',
        title: 'See What Is There',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 15,
        durationMinutesMax: 15,
        purpose: 'See the chosen space before changing it.',
        spokenLine: 'Order begins with seeing what is actually there.',
        steps: <String>[
          'Stand at the entrance of your chosen space.',
          'Write what is actually there, where it sits, and what the current arrangement communicates.',
          'Do not clean yet.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'See the Space',
        title: 'What Is This Space For?',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 10,
        durationMinutesMax: 10,
        purpose: 'Define the space by purpose rather than preference.',
        spokenLine: 'Every place has a right relation.',
        steps: <String>[
          'Define the space’s true purpose in one or two precise sentences.',
          'Write what this space should make easier.',
          'Name the quality of attention it should support.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'See the Space',
        title: 'What Is Isfet in This Space?',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 10,
        durationMinutesMax: 10,
        purpose: 'Mark what belongs, what does not, and what is misplaced.',
        spokenLine: 'Disorder can be named before it is removed.',
        steps: <String>[
          'Review the inventory.',
          'Mark each item: belongs here, does not belong here, or belongs but is misplaced.',
          'Do not remove anything yet.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'Clear the Space',
        title: 'Remove What Doesn’t Belong',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 30,
        durationMinutesMax: 60,
        purpose: 'Physically remove what does not belong.',
        spokenLine: 'What does not belong here is set in its true place.',
        steps: <String>[
          'Physically remove every item marked does not belong.',
          'Put each item where it truly belongs, discard it, or release it.',
          'Record what remains.',
        ],
        requiresRealWorldAction: true,
        extraCompletionStatusLabels: <String, String>{'cleared': 'Cleared'},
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'Clear the Space',
        title: 'Find the Center and Threshold',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 15,
        durationMinutesMax: 15,
        purpose: 'Orient the arrangement around center and entry.',
        spokenLine: 'The center and threshold orient the whole room.',
        steps: <String>[
          'Name the space’s center.',
          'Name the entry point.',
          'Decide how everything else will relate to these two points.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'Clear the Space',
        title: 'The Arrangement',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 30,
        durationMinutesMax: 60,
        purpose: 'Arrange what remains by purpose and movement.',
        spokenLine: 'For I ordered everything in its proper place.',
        steps: <String>[
          'Arrange what remains by purpose, proximity, clear path, clean surfaces, and orientation.',
          'Stand at the threshold.',
          'Write what the space now says.',
        ],
        requiresRealWorldAction: true,
        extraCompletionStatusLabels: <String, String>{'arranged': 'Arranged'},
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'Maintain the Space',
        title: 'The Purification',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 20,
        durationMinutesMax: 20,
        purpose: 'Purify the arranged space before inhabiting it.',
        spokenLine: 'Water, air, and scent return the space to clean order.',
        steps: <String>[
          'Open air into the space.',
          'Wipe surfaces with water.',
          'Add one intentional scent and record the state of the space after purification.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Maintain the Space',
        title: 'Inhabit the Space',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 10,
        durationMinutesMax: 15,
        purpose: 'Use the space and listen to what the arrangement enables.',
        spokenLine: 'The arranged space is tested by use.',
        steps: <String>[
          'Use the space for its main purpose.',
          'Do not adjust while using it.',
          'Afterward, write what was easier, what remains misaligned, and what the space communicated.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'Maintain the Space',
        title: 'The Maintenance Practice',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 10,
        purpose: 'Create the continuing five-minute maintenance practice.',
        spokenLine: 'What is arranged must be returned to arrangement.',
        steps: <String>[
          'Create a daily five-minute maintenance practice.',
          'It must return objects, clear surfaces, and include one sensory act of purification.',
          'Share only the one-sentence statement of what the space now communicates.',
        ],
        extraCompletionStatusLabels: <String, String>{
          'maintenance_established': 'Maintenance established',
        },
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kLivingPatternFlowKey,
    title: kLivingPatternTitle,
    eventTitlePrefix: 'Living Pattern',
    glyph: kLivingPatternGlyph,
    tagline: kLivingPatternTagline,
    overview: kLivingPatternOverview,
    confidenceLabel: kLivingPatternConfidence,
    routingSummary:
        'Best for nature, observation, animals, water, vegetation, night sky, moon, stars, patience, pattern, and natural lessons.',
    notesPrefix: 'living_pattern',
    behaviorKind: 'maat_living_pattern_event',
    graphNodeSlugs: <String>['maat', 'ra', 'hapy', 'anpu', 'khepri'],
    burdenLabel: 'Low',
    specialRequirementLabel: 'Choose a natural subject',
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'Observation',
        title: 'Choose the Subject',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 15,
        durationMinutesMax: 20,
        purpose: 'Choose and observe one natural subject.',
        spokenLine: 'Say what is. Do not interpret yet.',
        steps: <String>[
          'Go to your subject and observe for 15-20 minutes.',
          'Write only what actually happens.',
          'Do not interpret yet.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'Observation',
        title: 'What Is the Same?',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 15,
        durationMinutesMax: 20,
        purpose: 'Separate constants from variables.',
        spokenLine: 'Return to the same subject.',
        steps: <String>[
          'Return to the same subject.',
          'Record what repeated from Day 1 and what changed.',
          'Separate constants from variables. Do not interpret yet.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'Observation',
        title: 'Pattern Forming',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 15,
        durationMinutesMax: 20,
        purpose: 'Name the forming pattern without deciding its meaning.',
        spokenLine: 'The behavior comes before the lesson.',
        steps: <String>[
          'Observe again.',
          'Review Days 1, 5, and 9.',
          'Name the consistent behavior or change, but do not interpret yet.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'Pattern',
        title: 'Name What Repeats',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 15,
        durationMinutesMax: 20,
        purpose: 'State precisely what the subject consistently does.',
        spokenLine: 'What repeats begins to show its principle.',
        steps: <String>[
          'Observe again.',
          'Write: What this subject consistently does is ___.',
          'Keep it precise. Do not interpret yet.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'Pattern',
        title: 'What Does the Pattern Require?',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 15,
        durationMinutesMax: 20,
        purpose: 'Name what the pattern depends on.',
        spokenLine: 'The pattern survives by relation.',
        steps: <String>[
          'Observe again.',
          'Ask what the subject must give, face, return to, release, or depend on to maintain the pattern.',
          'Write the requirement without turning it into a lesson yet.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'Pattern',
        title: 'Name the Principle',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 10,
        durationMinutesMax: 15,
        purpose: 'Extract one principle from field notes.',
        spokenLine: 'The principle must come from observed behavior.',
        steps: <String>[
          'Use your field notes.',
          'Write one sentence: [Subject] demonstrates: [principle].',
          'Reject any principle that did not come from observed behavior.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'Lesson',
        title: 'Where It Operates in Your Life',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 10,
        durationMinutesMax: 15,
        purpose: 'Locate the principle in your life.',
        spokenLine: 'The natural principle is also a human question.',
        steps: <String>[
          'Write where this principle is already working in your life.',
          'Write where you are violating or ignoring it.',
          'Name one place where the observation corrects your assumption.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Lesson',
        title: 'State the Lesson',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 10,
        durationMinutesMax: 15,
        purpose: 'State one actionable lesson from the observation.',
        spokenLine: 'Watching this taught me something I did not invent.',
        steps: <String>[
          'Write one actionable lesson: Watching ___ taught me ___.',
          'Keep it tied to the observed pattern.',
          'Optionally share the lesson to the feed.',
        ],
        sharePromptOnComplete: true,
        extraCompletionStatusLabels: <String, String>{
          'lesson_extracted': 'Lesson extracted',
        },
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'Lesson',
        title: 'One Act From the Lesson',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 10,
        durationMinutesMax: 15,
        purpose: 'Take one action based on the lesson before logging.',
        spokenLine: 'The lesson enters the record through action.',
        steps: <String>[
          'Take one specific action based on the lesson before logging.',
          'Record what you did.',
          'Name the principle it came from.',
        ],
        requiresRealWorldAction: true,
        extraCompletionStatusLabels: <String, String>{'acted': 'Acted'},
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kHouseOfLifeFlowKey,
    title: kHouseOfLifeTitle,
    eventTitlePrefix: 'House of Life',
    glyph: kHouseOfLifeGlyph,
    tagline: kHouseOfLifeTagline,
    overview: kHouseOfLifeOverview,
    confidenceLabel: kHouseOfLifeConfidence,
    routingSummary:
        'Best for learning, accurate transmission, knowledge discipline, and users ready for a positive practice flow.',
    notesPrefix: 'house_life',
    behaviorKind: 'maat_house_of_life_event',
    graphNodeSlugs: <String>['maat', 'djehuty', 'ptah', 'ren'],
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'Enter the Per Ankh',
        title: 'Enter the House of Life',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Name what you are actively learning and whether you are learning it with scribal precision.',
        spokenLine:
            'Come to me, Djehuty, that you may give advice and make me skillful in your office.',
        steps: <String>[
          'Name what you are currently learning - a skill, craft, practice, tradition, or body of knowledge.',
          'Check the three disciplines: writing it down, speaking or reciting it, and seeking those who know more.',
          'Name the weakest of the three. This is where the practice begins.',
        ],
        sourceNote:
            'The Per Ankh was not a passive library. It was a working scriptorium where knowledge was copied, produced, preserved, and tested by use.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'Enter the Per Ankh',
        title: 'Neither Take Away Nor Add',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Check whether you are receiving the subject as it is or bending it toward what you already believe.',
        spokenLine: 'Say what he said. Neither take away nor add to it.',
        steps: <String>[
          'Name where you are adding: interpreting early, filling gaps, or importing your own agenda.',
          'Name where you are taking away: simplifying too far or avoiding what challenges you.',
          'Write one sentence about where accuracy is most compromised.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'Enter the Per Ankh',
        title: 'The First Inventory Complete',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Commit the next decan to writing, reciting, and seeking on the subject you named.',
        spokenLine:
            'See, it is good if you write frequently. Understanding transforms an eager person.',
        steps: <String>[
          'Write: In the second decan, I will practice writing, reciting, and seeking on [subject].',
          'Name one person, text, teacher, or practitioner who knows more than you.',
          'Name one thing you will write down this week with enough clarity for another reader.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'The Three Disciplines',
        title: 'Write With Your Hand',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Produce knowledge actively: write one thing clearly enough for a future reader.',
        spokenLine:
            'Write with your hand, recite with your mouth, and converse with those more knowledgeable than you.',
        steps: <String>[
          'Write one complete account of something you have learned, as if the reader cannot ask you to clarify.',
          'Read it back and correct anything that depends on you standing beside the text.',
          'Name what the writing revealed about the gaps in your understanding.',
        ],
        sourceNote:
            'The scribe was valued for writing accurately. What you can write precisely has been learned; what you can only gesture at is still loose.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'The Three Disciplines',
        title: 'Recite With Your Mouth',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Speak one piece of what you know without notes. The gaps in speech are useful evidence.',
        spokenLine:
            'Write with your hand, recite with your mouth, and converse with those more knowledgeable than you.',
        steps: <String>[
          'Speak one concept or principle from memory, accurately and in order.',
          'Notice what is fluent and what collapses when spoken.',
          'If someone asks a question you cannot answer accurately, write it as the next thing to learn.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'The Three Disciplines',
        title: 'Converse With One More Knowledgeable',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Seek the source your current understanding cannot replace.',
        spokenLine:
            'I am the servant of your house. Come to me that you may advise me.',
        steps: <String>[
          'Seek the person, book, source, teacher, or practitioner named on Day 9.',
          'Ask one question your current study cannot answer.',
          'Write one thing you learned that you could not have gotten from yourself alone.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'The Transmission',
        title: 'What Will Persist',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Choose what is accurate enough to pass forward and who could receive it.',
        spokenLine:
            'Writing was their memory-priest. The pen was their child, the papyrus surface their wife.',
        steps: <String>[
          'Name one thing you now know accurately enough to transmit without distortion.',
          'Name one person who could benefit from receiving it.',
          'Choose the form: conversation, written note, demonstration, source recommendation, or another clear transmission.',
        ],
        sourceNote:
            'Papyrus Chester Beatty IV treats accurate writing as survival: the pen became the child, and writing became the memory-priest that kept the name alive.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'The Transmission',
        title: 'The Act of Transmission',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose: 'Do or record the transmission promised on Day 21.',
        spokenLine:
            'Neither take away nor add to it. Give what was learned to those who will receive it.',
        steps: <String>[
          'If the transmission happened, write what you gave and to whom.',
          'If not, do it today or name exactly when before the close.',
          'Ask what the recipient understood and what confused them.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'The Transmission',
        title: 'The House of Life Holds',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Close with one precise sentence you can now transmit and one practice that continues.',
        spokenLine:
            'Writing was their memory-priest. Better is this profession than all professions. It makes people great.',
        steps: <String>[
          'Name what you can now say with precision on the subject you studied.',
          'Name what remains beyond this 30-day cycle and how you will keep learning it.',
          'Speak only the true lines: I wrote; I recited; I sought; I transmitted; what I know is more accurate.',
          'Open one ḥꜣw node entry and read slowly, as the scribe reads.',
        ],
        sharePromptOnComplete: true,
        extraCompletionStatusLabels: <String, String>{
          'transmitted': 'Transmitted',
        },
        sourceNote:
            'The node library is the app\'s Per Ankh: a place where careful reading can become accurate knowledge and accurate knowledge can be given onward.',
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kBoundaryStoneFlowKey,
    title: kBoundaryStoneTitle,
    eventTitlePrefix: 'Boundary Stone',
    glyph: kBoundaryStoneGlyph,
    tagline: kBoundaryStoneTagline,
    overview: kBoundaryStoneOverview,
    confidenceLabel: kBoundaryStoneConfidence,
    routingSummary:
        'Best for restraint, excess, taking more than is due, moved boundaries, credit, labor, resources, and disproportionate force.',
    notesPrefix: 'boundary_stone',
    behaviorKind: 'maat_boundary_stone_event',
    graphNodeSlugs: <String>['maat', 'isfet', 'set', 'djehuty'],
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'Map the Stones',
        title: 'Name the Fields',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Map the domains where you have a claim and where someone else begins.',
        spokenLine:
            'Do not move the markers on the boundaries of the fields, nor alter the measuring line.',
        steps: <String>[
          'Map four domains: resources, labor, credit, and force.',
          'For each, write what is actually yours and what belongs to others.',
          'For force, name what level of pressure or authority is proportionate to the situation.',
        ],
        sourceNote:
            'After the Nile flood, officials re-surveyed fields and replaced boundary markers. The stone was Ma\'at made visible in the land.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'Map the Stones',
        title: 'The Measure of Each Field',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Name what enough means in each domain - not the maximum you can take.',
        spokenLine:
            'Do not be covetous for a single cubit. The measure is exact.',
        steps: <String>[
          'Return to resources, labor, credit, and force. For each, write what enough looks like.',
          'Mark any domain where the measure is genuinely unclear.',
          'Name where you may be taking from not knowing the line rather than from actual entitlement.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'Map the Stones',
        title: 'First Survey Complete',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Read the map and choose one domain for honest survey in Decan 2.',
        spokenLine:
            'The boundary of the fields is set. What is mine is named. What is not mine is also named.',
        steps: <String>[
          'Look at the map. What field is larger, smaller, or more contested than you thought?',
          'Name one domain where you suspect the stone has moved.',
          'Write: In Decan 2, I will look honestly at [domain].',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'Assess the Survey',
        title: 'The Honest Survey',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Assess whether the stones are in their right places across the four domains.',
        spokenLine: 'One who transgresses the furrow shortens a lifetime.',
        steps: <String>[
          'For resources, ask whether you are consuming at the level that is actually yours.',
          'For labor, ask whether you are doing your work, someone else\'s work, or leaving yours to others.',
          'For credit, ask whether you are claiming what was shared or someone else\'s.',
          'For force, ask whether pressure or authority has continued past what the situation required.',
        ],
        sourceNote:
            'The re-survey after the flood was not creative; it was restorative. The question was where the stone belonged before disruption moved it.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'Assess the Survey',
        title: 'The Gullet\'s Evidence',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Look for the evidence that what was taken past the measure cannot be kept.',
        spokenLine:
            'The property of a dependent is an obstruction to the throat. Too much bread is swallowed and spat up.',
        steps: <String>[
          'Where the stone moved, name what life is already throwing back: strain, resentment, depletion, or loss of trust.',
          'Name the evidence without defending it.',
          'Write what enough would have looked like in that domain.',
        ],
        sourceNote:
            'Amenemope gives the image of the gullet rejecting what was taken past measure. Excess is not additive; it empties you of your good.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'Assess the Survey',
        title: 'Survey Findings',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Record what was taken beyond measure and what restoration would require.',
        spokenLine:
            'I have not taken more than my share. I have not used force beyond necessity.',
        steps: <String>[
          'For each moved stone, name what was taken beyond the measure and by how much.',
          'For each, name what restoration would look like in exact words.',
          'Carry these restorations into Decan 3 as commitments.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'Restore the Survey',
        title: 'Begin the Restoration',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Choose the moved stone that most strained relationship or trust and begin placing it back.',
        spokenLine:
            'Guard yourself against the blemish of greediness. He who forsakes his relatives is truly poor.',
        steps: <String>[
          'Choose the moved stone that caused the most relational damage.',
          'Write: To restore [domain], I will [specific act] by [date].',
          'Name the actual proportionate measure. This is where the stone belongs.',
        ],
        requiresRealWorldAction: true,
        sourceNote:
            'Ptahhotep treats greed as a relationship disease. The stone placed correctly is not loss; it is the beginning of restored trust.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Restore the Survey',
        title: 'The First Stone Placed',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 3,
        durationMinutesMax: 5,
        purpose:
            'Record whether the Day 21 restoration happened and choose one simpler restoration before the close.',
        spokenLine:
            'Do not be selfish in the division. Greater is the claim of the good-natured person than the assertive.',
        steps: <String>[
          'If the restoration happened, write what changed.',
          'If not, name exactly what is between you and the restoration.',
          'Choose a second, simpler stone that can be restored before Day 29.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'Restore the Survey',
        title: 'The Survey Complete',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Close by naming which stones are placed, restored, or still displaced with a clear next commitment.',
        spokenLine:
            'What is mine I hold. What is not mine I have set down. The fields are measured. The stones are placed.',
        steps: <String>[
          'For each domain, write: stone in right place, stone restored this cycle, or stone still displaced.',
          'For each restored stone, name what shifted in the relationship or situation.',
          'For any stone still displaced, name what prevents restoration and the next measure.',
        ],
        extraCompletionStatusLabels: <String, String>{
          'stones_placed': 'Stones placed',
        },
        sourceNote:
            'The survey ends when the stone is placed, not when the displacement is identified. What remains is not failure; it is a named commitment.',
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kHotepFlowKey,
    title: kHotepTitle,
    eventTitlePrefix: 'Hotep',
    glyph: kHotepGlyph,
    tagline: kHotepTagline,
    overview: kHotepOverview,
    confidenceLabel: kHotepConfidence,
    routingSummary:
        'Best for inability to stop, compulsive overwork, fear of tomorrow, and the feeling that the offering is never enough.',
    notesPrefix: 'hotep',
    behaviorKind: 'maat_hotep_event',
    graphNodeSlugs: <String>['maat', 'hapy', 'anpu', 'heru'],
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'Name the Offering',
        title: 'Name the Offering',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 3,
        durationMinutesMax: 5,
        purpose:
            'Name what you are actually offering in this period and what the measure of owed work is.',
        spokenLine:
            'I have come having gotten Horus\'s eye, that your heart may become cool with it.',
        steps: <String>[
          'Place water on your surface and sit somewhere you actually rest.',
          'Write what you are currently offering: time, labor, care, attention, skill.',
          'Write what is owed. The offering is complete when it meets the measure, not when you can give no more.',
          'Drink the water.',
        ],
        sourceNote:
            'The Pyramid Texts begin restoration with cool water. The cool heart is the heart met by an offering that has been named and completed.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'Name the Offering',
        title: 'The Measure of the Offering',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 3,
        durationMinutesMax: 5,
        purpose:
            'Distinguish an actual gap in what is owed from the belief that more is always owed.',
        spokenLine:
            'Accept the outflow that comes from you. Your heart will not become weary with it.',
        steps: <String>[
          'Return to what you wrote on Day 1.',
          'Ask whether there is a real gap between what was owed and what has been given.',
          'Write one sentence about the gap, or its absence.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'Name the Offering',
        title: 'The Offering Inventory Complete',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 3,
        durationMinutesMax: 5,
        purpose:
            'Name what is keeping the heart hot before the completion question begins.',
        spokenLine:
            'The eye has been gotten. The water is cool. What was offered has been offered.',
        steps: <String>[
          'Name what is producing the inability to rest or fear of tomorrow.',
          'Ask whether it is real incompleteness or the distortion that more is always owed.',
          'Carry that distinction into Decan 2.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'Is It Complete?',
        title: 'The Question: Is It Done?',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 3,
        durationMinutesMax: 5,
        purpose:
            'Ask the central question directly: has what was owed actually been given?',
        spokenLine:
            'Do not go to bed fearing tomorrow. God is success; man is failure.',
        steps: <String>[
          'Sit with the question for at least two minutes: Has the offering of this period been made?',
          'Answer with the Day 1 measure, not with a vague feeling of enough.',
          'Write: The offering is complete, or The offering is incomplete in [specific way].',
        ],
        sourceNote:
            'Amenemope does not answer fear of tomorrow with productivity advice. What is yours is the offering made today; tomorrow is not yours to control.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'Is It Complete?',
        title: 'What You Cannot Control',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 3,
        durationMinutesMax: 5,
        purpose:
            'Name what you are carrying to bed that your anxiety cannot actually change.',
        spokenLine:
            'Man knows not what tomorrow will be. What I cannot control, I set down here.',
        steps: <String>[
          'Write the outcomes, choices, or circumstances you are carrying to bed but cannot control.',
          'Draw a line through each one and place them outside the bed.',
          'Name what remains that is genuinely yours. That is the real offering.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'Is It Complete?',
        title: 'Seal the Offering',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 3,
        durationMinutesMax: 5,
        purpose:
            'Seal the record: complete, or incomplete in one named way with one remaining act.',
        spokenLine:
            'Horus has filled you complete with his eye. Your heart will become content through it.',
        steps: <String>[
          'State: The offering of this period is complete, or incomplete in [specific thing].',
          'If incomplete, name the one remaining act and when it will be done.',
          'If complete, write: What was owed has been given. The heart is owed its cooling.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'Receive the Hotep',
        title: 'Begin to Receive',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 3,
        durationMinutesMax: 5,
        purpose:
            'Practice receiving the peace of a completed offering by physically stopping.',
        spokenLine:
            'She will cool the heart with them on the day of awaking. Hotep. The heart begins to be cooled.',
        steps: <String>[
          'Before sleep, put work down thirty minutes earlier than usual.',
          'Place water, sit, and speak the line.',
          'Write one sentence about the real obstacle to resting in what has been given.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Receive the Hotep',
        title: 'The Cooled Heart in Practice',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 3,
        durationMinutesMax: 5,
        purpose:
            'Look for even one night where the heart was cooler than before.',
        spokenLine: 'Your heart will not become weary with it. Hotep.',
        steps: <String>[
          'Name one night in the last five days when you went to bed with less fear of tomorrow.',
          'Name one thing you set down that would usually have stayed in the bed with you.',
          'If nothing changed, name the specific thing keeping the heart hot.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'Receive the Hotep',
        title: 'The Cool Heart',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Close as near to sleep as possible: the offering named, the heart cooled, the night entered without fear.',
        spokenLine:
            'These your cool waters have come from your son. Your heart will not become weary with it. Hotep.',
        steps: <String>[
          'Place water and sit where you will be before sleep.',
          'Name aloud what you offered across this flow: time, labor, care, presence, skill.',
          'Speak: What was owed has been given.',
          'Write anything left in the bed that is not yours to control and place the paper away from where you sleep.',
          'Drink the water. Lie down.',
          'sleep',
        ],
        extraCompletionStatusLabels: <String, String>{'cooled': 'Cooled'},
        sourceNote:
            'The htp-di-nsw offering formula begins with Hotep: the offering made and the satisfaction received. This close returns the user to water, completion, and sleep.',
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kOpenMouthFlowKey,
    title: kOpenMouthTitle,
    eventTitlePrefix: 'Open Mouth',
    glyph: kOpenMouthGlyph,
    tagline: kOpenMouthTagline,
    overview: kOpenMouthOverview,
    confidenceLabel: kOpenMouthConfidence,
    routingSummary:
        'Best for heated speech, hasty response, slander, careless words, and important truth left unsaid.',
    notesPrefix: 'open_mouth',
    behaviorKind: 'maat_open_mouth_event',
    graphNodeSlugs: <String>['maat', 'ptah', 'djehuty', 'aset'],
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'The Inventory',
        title: 'Open the Mouth\'s Record',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Record what your mouth has actually been producing lately, not what you wish it produced.',
        spokenLine:
            'It is the heart and the tongue that have power. I open the record of what my tongue has been commanding.',
        steps: <String>[
          'Write what your mouth produces when you are tired, frustrated, or thoughtless.',
          'Name what you are saying that should not be said.',
          'Name what is inaccurate or overheated.',
          'Name what needs to be said but has been swallowed.',
        ],
        sourceNote:
            'In the Memphite Theology, the heart conceives and the tongue commands. Speech is not only expression; it participates in formation.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'The Inventory',
        title: 'What Has Your Mouth Created?',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Look at one thing said and one thing not said, then name what each created.',
        spokenLine:
            'My speech has not been heated. My heart has not been hasty.',
        steps: <String>[
          'Choose one piece of speech from the last five days and write what it created.',
          'Choose one thing not said and write what its absence created.',
          'Name the speech pattern from Day 1 that Decan 2 should govern.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'The Inventory',
        title: 'Seal the Mouth\'s Record',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Choose one speech discipline and one important thing that needs to be said.',
        spokenLine:
            'Repeat only what is seen, not what is heard. Do not repeat slander.',
        steps: <String>[
          'Name the speech pattern that would most improve what your mouth creates if governed.',
          'Name the one thing not said that needs to be said before this flow closes.',
          'Write: In Decan 2, I will practice [discipline]. I will say [needed thing].',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'The Governed Mouth',
        title: 'The Governed Mouth Opens',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Choose one discipline for the tongue: pause, accuracy, relevance, timing, or witness before speaking.',
        spokenLine: 'Be strong in your heart. Do not steer with your tongue.',
        steps: <String>[
          'Review the five disciplines: pause, accuracy, relevance, timing, witness before speaking.',
          'For each, write whether it is currently operating in your speech.',
          'Choose one discipline for this decan and define the specific practice.',
        ],
        sourceNote:
            'Amenemope says the tongue is the steering oar, but not the pilot. The heart holds course; the tongue carries it out.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'The Governed Mouth',
        title: 'One Silence Kept. One Thing Said.',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Record one word rightly withheld and move toward the important word that must be spoken.',
        spokenLine:
            'Do not pour out your words to others. Be strong in your heart.',
        steps: <String>[
          'Name one thing you did not say this decan that was better kept back.',
          'Check the thing that needs to be said: has it been said? If not, when before the decan ends?',
          'Practice one deliberate pause in a conversation today.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'The Governed Mouth',
        title: 'What the Governed Mouth Produced',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Name what changed because the mouth was governed rather than merely expressive.',
        spokenLine:
            'Your ears have been unplugged, your mouth has been opened, the bonds have been loosened.',
        steps: <String>[
          'For your chosen discipline, write one honest sentence about how it operated.',
          'Record whether the important thing has been said; if not, name what remains in the way.',
          'Name one conversation that went differently because the mouth was governed.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'The Mouth That Creates',
        title: 'The Mouth That Creates',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Write the true thing that will be spoken in the final decan before the tongue declares it.',
        spokenLine:
            'Your tongue is the plummet. Your heart is the weight. I open my mouth with care.',
        steps: <String>[
          'Ask what your mouth has been creating across this flow.',
          'Name one specific, true, currently unspoken thing you will bring into the world by saying it.',
          'Write it first. The heart conceives before the tongue declares.',
        ],
        sourceNote:
            'Khunanup calls the tongue a plummet and the heart its weight. Governed speech measures; it does not simply sound more polite.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'The Mouth That Creates',
        title: 'What Was Said',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose: 'Record whether the Day 21 sentence has entered the world.',
        spokenLine:
            'Open your mouth, for you have been tended. The bonds are loosened. You are sound.',
        steps: <String>[
          'If the thing written on Day 21 has been said, write what happened when it entered the world.',
          'If not, today is the day. Say it before Event 9.',
          'Write the most accurate thing you learned about your own speech.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'The Mouth That Creates',
        title: 'The Open Mouth',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose:
            'Close by naming what the mouth created, what changed, and what was finally spoken.',
        spokenLine:
            'My mouth is open. My speech is governed. What I command, I create with care.',
        steps: <String>[
          'Name the most significant speech pattern the inventory revealed.',
          'Name what the governance practice produced.',
          'Name what was spoken that needed to be spoken: I said [thing] on [day]. It is now in the world.',
          'Speak only the true lines: my speech was not heated; my heart was not hasty; I said what needed to be said.',
          'Sit in intentional silence for one full minute.',
        ],
        extraCompletionStatusLabels: <String, String>{'spoken': 'Spoken'},
        sourceNote:
            'The Opening of the Mouth restored speech, eating, and breath. The close is not perfection; it is a mouth more open and better governed than before.',
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kLivingRecordFlowKey,
    title: kLivingRecordTitle,
    eventTitlePrefix: 'Living Record',
    glyph: kLivingRecordGlyph,
    tagline: kLivingRecordTagline,
    overview: kLivingRecordOverview,
    confidenceLabel: kLivingRecordConfidence,
    routingSummary:
        'Best for positive ḥꜣw practice, new-user feature integration, decan record keeping, journaling, guidance engagement, and users ready to use the full app suite intentionally.',
    notesPrefix: 'living_record',
    behaviorKind: 'maat_living_record_event',
    graphNodeSlugs: <String>['maat', 'djehuty', 'house_of_life', 'ren'],
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'Enter the Record',
        title: 'Open the Day Card',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Open the decan record by locating the day in Kemetic time before anything else is written.',
        spokenLine:
            'What occurred must be placed within its time. What is placed within its time becomes record. What becomes record persists.',
        steps: <String>[
          'Open today\'s day card in ḥꜣw and read the Kemetic date, decan name, Ma\'at principle, and cosmic context.',
          'Write the date down outside the app: Kemetic date, season, and decan name.',
          'Speak the line. The record has been opened.',
        ],
        requiresRealWorldAction: true,
        sourceNote:
            'Merer\'s logbook dated each entry before naming the work. The Palermo Stone bounded each year in its own compartment. The day card is the app\'s dating entry: work placed within time.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'Enter the Record',
        title: 'Enter the Library',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Ground the decan record in one node that explains what this period is asking.',
        spokenLine:
            'Better is the profession of the scribe than all professions. The one skilled in it is fit for office.',
        steps: <String>[
          'Open the node library and choose the node that best matches the current decan quality or day-card principle.',
          'Read the node slowly, as a scribe reads to copy without distortion.',
          'Write one sentence in the physical record: The node that speaks to this decan is [name], and it means [one sentence].',
        ],
        sourceNote:
            'The House of Life was not a passive library. It preserved sacred texts so they could be read, copied, interpreted, and used.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'Enter the Record',
        title: 'Set It in the Planner',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Turn the decan quality from insight into one scheduled act with a date.',
        spokenLine:
            'I have hoed emmer for you, I have plowed barley for you: the work of the season is placed in time.',
        steps: <String>[
          'Open the planner and schedule one specific act this decan calls for.',
          'Review active flows and note one stalled or skipped place if it exists.',
          'Write in the physical record: Scheduled [what], on [date], because [decan quality].',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'Build the Record',
        title: 'Write in the Journal',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Use the journal as papyrus: the private record from which memory and guidance can be built.',
        spokenLine:
            'Their writing was their memory-priest. The pen was their child. Their names endured.',
        steps: <String>[
          'Open the journal and write at least three substantive sentences.',
          'Name what this decan has meant so far, what you actually did in Ma\'at, what resisted the period, and one unanswered question.',
          'Notice any badges generated from the entry. They are signals that the record is being read.',
        ],
        requiresRealWorldAction: true,
        sourceNote:
            'Papyrus Chester Beatty IV treats writing as survival: the writing becomes the memory-priest that keeps the name alive.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'Build the Record',
        title: 'Share in the Feed',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Let the record become communal: read what others have placed on the wall, then add one small true thing.',
        spokenLine:
            'O living ones who pass by: read what was done, speak the name, and let the record continue.',
        steps: <String>[
          'Open the feed and read what others have shared for at least two minutes.',
          'Share one small record: a decan observation, flow completion, question, node insight, or day-card insight.',
          'Write: Shared [what]. Received from others: [one thing that stood out].',
        ],
        requiresRealWorldAction: true,
        sharePromptOnComplete: true,
        sourceNote:
            'Kemetic autobiographies were public inscriptions. The feed is not a tomb wall, but it does make a record visible to those passing through.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'Build the Record',
        title: 'Complete an Alignment Check',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Use the alignment grid as a provisioning ledger: what was consumed, aligned, disrupted, and owed.',
        spokenLine:
            'What occurred must be dated. What is dated must be placed. What is placed shows what was given and what is owed.',
        steps: <String>[
          'Open Today\'s Alignment and complete the grid honestly.',
          'Review this decan so far: what has been consistent, and what has been disrupted?',
          'Write one specific change you will carry into Decan 3.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'Complete the Record',
        title: 'Enter Flow Studio',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Use Flow Studio as the Per Ankh workshop: intention becomes a structured path on the calendar.',
        spokenLine:
            'What the heart thinks, the tongue commands. The intention spoken becomes the flow that structures the work.',
        steps: <String>[
          'Open Flow Studio.',
          'Generate a flow from an unresolved intention, review an active flow, or browse templates for the flow this decan points toward.',
          'Write: Flow Studio, Day 21: [what I generated, reviewed, or discovered]. The intention I carry forward is [one thing].',
        ],
        requiresRealWorldAction: true,
        sourceNote:
            'The Per Ankh copied received texts and produced new ones. Flow Studio is the app\'s production room: received understanding becoming new structure.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Complete the Record',
        title: 'Read the Ma\'at Guidance',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Read guidance as consultation: it witnesses the record before offering one act.',
        spokenLine:
            'The guidance comes when the pattern has been seen. It witnesses before advising. It names without shame. It offers one act.',
        steps: <String>[
          'Open the Ma\'at guidance card, a recent guidance delivery, or the decan opening.',
          'Name the pattern it identified and the one act it recommends.',
          'If possible, complete the act today. If not, write what the right response is.',
          'Write: Ma\'at guidance, Day 25: [what it said]. My response: [what I did or decided].',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'Complete the Record',
        title: 'Write the Decan\'s Closing Record',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose:
            'Close the decan account by writing the final journal entry and physical closing line.',
        spokenLine:
            'I will put my annals among people and love of me among the gods. The record is real. The record persists.',
        steps: <String>[
          'Open the journal and write the closing entry: date, decan, what was done, what was not done, what surprised you, and what continues.',
          'Read the physical record from Day 1 through Day 25.',
          'Write the closing line: In [Kemetic date], decan of [name], I [what I actually did in Ma\'at]. The time was measured. The record is closed.',
          'Speak the final line.',
        ],
        requiresRealWorldAction: true,
        extraCompletionStatusLabels: <String, String>{
          'record_complete': 'Record complete',
        },
        sourceNote:
            'Merer\'s logbook ends with the final entry. The Palermo Stone closes each year with a marker. The Living Record closes when the decan is bounded and set down.',
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kHetHeruFlowKey,
    title: kHetHeruTitle,
    eventTitlePrefix: 'Het-Heru',
    glyph: kHetHeruGlyph,
    tagline: kHetHeruTagline,
    overview: kHetHeruOverview,
    confidenceLabel: kHetHeruConfidence,
    routingSummary:
        'Best for joy, beauty, music, delight, creative heat, rage that has become self-perpetuating, and users who need transformation through abundance rather than suppression.',
    notesPrefix: 'het_heru',
    behaviorKind: 'maat_het_heru_event',
    graphNodeSlugs: <String>['maat', 'hathor', 'sekhmet', 'eye_of_ra', 'ra'],
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'The Eye Goes Out',
        title: 'Find Your Sekhmet',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Name the fierce force in you that has gone further than intended and no longer comes back when called.',
        spokenLine:
            'Sekhmet, the Powerful One, the Eye of Ra, went out and did not come back when called. She is the same force as Het-Heru before the beer.',
        steps: <String>[
          'Read the core story: Ra sent the Eye as Sekhmet, she kept destroying after he called her back, and the gods flooded the field with red beer.',
          'Name your Sekhmet: resentment, ambition, grief, perfectionism, anger, or another force with its own momentum.',
          'Write: My Sekhmet is [specific thing]. It was sent out for [wound or purpose]. It is still going because [what sustains it].',
          'Optional: name the beautiful thing this force used to make before it went too far.',
        ],
        sourceNote:
            'In the Book of the Heavenly Cow, Ra sends his Eye as Sekhmet against humanity. When the slaughter will not stop, red beer is poured across the land. Sekhmet drinks, sleeps, and wakes as Het-Heru.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'The Eye Goes Out',
        title: 'The Scale of the Slaughter',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Assess whether the force is still serving its original purpose or has developed destructive momentum.',
        spokenLine:
            'She was wading through blood. She had gone beyond the point where a command could reach her.',
        steps: <String>[
          'Ask whether your Sekhmet still responds to your intention, or whether it keeps moving after you try to stop.',
          'Name who or what has entered its path that you did not intend to harm.',
          'Write without shame: the force may have been appropriate at the beginning; the question is whether it is still under direction.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'The Eye Goes Out',
        title: 'Before the Beer',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Find the need underneath the destructive momentum. That need gives the beer its shape.',
        spokenLine:
            'Ra looked at the field and did not meet Sekhmet with more force. He asked what would fill her.',
        steps: <String>[
          'Ask what your Sekhmet is actually looking for beneath the destruction.',
          'Write: My Sekhmet is looking for [the underlying need].',
          'Carry that need into Decan 2. The beer must fill this need without continuing the destruction.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'The Red Beer',
        title: 'Find the Beer',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Name the abundant, non-destructive thing that can fill the same hunger your Sekhmet has been feeding.',
        spokenLine:
            'Seven thousand jars of beer were dyed red like blood. The force received what it could drink, and it was transformed.',
        steps: <String>[
          'Name your beer: beauty, music, rest, connection, significance, touch, play, or another abundant good.',
          'Write: The beer for my Sekhmet is [specific thing]. It fills the actual need because [reason].',
          'Make it abundant. Ra did not pour one jar; he flooded the field.',
        ],
        sourceNote:
            'The myth names the scale: seven thousand jars. Transformation happens through abundance, not a sip. What is your field-flooding gift?',
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'The Red Beer',
        title: 'Pour the Beer',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Do the abundant act that fills the underlying need without feeding the destruction.',
        spokenLine:
            'The beer was poured before the face of the beautiful one. She drank and was content.',
        steps: <String>[
          'Do the beer act today in its abundant version: real music, real beauty, real rest, real connection, or the specific thing you named.',
          'Do it as the main event, not as background or a smaller compromise.',
          'Afterward write one sentence: Did the field fill? Did Sekhmet drink?',
        ],
        requiresRealWorldAction: true,
        extraCompletionStatusLabels: <String, String>{
          'beer_poured': 'Beer poured',
        },
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'The Red Beer',
        title: 'Waking Up',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose:
            'Check whether the force has changed quality since the beer was poured.',
        spokenLine:
            'When she awoke, she had forgotten the slaughter. She was the Golden One: the same Eye, transformed.',
        steps: <String>[
          'Return to the Sekhmet from Day 1. Has it become less self-perpetuating?',
          'Write what actually happened, not what you hoped would happen.',
          'If it is still active, name what more beer would look like. If something shifted, name the first sign of Het-Heru.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'Het-Heru Arrives',
        title: 'The Sistrum Sounds',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Let music be a sacred act of presence with Het-Heru, not background content.',
        spokenLine:
            'Het-Heru, the Golden One, Mistress of Joy, Lady of the Dance. The sistrum sounds and she is present.',
        steps: <String>[
          'Listen to music that actually moves you. Let it be the main event.',
          'Notice what the music does to the place where Sekhmet was.',
          'Afterward write one word about what you felt. That is the whole record.',
        ],
        requiresRealWorldAction: true,
        sourceNote:
            'The sistrum was Het-Heru\'s presence made audible. At Dendera, music was not entertainment; it was an offering that invited the goddess\'s joyful quality.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Het-Heru Arrives',
        title: 'The Feast',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Practice joy as shared presence. The feast is the attention, not the menu.',
        spokenLine:
            'The joy that passes between people is the Golden One moving through the feast.',
        steps: <String>[
          'Share a meal or feast-form with someone, with attention on the sharing.',
          'Notice one genuinely delightful thing about the other person or the shared moment.',
          'Write one sentence about what sharing produced that solitary receiving does not.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'Het-Heru Arrives',
        title: 'The Golden One\'s Presence',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Close by naming how the force has changed and receiving one available act of beauty now.',
        spokenLine:
            'Het-Heru, Mistress of Joy. The Eye that was sent out has returned, not defeated but transformed. The dance continues.',
        steps: <String>[
          'Return to Day 1 and write what changed in how that force is operating.',
          'Name the beer you poured and the Het-Heru quality that emerged from the same source as the Sekhmet.',
          'Speak only the true lines: I named the Sekhmet; I found what it sought; I poured the beer; I let music reach me; I shared a feast.',
          'Do one beautiful thing now: look, listen, smell, touch, or move with deliberate delight.',
        ],
        requiresRealWorldAction: true,
        extraCompletionStatusLabels: <String, String>{
          'golden_one_present': 'Golden One present',
        },
        sourceNote:
            'Het-Heru and Sekhmet are the same Eye in different modes. The close is not the defeat of the fierce force; it is the same force made golden.',
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kTheShoreFlowKey,
    title: kTheShoreTitle,
    eventTitlePrefix: 'Shore',
    glyph: kTheShoreGlyph,
    tagline: kTheShoreTagline,
    overview: kTheShoreOverview,
    confidenceLabel: kTheShoreConfidence,
    routingSummary:
        'Best for money, exchange, value, offers, sales, negotiation, resources, business, clients, and honest material return.',
    notesPrefix: 'shore',
    behaviorKind: 'maat_shore_event',
    graphNodeSlugs: <String>['maat', 'djehuty', 'hapy', 'renenutet'],
    burdenLabel: 'Low-Medium',
    specialRequirementLabel: 'Requires one real exchange',
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'What Is in Your Boat?',
        title: 'What Is in Your Boat?',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 8,
        purpose: 'Inventory what you can honestly offer now.',
        spokenLine: 'Do well, and you will attain influence.',
        steps: <String>[
          'Write an honest inventory of skills, labor, knowledge, and relationships you can offer now.',
          'Mark each item as active, cultivated but unused, or undeveloped.',
          'Finish: My boat is primarily full of ___.',
        ],
        sourceNote:
            'The sailor at Punt could not offer Punt its own goods. The honest question is what is actually in your boat.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'What Is in Your Boat?',
        title: 'What Is It Actually Worth?',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose: 'Weigh the exchange value without inflation or deflation.',
        spokenLine: 'The measure is the eye of Re.',
        steps: <String>[
          'Choose two or three items from your inventory.',
          'Write their honest exchange value, not the value you wish they had.',
          'Name where you are overvaluing or undervaluing them.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'What Is in Your Boat?',
        title: 'What Needs More Cultivation?',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose: 'Choose one offering whose real value can increase.',
        spokenLine: 'Fortunate is a scribe skilled in his office.',
        steps: <String>[
          'Name one offering that could become more valuable with focused development.',
          'Write the specific act that would increase its real value before the next decan.',
          'Name how the offering would be measured more honestly after that cultivation.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'The Shore',
        title: 'Prepare the Offering',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 8,
        purpose: 'Prepare one specific exchange at honest measure.',
        spokenLine: 'Do not tilt the scale nor falsify the weights.',
        steps: <String>[
          'Name one specific exchange you intend to make: what you will offer, to whom, and what return you seek.',
          'Write what must be prepared before you make the offer.',
          'Confirm the offer is genuinely useful to that person.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'The Shore',
        title: 'Make the Exchange',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose: 'Make one real exchange before logging the event.',
        spokenLine:
            'The Ape sits by the balance, while his heart is the plummet.',
        steps: <String>[
          'Make one real exchange before logging.',
          'Record what was offered, what was received, and whether both sides received honest value.',
          'If it has not happened, name the blocker and the next concrete opening.',
        ],
        requiresRealWorldAction: true,
        extraCompletionStatusLabels: <String, String>{'exchanged': 'Exchanged'},
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'The Shore',
        title: 'Was the Weight Honest?',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose: 'Review whether the exchange was delivered at honest measure.',
        spokenLine:
            'When jewels are heaped upon gold, at daybreak they turn to lead.',
        steps: <String>[
          'Review the exchange.',
          'Ask whether you delivered what you promised and whether the other side did too.',
          'Name any correction, return, or completion still owed.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'The Return',
        title: 'What Came Back?',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 8,
        purpose: 'Account for direct, indirect, and reputational return.',
        spokenLine: 'Make a good reputation for me in your city.',
        steps: <String>[
          'Account for the return: direct material return, indirect opportunity, and reputational return.',
          'Name the most valuable thing that came back.',
          'Write what return still needs time before it can be measured.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'The Return',
        title: 'Bread With an Easy Mind',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 5,
        purpose: 'Test whether the gain produced peace or anxiety.',
        spokenLine:
            'Better is bread when the mind is at ease than riches with anxiety.',
        steps: <String>[
          'Eat something while reflecting on the exchange.',
          'Ask whether this gain feels easy or anxious.',
          'Name what made it peaceful, or what made it uneasy.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'The Return',
        title: 'Make a Good Reputation',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 8,
        durationMinutesMax: 8,
        purpose: 'Close the account and pass the story forward.',
        spokenLine: 'What came to the shore has been weighed and told.',
        steps: <String>[
          'Close the account: what you brought, what you exchanged, what returned, and what you will pass forward.',
          'Write the final line of the exchange story.',
          'Optionally share the closing record, without exposing private details.',
        ],
        sharePromptOnComplete: true,
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kTheAutobiographyFlowKey,
    title: kTheAutobiographyTitle,
    eventTitlePrefix: 'Autobiography',
    glyph: kTheAutobiographyGlyph,
    tagline: kTheAutobiographyTagline,
    overview: kTheAutobiographyOverview,
    confidenceLabel: kTheAutobiographyConfidence,
    routingSummary:
        'Best for legacy, life review, career arc, purpose, year review, accomplishments, unfinished work, and what comes next.',
    notesPrefix: 'autobiography',
    behaviorKind: 'maat_autobiography_event',
    graphNodeSlugs: <String>['maat', 'ren', 'ka', 'djehuty'],
    burdenLabel: 'Medium',
    specialRequirementLabel: 'Includes long writing event',
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'Survey the Years',
        title: 'Survey the Capacities',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 15,
        durationMinutesMax: 15,
        purpose: 'Name the capacities built across years.',
        spokenLine: 'Say what is and do not say what is not.',
        steps: <String>[
          'Look across your adult life.',
          'Name the capacities developed through years of work, failure, repetition, and attention.',
          'Write what you can actually do now, without inflation or deflation.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'Survey the Years',
        title: 'Survey the Works',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 15,
        durationMinutesMax: 15,
        purpose: 'List the works of your life in sequence.',
        spokenLine: 'What was done is counted.',
        steps: <String>[
          'List the works of your life: completed, in progress, attempted but unfinished, and prevented by circumstance.',
          'Keep it specific and chronological.',
          'Do not rank the works while listing them.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'Survey the Years',
        title: 'Survey the Gifts',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 10,
        durationMinutesMax: 10,
        purpose: 'Name what was given beyond obligation.',
        spokenLine: 'I gave bread to the hungry and clothed the naked.',
        steps: <String>[
          'Name what you gave beyond obligation: time, skill, provision, protection, knowledge, or care.',
          'Write specific acts, not general traits.',
          'Mark what was given quietly and would otherwise disappear from the record.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'Find the Thread',
        title: 'Find the Thread',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 15,
        durationMinutesMax: 15,
        purpose:
            'Find the consistent pattern across capacities, works, and gifts.',
        spokenLine: 'The account has a thread.',
        steps: <String>[
          'Read the capacities, works, and gifts.',
          'Ask what consistent pattern runs through them.',
          'Write the thread in one sentence.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'Find the Thread',
        title: 'What Persisted Through Disruption',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 10,
        durationMinutesMax: 10,
        purpose: 'Name what continued despite disruption.',
        spokenLine: 'What persisted is part of the account.',
        steps: <String>[
          'Name the disruptions that interrupted your path.',
          'Name what persisted anyway: capacity, commitment, or way of being.',
          'Write what did not stop.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'Find the Thread',
        title: 'Name the Principle',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 10,
        durationMinutesMax: 10,
        purpose: 'State the principle that actually shaped the record.',
        spokenLine: 'The record shows the governing principle.',
        steps: <String>[
          'Based on the record, write the governing principle that has actually shaped your choices.',
          'Decide whether you endorse it or would choose differently now.',
          'Carry the true version into the document.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'Write the Account',
        title: 'Write the Autobiography',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 30,
        durationMinutesMax: 45,
        purpose: 'Produce the four-section autobiography document.',
        spokenLine: 'I will put my annals among people.',
        steps: <String>[
          'Write the four-section document: Capacities, Works, Gifts, Claim.',
          'Allow 30-45 minutes; this is a document, not a short note.',
          'Correct anything inflated or deflated before closing the document.',
        ],
        extraCompletionStatusLabels: <String, String>{
          'autobiography_written': 'Autobiography written',
        },
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Write the Account',
        title: 'Share One Line',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 10,
        purpose: 'Let one witnessed line meet another person.',
        spokenLine: 'Let me be tended and do not report me wrongly.',
        steps: <String>[
          'Share one line from the autobiography with someone who witnessed, shaped, or belongs to that part of the account.',
          'Record what they confirmed or corrected.',
          'Use the feed only if there is no clear person to receive the line.',
        ],
        requiresRealWorldAction: true,
        sharePromptOnComplete: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'Write the Account',
        title: 'What Remains',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 10,
        durationMinutesMax: 10,
        purpose: 'Name the work still required by the claim.',
        spokenLine: 'What remains is named. The autobiography continues.',
        steps: <String>[
          'Read the Claim section.',
          'Name the specific work, gift, or capacity still required to make the autobiography honest to its claim.',
          'Save the remaining work as a future-return field in your record.',
        ],
        extraCompletionStatusLabels: <String, String>{
          'remaining_work_named': 'Remaining work named',
        },
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kTrueNameFlowKey,
    title: kTrueNameTitle,
    eventTitlePrefix: 'True Name',
    glyph: kTrueNameGlyph,
    tagline: kTrueNameTagline,
    overview: kTrueNameOverview,
    confidenceLabel: kTrueNameConfidence,
    routingSummary:
        'Best for identity, confidence, self doubt, false belief, shame, accurate account, and acting from truth through self-accounting.',
    notesPrefix: 'true_name',
    behaviorKind: 'maat_true_name_event',
    graphNodeSlugs: <String>['maat', 'ren', 'aset', 'anpu'],
    burdenLabel: 'Low',
    specialRequirementLabel: 'Private self-accounting',
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'False Account',
        title: 'What Account Are You Operating From?',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Name the account without judging it.',
        spokenLine:
            'The first account is not your fault; it is the account to be measured.',
        steps: <String>[
          'Complete: People like me generally ___. When it comes to ___, I am someone who ___. The thing I quietly believe about myself is ___.',
          'Do not judge it yet and do not share this material.',
          'If what surfaces feels larger than this flow can hold, pause the flow and seek support.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'False Account',
        title: 'Where Did It Come From?',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Trace the account without blame.',
        spokenLine: 'The installed account can be traced.',
        steps: <String>[
          'Trace the account.',
          'Name who or what first suggested it.',
          'Ask whether it was installed through authority, intensity, repetition, or circumstance.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'False Account',
        title: 'What Has It Produced?',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Name where the account has shaped action.',
        spokenLine: 'A false account proves itself by narrowing motion.',
        steps: <String>[
          'Name where this account has been proving itself.',
          'Write what you avoided, declined, or did not reach for because this account felt true.',
          'Do not frame the account as your fault.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'Accurate Account',
        title: 'What the Scale Shows',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Measure the account against the actual record.',
        spokenLine: 'The scale shows the record.',
        steps: <String>[
          'Conduct the honest inventory.',
          'Write what your actual record shows about how you have acted, given, cared, worked, and shown up.',
          'Keep the record specific.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'Accurate Account',
        title: 'The Accurate Account',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Write the accurate account in one sentence.',
        spokenLine:
            'The true name is neither bigger nor smaller than the record.',
        steps: <String>[
          'Write the accurate account in one sentence.',
          'Test it for inflation and deflation.',
          'It must be neither bigger nor smaller than the record.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'Accurate Account',
        title: 'What Was Already There',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose:
            'Gather evidence that the accurate account has already existed.',
        spokenLine: 'The evidence has already entered the record.',
        steps: <String>[
          'Name five specific acts that prove the accurate account has already been present in your life.',
          'Use acts, not aspirations.',
          'Keep this evidence private by default.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'Declaration',
        title: 'The Heart Conceives',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Imagine one current situation from the accurate account.',
        spokenLine:
            'The heart conceives; the tongue releases the word into form.',
        steps: <String>[
          'Choose one current situation where the false account operates.',
          'Imagine acting from the accurate account in specific detail.',
          'Write what that looks like before you attempt it.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Declaration',
        title: 'Speak the True Name',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Stand and speak the accurate account aloud.',
        spokenLine: 'I am pure, I am pure, I am pure, I am pure.',
        steps: <String>[
          'Stand.',
          'Speak the accurate account aloud, then speak the evidence.',
          'Close with: I am pure, I am pure, I am pure, I am pure. Then record what it felt like.',
        ],
        requiresRealWorldAction: true,
        extraCompletionStatusLabels: <String, String>{'declared': 'Declared'},
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'Declaration',
        title: 'Act From the True Name',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Act from the accurate account in one real situation.',
        spokenLine: 'The accurate account becomes real in action.',
        steps: <String>[
          'Act from the accurate account in one real situation before logging.',
          'Record what you did, what happened, and what evidence it added.',
          'Only the closing claim may be optionally shared.',
        ],
        requiresRealWorldAction: true,
        sharePromptOnComplete: true,
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kLivingTextFlowKey,
    title: kLivingTextTitle,
    eventTitlePrefix: 'Living Text',
    glyph: kLivingTextGlyph,
    tagline: kLivingTextTagline,
    overview: kLivingTextOverview,
    confidenceLabel: kLivingTextConfidence,
    routingSummary:
        'Best for Library study, node entries, learning, questions, reflections, source connections, and adding insight to the living text.',
    notesPrefix: 'living_text',
    behaviorKind: 'maat_living_text_event',
    graphNodeSlugs: <String>['maat', 'djehuty', 'ptah', 'ren'],
    burdenLabel: 'Low',
    specialRequirementLabel: 'Uses the Library',
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'Read',
        title: 'Find the Entry That Calls You',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Begin by reading one Library entry fully.',
        spokenLine: 'The Library lives when it is read.',
        steps: <String>[
          'Open the Library and choose the entry that catches your attention.',
          'Read it fully.',
          'Write one new thought the entry opened in you.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'Read',
        title: 'Find the Entry You’ve Been Avoiding',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Read the entry you keep circling or dismissing.',
        spokenLine: 'Avoidance is also a reading mark.',
        steps: <String>[
          'Choose the Library entry you keep circling or dismissing.',
          'Read it fully.',
          'Write what the avoidance was about. Optionally add a question.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'Read',
        title: 'Find What You Don’t Understand',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 8,
        durationMinutesMax: 8,
        purpose: 'Turn confusion into a Library question.',
        spokenLine: 'No one is born wise.',
        steps: <String>[
          'Choose an important entry you do not fully understand.',
          'Name the exact passage or concept that is unclear.',
          'Add it as a Library question.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'Contribute',
        title: 'Add Your First Reflection',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Add a lived-experience reflection to the Library.',
        spokenLine: 'Good advice may be found at the grindstones.',
        steps: <String>[
          'Return to the Day 1 entry.',
          'Add a reflection from your lived experience.',
          'Mark it private or public. Reflections are private by default.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'Contribute',
        title: 'Connect Two Entries',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Add a short connection between two Library entries.',
        spokenLine: 'A living text shows relation.',
        steps: <String>[
          'Find two Library entries that connect in a way the app does not already show.',
          'Add a short connection explaining the relationship.',
          'Use Library language: connection, not comment.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'Contribute',
        title: 'Find What the Entry Doesn’t Say',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 8,
        durationMinutesMax: 8,
        purpose: 'Name a missing question or modern situation.',
        spokenLine:
            'The living text receives what the older text could not know.',
        steps: <String>[
          'Choose an entry that feels incomplete.',
          'Name the missing question or modern situation it does not yet address.',
          'Add that question to the Library.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'Colophon',
        title: 'Return to Day 1’s Entry',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 8,
        durationMinutesMax: 8,
        purpose: 'Re-read the first entry after the decan has turned.',
        spokenLine: 'The reader returns changed.',
        steps: <String>[
          'Re-read the Day 1 entry.',
          'Write what you saw then versus what you see now.',
          'Add or revise your reflection.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Colophon',
        title: 'Write the Application',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 10,
        durationMinutesMax: 10,
        purpose: 'Write one application from a real situation.',
        spokenLine: 'The principle becomes readable through life.',
        steps: <String>[
          'Write 150-250 words on how one Library principle operated in a real situation.',
          'Remove identifying details if needed.',
          'Optionally share the useful part.',
        ],
        sharePromptOnComplete: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'Colophon',
        title: 'Your Colophon',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 10,
        durationMinutesMax: 10,
        purpose: 'Close by naming what you read and what you added.',
        spokenLine: 'Completed correctly; the living text includes this mark.',
        steps: <String>[
          'Write your closing mark: what you read, what you added, and how the Library is richer because of it.',
          'Name reflections, questions, and connections without calling them comments.',
          'Share the final line if desired.',
        ],
        sharePromptOnComplete: true,
        extraCompletionStatusLabels: <String, String>{
          'colophon_written': 'Colophon written',
        },
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kClearingFlowKey,
    title: kClearingTitle,
    eventTitlePrefix: 'Clearing',
    glyph: kClearingGlyph,
    tagline: kClearingTagline,
    overview: kClearingOverview,
    confidenceLabel: kClearingConfidence,
    routingSummary:
        'Best for reactivity, anger, conflict, heated speech, patience, temper, stillness, and creating space before response.',
    notesPrefix: 'clearing',
    behaviorKind: 'maat_clearing_event',
    graphNodeSlugs: <String>['maat', 'ra', 'sekhmet', 'djehuty'],
    burdenLabel: 'Low',
    specialRequirementLabel: 'Practice stillness before response',
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'Indoor Tree',
        title: 'Find the Indoor Tree',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 8,
        purpose:
            'Name where heat drives action before the cleared state is available.',
        spokenLine:
            'The hot-headed man is like a tree grown in an enclosed space.',
        steps: <String>[
          'Name one situation where heat or reaction drives your actions before the cleared state is available.',
          'Write the specific situation and what generates the heat.',
          'Record what the heat-driven pattern has cost.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'Indoor Tree',
        title: 'What Has the Heat Cost?',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Name one concrete cost of the heat-driven pattern.',
        spokenLine: 'In a moment is its loss of foliage.',
        steps: <String>[
          'Return to the situation from Event 1.',
          'Name one specific cost of the heat-driven pattern: relationship, work, energy, goodwill, or opportunity.',
          'Write what would change if the response came from steadiness instead.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'Indoor Tree',
        title: 'Where Is the Clearing Already Present?',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Find an existing domain of steadiness.',
        spokenLine: 'The truly temperate person sets himself apart.',
        steps: <String>[
          'Name one domain where you already act from steadiness rather than heat.',
          'Write what this clearing produces.',
          'Name how it feels different from the heat-driven situation.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'Sunlit Field',
        title: 'Set Yourself Apart',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Choose one act that creates space before response.',
        spokenLine: 'Set yourself apart before the response forms.',
        steps: <String>[
          'Choose one physical or procedural act that creates space before response.',
          'Use a concrete practice: wait one hour, walk outside, write before sending, sleep on it, or consult the day card first.',
          'Write when you will use it and what heat situation it interrupts.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'Sunlit Field',
        title: 'One Act From the Clearing',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Take one real action from the cleared state before logging.',
        spokenLine: 'The clearing acts without heat.',
        steps: <String>[
          'Take one real action from the cleared state before logging.',
          'Record the situation and what the heat response would have been.',
          'Write what you did instead and what changed.',
        ],
        requiresRealWorldAction: true,
        extraCompletionStatusLabels: <String, String>{
          'from_the_clearing': 'from the clearing',
        },
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'Sunlit Field',
        title: 'What Your Clearing Has Already Produced',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Account for the output of steadiness.',
        spokenLine: 'It becomes verdant and doubles its yield.',
        steps: <String>[
          'Return to the domain where the clearing already exists.',
          'Name what has grown there and what has become easier.',
          'Write what output came from steadiness instead of strain.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'Fruit and Shade',
        title: 'The Grove',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Name the ecosystem your cleared state supports.',
        spokenLine: 'It reaches its end in a grove.',
        steps: <String>[
          'Name the relationship, community, household, or work ecosystem that your cleared state supports.',
          'Write what your steadiness contributes to the grove.',
          'Name one way the grove changes when you act from heat instead.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Fruit and Shade',
        title: 'The Fruit',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Name fruit others received from your cleared state.',
        spokenLine: 'Its fruit is something sweet.',
        steps: <String>[
          'Name three specific things your cleared state has produced that others received.',
          'Focus on fruit that came without depletion, resentment, or reactive heat.',
          'Write which fruit you want to keep producing.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'Fruit and Shade',
        title: 'The Shade',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Close with the shade your cleared state will continue to provide.',
        spokenLine: 'Its shade is pleasant.',
        steps: <String>[
          'Name one person or situation that benefits from your shade.',
          'Write the heat situation where you will continue setting yourself apart.',
          'Record the shade you intend to provide. Optionally share only the one-line commitment.',
        ],
        sharePromptOnComplete: true,
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kWanderingFlowKey,
    title: kWanderingTitle,
    eventTitlePrefix: 'Wandering',
    glyph: kWanderingGlyph,
    tagline: kWanderingTagline,
    overview: kWanderingOverview,
    confidenceLabel: kWanderingConfidence,
    routingSummary:
        'Best for grief, loss, mourning, missing, memory, breakup, searching, finding, restoration, support, body, and evening practice. Never a substitute for crisis support.',
    notesPrefix: 'wandering',
    behaviorKind: 'maat_wandering_event',
    graphNodeSlugs: <String>['maat', 'aset', 'nebet_het', 'anpu'],
    burdenLabel: 'Very low',
    specialRequirementLabel: 'Grief accompaniment',
    safetyNote: kWanderingSafetyNote,
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'The Search',
        title: 'Name What Was Lost',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Name the loss specifically and drink water slowly after.',
        spokenLine: 'My brother, for I have searched for you.',
        steps: <String>[
          'Write the name of what was lost. If it is not a person, name it as specifically as one.',
          'Write one sentence about what it gave you that you cannot get elsewhere right now.',
          'Place water nearby and drink slowly after.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'The Search',
        title: 'What Has the Loss Closed?',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Name what grief has closed without trying to reopen it.',
        spokenLine: 'The ears are plugged; the mouth is shut.',
        steps: <String>[
          'Name what grief has closed: mouth, ears, eyes, body.',
          'Write what no longer tastes, sounds, looks, or feels the same.',
          'Do not try to reopen it yet.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'The Search',
        title: 'Begin the Search',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Go toward what carries what was loved.',
        spokenLine: 'I have searched for you.',
        steps: <String>[
          'Go to one place, object, memory, or person that carries what was loved.',
          'Look for what remains, not for what is gone to return.',
          'Write what you found.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'The Finding',
        title: 'Where Do You Keep Looking?',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Notice where grief keeps returning.',
        spokenLine: 'The search has places it returns to.',
        steps: <String>[
          'Notice where grief keeps returning: places, songs, objects, dreams, people, memories.',
          'Write where you keep looking.',
          'Name what draws you there.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'The Finding',
        title: 'The First Finding',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Name one genuine finding from the search.',
        spokenLine: 'I found, I found.',
        steps: <String>[
          'Name one thing the search has genuinely found.',
          'Write what remains of the love.',
          'Name where it has gone now.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'The Finding',
        title: 'The Second Finding',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Listen to what the sound of grief revealed.',
        spokenLine: 'I have found.',
        steps: <String>[
          'Name what the sound of grief has revealed: crying, speaking, silence, or bodily expression.',
          'Write what the calling-out showed.',
          'Name what searching alone did not show.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'The Opening',
        title: 'What the Loss Is Teaching',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Name one thing known from inside the loss.',
        spokenLine: 'The loss is not for a reason; the record is still honest.',
        steps: <String>[
          'Gently name one thing you know now that you could only know from inside this loss.',
          'Do not frame the loss as for a reason.',
          'Write only what is true enough to hold tonight.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'The Opening',
        title: 'What Is Beginning to Open',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Return to the closures and name only what has truly shifted.',
        spokenLine:
            'The mouth, ear, eye, body, and breath open in their own time.',
        steps: <String>[
          'Return to the closures from Event 2.',
          'Ask whether anything has partially opened: taste, speech, sound, sight, body, movement, or breath.',
          'Name only what has truly shifted.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'The Opening',
        title: 'Stand Up',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Stand and choose one small act using a restored capacity.',
        spokenLine: 'Stand up for me.',
        steps: <String>[
          'Stand physically before logging.',
          'Choose one small act using a restored capacity: eat something wanted, listen to music, see something beautiful, or speak the name of what was lost to someone safe.',
          'Record the act.',
        ],
        requiresRealWorldAction: true,
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kKhatFlowKey,
    title: kKhatTitle,
    eventTitlePrefix: 'Khat',
    glyph: kKhatGlyph,
    tagline: kKhatTagline,
    overview: kKhatOverview,
    confidenceLabel: kKhatConfidence,
    routingSummary:
        'Best for body care, tiredness, fatigue, sleep, water, food, movement, pain, tension, physical rest, exercise, and embodiment. Does not diagnose medical issues.',
    notesPrefix: 'khat',
    behaviorKind: 'maat_khat_event',
    graphNodeSlugs: <String>['maat', 'ka', 'hapy', 'anpu'],
    burdenLabel: 'Low-Medium',
    specialRequirementLabel: 'Body-care practice',
    safetyNote: kKhatSafetyNote,
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'Attend',
        title: 'Listen to the Body',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 8,
        purpose: 'Listen to what the body is communicating now.',
        spokenLine: 'Teti is sound because of his body.',
        steps: <String>[
          'Sit or lie down.',
          'Move attention from feet to face.',
          'Write three things the body is communicating right now, without judging or correcting them.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'Attend',
        title: 'The Earth on Your Flesh',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'Name what has accumulated on the body and clear one small thing.',
        spokenLine: 'The earth on your flesh has been cleared away.',
        steps: <String>[
          'Name what has accumulated on the body: tension, fatigue, shallow breath, posture, clenching, or held stress.',
          'Do one immediate small clearing act.',
          'Record what changed, even if the change is small.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'Attend',
        title: 'What the Body Has Not Been Receiving',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Name one specific thing the body has been asking for.',
        spokenLine: 'Provision must be named before it can be received.',
        steps: <String>[
          'Name one specific thing the body has been asking for and not receiving.',
          'Choose from sleep, water, food timing, movement, rest, touch, or less of something excessive.',
          'Write the smallest honest way to provide it this decan.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'Provide',
        title: 'Feed the Body',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 10,
        durationMinutesMax: 15,
        purpose: 'Eat one meal with full attention.',
        spokenLine: 'The body receives what is given with attention.',
        steps: <String>[
          'At one meal today, eat with full attention and no screens.',
          'Record what the body received.',
          'Write what the body communicated during or after the meal.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'Provide',
        title: 'The Anointing',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Return deliberate care to part of the body.',
        spokenLine: 'Ointment returns attention to the body.',
        steps: <String>[
          'After washing, apply oil, lotion, cream, or water to part of the body with deliberate attention.',
          'Record what the act returned to your relationship with the body.',
          'Keep body details private by default.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'Provide',
        title: 'Rest That the Body Actually Receives',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Set up rest the body can receive.',
        spokenLine: 'Rest is provision when the body can receive it.',
        steps: <String>[
          'Before sleep, give the body a real rest setup: consistent hour, dark/cool/quiet space, five slow breaths, and no screens for 30 minutes if possible.',
          'Record the sleep quality in the morning.',
          'Name one setup element that helped or one that was missing.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'Move',
        title: 'Stand Up',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 20,
        durationMinutesMax: 20,
        purpose: 'Move deliberately for at least 20 minutes before logging.',
        spokenLine:
            'Stand up, repel your earth, clear away your dust, raise yourself.',
        steps: <String>[
          'Move deliberately for at least 20 minutes before logging.',
          'Walking, stretching, dancing, swimming, lifting, gardening, or physical cleaning all count if sustained and attended to.',
          'Record what the movement returned to the body.',
        ],
        requiresRealWorldAction: true,
        extraCompletionStatusLabels: <String, String>{'moved': 'Moved'},
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Move',
        title: 'Water',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 10,
        purpose: 'Use water deliberately and attend to the sensation.',
        spokenLine: 'Water cleans, restores, and returns sensation.',
        steps: <String>[
          'Use water deliberately: bath, shower, swim, or hands under running water.',
          'Give the sensation your full attention.',
          'Record what the water returned to the body.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'Move',
        title: 'The Assembled Body',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Close with the body record compared to Event 1.',
        spokenLine: 'The bones are assembled; the body is present.',
        steps: <String>[
          'Return to the three body reports from Event 1.',
          'Write what shifted.',
          'Stand fully at the end and record the khat’s current state compared to Day 1.',
        ],
        requiresRealWorldAction: true,
      ),
    ],
  ),
  MaatDecanFlowDefinition(
    key: kOracleFlowKey,
    title: kOracleTitle,
    eventTitlePrefix: 'Oracle',
    glyph: kOracleGlyph,
    tagline: kOracleTagline,
    overview: kOracleOverview,
    confidenceLabel: kOracleConfidence,
    routingSummary:
        'Best for dreams, sleep, oracle questions, guidance, signs, symbols, night records, waking impressions, uncertainty, and grounded action after interpretation.',
    notesPrefix: 'oracle',
    behaviorKind: 'maat_oracle_event',
    graphNodeSlugs: <String>['maat', 'djehuty', 'ba', 'heka'],
    burdenLabel: 'Low',
    specialRequirementLabel: 'Dream question practice',
    safetyNote: kOracleSafetyNote,
    events: <MaatDecanFlowEvent>[
      MaatDecanFlowEvent(
        eventNumber: 1,
        flowDay: 1,
        decanSection: 'Preparation',
        title: 'Prepare the Reception Chamber',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 10,
        durationMinutesMax: 10,
        purpose: 'Prepare the sleep space and oracle question.',
        spokenLine: 'I place myself in the shadow of the Great God.',
        steps: <String>[
          'Before sleep, clear the space near your head.',
          'Place one small object there.',
          'Write your oracle question on paper and set it under or beside the object.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 2,
        flowDay: 5,
        decanSection: 'Preparation',
        title: 'The Pre-Sleep Purification',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Purify before sleep and hold the question clearly.',
        spokenLine: 'The question is held clearly before sleep.',
        steps: <String>[
          'Before sleep, wash your face and hands with cool water.',
          'Hold the oracle question clearly.',
          'Lie down with the question present.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'Preparation',
        title: 'The Invocation',
        timing: MaatDecanFlowTiming.evening,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose: 'Speak the question once before sleep.',
        spokenLine: 'The question is spoken once, then silence receives.',
        steps: <String>[
          'Speak the invocation before sleep.',
          'Address the deity, principle, Ba, Ka, Ma’at, or divine presence you are asking.',
          'Speak the question clearly once. Do not speak again before sleep.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 4,
        flowDay: 11,
        decanSection: 'Reception',
        title: 'Record Upon Waking',
        timing: MaatDecanFlowTiming.morning,
        durationMinutesMin: 10,
        durationMinutesMax: 10,
        purpose: 'Record the dream before phone, speech, or interpretation.',
        spokenLine: 'The night record is written before interpretation.',
        steps: <String>[
          'Immediately upon waking, before phone or conversation, write what you remember.',
          'Record images, words, feelings, colors, sequence, and atmosphere.',
          'Do not interpret yet.',
        ],
        requiresRealWorldAction: true,
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'Reception',
        title: 'Distinguish Oracle from Ordinary',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Mark possible oracle material without forcing meaning.',
        spokenLine: 'Not every dream is the oracle.',
        steps: <String>[
          'Review the dream records.',
          'Mark possible oracle material: unusually vivid, direct address, clear relation to the question, or strong waking impression.',
          'Mark ordinary dreams honestly.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 6,
        flowDay: 19,
        decanSection: 'Reception',
        title: 'The Recurring Element',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Name what appeared more than once.',
        spokenLine: 'What returns asks to be examined.',
        steps: <String>[
          'Review all recorded dreams from the first two decans.',
          'Name what appeared more than once: figure, color, place, action, sound, feeling, or symbol.',
          'Keep the recurring element tied to the record.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 7,
        flowDay: 21,
        decanSection: 'Interpretation',
        title: 'The Kemetic Framework',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 10,
        durationMinutesMax: 10,
        purpose:
            'Interpret the recurring element through four grounded questions.',
        spokenLine: 'Interpretation serves action.',
        steps: <String>[
          'Interpret the recurring element with four questions.',
          'Ask what it does, what principle it carries, how it relates to the oracle question, and what action it indicates.',
          'Do not treat disturbing dream content as definitive truth.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Interpretation',
        title: 'What the Oracle Indicates',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
        purpose: 'Name one specific direction or admit what remains unclear.',
        spokenLine:
            'The indication is named only as clearly as it was received.',
        steps: <String>[
          'Write one specific direction or action the oracle appears to indicate.',
          'If unclear, say so honestly.',
          'Record the strongest impression received so far.',
        ],
      ),
      MaatDecanFlowEvent(
        eventNumber: 9,
        flowDay: 29,
        decanSection: 'Interpretation',
        title: 'Act on What Was Received',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 10,
        durationMinutesMax: 15,
        purpose:
            'Take one indicated action before logging and close the oracle record.',
        spokenLine: 'He awoke and acted.',
        steps: <String>[
          'Take one specific action indicated by the oracle before logging.',
          'Write the complete oracle record: question, what the night sent, what it indicated, and what action was taken.',
          'If the oracle stayed unclear, record that honestly and do only the grounded action you can justify.',
        ],
        requiresRealWorldAction: true,
        extraCompletionStatusLabels: <String, String>{
          'oracle_complete': 'Oracle complete',
        },
      ),
    ],
  ),
];

bool _maatDecanTimeZonesInitialized = false;

void _ensureMaatDecanTimeZonesInitialized() {
  if (_maatDecanTimeZonesInitialized) return;
  tzdata.initializeTimeZones();
  _maatDecanTimeZonesInitialized = true;
}

MaatDecanFlowDefinition? maatDecanFlowDefinitionForKey(String? key) {
  final normalized = key?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final definition in kMaatDecanFlowDefinitions) {
    if (definition.key == normalized) return definition;
  }
  return null;
}

MaatDecanFlowDefinition? maatDecanFlowDefinitionForTitle(String? title) {
  final normalized = title?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final definition in kMaatDecanFlowDefinitions) {
    if (definition.title.toLowerCase() == normalized) return definition;
  }
  return null;
}

MaatDecanFlowDefinition? maatDecanFlowDefinitionFromNotes(String? notes) {
  final kind = resolveMaatFlowKind(flowNotes: notes);
  final key = kind?.flowKey;
  return maatDecanFlowDefinitionForKey(key);
}

DateTime maatDecanFlowEventDate(DateTime startDate, MaatDecanFlowEvent event) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  return DateTime(start.year, start.month, start.day + event.flowDay - 1);
}

DateTime maatDecanFlowNowInZone(TrackSkyTimeZone timezone, {DateTime? now}) {
  _ensureMaatDecanTimeZonesInitialized();
  final location = tz.getLocation(timezone.ianaName);
  final zoned = tz.TZDateTime.from((now ?? DateTime.now()).toUtc(), location);
  return _fromZonedDateTime(zoned);
}

MaatDecanFlowOccurrenceSchedule maatDecanFlowScheduleForEvent(
  MaatDecanFlowEvent event,
  DateTime flowStart,
  TrackSkyTimeZone timezone, {
  int anchorHour = kMaatDecanFlowDefaultMiddayHour,
  int anchorMinute = kMaatDecanFlowDefaultMiddayMinute,
}) {
  final date = maatDecanFlowEventDate(flowStart, event);
  switch (event.timing) {
    case MaatDecanFlowTiming.morning:
      return maatDecanFlowMorningScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
    case MaatDecanFlowTiming.anyTime:
      return maatDecanFlowFixedScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
        hour: anchorHour,
        minute: anchorMinute,
        scheduleType: 'fixed_local_any_time_anchor',
        fallback: 'user_editable_local_time',
      );
    case MaatDecanFlowTiming.midday:
      return maatDecanFlowFixedScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
        hour: anchorHour,
        minute: anchorMinute,
        scheduleType: 'fixed_local_midday',
        fallback: 'user_editable_local_time',
      );
    case MaatDecanFlowTiming.evening:
      return maatDecanFlowEveningScheduleForDate(
        date,
        timezone,
        durationMinutes: event.durationMinutesMax,
      );
  }
}

MaatDecanFlowOccurrenceSchedule maatDecanFlowMorningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = dawnHouseRiteScheduleForDate(date, timezone);
  final startUtc = base.startUtc.add(const Duration(minutes: 30));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return MaatDecanFlowOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: base.usedFallback,
    timezone: timezone,
    referenceLocationName: base.referenceLocation.name,
    scheduleType: 'local_astronomical_dawn_plus_30_minutes',
    fallback: 'sunrise_minus_15_minutes_plus_30_minutes',
  );
}

MaatDecanFlowOccurrenceSchedule maatDecanFlowFixedScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
  required int hour,
  required int minute,
  required String scheduleType,
  required String fallback,
}) {
  _ensureMaatDecanTimeZonesInitialized();
  final localDate = DateTime(date.year, date.month, date.day);
  final location = tz.getLocation(timezone.ianaName);
  final clampedHour = hour.clamp(0, 23).toInt();
  final clampedMinute = minute.clamp(0, 59).toInt();
  final startUtc = tz.TZDateTime(
    location,
    localDate.year,
    localDate.month,
    localDate.day,
    clampedHour,
    clampedMinute,
  ).toUtc();
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  return MaatDecanFlowOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: false,
    timezone: timezone,
    referenceLocationName: timezone.label,
    scheduleType: scheduleType,
    fallback: fallback,
    anchorHour: clampedHour,
    anchorMinute: clampedMinute,
  );
}

MaatDecanFlowOccurrenceSchedule maatDecanFlowEveningScheduleForDate(
  DateTime date,
  TrackSkyTimeZone timezone, {
  required int durationMinutes,
}) {
  final base = eveningThresholdScheduleForDate(
    date,
    timezone,
    fallbackMinutesAfterMidnight: kMaatDecanFlowEveningFallbackMinutes,
  );
  final startUtc = base.startUtc.add(const Duration(minutes: 10));
  final endUtc = startUtc.add(Duration(minutes: durationMinutes));
  final location = tz.getLocation(timezone.ianaName);
  return MaatDecanFlowOccurrenceSchedule(
    startLocal: _fromZonedDateTime(tz.TZDateTime.from(startUtc, location)),
    endLocal: _fromZonedDateTime(tz.TZDateTime.from(endUtc, location)),
    startUtc: startUtc,
    endUtc: endUtc,
    usedFallback: base.usedFallback,
    timezone: timezone,
    referenceLocationName: base.referenceLocation.name,
    scheduleType: 'local_sunset_plus_30_minutes',
    fallback: 'user_selected_evening_time_plus_30_minutes',
  );
}

String maatDecanFlowEventTitle(
  MaatDecanFlowDefinition definition,
  MaatDecanFlowEvent event,
) {
  return '${definition.eventTitlePrefix} ${event.eventNumber}: ${event.title}';
}

String maatDecanFlowActionId(
  MaatDecanFlowDefinition definition,
  MaatDecanFlowEvent event,
) {
  return '${definition.key}-event-${event.eventNumber.toString().padLeft(2, '0')}';
}

String maatDecanFlowClientEventId({
  required int flowId,
  required MaatDecanFlowDefinition definition,
  required MaatDecanFlowEvent event,
}) {
  return '${definition.key}:$flowId:event-${event.eventNumber}';
}

MaatDecanFlowEvent? maatDecanFlowEventByNumber(
  MaatDecanFlowDefinition definition,
  int? eventNumber,
) {
  if (eventNumber == null) return null;
  for (final event in definition.events) {
    if (event.eventNumber == eventNumber) return event;
  }
  return null;
}

MaatDecanFlowEvent? maatDecanFlowEventForEvent({
  required MaatDecanFlowDefinition definition,
  String? title,
  String? actionId,
  Map<String, dynamic>? behaviorPayload,
}) {
  int? parseNumber(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  final payloadEvent = maatDecanFlowEventByNumber(
    definition,
    parseNumber(behaviorPayload?['event_number']),
  );
  if (payloadEvent != null) return payloadEvent;

  final actionMatch = RegExp(
    '${RegExp.escape(definition.key)}-event-(\\d{1,2})',
    caseSensitive: false,
  ).firstMatch(actionId?.trim() ?? '');
  final actionEvent = maatDecanFlowEventByNumber(
    definition,
    parseNumber(actionMatch?.group(1)),
  );
  if (actionEvent != null) return actionEvent;

  final titleMatch = RegExp(
    '^\\s*${RegExp.escape(definition.eventTitlePrefix)}\\s+(\\d{1,2})\\s*:',
    caseSensitive: false,
  ).firstMatch(title?.trim() ?? '');
  return maatDecanFlowEventByNumber(
    definition,
    parseNumber(titleMatch?.group(1)),
  );
}

Map<String, dynamic> maatDecanFlowBehaviorPayload({
  required MaatDecanFlowDefinition definition,
  required MaatDecanFlowEvent event,
  required MaatDecanFlowOccurrenceSchedule schedule,
}) {
  return <String, dynamic>{
    'kind': definition.behaviorKind,
    'flow_key': definition.key,
    'event_number': event.eventNumber,
    'flow_day': event.flowDay,
    'decan_section': _snake(event.decanSection),
    'timing_slot': event.timing.key,
    'requires_real_world_action': event.requiresRealWorldAction,
    'missed_event_rule': 'expire_quietly',
    'completion_options': <String>[
      'observed',
      'observed_partly',
      'skipped',
      ...event.extraCompletionStatusLabels.keys,
    ],
    'share_prompt_on_complete': event.sharePromptOnComplete,
    'duration_minutes': event.durationMinutesMax,
    'duration_minutes_min': event.durationMinutesMin,
    'duration_minutes_max': event.durationMinutesMax,
    'burden': _snake(definition.burdenLabel),
    'rhythm': _snake(definition.rhythmLabel),
    if (definition.specialRequirementLabel != null)
      'special_requirement': definition.specialRequirementLabel,
    if (definition.safetyNote != null) 'safety_note': definition.safetyNote,
    'routing_summary': definition.routingSummary,
    'schedule': <String, dynamic>{
      'type': schedule.scheduleType,
      'fallback': schedule.fallback,
      'used_fallback': schedule.usedFallback,
      'timezone': schedule.timezone.key,
      'iana_timezone': schedule.timezone.ianaName,
      'reference_location': schedule.referenceLocationName,
      if (schedule.anchorHour != null) 'anchor_hour': schedule.anchorHour,
      if (schedule.anchorMinute != null) 'anchor_minute': schedule.anchorMinute,
    },
  };
}

String maatDecanFlowDetailText(
  MaatDecanFlowDefinition definition,
  MaatDecanFlowEvent event,
) {
  final specialStatuses = event.extraCompletionStatusLabels.values
      .map((label) => label.trim())
      .where((label) => label.isNotEmpty)
      .toList(growable: false);
  return <String>[
    'Words\n"${event.spokenLine}"',
    'Steps\n${_numberedLines(event.steps)}',
    if (event.optionalSteps.isNotEmpty)
      'Optional\n${_numberedLines(event.optionalSteps)}',
    if (event.requiresRealWorldAction || specialStatuses.isNotEmpty)
      'Complete\n${_completionDetail(definition, event, specialStatuses)}',
  ].join('\n\n');
}

String maatDecanFlowTimingLabel(MaatDecanFlowEvent event) {
  switch (event.timing) {
    case MaatDecanFlowTiming.morning:
      return 'Day ${event.flowDay} · morning';
    case MaatDecanFlowTiming.anyTime:
      return 'Day ${event.flowDay} · any time · 11:00 reminder';
    case MaatDecanFlowTiming.midday:
      return 'Day ${event.flowDay} · 11:00 local';
    case MaatDecanFlowTiming.evening:
      return 'Day ${event.flowDay} · evening';
  }
}

String _completionDetail(
  MaatDecanFlowDefinition definition,
  MaatDecanFlowEvent event,
  List<String> specialStatuses,
) {
  final lines = <String>[];
  if (event.requiresRealWorldAction) {
    lines.add(
      'Mark ${definition.eventTitlePrefix} ${event.eventNumber} observed after the action in the steps is actually done.',
    );
  }
  if (specialStatuses.isNotEmpty) {
    lines.add(
      'Use ${_joinReadable(specialStatuses)} only when that is the real outcome.',
    );
  }
  return lines.join('\n');
}

String _joinReadable(List<String> values) {
  if (values.length <= 1) return values.join();
  if (values.length == 2) return '${values.first} or ${values.last}';
  return '${values.sublist(0, values.length - 1).join(', ')}, or ${values.last}';
}

String _numberedLines(List<String> lines) {
  return lines
      .asMap()
      .entries
      .map((entry) => '${entry.key + 1}. ${entry.value}')
      .join('\n');
}

String _snake(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
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
