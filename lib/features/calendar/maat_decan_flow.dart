import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dawn_house_rite_flow.dart';
import 'evening_threshold_rite_flow.dart';
import 'maat_flow_reflection_metadata.dart';
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
const String kMaatLibraryCtaAddInsight = 'add_insight';

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
  final String? libraryCta;
  final String? libraryCtaNodeSlug;
  final String? libraryCtaLabel;

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
    this.libraryCta,
    this.libraryCtaNodeSlug,
    this.libraryCtaLabel,
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
    'A 30-day practice of fair judgment: hear fully, keep one measure for favored and unfavored sides, and pronounce the decision clearly.';

const String kHouseOfLifeOverview =
    'A 30-day scribal practice: learn accurately, write and recite one useful piece of knowledge, then transmit it with care.';

const String kBoundaryStoneOverview =
    'A 30-day boundary practice: map resources, labor, credit, and force; name what moved; restore one marker to its place.';

const String kHotepOverview =
    'A 30-day evening peace practice: name what was given, separate real obligation from fear, and let the heart cool before sleep.';

const String kOpenMouthOverview =
    'A 30-day speech practice: record what the mouth creates, govern one word, and speak or withhold with discipline.';

const String kLivingRecordOverview =
    'A 30-day record practice: turn the decan into a living account across day card, library, planner, journal, and physical line.';

const String kHetHeruOverview =
    'A 30-day cooling practice: name the hot force, meet its real need, and return it toward music, beauty, feast, and joy.';

const String kTheShoreOverview =
    'A 30-day exchange practice: inventory what you offer, make one honest exchange, and account for what returns.';

const String kTheAutobiographyOverview =
    'A 30-day life-record practice: name capacities, works, gifts, and one honest claim supported by evidence.';

const String kFirstArrangementOverview =
    'A 30-day space-order practice: choose one place, see what belongs, remove what does not, and establish maintenance.';

const String kLivingPatternOverview =
    'A 30-day observation practice: watch one natural subject until a real pattern appears, then act from its principle.';

const String kTrueNameOverview =
    'A 30-day private naming practice: measure a false account against the record, speak the accurate account, and act from it.';

const String kLivingTextOverview =
    'A 30-day Library practice: read carefully, add reflection or connection, and close with a living mark.';

const String kClearingOverview =
    'A 30-day temperance practice: notice where heat drives action, create space before reply, and act from the cleared state.';

const String kWanderingOverview =
    'A 30-day evening grief accompaniment: name the loss, search gently, and notice one capacity that remains or returns.';

const String kKhatOverview =
    'A 30-day body-care practice: listen to the body, answer with water, food, washing, rest, or movement, then record what changed.';

