import '../calendar/maat_flow_catalog.dart';
import '../calendar/maat_flow_identity.dart';

enum FirstRhythmGoal {
  followTheSky,
  buildDailyDiscipline,
  reflectAndJournal,
  careForTheBody,
  studyAndRemember,
}

enum RhythmTimePreference { dawn, midday, evening, flexible }

enum RhythmDuration { twoMinutes, tenMinutes, twentyMinutes }

class StarterMaatFlow {
  const StarterMaatFlow({
    required this.templateKey,
    required this.title,
    required this.description,
    this.prominent = false,
  });

  final String templateKey;
  final String title;
  final String description;
  final bool prominent;

  StarterMaatFlow copyWith({bool? prominent}) {
    return StarterMaatFlow(
      templateKey: templateKey,
      title: title,
      description: description,
      prominent: prominent ?? this.prominent,
    );
  }
}

class StarterMaatFlowKeys {
  StarterMaatFlowKeys._();

  static final String followTheSky = MaatFlowKind.trackSky.flowKey;
  static final String dawnHouseRite = MaatFlowKind.dawnHouseRite.flowKey;
  static final String theWeighing = MaatFlowKind.theWeighing.flowKey;
  static final String offeringTable = MaatFlowKind.offeringTable.flowKey;
  static final String theTending = MaatFlowKind.theTending.flowKey;
  static final String keptWord = MaatFlowKind.keptWord.flowKey;
  static final String readingHouse = MaatFlowKind.readingHouse.flowKey;
}

class StarterFlowRecommendationService {
  const StarterFlowRecommendationService();

  static final StarterMaatFlow followTheSky = StarterMaatFlow(
    templateKey: StarterMaatFlowKeys.followTheSky,
    title: 'Follow the Sky',
    description: 'Observe cosmic events, seasonal shifts, and sky patterns.',
  );

  static final StarterMaatFlow dawnHouseRite = StarterMaatFlow(
    templateKey: StarterMaatFlowKeys.dawnHouseRite,
    title: 'Dawn House Rite',
    description:
        'Rise with the sun and begin the day with a short act of order, attention, and renewal.',
  );

  static final StarterMaatFlow theWeighing = StarterMaatFlow(
    templateKey: StarterMaatFlowKeys.theWeighing,
    title: 'The Weighing',
    description: 'Put material and spoken records on the scale.',
  );

  static final StarterMaatFlow keptWord = StarterMaatFlow(
    templateKey: StarterMaatFlowKeys.keptWord,
    title: 'The Kept Word',
    description: 'Choose one intention and return to it each day.',
  );

  static final StarterMaatFlow offeringTable = StarterMaatFlow(
    templateKey: StarterMaatFlowKeys.offeringTable,
    title: 'The Offering Table',
    description:
        'Use the calendar to support water, food, rest, and restoration.',
  );

  static final StarterMaatFlow theTending = StarterMaatFlow(
    templateKey: StarterMaatFlowKeys.theTending,
    title: 'The Tending',
    description: 'Find who needs you and do the specific labor of care.',
  );

  static final StarterMaatFlow readingHouse = StarterMaatFlow(
    templateKey: StarterMaatFlowKeys.readingHouse,
    title: 'The Reading House',
    description: 'Build a steady practice of reading and remembering.',
  );

  List<StarterMaatFlow> recommend({
    required FirstRhythmGoal goal,
    required RhythmTimePreference timePreference,
    required RhythmDuration duration,
  }) {
    final recommendations = <StarterMaatFlow>[];

    void add(StarterMaatFlow flow, {bool prominent = false}) {
      if (!isCoreMaatFlowKey(flow.templateKey)) return;
      if (recommendations.any((item) => item.templateKey == flow.templateKey)) {
        return;
      }
      recommendations.add(flow.copyWith(prominent: prominent));
    }

    switch (goal) {
      case FirstRhythmGoal.followTheSky:
        add(followTheSky);
        break;
      case FirstRhythmGoal.buildDailyDiscipline:
        if (timePreference == RhythmTimePreference.dawn) {
          add(dawnHouseRite, prominent: true);
          add(keptWord);
        } else {
          add(dawnHouseRite);
          add(keptWord);
        }
        break;
      case FirstRhythmGoal.reflectAndJournal:
        add(theWeighing);
        add(keptWord);
        break;
      case FirstRhythmGoal.careForTheBody:
        add(offeringTable);
        add(theTending);
        break;
      case FirstRhythmGoal.studyAndRemember:
        add(readingHouse);
        add(keptWord);
        break;
    }

    if (timePreference == RhythmTimePreference.dawn &&
        !recommendations.any(
          (flow) => flow.templateKey == StarterMaatFlowKeys.dawnHouseRite,
        )) {
      add(dawnHouseRite, prominent: true);
    }

    return recommendations.take(3).toList(growable: false);
  }
}
