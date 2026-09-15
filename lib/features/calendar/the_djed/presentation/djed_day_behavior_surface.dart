import 'package:flutter/material.dart';

import '../../the_djed_v2_flow.dart';
import 'djed_day_presentation.dart';
import 'djed_sitting_behavior_surface.dart';

/// Connects shared Djed sitting state to the Day View presentation only.
class DjedDayBehaviorSurface extends StatelessWidget {
  const DjedDayBehaviorSurface({
    super.key,
    required this.flowId,
    required this.event,
    required this.baseFixture,
    required this.supports,
    required this.onCompletionCommit,
    this.onPutOnCalendar,
  });

  final int flowId;
  final DjedV2Event event;
  final DjedDayVisualFixture baseFixture;
  final List<DjedSupportFixture> supports;
  final Future<void> Function(
    DjedCompletionVisualState state,
    String move,
    DjedResultVisualState result,
    String resultNote,
    String smallerMove,
    bool raised,
  )
  onCompletionCommit;
  final Future<void> Function()? onPutOnCalendar;

  @override
  Widget build(BuildContext context) {
    return DjedSittingBehaviorSurface(
      flowId: flowId,
      event: event,
      baseFixture: baseFixture,
      onPutOnCalendar: onPutOnCalendar,
      onCompletionCommit: onCompletionCommit,
      builder: (context, fixture, actions) => DjedDayPresentation(
        fixture: fixture,
        supports: supports,
        onMoveChanged: actions.onMoveChanged,
        onDoToday: actions.onDoToday,
        onPutOnCalendar: actions.onPutOnCalendar,
        onResultSelected: actions.onResultSelected,
        onResultNoteChanged: actions.onResultNoteChanged,
        onSmallerMoveChanged: actions.onSmallerMoveChanged,
        onCloseBeam: actions.onCloseBeam,
        onRaise: actions.onRaise,
        onCompletionSelected: actions.onCompletionSelected,
      ),
    );
  }
}
