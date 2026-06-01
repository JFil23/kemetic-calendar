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

  static const String followTheSky = 'track-the-sky';
  static const String riteHouseDawn = 'dawn-house-rite';
  static const String walkTheDecan = 'the-decan-watch';
  static const String keepTheWord = 'the-kept-word';
  static const String bodyInBalance = 'the-tending';
}

class StarterFlowRecommendationService {
  const StarterFlowRecommendationService();

  static const StarterMaatFlow followTheSky = StarterMaatFlow(
    templateKey: StarterMaatFlowKeys.followTheSky,
    title: 'Follow the Sky',
    description: 'Observe cosmic events, seasonal shifts, and sky patterns.',
  );

  static const StarterMaatFlow riteHouseDawn = StarterMaatFlow(
    templateKey: StarterMaatFlowKeys.riteHouseDawn,
    title: 'Rite House Dawn',
    description:
        'Rise with the sun and begin the day with a short act of order, attention, and renewal.',
  );

  static const StarterMaatFlow walkTheDecan = StarterMaatFlow(
    templateKey: StarterMaatFlowKeys.walkTheDecan,
    title: 'Walk the Decan',
    description:
        'Move through a ten-day rhythm of reflection, practice, and completion.',
  );

  static const StarterMaatFlow keepTheWord = StarterMaatFlow(
    templateKey: StarterMaatFlowKeys.keepTheWord,
    title: 'Keep the Word',
    description: 'Choose one intention and return to it each day.',
  );

  static const StarterMaatFlow bodyInBalance = StarterMaatFlow(
    templateKey: StarterMaatFlowKeys.bodyInBalance,
    title: 'Body in Balance',
    description:
        'Use the calendar to support food, movement, rest, and restoration.',
  );

  List<StarterMaatFlow> recommend({
    required FirstRhythmGoal goal,
    required RhythmTimePreference timePreference,
    required RhythmDuration duration,
  }) {
    final recommendations = <StarterMaatFlow>[];

    void add(StarterMaatFlow flow, {bool prominent = false}) {
      if (recommendations.any((item) => item.templateKey == flow.templateKey)) {
        return;
      }
      recommendations.add(flow.copyWith(prominent: prominent));
    }

    switch (goal) {
      case FirstRhythmGoal.followTheSky:
        add(followTheSky);
        add(walkTheDecan);
        break;
      case FirstRhythmGoal.buildDailyDiscipline:
        if (timePreference == RhythmTimePreference.dawn) {
          add(riteHouseDawn, prominent: true);
          add(keepTheWord);
          add(walkTheDecan);
        } else {
          add(walkTheDecan);
          add(keepTheWord);
        }
        break;
      case FirstRhythmGoal.reflectAndJournal:
        add(walkTheDecan);
        add(keepTheWord);
        break;
      case FirstRhythmGoal.careForTheBody:
        add(bodyInBalance);
        add(walkTheDecan);
        break;
      case FirstRhythmGoal.studyAndRemember:
        add(keepTheWord);
        add(walkTheDecan);
        break;
    }

    if (timePreference == RhythmTimePreference.dawn &&
        !recommendations.any(
          (flow) => flow.templateKey == StarterMaatFlowKeys.riteHouseDawn,
        )) {
      add(riteHouseDawn, prominent: true);
    }

    if (!recommendations.any(
      (flow) => flow.templateKey == StarterMaatFlowKeys.walkTheDecan,
    )) {
      add(walkTheDecan);
    }

    return recommendations.take(3).toList(growable: false);
  }
}