const String kOracleOverview =
    'A 30-day dream-question practice: prepare one question, receive without forcing meaning, and test one sign through grounded action.';

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
            'The hearing begins before you think it does. The view formed before the full account is heard is already shaping what you will hear. This sitting names that view.',
        spokenLine:
            'Be patient, so that you may learn Ma\'at. Control your own preference, so that the humble petitioner may gain.',
        steps: <String>[
          'List the work, family, friendship, community, or self-judgment situations where your view affects an outcome.',
          'For each, mark whether you have already formed a view before fully hearing all sides.',
          'Circle the situation where your preference is strongest. This is where the fair hearing is most needed.',
        ],
        sourceNote:
            'Khunanup appealed nine times because the first hearing produced no decision. The petitioner must persist; the judge must eventually decide. This sitting names who is waiting for a real hearing.',
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
            'Ptahhotep said the wronged person needs to unburden the heart even when not every request can be granted. The full hearing is itself a form of justice, before the decision.',
        spokenLine:
            'Be patient when listening to the words of a petitioner. Do not dismiss him until he has completely unburdened himself.',
        steps: <String>[
          'Before the hearing, write one sentence about what you expect to hear.',
          'Give the actual hearing. Do not interrupt. Do not signal your conclusion. The conclusion that forms while the person is still speaking is premature.',
          'Afterward, write one thing you heard that complicated or expanded your view.',
        ],
        requiresRealWorldAction: true,
        sourceNote:
            'Ptahhotep\'s instruction is specific: do not dismiss the petitioner before they have completely unburdened themselves. A hearing that stops when the judge has enough for their existing conclusion is not a fair hearing — it is an efficient confirmation.',
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
            'Indefinite postponement wearing the mask of patience is not patience — it is a different form of injustice. The hearing is complete when the decision is named clearly to those it affects.',
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
            'The target is not the dramatic silence of a judge prolonging a case for benefit. It is the ordinary silence of a decision deferred because pronouncing it is uncomfortable.',
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
            'The balance that wavered during this cycle is not a failure — it is information. The closing names where the balance held and where it didn\'t, and what practice will correct the latter.',
        spokenLine:
            'Do not utter falsehood, for you are a balance. Great is Ma\'at, lasting in effect.',
        steps: <String>[
          'Name the situation where the fair hearing was most complete.',
          'Name the situation where partiality or incompleteness still entered.',
          'Speak only the truth-check lines that apply: I heard fully; I applied the same measure; I pronounced a decision clearly.',
          'Write one continuing practice: When I am called to judge, I will [practice] before I decide.',
        ],
        sourceNote:
            'The Eloquent Peasant\'s nine appeals end with justice finally pronounced and goods restored. The balance protects both the judged and the judge. The judge who hears unfairly does not only harm the petitioner — they become an unreliable measure.',
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
        purpose:
            'The space cannot be arranged until it is seen accurately — as it is right now, with every accumulated thing in its current position.',
        spokenLine: 'Order begins with seeing what is actually there.',
        steps: <String>[
          'Stand at the entrance of your chosen space.',
          'Write what is actually there, where it sits, and what the current arrangement communicates.',
          'Do not clean yet.',
        ],
        sourceNote:
            'Temple restoration texts began by inventorying what was present before anything was moved. The unseen object cannot be placed correctly.',
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
        purpose:
            'Removal is the active half of ordering. The object in the wrong space does the same damage to the room\'s function as the boundary stone in the wrong field. A hallway pile or same-room corner keeps the false relation in place.',
        spokenLine: 'What does not belong here is set in its true place.',
        steps: <String>[
          'Physically remove every item marked "does not belong here."',
          'Put each item where it truly belongs, not in the hallway or a corner of the same room.',
          'If it belongs nowhere you inhabit, discard it or release it.',
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
        purpose:
            'Zep Tepi was not the creation of new things but the placing of existing things in right relationship. Each item goes where it belongs in relation to the center and the threshold.',
        spokenLine: 'For I ordered everything in its proper place.',
        steps: <String>[
          'Arrange what remains by purpose, proximity, clear path, clean surfaces, and orientation.',
          'Stand at the threshold.',
          'Write what the space now says.',
        ],
        sourceNote:
            '"For I ordered everything in its proper place" — the Kemetic standard for good governance applied to any space. The arrangement is relational first: what is in right relationship to the center, what is in right relationship to the entry, what has a clear path between them.',
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
          'Add one intentional scent.',
          'Record the state of the space after purification.',
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
          'Afterward, write what was easier.',
          'Write what remains misaligned and what the space communicated.',
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
        purpose:
            'The ordering established in the second ten-day section returns to disorder without maintenance. The five-minute daily practice is what makes the ordering permanent rather than a one-time reset. The instruction must be specific enough to follow without thinking about it.',
        spokenLine: 'What is arranged must be returned to arrangement.',
        steps: <String>[
          'Write the maintenance practice as a specific instruction: When I [enter/leave] this space each [morning/evening], I will [specific acts].',
          'Include how the practice returns objects.',
          'Include how the practice clears surfaces and performs one sensory act of purification.',
          'Share only the one-sentence statement of what the space now communicates.',
        ],
        sourceNote:
            'The offering ritual was daily — not because the offering expired, but because the space required continued attention to remain ordered. What is arranged once and not maintained is not an ordered space. It is a space that was arranged once.',
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
        purpose:
            'The Kemetic observer who watched the jackal did not decide in advance what it would mean. They watched. This rite begins the same way: choose the subject and look at it without deciding what it demonstrates.',
        spokenLine: 'Say what is. Do not interpret yet.',
        steps: <String>[
          'Go to your subject and observe for 15-20 minutes.',
          'Write only what actually happens.',
          'Do not interpret yet.',
        ],
        sourceNote:
            'The Anubis theology emerged from watching actual jackals at the boundary between living fields and the desert necropolis. The behavior came first; the principle followed. Choose the subject and begin watching — interpretation is Decan 2\'s work.',
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
        purpose:
            'The principle must come from the observed behavior — not from what the subject is supposed to represent, but from what the specific observed pattern actually demonstrates.',
        spokenLine: 'The principle must come from observed behavior.',
        steps: <String>[
          'Write one sentence beginning with "[Subject] demonstrates: [principle]." Reject any principle not directly traceable to a specific behavior you observed and recorded.',
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
        purpose:
            'The lesson is the observation\'s product — one actionable principle derived from patient watching over thirty days.',
        spokenLine:
            'Speak the lesson before writing it: Watching [subject] for thirty days taught me [lesson]. Say it aloud once. Then write it.',
        steps: <String>[
          'Write one actionable lesson: Watching ___ taught me ___.',
          'Keep it tied to the observed pattern.',
          'Optionally share the lesson to the feed.',
        ],
        sharePromptOnComplete: true,
        sourceNote:
            'The Anubis theology did not remain an observation — it became the threshold guardian, the weigher of hearts, the guide of the dead. The lesson extracted from the natural world becomes a principle of conduct. This sitting names that principle and commits it to the record.',
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
            'The Per Ankh was a working scriptorium — not a library where the learned went to read, but a workshop where texts were produced, tested, and transmitted. This sitting enters it as a practitioner, not a browser.',
        spokenLine:
            'Come to me, Djehuty, that you may give advice and make me skillful in your office.',
        steps: <String>[
          'Name what you are currently learning - a skill, craft, practice, tradition, or body of knowledge.',
          'Check the three disciplines: writing it down, speaking or reciting it, and seeking those who know more.',
          'Name the weakest of the three. This is where the practice begins.',
        ],
        sourceNote:
            'The Per Ankh\'s priests were not passive custodians — they copied, produced, interpreted, and applied what they held. Knowledge that sits in the archive without being used is not living knowledge. This sitting names what you are actively working with, and where the work is weakest.',
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
            'What you can write precisely has been learned. What you can only gesture at is still loose in the understanding. Writing is the test.',
        spokenLine:
            'Write with your hand, recite with your mouth, and converse with those more knowledgeable than you.',
        steps: <String>[
          'Write one complete account of something you have learned, as if the reader cannot ask you to clarify.',
          'Read it back and correct anything that depends on you standing beside the text.',
          'Name what the writing revealed about the gaps in your understanding. The gaps are not failures — they are the Per Ankh\'s next assignment.',
        ],
        sourceNote:
            'The Kemetic scribe was valued for the accuracy of the hand — the transmission that neither added nor removed. Writing what you know precisely enough for a future reader who cannot ask you to clarify is the scribal standard. Where the writing breaks down is where the learning is still incomplete.',
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
            'The scribe who could recite what they copied had internalized it. The scribe who could only locate it in the text had stored it, not learned it.',
        spokenLine:
            'Write with your hand, recite with your mouth, and converse with those more knowledgeable than you.',
        steps: <String>[
          'Speak one concept or principle from memory, accurately and in order.',
          'Notice what is fluent and what collapses when spoken. Collapse is useful data — it shows where the understanding depends on the text rather than on itself.',
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
        purpose:
            'The Per Ankh was not an isolation practice — knowledge was transmitted through conversation with those who had more of it. The source your current understanding cannot replace is the one this sitting goes looking for.',
        spokenLine:
            'I am the servant of your house. Come to me that you may advise me.',
        steps: <String>[
          'Seek the person, book, source, teacher, or practitioner named on Day 9.',
          'Ask one question your current study cannot answer.',
          'Write one thing you learned that you could not have gotten from yourself alone.',
        ],
        sourceNote:
            'The instruction texts frame the student\'s relationship to the teacher as: come, advise me, let me be your servant. The posture of seeking is part of the practice. The question you bring determines what you receive.',
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
            'The House of Life closes with one precise sentence on the subject studied and one practice that continues. The practice that continues is more important than the thirty-day record.',
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
            'Chester Beatty IV called the scribes\' writing their memory-priest — the mechanism of their continued existence. The precise sentence that closes this flow is the user\'s contribution to the same chain. What you can now say accurately, you can now transmit.',
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
            'After the Nile flood, the boundaries were resurveyed because the water had moved them. The stone was replaced not according to memory but according to the original measurement. Map the four fields from the same starting question: what is actually mine?',
        spokenLine:
            'Do not move the markers on the boundaries of the fields, nor alter the measuring line.',
        steps: <String>[
          'Map four domains: resources, labor, credit, and force.',
          'For each, write what is actually yours and what belongs to others.',
          'For force, name what level of pressure or authority is proportionate to the situation.',
        ],
        sourceNote:
            'The boundary-stone surveyors worked from original records, not from what was convenient after the flood. This sitting maps four fields — resources, labor, credit, force — from the same starting question: what is actually mine, and where does someone else begin?',
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
            'The resurvey asked one question per field: where does the stone actually belong? Not where it ended up after the flood — where the original measurement said it should be.',
        spokenLine: 'One who transgresses the furrow shortens a lifetime.',
        steps: <String>[
          'For resources, ask whether you are consuming at the level that is actually yours.',
          'For labor, ask whether you are doing your work, someone else\'s work, or leaving yours to others.',
          'For credit, ask whether you are claiming what was shared or someone else\'s.',
          'For force, ask whether pressure or authority has continued past what the situation required.',
        ],
        sourceNote:
            'The re-survey after the Nile flood was restorative, not creative — it found where the stone belonged before disruption moved it. Not where the boundary has drifted, but where it should be if the original measure were applied honestly.',
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
            'What was taken past the measure is already being returned through a different mechanism. The gullet\'s rejection is not a metaphor — it is the actual consequence operating in the relationship, the situation, or the body of the one who took too much.',
        spokenLine:
            'The property of a dependent is an obstruction to the throat. Too much bread is swallowed and spat up.',
        steps: <String>[
          'Where the stone moved, name what life is already throwing back: strain, resentment, depletion, or loss of trust.',
          'Name the evidence without defending it.',
          'Write what enough would have looked like in that domain.',
        ],
        sourceNote:
            'Amenemope\'s image of the gullet rejecting what was taken past measure is viscerally physical — bread swallowed and spat up, property that becomes an obstruction in the throat. The excess does not stay. It produces visible evidence that the measure was exceeded.',
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
            'The survey closes with the stones named: placed, restored, or still displaced. What remains displaced is a named commitment — which is different from an unexamined situation.',
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
            'The Kemetic resurvey was complete when every stone was accounted for — placed, replaced, or noted as requiring further work. What remains displaced has been located and named, which is the prerequisite for restoration.',
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
            'The offering is complete when it meets the measure of what was owed — not when the giver has given everything possible. Hotep does not happen from a working position; the body must be allowed to sit where the offering can close. This distinction is the practice.',
        spokenLine:
            'I have come having gotten Horus\'s eye, that your heart may become cool with it.',
        steps: <String>[
          'Place water on your surface.',
          'Sit somewhere you actually rest, not in a working position.',
          'Write what you are currently offering: time, labor, care, attention, skill.',
          'Write what is owed.',
          'Drink the water.',
        ],
        sourceNote:
            'The Pyramid Texts begin restoration with cool water because the heart that has been cooled can receive the offering\'s completion. The cool heart is what Hotep produces — not what you must bring to it.',
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
          'Carry that distinction into the next ten-day section.',
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
            'The central question of Hotep is not "have I done enough" — it is "have I done what was owed." These produce different answers.',
        spokenLine:
            'Do not go to bed fearing tomorrow. God is success; man is failure.',
        steps: <String>[
          'Speak the line before the question.',
          'Sit with the question for at least two minutes: Has the offering of this period been made?',
          'Answer with the Day 1 measure, not with a vague feeling of enough.',
          'Write: The offering is complete, or The offering is incomplete in [specific way].',
        ],
        sourceNote:
            'Amenemope does not address fear of tomorrow with productivity advice. The answer is distinguishing between what is yours to do and what is tomorrow\'s problem. The offering made today closes today\'s account.',
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
            'Name what you are carrying to bed that your anxiety cannot actually change. What remains after that sorting is the real offering.',
        spokenLine:
            'Man knows not what tomorrow will be. What I cannot control, I set down here.',
        steps: <String>[
          'Write the outcomes, choices, or circumstances you are carrying to bed but cannot control.',
          'Draw a line through each one.',
          'Place the page away from the bed.',
          'Name what remains that is genuinely yours.',
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
          'Place water beside you.',
          'Sit.',
          'Speak the line.',
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
            'The cool heart is the product of the completed offering, not its prerequisite. This sitting produces the cool heart by closing the offering record and placing what cannot be controlled outside the sleeping space. The act is physical because the cool heart is physical.',
        spokenLine:
            'These your cool waters have come from your son. Your heart will not become weary with it. Hotep.',
        steps: <String>[
          'Place water where you will be before sleep.',
          'Sit where you will be before sleep.',
          'Name aloud what you offered across this flow: time, labor, care, presence, skill.',
          'Speak: What was owed has been given.',
          'Write anything left in the bed that is not yours to control.',
          'Place the paper away from where you sleep.',
          'Drink the water.',
          'Lie down to sleep.',
        ],
        extraCompletionStatusLabels: <String, String>{'cooled': 'Cooled'},
        sourceNote:
            'The ḥtp formula began with "Hotep" — satisfaction received, offering made — and the provision followed. The peace comes first; the provision follows from it. This final event replicates that sequence: the record is closed, the water is drunk, the heart is cooled.',
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
            'What comes out of the mouth before the heart has governed it is not yet speech — it is reflex with sound. This sitting finds the reflex patterns before they are taken for speech.',
        spokenLine:
            'It is the heart and the tongue that have power. I open the record of what my tongue has been commanding.',
        steps: <String>[
          'Write what your mouth produces when you are tired, frustrated, or thoughtless.',
          'Name what you are saying that should not be said.',
          'Name what is inaccurate or overheated.',
          'Name what needs to be said but has been swallowed.',
        ],
        sourceNote:
            'In the Memphite Theology, the heart conceives and the tongue commands — formation happens through speech. The mouth that produces without the heart\'s governance is not creating order; it is creating noise. This sitting opens the record of which category most of the recent speech has fallen into.',
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
          'Choose one piece of speech from the last five days.',
          'Write what it created.',
          'Choose one thing not said.',
          'Write what its absence created.',
          'Name the speech pattern from Day 1 that the next ten-day section should govern.',
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
          'Write: In the next ten-day section, I will practice [discipline]. I will say [needed thing].',
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
            'The tongue is the steering oar, not the pilot. The heart holds course; the tongue carries it out. This decan names the one discipline that keeps the oar from steering where the heart didn\'t direct it.',
        spokenLine: 'Be strong in your heart. Do not steer with your tongue.',
        steps: <String>[
          'Review the five disciplines: pause, accuracy, relevance, timing, witness before speaking.',
          'For each, write whether it is currently operating in your speech.',
          'Choose one discipline for this ten-day section.',
          'Define the specific practice.',
        ],
        sourceNote:
            'Amenemope\'s image of the tongue as a steering oar places the problem clearly: an oar not controlled by the navigator creates the illusion of movement while taking the vessel in the wrong direction. Choose the discipline most absent.',
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
          'Check whether the thing that needs to be said has been said.',
          'If it has not been said, name the time before this ten-day section ends when you will say it.',
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
          'Record whether the important thing has been said.',
          'If it has not been said, name what remains in the way.',
          'Name one conversation that changed when the mouth was governed.',
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
            'The heart conceives before the tongue declares. Writing the true thing first is the heart\'s work — making it real through speech is the tongue\'s work. What is not fully conceived is not ready to be declared. This sitting completes the first half.',
        spokenLine:
            'Your tongue is the plummet. Your heart is the weight. I open my mouth with care.',
        steps: <String>[
          'Ask what your mouth has been creating across this flow.',
          'Name one specific, true, currently unspoken thing you will bring into the world by saying it.',
          'Write it first.',
        ],
        sourceNote:
            'The Memphite Theology describes creation as: heart conceives, tongue declares, world forms. The mouth that speaks before the heart has finished conceiving is interrupting the process. Writing the sentence first is the heart\'s work completed before the tongue takes over.',
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
          'If it has not been said, say it before the closing sitting.',
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
            'The flow closes with what was spoken that needed to be spoken, and with one minute of intentional silence. The silence is not the absence of speech — it is the space the governed mouth creates.',
        spokenLine:
            'My mouth is open. My speech is governed. What I command, I create with care.',
        steps: <String>[
          'Name the most significant speech pattern the inventory revealed.',
          'Name what the governance practice produced.',
          'Name what was spoken that needed to be spoken: I said [thing] on [day]. It is now in the world.',
          'Check whether the line is true before speaking it.',
          'Speak only the parts of the line that are true.',
          'Say, if true: My speech was not heated.',
          'Say, if true: My heart was not hasty.',
          'Say, if true: I said what needed to be said.',
          'Sit in intentional silence for one full minute.',
        ],
        extraCompletionStatusLabels: <String, String>{'spoken': 'Spoken'},
        sourceNote:
            'The Opening of the Mouth ceremony restored speech, eating, and breath after they had been closed. This close makes silence available — the governed mouth can be silent when silence is right. The one minute at the end is the practice of that.',
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
            'The day card is the record\'s first entry — the dating before the work. Merer\'s logbook placed the date before naming the work because the work outside of time is not a record.',
        spokenLine:
            'What occurred must be placed within its time. What is placed within its time becomes record. What becomes record persists.',
        steps: <String>[
          'Open today\'s day card in ḥꜣw and read the Kemetic date, decan name, Ma\'at principle, and cosmic context.',
          'Write the date down outside the app: Kemetic date, season, and decan name.',
          'Speak the line. The record has been opened.',
        ],
        requiresRealWorldAction: true,
        sourceNote:
            'Merer\'s logbook dated each entry before naming the work because work outside of time is not a record — it is an anecdote. The day card does the same: it places the decan\'s activity inside the Kemetic count before anything is added to it.',
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
            'The journal is the papyrus — the private record from which the guidance system builds its account. What is written with honesty and specificity produces more accurate guidance than what is performed there with care for appearance.',
        spokenLine:
            'Their writing was their memory-priest. The pen was their child. Their names endured.',
        steps: <String>[
          'Open the journal and write at least three substantive sentences.',
          'Write at least three substantive sentences about what this decan has meant, what you actually did in Ma\'at, what resisted the period, and one unanswered question. Specific is more useful than comprehensive.',
          'Notice any badges generated from the entry. They are signals that the record is being read.',
        ],
        requiresRealWorldAction: true,
        sourceNote:
            'Chester Beatty IV calls writing the memory-priest that keeps the name alive. The journal\'s entries are that priest — they build the account the guidance system works from. Honest and specific entries produce honest and specific guidance.',
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
            'The guidance witnesses before it advises. It names what the record shows — not what you hope the record shows. Read it as a lector priest\'s consultation, not as a notification.',
        spokenLine:
            'The guidance comes when the pattern has been seen. It witnesses before advising. It names without shame. It offers one act.',
        steps: <String>[
          'Open the Ma\'at guidance card, a recent guidance delivery, or the decan opening.',
          'Name the pattern it identified and the one act it recommends.',
          'If possible, complete the act today. If not, write what the right response is.',
          'Write: Ma\'at guidance, Day 25: [what it said]. My response: [what I did or decided].',
        ],
        sourceNote:
            'The lector priest read the sacred texts aloud during ritual — the voice that activated what was written. The guidance reads the journal\'s record and names what is there. Reading it attentively, rather than skimming, completes the consultation.',
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
            'Sekhmet was sent by Ra for a legitimate reason, against a real threat. The force going further than intended is not a character flaw — it is what happens when the Eye has no beer. Name yours without assigning fault to its origin.',
        spokenLine:
            'Sekhmet, the Powerful One, the Eye of Ra, went out and did not come back when called. She is the same force as Het-Heru before the beer.',
        steps: <String>[
          'Read the core story: Ra sent the Eye as Sekhmet, she kept destroying after he called her back, and the gods flooded the field with red beer.',
          'Name your Sekhmet: resentment, ambition, grief, perfectionism, anger, or another force with its own momentum.',
          'Write: My Sekhmet is [specific thing]. It was sent out for [wound or purpose]. It is still going because [what sustains it].',
        ],
        optionalSteps: <String>[
          'Name the beautiful thing this force used to make before it went too far.',
        ],
        sourceNote:
            'In the Book of the Heavenly Cow, Sekhmet\'s origin is Ra\'s wound and his legitimate anger. The force was right at the beginning. The problem arrived when it could not be recalled. This sitting names the force and its original purpose before deciding what the beer should be.',
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
            'The beer must be abundant. Ra did not pour one jar — he poured seven thousand. Whatever the transforming thing is, it must be given generously enough that the underlying need is actually met.',
        spokenLine:
            'Seven thousand jars of beer were dyed red like blood. The force received what it could drink, and it was transformed.',
        steps: <String>[
          'Name your beer: beauty, music, rest, connection, significance, touch, play, or another abundant good.',
          'Write: The beer for my Sekhmet is [specific thing]. It fills the actual need because [reason].',
          'Make it abundant. Ra did not pour one jar; he flooded the field.',
        ],
        sourceNote:
            'The myth names the scale: seven thousand jars, poured across the whole field of Lower Kemet. Transformation through a token gesture is not the Kemetic model. The beer that transforms must be given in the quantity that allows the need to be fully met.',
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
          'If it is still active, name what more beer would look like.',
          'If something shifted, name the first sign of Het-Heru.',
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
            'The sistrum was not Het-Heru\'s symbol — it was her presence made audible. When it was shaken, the goddess arrived. This sitting makes music the main event, not the background.',
        spokenLine:
            'Het-Heru, the Golden One, Mistress of Joy, Lady of the Dance. The sistrum sounds and she is present.',
        steps: <String>[
          'Listen to music that actually moves you — not as background, not as accompaniment, but as the event itself.',
          'Notice what the music does to the place where Sekhmet was.',
          'Afterward write one word about what you felt. That is the whole record.',
        ],
        requiresRealWorldAction: true,
        sourceNote:
            'At Dendera, music was the primary act of worship, and the reception of that music was the offering returned. The sistrum sounds, and Het-Heru is present. The one word written after is the record of whether that presence arrived.',
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
          'Speak only the lines that are true.',
          'Say, if true: I named the Sekhmet.',
          'Say, if true: I found what it sought.',
          'Say, if true: I poured the beer.',
          'Say, if true: I let music reach me.',
          'Say, if true: I shared a feast.',
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
        purpose:
            'The sailor offered oil to the Prince of Punt — the main product of the island he was standing on. The Prince laughed. Honest inventory prevents that error.',
        spokenLine: 'Do well, and you will attain influence.',
        steps: <String>[
          'Write an honest inventory of skills, labor, knowledge, and relationships you can offer now.',
          'Mark each item as active, cultivated but unused, or undeveloped.',
          'Finish: My boat is primarily full of ___.',
        ],
        sourceNote:
            'The Shipwrecked Sailor arrived with nothing and offered what the island already had. The exchange that worked was not the commercial offer — it was his honest presence and his true account of the situation. What is actually in your boat, not what you wish were there?',
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
        purpose:
            'The shore is a physical place. The exchange must actually happen before this event is logged.',
        spokenLine:
            'The Ape sits by the balance, while his heart is the plummet.',
        steps: <String>[
          'Make one real exchange before logging this event. The act is the event. Logging a planned exchange is not the same as recording a completed one.',
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
        purpose:
            'Amenemope returns to this formulation three times — not as a preference for simplicity over wealth, but as a diagnostic. Anxious bread means something in the exchange was not at honest measure.',
        spokenLine:
            'Better is bread when the mind is at ease than riches with anxiety.',
        steps: <String>[
          'Eat something while doing this event. The bread test is practical: can this bread be eaten without planning how to protect what you have, or how to get more before it runs out?',
          'Ask whether this gain feels easy or anxious.',
          'Name what made it peaceful, or what made it uneasy.',
        ],
        sourceNote:
            'Amenemope\'s formulation is a diagnostic, not a moral preference. Bread eaten with an easy mind means the exchange was at honest measure. Bread eaten with anxiety means something went wrong in the gaining or the holding.',
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
        purpose:
            'What you can actually do now is different from what you could do at twenty. This survey names the difference — the capacities that the years specifically built.',
        spokenLine: 'Say what is and do not say what is not.',
        steps: <String>[
          'Look across your adult life.',
          'Name the capacities developed through years of work, failure, repetition, and attention.',
          'Write what you can actually do now, without inflation or deflation.',
        ],
        sourceNote:
            'The Kemetic autobiography opened with offices held and capacities demonstrated — not as a résumé but as a fact-check on what the years had actually produced. The capacities named here are the ones that required the full span to develop.',
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
        purpose:
            'The four-section document is a fact-check on the life so far. Allow the full thirty to forty-five minutes. This is not a note — it is a document.',
        spokenLine: 'I will put my annals among people.',
        steps: <String>[
          'Write the four-section document: Capacities, Works, Gifts, Claim.',
          'Allow 30-45 minutes; this is a document, not a short note.',
          'Read the document back once and correct anything inflated or deflated. Not improved — corrected. The autobiography must be accurate.',
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
        purpose:
            'The Claim commits the life to something. This sitting names what the autobiography still needs to contain to have made the Claim honest.',
        spokenLine: 'What remains is named. The autobiography continues.',
        steps: <String>[
          'Read the Claim section.',
          'Name the specific work, gift, or capacity still required to make the autobiography honest to its claim.',
          'Save the remaining work as a future-return field in your record.',
        ],
        sourceNote:
            'The Kemetic autobiography could be updated while the person lived — the carving was not closed until they were. This closing names what update the life still requires to make the Section 4 claim accurate.',
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
        purpose:
            'The account that feels like "just the truth about me" is the one most worth examining. The account you chose to believe has friction; the one that feels like fact has been operating as premise long enough to lose its edges.',
        spokenLine:
            'The first account is not your fault; it is the account to be measured.',
        steps: <String>[
          'Complete: People like me generally ___. When it comes to ___, I am someone who ___. The thing I quietly believe about myself is ___.',
          'Do not judge it yet and do not share this material.',
          'If what surfaces feels larger than this flow can hold, pause the flow and seek support.',
        ],
        sourceNote:
            'The Ren — the name — was a constituent part of the person, as real as the body. A name given by someone else and accepted as your own still operates as your name. This sitting finds the name you have been living under and asks whether it belongs to you.',
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
        purpose:
            'The Memphite Theology places conception before declaration: the heart must know the form before the tongue can command it into existence. This sitting lets the heart conceive the accurate account in a specific current situation before the tongue is asked to declare it. The imagination must be specific to do its work.',
        spokenLine:
            'The heart conceives; the tongue releases the word into form.',
        steps: <String>[
          'Choose one specific current situation where the false account operates, not a general pattern.',
          'Imagine acting from the accurate account in specific detail.',
          'Write what that looks like before you attempt it.',
        ],
        sourceNote:
            'The heart conceives before the tongue commands — that is the Kemetic sequence. The imagination of acting from the accurate account in a specific situation is the heart\'s work before the declaration. What is vividly conceived with the heart\'s knowledge behind it is available to the tongue.',
      ),
      MaatDecanFlowEvent(
        eventNumber: 8,
        flowDay: 25,
        decanSection: 'Declaration',
        title: 'Speak the True Name',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'The Declaration of Innocence was spoken standing, before the divine court, aloud. Not written. Not thought. Spoken. This sitting follows the same form.',
        spokenLine: 'I am pure. I am pure. I am pure. I am pure.',
        steps: <String>[
          'Stand before speaking. The declaration is not made while seated.',
          'Speak the accurate account aloud, then speak the evidence.',
          'Say the closing declaration.',
          'Record what it felt like.',
        ],
        sourceNote:
            'The Declaration was spoken in a hall, before 42 Assessors, standing. The posture was not ceremonial — it was the form in which the declaration carried weight. This sitting follows it.',
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
        purpose:
            'The entry that arrests attention is already communicating something. Reading it fully — not the first paragraph, the whole entry — is the first act of the scribe who copies to transmit rather than to survey.',
        spokenLine: 'The Library lives when it is read.',
        steps: <String>[
          'Open the Library and choose the entry that catches your attention.',
          'Read it fully.',
          'Write one new thought the entry opened in you.',
        ],
        sourceNote:
            'The Kemetic scribe copied what was assigned and what was sought out. The entry that arrests your attention is the one the Per Ankh is directing you to. Read it the way a scribe reads to copy: without assuming you know how it ends.',
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
          'Write what the avoidance was about.',
        ],
        optionalSteps: <String>['Add one question the avoidance raises.'],
      ),
      MaatDecanFlowEvent(
        eventNumber: 3,
        flowDay: 9,
        decanSection: 'Read',
        title: 'Find What You Don’t Understand',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 8,
        durationMinutesMax: 8,
        purpose:
            'Confusion belongs in Your Insights. The unanswered question is as useful to the living record as what you can already answer.',
        spokenLine: 'No one is born wise.',
        steps: <String>[
          'Choose an important entry you do not fully understand.',
          'Open the node and tap Your Insights.',
          'Write the exact unclear passage or concept as a question.',
          'Save it to the node so the gap remains visible in your own record.',
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
        purpose:
            'A reflection is not a summary or a response. It is what the entry opened in you that the entry itself could not say — because the entry was written before you encountered it with your specific life.',
        spokenLine: 'Good advice may be found at the grindstones.',
        steps: <String>[
          'Return to the node you chose on Day 1 and tap Your Insights.',
          'Add a reflection from your lived experience — what the entry opened in you that the entry itself could not say.',
          'Save it to the node.',
        ],
        optionalSteps: <String>[
          'If it belongs to others, use Post to share it on your profile.',
        ],
        sourceNote:
            'Scribal annotations in Kemetic manuscripts were often incorporated into subsequent copies — the reader\'s gloss became part of the text. What your experience adds to the entry belongs in the record alongside the original.',
        requiresRealWorldAction: true,
        libraryCta: kMaatLibraryCtaAddInsight,
        libraryCtaNodeSlug: null,
        libraryCtaLabel: 'Add your insight',
      ),
      MaatDecanFlowEvent(
        eventNumber: 5,
        flowDay: 15,
        decanSection: 'Contribute',
        title: 'Connect Two Entries',
        timing: MaatDecanFlowTiming.anyTime,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
        purpose:
            'A short connection between two Library entries makes the relationship tappable in the living text.',
        spokenLine: 'A living text shows relation.',
        steps: <String>[
          'Find two Library entries that connect in a way the app does not already show.',
          'Open Your Insights on one of the two nodes.',
          'Write and save the connection in one or two sentences.',
          'Use Link Insight to highlight the phrase that points toward the second node and select the target node.',
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
          'Open the node and tap Your Insights.',
          'Name the missing question or modern situation the entry does not yet address.',
          'Save it to the node.',
        ],
        optionalSteps: <String>[
          'Share it if it should be available to the next person who finds the same gap.',
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
        purpose:
            'The first entry reads differently after the decan has turned. What you see now that you did not see three decans ago is the decan doing its work, and that change is worth leaving in the record.',
        spokenLine: 'The reader returns changed.',
        steps: <String>[
          'Open the node you chose on Day 1.',
          'Return to Your Insights.',
          'Add or revise your entry.',
        ],
        requiresRealWorldAction: true,
        libraryCta: kMaatLibraryCtaAddInsight,
        libraryCtaNodeSlug: null,
        libraryCtaLabel: 'Revise your insight',
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
        ],
        optionalSteps: <String>['Share the useful part.'],
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
        purpose:
            'The colophon closed with the scribe\'s mark: who was here, what was completed. Not a flourish — a record. This sitting produces the same mark on the living text.',
        spokenLine: 'Completed correctly; the living text includes this mark.',
        steps: <String>[
          'Write your closing mark: what you read, what you added, and how the Library is richer because of it.',
          'Speak the closing line.',
          'Name reflections, questions, and connections without calling them comments.',
        ],
        optionalSteps: <String>['Share the final line if desired.'],
        sharePromptOnComplete: true,
        sourceNote:
            'The Kemetic colophon was a formal record, not a signature of pride. The scribe\'s name claimed engagement, not authorship. Your colophon does the same: not "I wrote this" but "I was here, I engaged with this, what I added belongs to it now."',
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
            'The indoor tree is growing toward the available light, not toward the actual light. The direction it has been growing is visible in what it has been producing — and in what the heat has been costing.',
        spokenLine:
            'The hot-headed man is like a tree grown in an enclosed space.',
        steps: <String>[
          'Name one situation where heat or reaction drives your actions before the cleared state is available.',
          'Write the specific situation and what generates the heat.',
          'Record what the heat-driven pattern has cost.',
        ],
        sourceNote:
            'Amenemope\'s image is precise: the indoor tree loses its foliage in a moment because it grew toward whatever light was available, not toward the actual sun. The heat-driven response does the same — it goes toward the available outlet, not the right one.',
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
        purpose:
            'The act of setting yourself apart is physical and procedural, not just intentional. The clearing is found by getting out of the enclosure, not by deciding the enclosure is no longer one.',
        spokenLine: 'Set yourself apart before the response forms.',
        steps: <String>[
          'Choose one concrete physical or procedural act that creates space before response: wait one hour, walk outside, write before sending, sleep on it, or consult the day card first.',
          'Do not use "try to be calmer" as the act.',
          'Write it as: Before responding to [situation], I will [specific act].',
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
            'The shade is pleasant — Amenemope is specific. Not merely useful, not protective, but pleasant. The cleared person is a pleasure to be near because their stillness creates a different climate.',
        spokenLine: 'Its shade is pleasant.',
        steps: <String>[
          'Name one person or situation that benefits from your shade.',
          'Write the heat situation where you will continue setting yourself apart.',
          'Record the shade you intend to provide.',
        ],
        optionalSteps: <String>['Share only the one-line commitment.'],
        sourceNote:
            'Amenemope says the temperate person reaches their end in a grove — surrounded by other trees, part of an ecosystem. The shade is not a side effect of the clearing. It is the clearing\'s gift to the people around it.',
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
        purpose:
            'The loss named specifically is the loss that can be searched for. Aset did not search for "what was gone" — she searched for Ausar. The name begins the search. The water is provision for the body while it does this work.',
        spokenLine: 'My brother, for I have searched for you.',
        steps: <String>[
          'Write the name of what was lost. If it is not a person, name it as specifically as one.',
          'Write one sentence about what it gave you that you cannot get elsewhere right now.',
          'Place water nearby.',
          'Drink it slowly after writing the name.',
        ],
        sourceNote:
            'Aset\'s search began with Ausar\'s specific identity — not with the category of loss but with the specific person. The specific name makes the search possible.',
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
        purpose:
            '"I found, I found" — the double testimony. The finding is not the return of what was lost — it is what remains of the love in the places the search visited.',
        spokenLine: 'I found, I found.',
        steps: <String>[
          'Name one thing the search has genuinely found.',
          'Write what remains of the love.',
          'Name where it has gone now.',
        ],
        sourceNote:
            'In the Pyramid Texts, the finding is announced twice: "I found, I found, said Isis; I have found, said Nephthys." The repetition is testimony. What is found by two witnesses has been genuinely found. This sitting names one genuine finding.',
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
        purpose:
            'The Pyramid Texts command to stand is not a demand to stop grieving — it is the voice of love that has searched, found, and now asks the found one to rise. The physical act is the event.',
        spokenLine: 'Stand up for me.',
        steps: <String>[
          'Speak the line before standing.',
          'Stand physically before logging.',
          'Do one small act using a restored capacity: eat something wanted, listen to music, see something beautiful, or speak the name of what was lost to someone safe.',
          'Record the act.',
        ],
        sourceNote:
            'The command to stand in the Pyramid Texts is spoken by those who love the one who is down — Isis\'s command, Nephthys\'s command, Horus\'s command. The standing is invited by love that has found what it was looking for. This sitting receives that invitation and enacts it in one small act of the restored capacity.',
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
        purpose:
            'The body is reporting something right now — not what you think it should be feeling, but what it is actually communicating in this moment. The inventory is not an assessment; it is the act of listening to a report the body has been trying to give.',
        spokenLine: 'Teti is sound because of his body.',
        steps: <String>[
          'Sit or lie down.',
          'Move attention from feet to face.',
          'Write three things the body is communicating right now, without judging or correcting them.',
        ],
        sourceNote:
            '"Teti is sound because of his body." The soundness was located in the physical form — bones assembled, limbs collected, earth on the flesh cleared away. The khat is not the vessel for the other four parts; it is one of the five. This sitting attends to it as such.',
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
          'Write the smallest honest way to provide it in this ten-day section.',
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
        purpose:
            'The anointing was not comfort — it was the mechanism of bodily agency: "you shall make him have control of his body." The Pyramid Texts anointed the forehead first because the forehead is the face the person presents to the world. The body that receives deliberate care is the body the person can actually inhabit.',
        spokenLine: 'Ointment returns attention to the body.',
        steps: <String>[
          'After washing, apply oil, lotion, cream, or water to some part of the body with deliberate attention.',
          'Begin with the forehead if that is available to you.',
          'Record what the act returned to your relationship with the body.',
          'Keep body details private by default.',
        ],
        sourceNote:
            'The Pyramid Texts formula for anointing is specific: "you shall make it pleasant for him, wearing you; you shall make him have control of his body." The oil was the mechanism of control — the body that receives deliberate care is available to the person\'s intention.',
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
        purpose:
            'The Pyramid Texts repeated this command because the rising is the primary physical act of restoration. Not the most dramatic, not the most strenuous — the most fundamental. The record follows the movement.',
        spokenLine:
            'Stand up, repel your earth, clear away your dust, raise yourself.',
        steps: <String>[
          'Speak the line before beginning to move.',
          'Begin moving deliberately for at least 20 minutes before logging.',
          'Walking, stretching, dancing, swimming, lifting, gardening, or physical cleaning all count if sustained and attended to.',
          'Record what the movement returned to the body.',
        ],
        sourceNote:
            'The command to stand appears throughout the Pyramid Texts corpus with the same urgency — it is the foundational physical act that all others depend on. The twenty-minute movement demonstrates that the body can still do what the rite commands.',
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
          'Stand fully at the end.',
          'Record the khat’s current state compared to Day 1.',
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
        purpose:
            'Thutmose did not simply fall asleep near the Sphinx — he placed himself in the shadow deliberately. The preparation creates the conditions for reception.',
        spokenLine: 'I place myself in the shadow of the Great God.',
        steps: <String>[
          'Before sleep, clear the space near your head.',
          'Place one small object there.',
          'Write your oracle question on paper.',
          'Set the paper under or beside the object.',
        ],
        sourceNote:
            'The Dream Stela records that Thutmose rested in the shadow of the Great God — a deliberate spatial act before the dream. The incubation at Kemetic temples followed the same logic: you position yourself within the field of divine presence and wait. The reception chamber is that positioning, made domestic.',
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
        purpose:
            'The oracle consultation was formal — a specific address to a specific presence, with a specific question, in a specific posture of receiving. This invocation follows that form.',
        spokenLine: 'The question is spoken once, then silence receives.',
        steps: <String>[
          'Before lying down, address the deity, principle, Ba, Ka, Ma’at, or divine presence you are asking.',
          'Speak the question once, clearly and completely.',
          'Lie down.',
          'Do not speak again before sleep.',
        ],
        sourceNote:
            'Temple dream incubation was a formal consultation — not a vague hope for inspiration but a specific request made in a specific place with specific preparation. The invocation formalizes the request so that what the night sends can be understood as responsive to it.',
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
        purpose:
            'The dream disperses immediately. Record before anything else — before the phone, before speaking, before the day\'s logic takes over.',
        spokenLine: 'The night record is written before interpretation.',
        steps: <String>[
          'Immediately upon waking, reach for the notebook before the phone or speaking to anyone.',
          'Record images, words, feelings, colors, sequence, and atmosphere.',
          'Do not interpret yet.',
        ],
        sourceNote:
            'The temple dream-reader received the dreamer\'s account immediately upon waking — before the dream had been edited by the waking mind. The dream written in the first thirty seconds is more accurate than the dream reconstructed an hour later.',
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
          'Review all recorded dreams from the first two ten-day sections.',
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
          'Ask what the recurring element does.',
          'Ask what principle it carries.',
          'Ask how it relates to the oracle question.',
          'Ask what action it indicates without treating disturbing dream content as definitive truth.',
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
            'The oracle completes when the action is taken. Thutmose cleared the sand from around the Sphinx. The dream that produces no action was not a consultation — it was a night\'s sleep.',
        spokenLine: 'He awoke and acted.',
        steps: <String>[
          'If the oracle indicated a specific action, take that action before logging this event.',
          'If the oracle stayed unclear, do only the grounded action you can justify before logging this event.',
          'Write the complete oracle record: question, what the night sent, what it indicated or left unclear, and what action was taken.',
        ],
        sourceNote:
            'Thutmose\'s stela records the dream and then records that he commanded the sand to be cleared. The action is what closes the Stela\'s account — not the dream, not the interpretation, but the act taken in response.',
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
    'reflection_guidance': resolveMaatFlowReflectionMetadata(
      flowId: definition.key,
      eventId: 'event-${event.eventNumber}',
      flowTitle: definition.title,
      eventTitle: event.title,
      theme: definition.routingSummary,
      ritualAction: event.purpose,
      reflectionIntent: event.spokenLine,
    ).toJson(),
    if (event.libraryCta != null)
      'library_cta': <String, dynamic>{
        'type': event.libraryCta,
        'node_slug': event.libraryCtaNodeSlug,
        'label': event.libraryCtaLabel ?? 'Add your insight',
      },
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
