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
      'Stand. Speak the accurate account, then speak the evidence. Then: I am pure, I am pure, I am pure, I am pure. Standing, four times.',
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
      'Write the closing mark and then speak: Completed correctly; the living text includes this mark.',
    );
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
