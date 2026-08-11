import 'calendar_hydration_diagnostics.dart';

enum CalendarHydrationPublicationPhase { flowEvents, complete }

bool hydrationFetchSucceeded(HydrationFetchStatus status) =>
    status == HydrationFetchStatus.successNonempty ||
    status == HydrationFetchStatus.successfulEmpty;

bool calendarHydrationIsSemanticallyComplete({
  required bool catalogComplete,
  required HydrationFetchStatus flowEvents,
  required HydrationFetchStatus standalone,
}) =>
    catalogComplete &&
    hydrationFetchSucceeded(flowEvents) &&
    hydrationFetchSucceeded(standalone);

bool shouldPublishVisibleCalendarHydration({
  required CalendarHydrationPublicationPhase phase,
  required bool loadComplete,
}) {
  // Flow and standalone hydration run concurrently, but neither lane owns a
  // visible server snapshot by itself. Local state remains authoritative until
  // both required lanes have produced the complete result for this pass.
  return phase == CalendarHydrationPublicationPhase.complete && loadComplete;
}

bool shouldPreservePaintedStandaloneLaneForHydrationCommit({
  required String source,
  required String commitPhase,
  required bool hasPaintedStandaloneLane,
}) {
  return hasPaintedStandaloneLane &&
      source == 'invalidation:calendarImportSynced' &&
      commitPhase == 'complete';
}
