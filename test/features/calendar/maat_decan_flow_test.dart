import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/calendar/maat_decan_flow.dart';
import 'package:mobile/features/calendar/track_sky_flow.dart';

void main() {
  test('Ma’at decan flows register standard 30-day sparse practices', () {
    final keys = kMaatDecanFlowDefinitions
        .map((definition) => definition.key)
        .toList(growable: false);

    expect(keys, hasLength(13));
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
      expect(payload['routing_summary'], definition.routingSummary);
      expect(payload['schedule'], containsPair('timezone', 'pacific'));
    }
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
  });

  test('new Ma’at flow events keep direct event notes and action gates', () {
    for (final definition in <MaatDecanFlowDefinition>[
      maatDecanFlowDefinitionForKey(kTheShoreFlowKey)!,
      maatDecanFlowDefinitionForKey(kTheAutobiographyFlowKey)!,
      maatDecanFlowDefinitionForKey(kFirstArrangementFlowKey)!,
      maatDecanFlowDefinitionForKey(kLivingPatternFlowKey)!,
      maatDecanFlowDefinitionForKey(kTrueNameFlowKey)!,
      maatDecanFlowDefinitionForKey(kLivingTextFlowKey)!,
    ]) {
      for (final event in definition.events) {
        expect(event.steps.length, inInclusiveRange(2, 4));
        expect(event.sourceNote?.length ?? 0, lessThan(260));
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
  });

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
