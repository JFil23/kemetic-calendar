import 'package:flutter/foundation.dart';

import '../../the_djed_v2_flow.dart';

enum DjedSupportCondition { unassessed, holding, underPressure, wobbling }

@immutable
class DjedSupportFixture {
  const DjedSupportFixture({
    required this.name,
    required this.condition,
    this.released = false,
  });

  final String name;
  final DjedSupportCondition condition;
  final bool released;
}

@immutable
class DjedSittingFixture {
  const DjedSittingFixture({
    required this.number,
    required this.flowDay,
    required this.phase,
    required this.title,
    required this.timeLabel,
    required this.durationLabel,
  });

  final int number;
  final int flowDay;
  final String phase;
  final String title;
  final String timeLabel;
  final String durationLabel;
}

const List<DjedSupportFixture> kDjedSupportFixtures = <DjedSupportFixture>[
  DjedSupportFixture(name: '', condition: DjedSupportCondition.unassessed),
  DjedSupportFixture(name: '', condition: DjedSupportCondition.unassessed),
  DjedSupportFixture(name: '', condition: DjedSupportCondition.unassessed),
  DjedSupportFixture(name: '', condition: DjedSupportCondition.unassessed),
];

const List<DjedSittingFixture> kDjedSittingFixtures = <DjedSittingFixture>[
  DjedSittingFixture(
    number: 1,
    flowDay: 1,
    phase: 'FIND YOUR FOOTING',
    title: 'Set your footing',
    timeLabel: 'Dawn + 30 min',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 2,
    flowDay: 5,
    phase: 'SUPPORT 01',
    title: 'Make one move',
    timeLabel: '11:00 local',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 3,
    flowDay: 9,
    phase: 'SUPPORT 01',
    title: 'Read the result',
    timeLabel: 'Dawn + 30 min',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 4,
    flowDay: 11,
    phase: 'SUPPORT 02',
    title: 'Make one move',
    timeLabel: 'Dawn + 30 min',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 5,
    flowDay: 15,
    phase: 'SUPPORT 02',
    title: 'Read the result',
    timeLabel: '11:00 local',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 6,
    flowDay: 19,
    phase: 'SUPPORT 03',
    title: 'Make one move',
    timeLabel: 'Sunset + 30 min',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 7,
    flowDay: 21,
    phase: 'SUPPORT 03',
    title: 'Read the result',
    timeLabel: 'Dawn + 30 min',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 8,
    flowDay: 25,
    phase: 'SUPPORT 04',
    title: 'Make one move',
    timeLabel: '11:00 local',
    durationLabel: '5 min',
  ),
  DjedSittingFixture(
    number: 9,
    flowDay: 29,
    phase: 'SUPPORT 04',
    title: 'Read the result',
    timeLabel: 'Dawn + 30 min',
    durationLabel: '10–15 min',
  ),
];

enum DjedPracticeStageVisual {
  orientation,
  makeMove,
  putOnCalendar,
  readResult,
  blocker,
  smallerRetry,
  finalRaising,
}

enum DjedResultVisualState { none, helped, noChange, notDone }

enum DjedCompletionVisualState { none, observed, partly, skipped }

@immutable
class DjedDayVisualFixture {
  const DjedDayVisualFixture({
    required this.sittingNumber,
    required this.stage,
    required this.supportSlot,
    required this.supportName,
    this.move = '',
    this.result = DjedResultVisualState.none,
    this.completion = DjedCompletionVisualState.none,
    this.resultNote = '',
    this.smallerMove = '',
    this.raised = false,
    this.raisingActive = false,
    this.raisingSecondsRemaining = 30,
  });

  final int sittingNumber;
  final DjedPracticeStageVisual stage;
  final int supportSlot;
  final String supportName;
  final String move;
  final DjedResultVisualState result;
  final DjedCompletionVisualState completion;
  final String resultNote;
  final String smallerMove;
  final bool raised;
  final bool raisingActive;
  final int raisingSecondsRemaining;
}

const DjedDayVisualFixture kDjedDayVisualFixture = DjedDayVisualFixture(
  sittingNumber: 4,
  stage: DjedPracticeStageVisual.makeMove,
  supportSlot: 2,
  supportName: 'the weekly call with my sister',
);

String authoredDjedSupportNameForSitting(int sitting) => switch (sitting) {
  1 => 'four supports · one at a time',
  4 || 5 => 'the weekly call with my sister',
  _ => '',
};

DjedDayVisualFixture djedDayVisualFixtureForEvent(
  DjedV2Event event, {
  String? supportName,
}) {
  final supportSlot = event.supportSlot ?? 1;
  final resolvedSupportName = supportName?.trim();
  return DjedDayVisualFixture(
    sittingNumber: event.eventNumber,
    stage: switch (event.stepKind) {
      DjedV2StepKind.orientation => DjedPracticeStageVisual.orientation,
      DjedV2StepKind.makeMove => DjedPracticeStageVisual.makeMove,
      DjedV2StepKind.readResult when event.finalRaising =>
        DjedPracticeStageVisual.finalRaising,
      DjedV2StepKind.readResult => DjedPracticeStageVisual.readResult,
    },
    supportSlot: supportSlot,
    supportName: resolvedSupportName?.isNotEmpty == true
        ? resolvedSupportName!
        : authoredDjedSupportNameForSitting(event.eventNumber),
  );
}

String djedSheetSupportBarLabel({
  required int slotNumber,
  required String name,
}) {
  final number = slotNumber.toString().padLeft(2, '0');
  final trimmed = name.trim();
  if (trimmed.isEmpty) return number;
  final clipped = trimmed.length > 20
      ? '${trimmed.substring(0, 19)}…'
      : trimmed;
  return '$number · $clipped';
}
