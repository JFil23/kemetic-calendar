import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('Ma’at decan flows register standard 30-day sparse practices', () {
    final keys = kMaatDecanFlowDefinitions
        .map((definition) => definition.key)
        .toList(growable: false);

    expect(keys, hasLength(17));
    expect(
      keys,
      containsAll(<String>[
        kFairHearingFlowKey,
        kHouseOfLifeFlowKey,
        kBoundaryStoneFlowKey,
        kHotepFlowKey,
        kOpenMouthFlowKey,
        kLivingRecordFlowKey,
        kHetHeruFlowKey,
        kTheShoreFlowKey,
        kTheAutobiographyFlowKey,
        kFirstArrangementFlowKey,
        kLivingPatternFlowKey,
        kTrueNameFlowKey,
        kLivingTextFlowKey,
        kClearingFlowKey,
        kWanderingFlowKey,
        kKhatFlowKey,
        kOracleFlowKey,
      ]),
    );

    for (final definition in kMaatDecanFlowDefinitions) {
      expect(definition.events, hasLength(9));
      expect(definition.events.map((event) => event.flowDay), <int>[
        1,
        5,
        9,
        11,
        15,
        19,
        21,
        25,
        29,
      ]);
      expect(definition.behaviorKind, startsWith('maat_'));
      expect(definition.graphNodeSlugs, contains('maat'));
    }
  });

  test('Ma’at decan event payloads keep routing and completion metadata', () {
    final flowStart = DateTime(2026, 5, 16);

    for (final definition in kMaatDecanFlowDefinitions) {
      final first = definition.events.first;
      final schedule = maatDecanFlowScheduleForEvent(
        first,
        flowStart,
        TrackSkyTimeZone.pacific,
      );
      final payload = maatDecanFlowBehaviorPayload(
        definition: definition,
        event: first,
        schedule: schedule,
      );

      expect(payload['kind'], definition.behaviorKind);
      expect(payload['flow_key'], definition.key);
      expect(payload['event_number'], first.eventNumber);
      expect(payload['flow_day'], first.flowDay);
      expect(payload['completion_options'], contains('observed'));
      expect(payload['completion_options'], contains('observed_partly'));
      expect(payload['completion_options'], contains('skipped'));
      expect(payload['reflection_guidance'], isA<Map<String, dynamic>>());
      final reflectionGuidance =
          payload['reflection_guidance'] as Map<String, dynamic>;
      expect(reflectionGuidance['flowId'], definition.key);
      expect(reflectionGuidance['eventId'], 'event-${first.eventNumber}');
      expect(reflectionGuidance['theme'], definition.routingSummary);
      expect(reflectionGuidance['ritualAction'], first.purpose);
      expect(reflectionGuidance['reflectionIntent'], first.spokenLine);
      expect(payload['routing_summary'], definition.routingSummary);
      expect(payload['schedule'], containsPair('timezone', 'pacific'));
    }
  });

  test('Fair Hearing copy keeps hearing and delayed judgment clear', () {
    final fairHearing = maatDecanFlowDefinitionForKey(kFairHearingFlowKey)!;
    final event1 = maatDecanFlowEventByNumber(fairHearing, 1)!;
    final event2 = maatDecanFlowEventByNumber(fairHearing, 2)!;
    final event3 = maatDecanFlowEventByNumber(fairHearing, 3)!;
    final event4 = maatDecanFlowEventByNumber(fairHearing, 4)!;
    final event5 = maatDecanFlowEventByNumber(fairHearing, 5)!;
    final event7 = maatDecanFlowEventByNumber(fairHearing, 7)!;
    final event8 = maatDecanFlowEventByNumber(fairHearing, 8)!;
    final event9 = maatDecanFlowEventByNumber(fairHearing, 9)!;

    expect(event1.purpose, contains('strongest preference'));
    expect(
      event1.steps.last,
      'Circle the situation where your preference is strongest.',
    );
    expect(event2.purpose, startsWith('A named preference'));
    expect(event2.steps, <String>[
      'Return to the most charged situation from Day 1 and name what you prefer to be true.',
      'Name who has more power and who has less.',
      'Name whether your preference aligns with the more powerful party.',
      'Write: My preference in [situation] is [specific view]. I will hold this preference lightly until I have heard fully.',
    ]);
    expect(event3.purpose, contains('second ten-day section'));
    expect(
      event3.steps.first,
      'Choose one situation for the second ten-day section - the one where fairness will require the most from you.',
    );
    expect(
      event3.steps.last,
      'Write: In the second ten-day section, I will give the full fair hearing to [situation]. I will hear [person or side] before I decide.',
    );

    expect(event4.purpose, contains('premature'));
    expect(event4.steps, <String>[
      'Before the hearing, write one sentence about what you expect to hear.',
      'Give the actual hearing.',
      'Do not interrupt.',
      'Do not signal or state your conclusion while the person is still speaking.',
      'Afterward, write one thing you heard that complicated or expanded your view.',
    ]);
    expect(event4.requiresRealWorldAction, isTrue);

    expect(
      event5.steps.first,
      'Test whether you would hear the claim the same way if the parties were reversed.',
    );
    expect(event7.steps, <String>[
      'Ask whether the hearing was full.',
      'Ask whether the measure was consistent.',
      'Ask whether the decision was based on what was heard.',
      'For any no or partial answer, name exactly what was missing.',
      'If something was not fully heard, name whether an acknowledgment is owed.',
    ]);
    expect(
      event8.steps.last,
      'Name what a fair hearing would require before the closing sitting.',
    );
    expect(event9.steps, contains('Speak only the lines that are true.'));
    expect(event9.steps, contains('Say, if true: I heard fully.'));
    expect(event9.steps, contains('Say, if true: I applied the same measure.'));
    expect(
      event9.steps,
      contains('Say, if true: I pronounced a decision clearly.'),
    );
    expect(
      event9.steps.any((step) => step.contains('I heard fully;')),
      isFalse,
    );
  });

  test('Fair Hearing words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];
    final fairHearing = maatDecanFlowDefinitionForKey(kFairHearingFlowKey)!;

    for (final event in fairHearing.events) {
      for (final pattern in _fairHearingWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Fair Hearing steps keep rationale and optional sharing out', () {
    final issues = <String>[];
    final fairHearing = maatDecanFlowDefinitionForKey(kFairHearingFlowKey)!;

    for (final event in fairHearing.events) {
      final requiredSteps = event.steps.toSet();
      for (final step in event.steps) {
        if (_fairHearingRequiredStepRationalePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
        if (_fairHearingRequiredStepOptionalSharingPattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
      for (final optionalStep in event.optionalSteps) {
        if (requiredSteps.contains(optionalStep)) {
          issues.add('Event ${event.eventNumber}: $optionalStep');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Living Text emits library CTA only on Events 4 and 7', () {
    final definition = maatDecanFlowDefinitionForKey(kLivingTextFlowKey)!;
    final flowStart = DateTime(2026, 5, 16);

    Map<String, dynamic> payloadForEvent(int eventNumber) {
      final event = maatDecanFlowEventByNumber(definition, eventNumber)!;
      final schedule = maatDecanFlowScheduleForEvent(
        event,
        flowStart,
        TrackSkyTimeZone.pacific,
      );
      return maatDecanFlowBehaviorPayload(
        definition: definition,
        event: event,
        schedule: schedule,
      );
    }

    expect(payloadForEvent(3).containsKey('library_cta'), isFalse);
    expect(payloadForEvent(5).containsKey('library_cta'), isFalse);
    expect(payloadForEvent(6).containsKey('library_cta'), isFalse);

    expect(payloadForEvent(4)['library_cta'], <String, dynamic>{
      'type': kMaatLibraryCtaAddInsight,
      'node_slug': null,
      'label': 'Add your insight',
    });
    expect(payloadForEvent(7)['library_cta'], <String, dynamic>{
      'type': kMaatLibraryCtaAddInsight,
      'node_slug': null,
      'label': 'Revise your insight',
    });
  });

  test('Living Text copy separates optional actions and save/share sequence', () {
    final livingText = maatDecanFlowDefinitionForKey(kLivingTextFlowKey)!;
    final event2 = maatDecanFlowEventByNumber(livingText, 2)!;
    final event3 = maatDecanFlowEventByNumber(livingText, 3)!;
    final event4 = maatDecanFlowEventByNumber(livingText, 4)!;
    final event5 = maatDecanFlowEventByNumber(livingText, 5)!;
    final event6 = maatDecanFlowEventByNumber(livingText, 6)!;
    final event7 = maatDecanFlowEventByNumber(livingText, 7)!;
    final event8 = maatDecanFlowEventByNumber(livingText, 8)!;
    final event9 = maatDecanFlowEventByNumber(livingText, 9)!;

    expect(event2.steps, <String>[
      'Choose the Library entry you keep circling or dismissing.',
      'Read it fully.',
      'Write what the avoidance was about.',
    ]);
    expect(event2.optionalSteps, <String>[
      'Add one question the avoidance raises.',
    ]);

    expect(event3.purpose, contains('unanswered question'));
    expect(event3.steps, <String>[
      'Choose an important entry you do not fully understand.',
      'Open the node and tap Your Insights.',
      'Write the exact unclear passage or concept as a question.',
      'Save it to the node so the gap remains visible in your own record.',
    ]);

    expect(event4.steps.last, 'Save it to the node.');
    expect(event4.optionalSteps, <String>[
      'If it belongs to others, use Post to share it on your profile.',
    ]);

    expect(event5.purpose, contains('tappable in the living text'));
    expect(event5.steps, <String>[
      'Find two Library entries that connect in a way the app does not already show.',
      'Open Your Insights on one of the two nodes.',
      'Write and save the connection in one or two sentences.',
      'Use Link Insight to highlight the phrase that points toward the second node and select the target node.',
    ]);

    expect(event6.steps, <String>[
      'Choose an entry that feels incomplete.',
      'Open the node and tap Your Insights.',
      'Name the missing question or modern situation the entry does not yet address.',
      'Save it to the node.',
    ]);
    expect(event6.optionalSteps, <String>[
      'Share it if it should be available to the next person who finds the same gap.',
    ]);

    expect(event7.purpose, contains('worth leaving in the record'));
    expect(event7.steps, <String>[
      'Open the node you chose on Day 1.',
      'Return to Your Insights.',
      'Add or revise your entry.',
    ]);

    expect(event8.optionalSteps, <String>['Share the useful part.']);
    expect(
      event9.spokenLine,
      'Completed correctly; the living text includes this mark.',
    );
    expect(event9.steps, <String>[
      'Write your closing mark: what you read, what you added, and how the Library is richer because of it.',
      'Speak the closing line.',
      'Name reflections, questions, and connections without calling them comments.',
    ]);
    expect(event9.optionalSteps, <String>['Share the final line if desired.']);
    expect(event9.sharePromptOnComplete, isTrue);
  });

  test('Living Text words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];
    final livingText = maatDecanFlowDefinitionForKey(kLivingTextFlowKey)!;

    for (final event in livingText.events) {
      for (final pattern in _livingTextWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test(
    'Living Text required steps keep rationale and optional sharing out',
    () {
      final issues = <String>[];
      final livingText = maatDecanFlowDefinitionForKey(kLivingTextFlowKey)!;

      for (final event in livingText.events) {
        final requiredSteps = event.steps.toSet();
        for (final step in event.steps) {
          if (_livingTextRequiredStepRationalePattern.hasMatch(step)) {
            issues.add('Event ${event.eventNumber}: $step');
          }
          if (_livingTextRequiredStepOptionalPattern.hasMatch(step)) {
            issues.add('Event ${event.eventNumber}: $step');
          }
        }
        for (final optionalStep in event.optionalSteps) {
          if (requiredSteps.contains(optionalStep)) {
            issues.add('Event ${event.eventNumber}: $optionalStep');
          }
        }
      }

      expect(issues, isEmpty);
    },
  );

  test('House of Life copy keeps knowledge actions and truth checks clear', () {
    final houseOfLife = maatDecanFlowDefinitionForKey(kHouseOfLifeFlowKey)!;
    final event1 = maatDecanFlowEventByNumber(houseOfLife, 1)!;
    final event2 = maatDecanFlowEventByNumber(houseOfLife, 2)!;
    final event3 = maatDecanFlowEventByNumber(houseOfLife, 3)!;
    final event4 = maatDecanFlowEventByNumber(houseOfLife, 4)!;
    final event5 = maatDecanFlowEventByNumber(houseOfLife, 5)!;
    final event7 = maatDecanFlowEventByNumber(houseOfLife, 7)!;
    final event8 = maatDecanFlowEventByNumber(houseOfLife, 8)!;
    final event9 = maatDecanFlowEventByNumber(houseOfLife, 9)!;

    expect(event1.purpose, contains('weakest discipline'));
    expect(event1.steps.last, 'Name the weakest of the three.');
    expect(event2.purpose, startsWith('Accuracy begins'));
    expect(
      event3.steps.first,
      'Write: In the second ten-day section, I will practice writing, reciting, and seeking on [subject].',
    );

    expect(event4.purpose, contains('specific gap'));
    expect(event4.steps, <String>[
      'Write one complete account of something you have learned, as if the reader cannot ask you to clarify.',
      'Read it back and correct anything that depends on you standing beside the text.',
      'Name the specific gap the writing revealed in your understanding.',
    ]);

    expect(event5.purpose, contains('Collapse is useful data'));
    expect(event5.steps, <String>[
      'Speak one concept or principle from memory, accurately and in order.',
      'Mark what stays fluent when spoken.',
      'Mark what collapses when spoken.',
      'If something collapses, write the exact sentence, term, or sequence that needs repair.',
      'If someone asks a question you cannot answer accurately, write it as the next thing to learn.',
    ]);

    expect(event7.purpose, startsWith('Transmission requires'));
    expect(event8.requiresRealWorldAction, isTrue);
    expect(event8.purpose, contains('living knowledge'));
    expect(event8.steps, <String>[
      'If the transmission happened, write what you gave and to whom.',
      'Ask what the recipient understood and what confused them.',
      'If the transmission has not happened, do it today.',
      'If it cannot happen today, name exactly when before the closing sitting.',
    ]);

    expect(event9.steps, contains('Speak only the lines that are true.'));
    expect(event9.steps, contains('Say, if true: I wrote.'));
    expect(event9.steps, contains('Say, if true: I recited.'));
    expect(event9.steps, contains('Say, if true: I sought.'));
    expect(event9.steps, contains('Say, if true: I transmitted.'));
    expect(
      event9.steps,
      contains('Say, if true: What I know is more accurate.'),
    );
    expect(
      event9.steps.any((step) => step.contains('I wrote; I recited')),
      isFalse,
    );
  });

  test(
    'House of Life words fields do not contain stage-direction wrappers',
    () {
      final issues = <String>[];
      final houseOfLife = maatDecanFlowDefinitionForKey(kHouseOfLifeFlowKey)!;

      for (final event in houseOfLife.events) {
        for (final pattern in _houseOfLifeWordsStageDirectionPatterns) {
          if (pattern.hasMatch(event.spokenLine)) {
            issues.add(
              'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
            );
          }
        }
      }

      expect(issues, isEmpty);
    },
  );

  test('House of Life steps keep rationale and optional sharing out', () {
    final issues = <String>[];
    final houseOfLife = maatDecanFlowDefinitionForKey(kHouseOfLifeFlowKey)!;

    for (final event in houseOfLife.events) {
      final requiredSteps = event.steps.toSet();
      for (final step in event.steps) {
        if (_houseOfLifeRequiredStepRationalePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
        if (_houseOfLifeRequiredStepOptionalSharingPattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
      for (final optionalStep in event.optionalSteps) {
        if (requiredSteps.contains(optionalStep)) {
          issues.add('Event ${event.eventNumber}: $optionalStep');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Ma’at decan closing events expose their special completion labels', () {
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kFairHearingFlowKey)!,
        6,
      )?.extraCompletionStatusLabels,
      containsPair('decision_pronounced', 'Decision pronounced'),
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kHouseOfLifeFlowKey,
      )!.events.last.extraCompletionStatusLabels,
      containsPair('transmitted', 'Transmitted'),
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kBoundaryStoneFlowKey,
      )!.events.last.extraCompletionStatusLabels,
      containsPair('stones_placed', 'Stones placed'),
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kHotepFlowKey,
      )!.events.last.extraCompletionStatusLabels,
      containsPair('cooled', 'Cooled'),
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kOpenMouthFlowKey,
      )!.events.last.extraCompletionStatusLabels,
      containsPair('spoken', 'Spoken'),
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kLivingRecordFlowKey,
      )!.events.last.extraCompletionStatusLabels,
      containsPair('record_complete', 'Record complete'),
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kHetHeruFlowKey)!,
        5,
      )?.extraCompletionStatusLabels,
      containsPair('beer_poured', 'Beer poured'),
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kHetHeruFlowKey,
      )!.events.last.extraCompletionStatusLabels,
      containsPair('golden_one_present', 'Golden One present'),
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kTheShoreFlowKey)!,
        5,
      )?.extraCompletionStatusLabels,
      containsPair('exchanged', 'Exchanged'),
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kTheAutobiographyFlowKey)!,
        7,
      )?.extraCompletionStatusLabels,
      containsPair('autobiography_written', 'Autobiography written'),
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kTheAutobiographyFlowKey,
      )!.events.last.extraCompletionStatusLabels,
      containsPair('remaining_work_named', 'Remaining work named'),
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kFirstArrangementFlowKey)!,
        4,
      )?.extraCompletionStatusLabels,
      containsPair('cleared', 'Cleared'),
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kFirstArrangementFlowKey)!,
        6,
      )?.extraCompletionStatusLabels,
      containsPair('arranged', 'Arranged'),
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kFirstArrangementFlowKey,
      )!.events.last.extraCompletionStatusLabels,
      containsPair('maintenance_established', 'Maintenance established'),
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kLivingPatternFlowKey)!,
        8,
      )?.extraCompletionStatusLabels,
      containsPair('lesson_extracted', 'Lesson extracted'),
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kLivingPatternFlowKey,
      )!.events.last.extraCompletionStatusLabels,
      containsPair('acted', 'Acted'),
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kTrueNameFlowKey)!,
        8,
      )?.extraCompletionStatusLabels,
      containsPair('declared', 'Declared'),
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kLivingTextFlowKey,
      )!.events.last.extraCompletionStatusLabels,
      containsPair('colophon_written', 'Colophon written'),
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kClearingFlowKey)!,
        5,
      )?.extraCompletionStatusLabels,
      containsPair('from_the_clearing', 'from the clearing'),
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kWanderingFlowKey,
      )!.events.expand((event) => event.extraCompletionStatusLabels.keys),
      isEmpty,
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kKhatFlowKey)!,
        7,
      )?.extraCompletionStatusLabels,
      containsPair('moved', 'Moved'),
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kOracleFlowKey,
      )!.events.last.extraCompletionStatusLabels,
      containsPair('oracle_complete', 'Oracle complete'),
    );
  });

  test('new Ma’at flow events keep direct event notes and action gates', () {
    for (final definition in <MaatDecanFlowDefinition>[
      maatDecanFlowDefinitionForKey(kTheShoreFlowKey)!,
      maatDecanFlowDefinitionForKey(kTheAutobiographyFlowKey)!,
      maatDecanFlowDefinitionForKey(kFirstArrangementFlowKey)!,
      maatDecanFlowDefinitionForKey(kLivingPatternFlowKey)!,
      maatDecanFlowDefinitionForKey(kTrueNameFlowKey)!,
      maatDecanFlowDefinitionForKey(kLivingTextFlowKey)!,
      maatDecanFlowDefinitionForKey(kClearingFlowKey)!,
      maatDecanFlowDefinitionForKey(kWanderingFlowKey)!,
      maatDecanFlowDefinitionForKey(kKhatFlowKey)!,
      maatDecanFlowDefinitionForKey(kOracleFlowKey)!,
    ]) {
      for (final event in definition.events) {
        expect(event.steps.length, inInclusiveRange(2, 4));
        expect(event.sourceNote?.length ?? 0, lessThan(700));
      }
    }

    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kTheShoreFlowKey)!,
        5,
      )!.requiresRealWorldAction,
      isTrue,
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kLivingPatternFlowKey,
      )!.events.last.requiresRealWorldAction,
      isTrue,
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kTrueNameFlowKey,
      )!.events.last.requiresRealWorldAction,
      isTrue,
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kClearingFlowKey)!,
        5,
      )!.requiresRealWorldAction,
      isTrue,
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kWanderingFlowKey,
      )!.events.last.requiresRealWorldAction,
      isTrue,
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kKhatFlowKey)!,
        7,
      )!.requiresRealWorldAction,
      isTrue,
    );
    expect(
      maatDecanFlowDefinitionForKey(
        kOracleFlowKey,
      )!.events.last.requiresRealWorldAction,
      isTrue,
    );
  });

  test('upgraded spoken-line delivery beats are stored', () {
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kTrueNameFlowKey)!,
        8,
      )!.spokenLine,
      'I am pure. I am pure. I am pure. I am pure.',
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kWanderingFlowKey)!,
        9,
      )!.spokenLine,
      'Stand up for me.',
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kKhatFlowKey)!,
        7,
      )!.spokenLine,
      'Stand up, repel your earth, clear away your dust, raise yourself.',
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kHotepFlowKey)!,
        4,
      )!.spokenLine,
      'Do not go to bed fearing tomorrow. God is success; man is failure.',
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kLivingTextFlowKey)!,
        9,
      )!.spokenLine,
      'Completed correctly; the living text includes this mark.',
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kLivingPatternFlowKey)!,
        8,
      )!.spokenLine,
      'Watching [subject] for thirty days taught me [lesson].',
    );
  });

  test('Living Pattern copy keeps principle and lesson sequence explicit', () {
    final livingPattern = maatDecanFlowDefinitionForKey(kLivingPatternFlowKey)!;
    final event6 = maatDecanFlowEventByNumber(livingPattern, 6)!;
    final event8 = maatDecanFlowEventByNumber(livingPattern, 8)!;
    final event9 = maatDecanFlowEventByNumber(livingPattern, 9)!;

    expect(event6.steps, <String>[
      'Write one sentence: [Subject] demonstrates: [principle].',
      'Reject any principle not directly traceable to a specific behavior you observed and recorded.',
    ]);
    expect(
      event6.steps.where((step) => step.contains('demonstrates')),
      hasLength(1),
    );
    expect(
      event6.steps.where((step) => step.startsWith('Reject')),
      hasLength(1),
    );

    expect(
      event8.spokenLine,
      'Watching [subject] for thirty days taught me [lesson].',
    );
    expect(event8.steps, <String>[
      'Speak the lesson aloud once before writing it.',
      'Write one actionable lesson: Watching ___ taught me ___.',
      'Keep it tied to the observed pattern.',
    ]);
    expect(event8.optionalSteps, <String>['Share the lesson to the feed.']);
    expect(event8.sharePromptOnComplete, isTrue);
    expect(
      event8.extraCompletionStatusLabels,
      containsPair('lesson_extracted', 'Lesson extracted'),
    );

    expect(
      event9.purpose,
      'The lesson enters the record only when it produces one action before logging.',
    );
  });

  test(
    'Living Pattern words fields do not contain stage-direction wrappers',
    () {
      final issues = <String>[];
      final livingPattern = maatDecanFlowDefinitionForKey(
        kLivingPatternFlowKey,
      )!;

      for (final event in livingPattern.events) {
        for (final pattern in _livingPatternWordsStageDirectionPatterns) {
          if (pattern.hasMatch(event.spokenLine)) {
            issues.add(
              'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
            );
          }
        }
      }

      expect(issues, isEmpty);
    },
  );

  test('Living Pattern steps keep rationale and optional actions out', () {
    final issues = <String>[];
    final livingPattern = maatDecanFlowDefinitionForKey(kLivingPatternFlowKey)!;

    for (final event in livingPattern.events) {
      final requiredSteps = event.steps.toSet();
      for (final step in event.steps) {
        if (step.startsWith('Optionally')) {
          issues.add('Event ${event.eventNumber}: $step');
        }
        if (_livingPatternRationalePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
      for (final optionalStep in event.optionalSteps) {
        if (requiredSteps.contains(optionalStep)) {
          issues.add('Event ${event.eventNumber}: $optionalStep');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Living Record copy keeps journal and guidance actions clear', () {
    final livingRecord = maatDecanFlowDefinitionForKey(kLivingRecordFlowKey)!;
    final event1 = maatDecanFlowEventByNumber(livingRecord, 1)!;
    final event2 = maatDecanFlowEventByNumber(livingRecord, 2)!;
    final event3 = maatDecanFlowEventByNumber(livingRecord, 3)!;
    final event4 = maatDecanFlowEventByNumber(livingRecord, 4)!;
    final event5 = maatDecanFlowEventByNumber(livingRecord, 5)!;
    final event6 = maatDecanFlowEventByNumber(livingRecord, 6)!;
    final event7 = maatDecanFlowEventByNumber(livingRecord, 7)!;
    final event8 = maatDecanFlowEventByNumber(livingRecord, 8)!;
    final event9 = maatDecanFlowEventByNumber(livingRecord, 9)!;

    expect(event1.steps.last, 'Speak the line.');
    expect(event2.purpose, startsWith('One node grounds'));
    expect(event3.purpose, startsWith('A scheduled act gives'));
    expect(event4.purpose, contains('specific record is more useful'));
    expect(event4.purpose, contains('entry has been recognized'));
    expect(event4.steps, <String>[
      'Open the journal.',
      'Write at least three substantive sentences about what this decan has meant, what you actually did in Ma\'at, what resisted the period, and one unanswered question.',
      'Notice any badges generated from the entry.',
    ]);
    expect(
      event4.steps.where((step) => step.contains('at least three')),
      hasLength(1),
    );
    expect(event5.purpose, startsWith('The record becomes communal'));
    expect(event6.purpose, startsWith('The alignment grid functions'));
    expect(event7.purpose, startsWith('Flow Studio functions'));
    expect(event8.steps, <String>[
      'Open the Ma\'at guidance card, a recent guidance delivery, or the decan opening.',
      'Name the pattern it identified and the one act it recommends.',
      'If possible, complete the act today.',
      'If not, write what the right response is.',
      'Write: Ma\'at guidance, Day 25: [what it said]. My response: [what I did or decided].',
    ]);
    expect(
      event9.purpose,
      'The final journal entry and physical closing line bound the decan account so it can be returned to as a measured record.',
    );
  });

  test(
    'Living Record words fields do not contain stage-direction wrappers',
    () {
      final issues = <String>[];
      final livingRecord = maatDecanFlowDefinitionForKey(kLivingRecordFlowKey)!;

      for (final event in livingRecord.events) {
        for (final pattern in _livingRecordWordsStageDirectionPatterns) {
          if (pattern.hasMatch(event.spokenLine)) {
            issues.add(
              'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
            );
          }
        }
      }

      expect(issues, isEmpty);
    },
  );

  test('Living Record steps keep rationale and optional actions out', () {
    final issues = <String>[];
    final livingRecord = maatDecanFlowDefinitionForKey(kLivingRecordFlowKey)!;

    for (final event in livingRecord.events) {
      final requiredSteps = event.steps.toSet();
      for (final step in event.steps) {
        if (step.startsWith('Optionally')) {
          issues.add('Event ${event.eventNumber}: $step');
        }
        if (_livingRecordRationalePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
      for (final optionalStep in event.optionalSteps) {
        if (requiredSteps.contains(optionalStep)) {
          issues.add('Event ${event.eventNumber}: $optionalStep');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('True Name copy keeps posture and declaration sequence explicit', () {
    final trueName = maatDecanFlowDefinitionForKey(kTrueNameFlowKey)!;
    final event7 = maatDecanFlowEventByNumber(trueName, 7)!;
    final event8 = maatDecanFlowEventByNumber(trueName, 8)!;

    expect(event7.purpose, contains('imagination must be specific'));
    expect(event7.steps, <String>[
      'Choose one specific current situation where the false account operates, not a general pattern.',
      'Imagine acting from the accurate account in specific detail.',
      'Write what that looks like before you attempt it.',
    ]);

    expect(event8.spokenLine, 'I am pure. I am pure. I am pure. I am pure.');
    expect(event8.steps, <String>[
      'Stand before speaking. The declaration is not made while seated.',
      'Speak the accurate account aloud, then speak the evidence.',
      'Say the closing declaration.',
      'Record what it felt like.',
    ]);
    expect(event8.requiresRealWorldAction, isTrue);
    expect(
      event8.extraCompletionStatusLabels,
      containsPair('declared', 'Declared'),
    );
  });

  test('True Name words fields do not contain posture wrappers', () {
    final issues = <String>[];
    final trueName = maatDecanFlowDefinitionForKey(kTrueNameFlowKey)!;

    for (final event in trueName.events) {
      for (final pattern in _trueNameWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('True Name steps keep source-note phrases out of actions', () {
    final issues = <String>[];
    final trueName = maatDecanFlowDefinitionForKey(kTrueNameFlowKey)!;

    for (final event in trueName.events) {
      for (final step in event.steps) {
        if (_trueNameSourceNotePhrasePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('True Name optional steps do not duplicate required steps', () {
    final issues = <String>[];
    final trueName = maatDecanFlowDefinitionForKey(kTrueNameFlowKey)!;

    for (final event in trueName.events) {
      final requiredSteps = event.steps.toSet();
      for (final step in event.steps) {
        if (step.startsWith('Optional:')) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
      for (final optionalStep in event.optionalSteps) {
        if (requiredSteps.contains(optionalStep)) {
          issues.add('Event ${event.eventNumber}: $optionalStep');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Het-Heru copy keeps optional and truth-check actions explicit', () {
    final hetHeru = maatDecanFlowDefinitionForKey(kHetHeruFlowKey)!;
    final event1 = maatDecanFlowEventByNumber(hetHeru, 1)!;
    final event6 = maatDecanFlowEventByNumber(hetHeru, 6)!;
    final event9 = maatDecanFlowEventByNumber(hetHeru, 9)!;

    expect(event1.steps, <String>[
      'Read the core story: Ra sent the Eye as Sekhmet, she kept destroying after he called her back, and the gods flooded the field with red beer.',
      'Name your Sekhmet: resentment, ambition, grief, perfectionism, anger, or another force with its own momentum.',
      'Write: My Sekhmet is [specific thing]. It was sent out for [wound or purpose]. It is still going because [what sustains it].',
    ]);
    expect(event1.optionalSteps, <String>[
      'Name the beautiful thing this force used to make before it went too far.',
    ]);

    expect(event6.steps, <String>[
      'Return to the Sekhmet from Day 1. Has it become less self-perpetuating?',
      'Write what actually happened, not what you hoped would happen.',
      'If it is still active, name what more beer would look like.',
      'If something shifted, name the first sign of Het-Heru.',
    ]);

    expect(
      event9.spokenLine,
      'Het-Heru, Mistress of Joy. The Eye that was sent out has returned, not defeated but transformed. The dance continues.',
    );
    expect(event9.steps, <String>[
      'Return to Day 1 and write what changed in how that force is operating.',
      'Name the beer you poured and the Het-Heru quality that emerged from the same source as the Sekhmet.',
      'Speak only the lines that are true.',
      'Say, if true: I named the Sekhmet.',
      'Say, if true: I found what it sought.',
      'Say, if true: I poured the beer.',
      'Say, if true: I let music reach me.',
      'Say, if true: I shared a feast.',
      'Do one beautiful thing now: look, listen, smell, touch, or move with deliberate delight.',
    ]);
    expect(event9.requiresRealWorldAction, isTrue);
    expect(
      event9.extraCompletionStatusLabels,
      containsPair('golden_one_present', 'Golden One present'),
    );
  });

  test('Het-Heru words fields do not contain truth-check wrappers', () {
    final issues = <String>[];
    final hetHeru = maatDecanFlowDefinitionForKey(kHetHeruFlowKey)!;

    for (final event in hetHeru.events) {
      for (final pattern in _hetHeruWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Het-Heru steps keep source-note phrases out of actions', () {
    final issues = <String>[];
    final hetHeru = maatDecanFlowDefinitionForKey(kHetHeruFlowKey)!;

    for (final event in hetHeru.events) {
      for (final step in event.steps) {
        if (_hetHeruSourceNotePhrasePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Het-Heru optional steps do not duplicate required steps', () {
    final issues = <String>[];
    final hetHeru = maatDecanFlowDefinitionForKey(kHetHeruFlowKey)!;

    for (final event in hetHeru.events) {
      final requiredSteps = event.steps.toSet();
      for (final step in event.steps) {
        if (step.startsWith('Optional:')) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
      for (final optionalStep in event.optionalSteps) {
        if (requiredSteps.contains(optionalStep)) {
          issues.add('Event ${event.eventNumber}: $optionalStep');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Clearing copy keeps action gates and optional sharing explicit', () {
    final clearing = maatDecanFlowDefinitionForKey(kClearingFlowKey)!;
    final event4 = maatDecanFlowEventByNumber(clearing, 4)!;
    final event5 = maatDecanFlowEventByNumber(clearing, 5)!;
    final event9 = maatDecanFlowEventByNumber(clearing, 9)!;

    expect(event4.steps, <String>[
      'Choose one concrete physical or procedural act that creates space before response: wait one hour, walk outside, write before sending, sleep on it, or consult the day card first.',
      'Do not use "try to be calmer" as the act.',
      'Write it as: Before responding to [situation], I will [specific act].',
      'Write when you will use it and what heat situation it interrupts.',
    ]);

    expect(event5.spokenLine, 'The clearing acts without heat.');
    expect(event5.steps, <String>[
      'Take one real action from the cleared state before logging.',
      'Record the situation and what the heat response would have been.',
      'Write what you did instead and what changed.',
    ]);
    expect(event5.requiresRealWorldAction, isTrue);
    expect(
      event5.extraCompletionStatusLabels,
      containsPair('from_the_clearing', 'from the clearing'),
    );

    expect(event9.steps, <String>[
      'Name one person or situation that benefits from your shade.',
      'Write the heat situation where you will continue setting yourself apart.',
      'Record the shade you intend to provide.',
    ]);
    expect(event9.optionalSteps, <String>[
      'Share only the one-line commitment.',
    ]);
    expect(event9.sharePromptOnComplete, isTrue);
  });

  test('Clearing words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];
    final clearing = maatDecanFlowDefinitionForKey(kClearingFlowKey)!;

    for (final event in clearing.events) {
      for (final pattern in _clearingWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Clearing steps keep source-note phrases out of actions', () {
    final issues = <String>[];
    final clearing = maatDecanFlowDefinitionForKey(kClearingFlowKey)!;

    for (final event in clearing.events) {
      for (final step in event.steps) {
        if (_clearingSourceNotePhrasePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Clearing optional steps do not duplicate required steps', () {
    final issues = <String>[];
    final clearing = maatDecanFlowDefinitionForKey(kClearingFlowKey)!;

    for (final event in clearing.events) {
      final requiredSteps = event.steps.toSet();
      for (final step in event.steps) {
        if (step.startsWith('Optional:')) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
      for (final optionalStep in event.optionalSteps) {
        if (requiredSteps.contains(optionalStep)) {
          issues.add('Event ${event.eventNumber}: $optionalStep');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Wandering copy keeps closing instructions in steps', () {
    final wandering = maatDecanFlowDefinitionForKey(kWanderingFlowKey)!;
    final event1 = maatDecanFlowEventByNumber(wandering, 1)!;
    final event9 = maatDecanFlowEventByNumber(wandering, 9)!;

    expect(event1.purpose, contains('water is provision'));
    expect(event1.steps, <String>[
      'Write the name of what was lost. If it is not a person, name it as specifically as one.',
      'Write one sentence about what it gave you that you cannot get elsewhere right now.',
      'Place water nearby.',
      'Drink it slowly after writing the name.',
    ]);

    expect(event9.spokenLine, 'Stand up for me.');
    expect(event9.steps, <String>[
      'Speak the line before standing.',
      'Stand physically before logging.',
      'Do one small act using a restored capacity: eat something wanted, listen to music, see something beautiful, or speak the name of what was lost to someone safe.',
      'Record the act.',
    ]);
    expect(event9.requiresRealWorldAction, isTrue);
    expect(event9.sharePromptOnComplete, isFalse);
  });

  test('Wandering words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];
    final wandering = maatDecanFlowDefinitionForKey(kWanderingFlowKey)!;

    for (final event in wandering.events) {
      for (final pattern in _wanderingWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test(
    'Wandering steps keep rationale and source-note phrases out of actions',
    () {
      final issues = <String>[];
      final wandering = maatDecanFlowDefinitionForKey(kWanderingFlowKey)!;

      for (final event in wandering.events) {
        for (final step in event.steps) {
          if (_wanderingRationalePhrasePattern.hasMatch(step)) {
            issues.add('Event ${event.eventNumber}: $step');
          }
        }
      }

      expect(issues, isEmpty);
    },
  );

  test('Wandering optional steps do not duplicate required steps', () {
    final issues = <String>[];
    final wandering = maatDecanFlowDefinitionForKey(kWanderingFlowKey)!;

    for (final event in wandering.events) {
      final requiredSteps = event.steps.toSet();
      for (final optionalStep in event.optionalSteps) {
        if (requiredSteps.contains(optionalStep)) {
          issues.add('Event ${event.eventNumber}: $optionalStep');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('First Arrangement copy keeps removal guardrails and actions explicit', () {
    final arrangement = maatDecanFlowDefinitionForKey(
      kFirstArrangementFlowKey,
    )!;
    final event4 = maatDecanFlowEventByNumber(arrangement, 4)!;
    final event7 = maatDecanFlowEventByNumber(arrangement, 7)!;
    final event8 = maatDecanFlowEventByNumber(arrangement, 8)!;
    final event9 = maatDecanFlowEventByNumber(arrangement, 9)!;

    expect(event4.purpose, contains('hallway pile'));
    expect(event4.steps, <String>[
      'Physically remove every item marked "does not belong here."',
      'Put each item where it truly belongs, not in the hallway or a corner of the same room.',
      'If it belongs nowhere you inhabit, discard it or release it.',
      'Record what remains.',
    ]);
    expect(event4.requiresRealWorldAction, isTrue);
    expect(
      event4.extraCompletionStatusLabels,
      containsPair('cleared', 'Cleared'),
    );

    expect(event7.steps, <String>[
      'Open air into the space.',
      'Wipe surfaces with water.',
      'Add one intentional scent.',
      'Record the state of the space after purification.',
    ]);

    expect(event8.steps, <String>[
      'Use the space for its main purpose.',
      'Do not adjust while using it.',
      'Afterward, write what was easier.',
      'Write what remains misaligned and what the space communicated.',
    ]);

    expect(
      event9.purpose,
      contains('second ten-day section returns to disorder'),
    );
    expect(event9.steps, <String>[
      'Write the maintenance practice as a specific instruction: When I [enter/leave] this space each [morning/evening], I will [specific acts].',
      'Include how the practice returns objects.',
      'Include how the practice clears surfaces and performs one sensory act of purification.',
      'Share only the one-sentence statement of what the space now communicates.',
    ]);
    expect(
      event9.extraCompletionStatusLabels,
      containsPair('maintenance_established', 'Maintenance established'),
    );
  });

  test(
    'First Arrangement words fields do not contain stage-direction wrappers',
    () {
      final issues = <String>[];
      final arrangement = maatDecanFlowDefinitionForKey(
        kFirstArrangementFlowKey,
      )!;

      for (final event in arrangement.events) {
        for (final pattern in _firstArrangementWordsStageDirectionPatterns) {
          if (pattern.hasMatch(event.spokenLine)) {
            issues.add(
              'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
            );
          }
        }
      }

      expect(issues, isEmpty);
    },
  );

  test(
    'First Arrangement steps keep rationale out without losing guardrails',
    () {
      final issues = <String>[];
      final arrangement = maatDecanFlowDefinitionForKey(
        kFirstArrangementFlowKey,
      )!;

      for (final event in arrangement.events) {
        for (final step in event.steps) {
          if (_firstArrangementRationalePattern.hasMatch(step)) {
            issues.add('Event ${event.eventNumber}: $step');
          }
        }
      }

      expect(issues, isEmpty);
      expect(
        maatDecanFlowEventByNumber(arrangement, 4)!.steps,
        contains(
          'Put each item where it truly belongs, not in the hallway or a corner of the same room.',
        ),
      );
    },
  );

  test('First Arrangement optional steps do not duplicate required steps', () {
    final issues = <String>[];
    final arrangement = maatDecanFlowDefinitionForKey(
      kFirstArrangementFlowKey,
    )!;

    for (final event in arrangement.events) {
      final requiredSteps = event.steps.toSet();
      for (final optionalStep in event.optionalSteps) {
        if (requiredSteps.contains(optionalStep)) {
          issues.add('Event ${event.eventNumber}: $optionalStep');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Khat copy keeps words speakable and movement directions in steps', () {
    final khat = maatDecanFlowDefinitionForKey(kKhatFlowKey)!;
    final event1 = maatDecanFlowEventByNumber(khat, 1)!;
    final event5 = maatDecanFlowEventByNumber(khat, 5)!;
    final event7 = maatDecanFlowEventByNumber(khat, 7)!;
    final event9 = maatDecanFlowEventByNumber(khat, 9)!;

    expect(event1.steps, <String>[
      'Sit or lie down.',
      'Move attention from feet to face.',
      'Write three things the body is communicating right now, without judging or correcting them.',
    ]);
    expect(event1.purpose, contains('The inventory is not an assessment'));

    expect(event5.steps, <String>[
      'After washing, apply oil, lotion, cream, or water to some part of the body with deliberate attention.',
      'Begin with the forehead if that is available to you.',
      'Record what the act returned to your relationship with the body.',
      'Keep body details private by default.',
    ]);
    expect(event5.purpose, contains('anointed the forehead first'));

    expect(event7.spokenLine, isNot(contains('Speak this')));
    expect(event7.spokenLine, isNot(contains('Then begin')));
    expect(event7.steps, contains('Speak the line before beginning to move.'));
    expect(
      event7.steps,
      contains(
        'Begin moving deliberately for at least 20 minutes before logging.',
      ),
    );

    expect(
      event9.steps,
      containsAll(<String>[
        'Stand fully at the end.',
        'Record the khat’s current state compared to Day 1.',
      ]),
    );
  });

  test('Khat words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];
    final khat = maatDecanFlowDefinitionForKey(kKhatFlowKey)!;

    for (final event in khat.events) {
      for (final pattern in _khatWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Khat steps keep source-note phrases out of actions', () {
    final issues = <String>[];
    final khat = maatDecanFlowDefinitionForKey(kKhatFlowKey)!;

    for (final event in khat.events) {
      for (final step in event.steps) {
        if (_khatSourceNotePhrasePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Hotep copy keeps words speakable and closing actions explicit', () {
    final hotep = maatDecanFlowDefinitionForKey(kHotepFlowKey)!;
    final event1 = maatDecanFlowEventByNumber(hotep, 1)!;
    final event4 = maatDecanFlowEventByNumber(hotep, 4)!;
    final event5 = maatDecanFlowEventByNumber(hotep, 5)!;
    final event7 = maatDecanFlowEventByNumber(hotep, 7)!;
    final event9 = maatDecanFlowEventByNumber(hotep, 9)!;

    expect(event1.steps, <String>[
      'Place water on your surface.',
      'Sit somewhere you actually rest, not in a working position.',
      'Write what you are currently offering: time, labor, care, attention, skill.',
      'Write what is owed.',
      'Drink the water.',
    ]);
    expect(event1.purpose, contains('Hotep does not happen'));

    expect(
      event4.spokenLine,
      'Do not go to bed fearing tomorrow. God is success; man is failure.',
    );
    expect(event4.steps, <String>[
      'Speak the line before the question.',
      'Sit with the question for at least two minutes: Has the offering of this period been made?',
      'Answer with the Day 1 measure, not with a vague feeling of enough.',
      'Write: The offering is complete, or The offering is incomplete in [specific way].',
    ]);

    expect(
      event5.steps,
      containsAll(<String>[
        'Draw a line through each one.',
        'Place the page away from the bed.',
        'Name what remains that is genuinely yours.',
      ]),
    );
    expect(event5.purpose, contains('the real offering'));

    expect(
      event7.steps,
      containsAll(<String>[
        'Place water beside you.',
        'Sit.',
        'Speak the line.',
      ]),
    );

    expect(
      event9.spokenLine,
      'These your cool waters have come from your son. Your heart will not become weary with it. Hotep.',
    );
    expect(event9.steps, <String>[
      'Place water where you will be before sleep.',
      'Sit where you will be before sleep.',
      'Name aloud what you offered across this flow: time, labor, care, presence, skill.',
      'Speak: What was owed has been given.',
      'Write anything left in the bed that is not yours to control.',
      'Place the paper away from where you sleep.',
      'Drink the water.',
      'Lie down to sleep.',
    ]);
    expect(event9.purpose, contains('The act is physical'));
  });

  test('Hotep words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];
    final hotep = maatDecanFlowDefinitionForKey(kHotepFlowKey)!;

    for (final event in hotep.events) {
      for (final pattern in _hotepWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Hotep steps keep source-note phrases out of actions', () {
    final issues = <String>[];
    final hotep = maatDecanFlowDefinitionForKey(kHotepFlowKey)!;

    for (final event in hotep.events) {
      for (final step in event.steps) {
        if (_hotepSourceNotePhrasePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Open Mouth copy keeps words speakable and truth checks in steps', () {
    final openMouth = maatDecanFlowDefinitionForKey(kOpenMouthFlowKey)!;
    final event2 = maatDecanFlowEventByNumber(openMouth, 2)!;
    final event3 = maatDecanFlowEventByNumber(openMouth, 3)!;
    final event4 = maatDecanFlowEventByNumber(openMouth, 4)!;
    final event5 = maatDecanFlowEventByNumber(openMouth, 5)!;
    final event6 = maatDecanFlowEventByNumber(openMouth, 6)!;
    final event7 = maatDecanFlowEventByNumber(openMouth, 7)!;
    final event8 = maatDecanFlowEventByNumber(openMouth, 8)!;
    final event9 = maatDecanFlowEventByNumber(openMouth, 9)!;

    expect(event2.steps, <String>[
      'Choose one piece of speech from the last five days.',
      'Write what it created.',
      'Choose one thing not said.',
      'Write what its absence created.',
      'Name the speech pattern from Day 1 that the next ten-day section should govern.',
    ]);
    expect(
      event3.steps,
      contains(
        'Write: In the next ten-day section, I will practice [discipline]. I will say [needed thing].',
      ),
    );
    expect(
      event4.steps,
      contains('Choose one discipline for this ten-day section.'),
    );
    expect(event4.steps, contains('Define the specific practice.'));

    expect(event5.steps, <String>[
      'Name one thing you did not say this decan that was better kept back.',
      'Check whether the thing that needs to be said has been said.',
      'If it has not been said, name the time before this ten-day section ends when you will say it.',
      'Practice one deliberate pause in a conversation today.',
    ]);
    expect(event5.requiresRealWorldAction, isTrue);

    expect(
      event6.steps,
      contains('Record whether the important thing has been said.'),
    );
    expect(
      event6.steps,
      contains('If it has not been said, name what remains in the way.'),
    );
    expect(
      event6.steps,
      contains(
        'Name one conversation that changed when the mouth was governed.',
      ),
    );
    expect(event7.purpose, contains('not ready to be declared'));
    expect(event7.steps, contains('Write it first.'));
    expect(
      event7.steps,
      isNot(
        contains(
          'Write it first. What is not fully conceived is not ready to be declared.',
        ),
      ),
    );
    expect(
      event8.steps,
      contains('If it has not been said, say it before the closing sitting.'),
    );
    expect(event8.requiresRealWorldAction, isTrue);

    expect(
      event9.spokenLine,
      'My mouth is open. My speech is governed. What I command, I create with care.',
    );
    expect(event9.steps, <String>[
      'Name the most significant speech pattern the inventory revealed.',
      'Name what the governance practice produced.',
      'Name what was spoken that needed to be spoken: I said [thing] on [day]. It is now in the world.',
      'Check whether the line is true before speaking it.',
      'Speak only the parts of the line that are true.',
      'Say, if true: My speech was not heated.',
      'Say, if true: My heart was not hasty.',
      'Say, if true: I said what needed to be said.',
      'Sit in intentional silence for one full minute.',
    ]);
    expect(
      event9.extraCompletionStatusLabels,
      containsPair('spoken', 'Spoken'),
    );
  });

  test('Open Mouth words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];
    final openMouth = maatDecanFlowDefinitionForKey(kOpenMouthFlowKey)!;

    for (final event in openMouth.events) {
      for (final pattern in _openMouthWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Open Mouth steps keep source-note phrases out of actions', () {
    final issues = <String>[];
    final openMouth = maatDecanFlowDefinitionForKey(kOpenMouthFlowKey)!;

    for (final event in openMouth.events) {
      for (final step in event.steps) {
        if (_openMouthSourceNotePhrasePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Oracle copy keeps invocation, recording, and action sequences clear', () {
    final oracle = maatDecanFlowDefinitionForKey(kOracleFlowKey)!;
    final event1 = maatDecanFlowEventByNumber(oracle, 1)!;
    final event3 = maatDecanFlowEventByNumber(oracle, 3)!;
    final event4 = maatDecanFlowEventByNumber(oracle, 4)!;
    final event6 = maatDecanFlowEventByNumber(oracle, 6)!;
    final event7 = maatDecanFlowEventByNumber(oracle, 7)!;
    final event9 = maatDecanFlowEventByNumber(oracle, 9)!;

    expect(event1.steps, <String>[
      'Before sleep, clear the space near your head.',
      'Place one small object there.',
      'Write your oracle question on paper.',
      'Set the paper under or beside the object.',
    ]);

    expect(event3.steps, <String>[
      'Before lying down, address the deity, principle, Ba, Ka, Ma’at, or divine presence you are asking.',
      'Speak the question once, clearly and completely.',
      'Lie down.',
      'Do not speak again before sleep.',
    ]);
    expect(
      event3.steps,
      isNot(
        contains(
          'Address the deity, principle, Ba, Ka, Ma’at, or divine presence you are asking.',
        ),
      ),
    );
    expect(
      event3.steps,
      isNot(
        contains(
          'Speak the question clearly once. Do not speak again before sleep.',
        ),
      ),
    );

    expect(event4.steps, <String>[
      'Immediately upon waking, reach for the notebook before the phone or speaking to anyone.',
      'Record images, words, feelings, colors, sequence, and atmosphere.',
      'Do not interpret yet.',
    ]);
    expect(
      event4.steps.where((step) => step.contains('Do not interpret yet')),
      hasLength(1),
    );
    expect(
      event4.steps.indexWhere((step) => step.startsWith('Record images')),
      lessThan(event4.steps.indexOf('Do not interpret yet.')),
    );

    expect(
      event6.steps,
      contains(
        'Review all recorded dreams from the first two ten-day sections.',
      ),
    );

    expect(event7.steps, <String>[
      'Ask what the recurring element does.',
      'Ask what principle it carries.',
      'Ask how it relates to the oracle question.',
      'Ask what action it indicates without treating disturbing dream content as definitive truth.',
    ]);

    expect(event9.steps, <String>[
      'If the oracle indicated a specific action, take that action before logging this event.',
      'If the oracle stayed unclear, do only the grounded action you can justify before logging this event.',
      'Write the complete oracle record: question, what the night sent, what it indicated or left unclear, and what action was taken.',
    ]);
    expect(event9.requiresRealWorldAction, isTrue);
    expect(
      event9.extraCompletionStatusLabels,
      containsPair('oracle_complete', 'Oracle complete'),
    );
  });

  test('Oracle words fields do not contain stage-direction wrappers', () {
    final issues = <String>[];
    final oracle = maatDecanFlowDefinitionForKey(kOracleFlowKey)!;

    for (final event in oracle.events) {
      for (final pattern in _oracleWordsStageDirectionPatterns) {
        if (pattern.hasMatch(event.spokenLine)) {
          issues.add(
            'Event ${event.eventNumber} ${event.title}: ${event.spokenLine}',
          );
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('Oracle steps keep source-note phrases out of actions', () {
    final issues = <String>[];
    final oracle = maatDecanFlowDefinitionForKey(kOracleFlowKey)!;

    for (final event in oracle.events) {
      for (final step in event.steps) {
        if (_oracleSourceNotePhrasePattern.hasMatch(step)) {
          issues.add('Event ${event.eventNumber}: $step');
        }
      }
    }

    expect(issues, isEmpty);
  });

  test('representative source-note upgrades are stored', () {
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kBoundaryStoneFlowKey)!,
        5,
      )!.sourceNote,
      'Amenemope\'s image of the gullet rejecting what was taken past measure is viscerally physical — bread swallowed and spat up, property that becomes an obstruction in the throat. The excess does not stay. It produces visible evidence that the measure was exceeded.',
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kHouseOfLifeFlowKey)!,
        9,
      )!.sourceNote,
      'Chester Beatty IV called the scribes\' writing their memory-priest — the mechanism of their continued existence. The precise sentence that closes this flow is the user\'s contribution to the same chain. What you can now say accurately, you can now transmit.',
    );
    expect(
      maatDecanFlowEventByNumber(
        maatDecanFlowDefinitionForKey(kOracleFlowKey)!,
        9,
      )!.sourceNote,
      'Thutmose\'s stela records the dream and then records that he commanded the sand to be cleared. The action is what closes the Stela\'s account — not the dream, not the interpretation, but the act taken in response.',
    );
  });

  test(
    'sensitive Ma’at decan flows keep event notes free of disclaimer copy',
    () {
      final wandering = maatDecanFlowDefinitionForKey(kWanderingFlowKey)!;
      final khat = maatDecanFlowDefinitionForKey(kKhatFlowKey)!;
      final oracle = maatDecanFlowDefinitionForKey(kOracleFlowKey)!;

      expect(wandering.safetyNote, contains('988 in the US'));
      expect(
        wandering.events.any((event) => event.sharePromptOnComplete),
        isFalse,
      );
      expect(
        maatDecanFlowDetailText(wandering, wandering.events.first),
        isNot(contains('This flow accompanies grief')),
      );

      final khatDetail = maatDecanFlowDetailText(khat, khat.events.first);
      expect(khatDetail, isNot(contains('This flow is not medical care')));
      expect(khatDetail.toLowerCase(), isNot(contains('appearance')));
      expect(khatDetail.toLowerCase(), isNot(contains('weight loss')));
      expect(khat.events.any((event) => event.sharePromptOnComplete), isFalse);

      final oracleDetail = maatDecanFlowDetailText(oracle, oracle.events.first);
      expect(oracleDetail, isNot(contains('disturbing dream content')));

      for (final definition in <MaatDecanFlowDefinition>[
        wandering,
        khat,
        oracle,
      ]) {
        for (final event in definition.events) {
          final detail = maatDecanFlowDetailText(definition, event);
          expect(detail, isNot(contains('Source\n')));
          expect(detail, isNot(contains('Confidence\n')));
        }
      }
    },
  );

  test('Ma’at decan detail notes stay event-action focused', () {
    final definition = maatDecanFlowDefinitionForKey(kLivingRecordFlowKey)!;
    final firstEvent = maatDecanFlowEventByNumber(definition, 1)!;
    final detail = maatDecanFlowDetailText(definition, firstEvent);

    expect(detail, startsWith('Words\n'));
    expect(detail, contains('Steps\n1. Open today\'s day card'));
    expect(detail, contains('Complete\nMark Living Record 1 observed'));
    expect(detail, isNot(contains('Purpose\n')));
    expect(detail, isNot(contains('Timing\n')));
    expect(detail, isNot(contains('Privacy\n')));
    expect(detail, isNot(contains('Confidence\n')));
    expect(detail, isNot(contains('Source\n')));
    expect(detail, isNot(contains('specific app action')));
    expect(detail, isNot(contains('Merer')));

    final closingEvent = definition.events.last;
    final closingDetail = maatDecanFlowDetailText(definition, closingEvent);

    expect(
      closingDetail,
      contains('Use Record complete only when that is the real outcome.'),
    );
  });
}

final _khatWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*speak this\b', caseSensitive: false),
  RegExp(r'\bbefore beginning\b', caseSensitive: false),
  RegExp(r'\bthen begin\b', caseSensitive: false),
];

final _livingTextWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*write\b', caseSensitive: false),
  RegExp(r'\bthen speak\b', caseSensitive: false),
  RegExp(r'\bbefore .*speak\b', caseSensitive: false),
  RegExp(r'\bspeak:\b', caseSensitive: false),
];

final _livingTextRequiredStepRationalePattern = RegExp(
  r'\b(as useful to the record|This makes|Shared,|decan doing its work|worth leaving in the record|source note)\b',
  caseSensitive: false,
);

final _livingTextRequiredStepOptionalPattern = RegExp(
  r'\b(optionally|if desired|share the useful part|share the final line|use Post to share|Shared,)\b',
  caseSensitive: false,
);

final _fairHearingWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'\bspeak only\b', caseSensitive: false),
  RegExp(r'\bif true\b', caseSensitive: false),
  RegExp(r'\btrue lines\b', caseSensitive: false),
  RegExp(r'\btruth-check\b', caseSensitive: false),
];

final _fairHearingRequiredStepRationalePattern = RegExp(
  r'\b(This is where the fair hearing is most needed|The conclusion that forms|is premature|not a fair hearing|efficient confirmation|Ptahhotep|Khunanup|Eloquent Peasant|source note|dramatic silence|ordinary silence)\b',
  caseSensitive: false,
);

final _fairHearingRequiredStepOptionalSharingPattern = RegExp(
  r'\b(optionally|if desired|share|post|public)\b',
  caseSensitive: false,
);

final _houseOfLifeWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*(before|after|then)\b', caseSensitive: false),
  RegExp(r'\bspeak only\b', caseSensitive: false),
  RegExp(r'\bif true\b', caseSensitive: false),
  RegExp(r'\btrue lines\b', caseSensitive: false),
  RegExp(r'\btruth-check\b', caseSensitive: false),
];

final _houseOfLifeRequiredStepRationalePattern = RegExp(
  r'\b(The gaps are not failures|Per Ankh.s next assignment|Collapse is useful data|depends on the text rather than on itself|This is where the practice begins|Choose what is accurate enough|Do or record the transmission|source note|Chester Beatty|passive custodians|The source your current understanding|The scribe who could only locate)\b',
  caseSensitive: false,
);

final _houseOfLifeRequiredStepOptionalSharingPattern = RegExp(
  r'\b(optionally|if desired|share|post|public)\b',
  caseSensitive: false,
);

final _livingPatternWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'\bbefore writing\b', caseSensitive: false),
  RegExp(r'\bsay it aloud\b', caseSensitive: false),
  RegExp(r'\bthen write\b', caseSensitive: false),
  RegExp(r'\boptionally\b', caseSensitive: false),
];

final _livingPatternRationalePattern = RegExp(
  r'\b(Anubis theology|source note|not from what the subject is supposed to represent|patient watching over thirty days|lesson extracted|Then write it)\b',
  caseSensitive: false,
);

final _livingRecordWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*speak the line\b', caseSensitive: false),
  RegExp(r'^\s*write\b', caseSensitive: false),
  RegExp(r'\bthen\b', caseSensitive: false),
  RegExp(r'\bif possible\b', caseSensitive: false),
];

final _livingRecordRationalePattern = RegExp(
  r'\b(record has been opened|Specific is more useful|Badges are signals|entry has been recognized|record is being read|Merer|Palermo Stone|source note|specific app action)\b',
  caseSensitive: false,
);

final _trueNameWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*stand\b', caseSensitive: false),
  RegExp(r'\bstanding\b', caseSensitive: false),
  RegExp(r'\bbefore speaking\b', caseSensitive: false),
  RegExp(r'\bthen:\b', caseSensitive: false),
  RegExp(r'\bthen speak\b', caseSensitive: false),
  RegExp(r'\bwhile seated\b', caseSensitive: false),
];

final _trueNameSourceNotePhrasePattern = RegExp(
  r'\b(Ren theology|Memphite Theology|Declaration of Innocence|42 Assessors|source note|posture was not ceremonial|heart conceives before)\b',
  caseSensitive: false,
);

final _hetHeruWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*speak only\b', caseSensitive: false),
  RegExp(r'\btrue lines\b', caseSensitive: false),
  RegExp(r'\bif true\b', caseSensitive: false),
  RegExp(r'\bclosing instructions\b', caseSensitive: false),
];

final _hetHeruSourceNotePhrasePattern = RegExp(
  r'\b(Book of the Heavenly Cow|Dendera|source note|same Eye in different modes|not the defeat|token gesture)\b',
  caseSensitive: false,
);

final _clearingWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*speak only\b', caseSensitive: false),
  RegExp(r'\btrue lines\b', caseSensitive: false),
  RegExp(r'\bif true\b', caseSensitive: false),
  RegExp(r'\boptionally\b', caseSensitive: false),
  RegExp(r'\bshare only\b', caseSensitive: false),
];

final _clearingSourceNotePhrasePattern = RegExp(
  r'\b(Amenemope|source note|foliage|enclosed space|surrounded by other trees|side effect)\b',
  caseSensitive: false,
);

final _wanderingWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*before\b', caseSensitive: false),
  RegExp(r'\bthen stand\b', caseSensitive: false),
  RegExp(r'\bthen choose\b', caseSensitive: false),
  RegExp(r'\bbefore logging\b', caseSensitive: false),
];

final _wanderingRationalePhrasePattern = RegExp(
  r'\b(Pyramid Texts|source|because|provision the body needs|The provision|not a demand to stop grieving)\b',
  caseSensitive: false,
);

final _firstArrangementWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*physically\b', caseSensitive: false),
  RegExp(r'^\s*write\b', caseSensitive: false),
  RegExp(r'^\s*stand\b', caseSensitive: false),
  RegExp(r'\bdo not\b', caseSensitive: false),
];

final _firstArrangementRationalePattern = RegExp(
  r'\b(boundary stone|Zep Tepi|Temple|source|because|does the same damage|one-time reset|without thinking about it)\b',
  caseSensitive: false,
);

final _khatSourceNotePhrasePattern = RegExp(
  r'\b(Pyramid Texts|source|because)\b',
  caseSensitive: false,
);

final _hotepWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*speak this\b', caseSensitive: false),
  RegExp(r'\bbefore the question\b', caseSensitive: false),
  RegExp(r'\bthen sit\b', caseSensitive: false),
  RegExp(r'\bhas the offering\b', caseSensitive: false),
];

final _hotepSourceNotePhrasePattern = RegExp(
  r'\b(Pyramid Texts|Amenemope|source|because)\b',
  caseSensitive: false,
);

final _openMouthWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*speak only\b', caseSensitive: false),
  RegExp(r'\bthen sit\b', caseSensitive: false),
  RegExp(r'\bintentional silence\b', caseSensitive: false),
];

final _openMouthSourceNotePhrasePattern = RegExp(
  r'\b(Memphite Theology|Opening of the Mouth|source|because)\b',
  caseSensitive: false,
);

final _oracleWordsStageDirectionPatterns = <RegExp>[
  RegExp(r'^\s*speak the invocation\b', caseSensitive: false),
  RegExp(r'\bbefore lying down\b', caseSensitive: false),
  RegExp(r'\bdo not speak again\b', caseSensitive: false),
  RegExp(r'\bimmediately upon waking\b', caseSensitive: false),
  RegExp(r'\bdo not interpret yet\b', caseSensitive: false),
];

final _oracleSourceNotePhrasePattern = RegExp(
  r'\b(Dream Stela|Temple dream|Thutmose|source|because)\b',
  caseSensitive: false,
);
